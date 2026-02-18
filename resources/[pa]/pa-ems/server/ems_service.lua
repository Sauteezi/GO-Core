local RESOURCE_NAME = GetCurrentResourceName()

local PatientState = {}
local ActiveBeds = {}
local GoodSamaritanCooldown = {}

local HOSPITAL_BEDS = {
    { id = 'pillbox-1', label = 'Pillbox Bed 1', coords = vec3(308.21, -590.12, 43.29) },
    { id = 'pillbox-2', label = 'Pillbox Bed 2', coords = vec3(313.42, -584.75, 43.29) },
    { id = 'sandy-1', label = 'Sandy Bed 1', coords = vec3(1828.1, 3678.46, 34.27) },
}

local INJURY_VALUES = { minor = true, major = true, critical = true }

local function nowIso()
    return os.date('!%Y-%m-%dT%H:%M:%SZ')
end

local function getCharId(src)
    if GetResourceState('pa-core') ~= 'started' then return nil end
    return exports['pa-core']['PaCore:GetCharId'](src)
end

local function getJob(src)
    if GetResourceState('pa-jobs') ~= 'started' then return nil end
    return exports['pa-jobs']['PaJobs:GetJob'](src)
end

local function isEmsOnDuty(src)
    local job = getJob(src)
    return type(job) == 'table' and job.name == 'ems' and job.onDuty == true
end

local function isRateLimited(src, key, maxPerWindow, windowMs)
    if GetResourceState('pa-guard') ~= 'started' then return false end
    local ok = exports['pa-guard']['PaGuard:RateLimit'](src, key, maxPerWindow, windowMs)
    return ok ~= true
end

local function validateDistance(src, coords, maxDistance)
    if GetResourceState('pa-guard') ~= 'started' then return true end
    return exports['pa-guard']['PaGuard:ValidateDistance'](src, coords, maxDistance) == true
end

local function logEvent(levelExport, payload)
    if GetResourceState('pa-logging') ~= 'started' then return end
    pcall(function() exports['pa-logging'][levelExport](payload) end)
end

local function notify(src, kind, title, message)
    if GetResourceState('pa-ui') ~= 'started' then return end
    exports['pa-ui']['PaUI:Notify'](kind, title, message, 4500)
end

local function querySync(query, params)
    if GetResourceState('oxmysql') ~= 'started' then return {} end
    local done, rows = false, {}
    exports.oxmysql:execute(query, params or {}, function(r) rows = r or {}; done = true end)
    while not done do Wait(0) end
    return rows
end

local function ensurePatient(src)
    local key = tostring(src)
    PatientState[key] = PatientState[key] or {
        injury = 'minor',
        transported = false,
        insured = true,
        updatedAt = nowIso(),
    }
    return PatientState[key]
end

local function setInjury(src, injury)
    injury = tostring(injury or 'minor'):lower()
    if not INJURY_VALUES[injury] then return false, 'Invalid injury state.' end
    local patient = ensurePatient(src)
    patient.injury = injury
    patient.updatedAt = nowIso()
    TriggerClientEvent('pa:ems:injuryUpdated', src, patient)
    return true, patient
end

local function reserveBed(src, bedId)
    for _, bed in ipairs(HOSPITAL_BEDS) do
        if bed.id == bedId then
            if ActiveBeds[bedId] and ActiveBeds[bedId] ~= src then
                return false, 'Bed is occupied.'
            end
            ActiveBeds[bedId] = src
            local patient = ensurePatient(src)
            patient.transported = true
            patient.bedId = bedId
            patient.updatedAt = nowIso()
            return true, bed
        end
    end
    return false, 'Unknown hospital bed.'
end

local function releaseBed(src)
    for bedId, occupier in pairs(ActiveBeds) do
        if occupier == src then
            ActiveBeds[bedId] = nil
        end
    end

    local patient = ensurePatient(src)
    patient.transported = false
    patient.bedId = nil
    patient.updatedAt = nowIso()
end

local function hasReviveSupplies(src)
    if GetResourceState('pa-inventory') ~= 'started' then
        return false, 'Inventory dependency unavailable.'
    end

    local haveKit = exports['pa-inventory']['PaInventory:HasItem'](src, 'medkit', 1)
    local haveBandage = exports['pa-inventory']['PaInventory:HasItem'](src, 'bandage', 1)

    if haveKit == true then return true, 'medkit' end
    if haveBandage == true then return true, 'bandage' end

    return false, 'Need a medkit or bandage to revive.'
end

local function consumeReviveItem(src, itemName)
    if GetResourceState('pa-inventory') ~= 'started' then return false end
    exports['pa-inventory']['PaInventory:RemoveItem'](src, itemName, 1, {}, 'ems_revive_use')
    return true
end

local function writeMajorIncidentRecord(emsSrc, patientSrc, context)
    local emsCharId = getCharId(emsSrc)
    local patientCharId = getCharId(patientSrc)
    local patient = ensurePatient(patientSrc)

    if patient.injury ~= 'major' and patient.injury ~= 'critical' then return end

    if GetResourceState('oxmysql') ~= 'started' then return end

    exports.oxmysql:insert([[INSERT INTO ems_records
        (medic_char_id, patient_char_id, diagnosis, treatment, incident_severity, hospital_name, outcome, billing_amount, context_json)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)]], {
        emsCharId,
        patientCharId,
        tostring(context.diagnosis or 'major incident'),
        tostring(context.treatment or 'stabilized and transported'),
        patient.injury,
        tostring(context.hospitalName or 'Pillbox Medical Center'),
        tostring(context.outcome or 'stabilized'),
        tonumber(context.billingAmount) or 0,
        json.encode(context.extra or {}),
    })
end

local function calculateBill(patientSrc, baseAmount)
    baseAmount = math.max(0, math.floor(tonumber(baseAmount) or 0))
    local patient = ensurePatient(patientSrc)
    local reduction = patient.insured and 0.45 or 0.0
    local finalAmount = math.floor(baseAmount * (1.0 - reduction))
    finalAmount = math.max(100, finalAmount)
    return finalAmount, reduction
end

local function issueHospitalBill(actorSrc, patientSrc, baseAmount, reason)
    local amount, insuranceCut = calculateBill(patientSrc, baseAmount)
    local ok, err = exports['pa-economy']['PaEconomy:RemoveMoney'](patientSrc, 'bank', amount, reason or 'hospital_bill', {
        actor = actorSrc,
        insuranceReduction = insuranceCut,
    })

    if not ok then
        return false, err or 'Unable to process bill.'
    end

    if GetResourceState('oxmysql') == 'started' then
        exports.oxmysql:insert([[INSERT INTO ems_billing
            (patient_char_id, medic_char_id, amount, insurance_reduction, reason, status)
            VALUES (?, ?, ?, ?, ?, 'paid')]], {
            getCharId(patientSrc),
            getCharId(actorSrc),
            amount,
            insuranceCut,
            tostring(reason or 'hospital_bill'),
        })
    end

    logEvent('PaLogging:LogEconomy', {
        resource = RESOURCE_NAME,
        source = actorSrc,
        action = 'hospital_bill_paid',
        message = 'Hospital bill processed.',
        meta = {
            patientSrc = patientSrc,
            amount = amount,
            insuranceReduction = insuranceCut,
        },
    })

    return true, amount
end

local function emsRevive(src, targetSrc, payload)
    if not isEmsOnDuty(src) then return false, 'Must be on EMS duty.' end

    targetSrc = tonumber(targetSrc)
    if not targetSrc then return false, 'Invalid target.' end

    if isRateLimited(src, 'ems:revive', 6, 20000) then
        return false, 'Revive cooldown active.'
    end

    payload = type(payload) == 'table' and payload or {}
    if type(payload.coords) ~= 'table' or not validateDistance(src, payload.coords, 4.0) then
        return false, 'Revive failed: proximity validation failed.'
    end

    local haveItem, itemOrReason = hasReviveSupplies(src)
    if not haveItem then return false, itemOrReason end

    consumeReviveItem(src, itemOrReason)

    local okInjury = setInjury(targetSrc, 'minor')
    if not okInjury then
        return false, 'Unable to update injury state.'
    end

    TriggerClientEvent('pa:ems:revived', targetSrc, { by = src, at = nowIso() })
    notify(src, 'success', 'EMS', 'Patient revived and stabilized.')
    notify(targetSrc, 'success', 'Medical', 'You were revived by EMS.')

    return true, 'Patient revived.'
end

local function emsTransport(src, targetSrc, bedId)
    if not isEmsOnDuty(src) then return false, 'Must be on EMS duty.' end

    targetSrc = tonumber(targetSrc)
    if not targetSrc then return false, 'Invalid target.' end

    if isRateLimited(src, 'ems:transport', 10, 30000) then
        return false, 'Transport cooldown active.'
    end

    local okBed, bedOrErr = reserveBed(targetSrc, tostring(bedId or ''))
    if not okBed then return false, bedOrErr end

    TriggerClientEvent('pa:ems:transported', targetSrc, {
        bedId = bedOrErr.id,
        bedLabel = bedOrErr.label,
        coords = { x = bedOrErr.coords.x, y = bedOrErr.coords.y, z = bedOrErr.coords.z },
    })

    notify(src, 'success', 'EMS', ('Patient transported to %s.'):format(bedOrErr.label))
    return true, 'Patient transported.'
end

local function writeIncident(src, payload)
    if not isEmsOnDuty(src) then return false, 'Must be on EMS duty.' end

    payload = type(payload) == 'table' and payload or {}
    local patientSrc = tonumber(payload.patientSrc)
    if not patientSrc then return false, 'Patient source is required.' end

    local context = {
        diagnosis = tostring(payload.diagnosis or 'major trauma'),
        treatment = tostring(payload.treatment or 'stabilized'),
        hospitalName = tostring(payload.hospitalName or 'Pillbox Medical Center'),
        outcome = tostring(payload.outcome or 'stable'),
        billingAmount = tonumber(payload.billingAmount) or 0,
        extra = type(payload.extra) == 'table' and payload.extra or {},
    }

    writeMajorIncidentRecord(src, patientSrc, context)
    return true, 'Incident recorded.'
end

local function billPatient(src, patientSrc, payload)
    if not isEmsOnDuty(src) then return false, 'Must be on EMS duty.' end

    patientSrc = tonumber(patientSrc)
    if not patientSrc then return false, 'Invalid patient.' end

    payload = type(payload) == 'table' and payload or {}
    local base = math.max(0, math.floor(tonumber(payload.baseAmount) or 650))
    local reason = tostring(payload.reason or 'ems_treatment_bill')

    local ok, result = issueHospitalBill(src, patientSrc, base, reason)
    if not ok then return false, result end

    notify(src, 'success', 'EMS Billing', ('Bill processed: $%s'):format(result))
    notify(patientSrc, 'info', 'Hospital', ('You were billed $%s for treatment.'):format(result))
    return true, result
end

local function goodSamaritanCall911(src, payload)
    if isRateLimited(src, 'ems:goodsam:911', 1, 90000) then
        return false, 'Please wait before making another emergency call.'
    end

    payload = type(payload) == 'table' and payload or {}
    local description = tostring(payload.description or 'Civilian requesting medical assistance.')
    local coords = type(payload.coords) == 'table' and payload.coords or nil
    if not coords then return false, 'Location required.' end

    local ok, result = exports['pa-dispatch']['PaDispatch:CreateCall'](src, {
        type = 'medical',
        priority = payload.priority or 'high',
        description = description,
        coords = coords,
    })

    if not ok then return false, result end
    notify(src, 'success', '911', ('Call #%s sent to EMS dispatch.'):format(result.id))
    return true, result
end

local function goodSamaritanCPR(src, targetSrc, payload)
    targetSrc = tonumber(targetSrc)
    if not targetSrc then return false, 'Invalid target.' end

    if isRateLimited(src, 'ems:goodsam:cpr', 1, 120000) then
        return false, 'You need to recover before trying CPR again.'
    end

    payload = type(payload) == 'table' and payload or {}
    if type(payload.coords) ~= 'table' or not validateDistance(src, payload.coords, 3.0) then
        return false, 'CPR failed: proximity validation failed.'
    end

    local patient = ensurePatient(targetSrc)
    if patient.injury == 'minor' then
        return false, 'Patient does not need CPR.'
    end

    local samKey = tostring(src)
    GoodSamaritanCooldown[samKey] = os.time()

    local newState = (patient.injury == 'critical') and 'major' or 'minor'
    setInjury(targetSrc, newState)

    notify(src, 'success', 'CPR', 'You provided basic CPR. EMS should still respond.')
    notify(targetSrc, 'info', 'Medical', 'A civilian performed CPR on you.')

    logEvent('PaLogging:LogInfo', {
        resource = RESOURCE_NAME,
        source = src,
        action = 'good_samaritan_cpr',
        message = 'Civilian performed basic CPR.',
        meta = {
            targetSrc = targetSrc,
            newState = newState,
        },
    })

    return true, 'CPR applied.'
end

RegisterNetEvent('pa:ems:setDuty', function(onDuty)
    local src = source
    local ok, reason = exports['pa-jobs']['PaJobs:SetDuty'](src, onDuty == true)
    if not ok then
        notify(src, 'error', 'EMS Duty', tostring(reason))
        return
    end

    notify(src, 'success', 'EMS Duty', onDuty and 'You are now on duty.' or 'You are now off duty.')
end)

RegisterNetEvent('pa:ems:setInjuryState', function(injury)
    local src = source
    local ok, result = setInjury(src, injury)
    TriggerClientEvent('pa:ems:actionResult', src, ok, result)
end)

RegisterNetEvent('pa:ems:revive', function(targetSrc, payload)
    local src = source
    local ok, result = emsRevive(src, targetSrc, payload)
    TriggerClientEvent('pa:ems:actionResult', src, ok, result)
end)

RegisterNetEvent('pa:ems:transport', function(targetSrc, bedId)
    local src = source
    local ok, result = emsTransport(src, targetSrc, bedId)
    TriggerClientEvent('pa:ems:actionResult', src, ok, result)
end)

RegisterNetEvent('pa:ems:releaseBed', function()
    local src = source
    releaseBed(src)
    TriggerClientEvent('pa:ems:actionResult', src, true, 'Bed released.')
end)

RegisterNetEvent('pa:ems:recordIncident', function(payload)
    local src = source
    local ok, result = writeIncident(src, payload)
    TriggerClientEvent('pa:ems:actionResult', src, ok, result)
end)

RegisterNetEvent('pa:ems:billPatient', function(patientSrc, payload)
    local src = source
    local ok, result = billPatient(src, patientSrc, payload)
    TriggerClientEvent('pa:ems:actionResult', src, ok, result)
end)

RegisterNetEvent('pa:ems:goodSamaritan911', function(payload)
    local src = source
    local ok, result = goodSamaritanCall911(src, payload)
    TriggerClientEvent('pa:ems:actionResult', src, ok, result)
end)

RegisterNetEvent('pa:ems:goodSamaritanCPR', function(targetSrc, payload)
    local src = source
    local ok, result = goodSamaritanCPR(src, targetSrc, payload)
    TriggerClientEvent('pa:ems:actionResult', src, ok, result)
end)

AddEventHandler('playerDropped', function()
    releaseBed(source)
end)

exports('PaEMS:SetInjuryState', function(src, injury)
    return setInjury(src, injury)
end)

exports('PaEMS:RevivePlayer', function(src, targetSrc, payload)
    return emsRevive(src, targetSrc, payload)
end)

exports('PaEMS:TransportPlayer', function(src, targetSrc, bedId)
    return emsTransport(src, targetSrc, bedId)
end)

exports('PaEMS:BillPatient', function(src, patientSrc, payload)
    return billPatient(src, patientSrc, payload)
end)

exports('PaEMS:GoodSamaritan911', function(src, payload)
    return goodSamaritanCall911(src, payload)
end)

exports('PaEMS:GoodSamaritanCPR', function(src, targetSrc, payload)
    return goodSamaritanCPR(src, targetSrc, payload)
end)

exports('PaEMS:GetHospitalBeds', function()
    return HOSPITAL_BEDS
end)

exports('PaEMS:GetPatientState', function(src)
    return ensurePatient(src)
end)
