local RESOURCE_NAME = GetCurrentResourceName()

local EvidenceCollectionCooldown = {}
local DutyUnits = {}

local GRADE_PERMISSIONS = {
    officer = 0,
    senior = 1,
    supervisor = 2,
    command = 3,
}

local LOADOUT_RESTRICTIONS = {
    [0] = { 'weapon_stungun', 'weapon_nightstick', 'weapon_flashlight', 'weapon_pistol', 'ammo-9' },
    [1] = { 'weapon_stungun', 'weapon_nightstick', 'weapon_flashlight', 'weapon_pistol', 'ammo-9', 'weapon_carbinerifle', 'ammo-rifle' },
    [2] = { 'weapon_stungun', 'weapon_nightstick', 'weapon_flashlight', 'weapon_pistol', 'ammo-9', 'weapon_carbinerifle', 'ammo-rifle', 'weapon_pumpshotgun', 'ammo-shotgun' },
    [3] = { 'weapon_stungun', 'weapon_nightstick', 'weapon_flashlight', 'weapon_pistol', 'ammo-9', 'weapon_carbinerifle', 'ammo-rifle', 'weapon_pumpshotgun', 'ammo-shotgun', 'weapon_smg', 'ammo-smg' },
}

local function nowIso()
    return os.date('!%Y-%m-%dT%H:%M:%SZ')
end

local function getCharId(src)
    if GetResourceState('pa-core') ~= 'started' then
        return nil
    end

    return exports['pa-core']['PaCore:GetCharId'](src)
end

local function getJob(src)
    if GetResourceState('pa-jobs') ~= 'started' then
        return nil
    end

    return exports['pa-jobs']['PaJobs:GetJob'](src)
end

local function isRateLimited(src, key, maxPerWindow, windowMs)
    if GetResourceState('pa-guard') ~= 'started' then
        return false
    end

    local ok = exports['pa-guard']['PaGuard:RateLimit'](src, key, maxPerWindow, windowMs)
    return ok ~= true
end

local function validateDistance(src, coords, maxDistance)
    if GetResourceState('pa-guard') ~= 'started' then
        return true
    end

    local ok = exports['pa-guard']['PaGuard:ValidateDistance'](src, coords, maxDistance)
    return ok == true
end

local function logEvent(levelExport, payload)
    if GetResourceState('pa-logging') ~= 'started' then
        return
    end

    pcall(function()
        exports['pa-logging'][levelExport](payload)
    end)
end

local function notify(src, messageType, title, message)
    if GetResourceState('pa-ui') ~= 'started' then
        return
    end

    exports['pa-ui']['PaUI:Notify'](messageType, title, message, 4500)
end

local function getOfficerGrade(src)
    local job = getJob(src)
    if type(job) ~= 'table' or job.name ~= 'police' then
        return -1
    end

    return tonumber(job.grade) or 0
end

local function isPoliceOnDuty(src)
    local job = getJob(src)
    return type(job) == 'table' and job.name == 'police' and job.onDuty == true
end

local function hasPermission(src, permission)
    local grade = getOfficerGrade(src)
    if grade < 0 then
        return false
    end

    local required = GRADE_PERMISSIONS[permission] or 0
    return grade >= required
end

local function runQuery(query, params, cb)
    if GetResourceState('oxmysql') ~= 'started' then
        if cb then
            cb({})
        end
        return
    end

    if cb then
        exports.oxmysql:execute(query, params or {}, cb)
    else
        exports.oxmysql:execute(query, params or {})
    end
end

local function runInsert(query, params, cb)
    if GetResourceState('oxmysql') ~= 'started' then
        cb(nil)
        return
    end

    exports.oxmysql:insert(query, params or {}, cb)
end

local function shortTemplate(payload)
    payload = type(payload) == 'table' and payload or {}

    return {
        reportType = tostring(payload.reportType or 'incident'),
        subjectCharId = tonumber(payload.subjectCharId),
        summary = tostring(payload.summary or ''),
        location = tostring(payload.location or ''),
        involved = tostring(payload.involved or ''),
        forceUsed = payload.forceUsed == true,
        notes = tostring(payload.notes or ''),
    }
end

local function pushDutyRoster()
    local roster = {}
    for src, item in pairs(DutyUnits) do
        if GetPlayerName(src) then
            roster[#roster + 1] = {
                source = src,
                callsign = item.callsign,
                status = item.status,
                at = item.updatedAt,
                grade = getOfficerGrade(src),
            }
        end
    end

    TriggerClientEvent('pa:police:updateDutyRoster', -1, roster)
end

local function refreshDutyState(src)
    if isPoliceOnDuty(src) then
        DutyUnits[src] = DutyUnits[src] or {
            callsign = ('PD-%s'):format(src),
            status = 'available',
            updatedAt = nowIso(),
        }
    else
        DutyUnits[src] = nil
    end

    pushDutyRoster()
end

local function createCitation(src, payload)
    if not isPoliceOnDuty(src) then
        return false, 'Must be on duty.'
    end

    if not hasPermission(src, 'officer') then
        return false, 'Missing permission.'
    end

    payload = type(payload) == 'table' and payload or {}
    local targetCharId = tonumber(payload.targetCharId)
    local amount = math.floor(tonumber(payload.amount) or 0)
    local reason = tostring(payload.reason or '')
    local offense = tostring(payload.offenseCode or 'GEN')

    if not targetCharId or targetCharId <= 0 then
        return false, 'Target character required.'
    end

    if amount <= 0 then
        return false, 'Citation amount must be greater than zero.'
    end

    if reason == '' then
        return false, 'Citation reason is required.'
    end

    local officerCharId = getCharId(src)
    runInsert([[INSERT INTO police_citations (officer_char_id, target_char_id, amount, offense_code, reason, status)
        VALUES (?, ?, ?, ?, ?, 'issued')]], {
        officerCharId,
        targetCharId,
        amount,
        offense,
        reason,
    }, function(insertId)
        logEvent('PaLogging:LogInfo', {
            resource = RESOURCE_NAME,
            source = src,
            action = 'citation_issued',
            message = 'Citation issued through police service.',
            meta = {
                citationId = insertId,
                officerCharId = officerCharId,
                targetCharId = targetCharId,
                amount = amount,
                offense = offense,
            },
        })
    end)

    return true, 'Citation issued.'
end


local function payCitation(src, citationId)
    citationId = tonumber(citationId)
    if not citationId then
        return false, 'Citation id required.'
    end

    local payerCharId = getCharId(src)
    if not payerCharId then
        return false, 'No active character.'
    end

    local result = nil
    runQuery('SELECT * FROM police_citations WHERE id = ? LIMIT 1', { citationId }, function(rows)
        result = rows and rows[1] or false
    end)
    while result == nil do Wait(0) end

    if result == false then
        return false, 'Citation not found.'
    end

    if tonumber(result.target_char_id) ~= tonumber(payerCharId) then
        return false, 'You can only pay your own citations.'
    end

    if tostring(result.status) ~= 'issued' then
        return false, 'Citation already resolved.'
    end

    local amount = tonumber(result.amount) or 0
    if amount <= 0 then
        return false, 'Invalid citation amount.'
    end

    local ok, err = exports['pa-economy']['PaEconomy:RemoveMoney'](src, 'bank', amount, 'police_citation_payment', {
        citationId = citationId,
        offense = result.offense_code,
    })

    if not ok then
        return false, err or 'Payment failed.'
    end

    runQuery('UPDATE police_citations SET status = ?, paid_at = NOW() WHERE id = ?', { 'paid', citationId })

    logEvent('PaLogging:LogEconomy', {
        resource = RESOURCE_NAME,
        source = src,
        action = 'citation_paid',
        message = 'Citation paid through police module.',
        meta = {
            citationId = citationId,
            amount = amount,
            targetCharId = payerCharId,
        },
    })

    return true, 'Citation paid.'
end

local function beginTrafficStop(src, payload)
    if not isPoliceOnDuty(src) then
        return false, 'Must be on duty.'
    end

    payload = type(payload) == 'table' and payload or {}
    local plate = string.upper(tostring(payload.plate or ''):gsub('%s+', ''))
    local targetSrc = tonumber(payload.targetSrc)

    if plate == '' then
        return false, 'Plate is required.'
    end

    logEvent('PaLogging:LogInfo', {
        resource = RESOURCE_NAME,
        source = src,
        action = 'traffic_stop_started',
        message = 'Traffic stop initiated.',
        meta = {
            plate = plate,
            targetSrc = targetSrc,
            location = payload.location,
        },
    })

    if targetSrc then
        notify(targetSrc, 'warning', 'LSPD', 'You are being stopped by police. Please pull over safely.')
    end

    return true, 'Traffic stop initiated.'
end

local function processArrest(src, payload)
    if not isPoliceOnDuty(src) then
        return false, 'Must be on duty.'
    end

    payload = type(payload) == 'table' and payload or {}
    local targetSrc = tonumber(payload.targetSrc)
    local targetCharId = tonumber(payload.targetCharId) or (targetSrc and getCharId(targetSrc) or nil)
    local jailMinutes = math.max(0, math.floor(tonumber(payload.jailMinutes) or 0))
    local charges = tostring(payload.charges or '')

    if not targetCharId then
        return false, 'Target required.'
    end

    runInsert([[INSERT INTO police_arrests (officer_char_id, target_char_id, charges, jail_minutes, status, processed_at)
        VALUES (?, ?, ?, ?, 'processed', NOW())]], {
        getCharId(src),
        targetCharId,
        charges,
        jailMinutes,
    }, function(insertId)
        logEvent('PaLogging:LogAudit', {
            resource = RESOURCE_NAME,
            source = src,
            action = 'arrest_processed',
            message = 'Arrest and jail processing completed.',
            meta = {
                arrestId = insertId,
                targetCharId = targetCharId,
                jailMinutes = jailMinutes,
                charges = charges,
            },
        })
    end)

    if targetSrc then
        notify(targetSrc, 'warning', 'Police', ('You were processed for %s minute(s).'):format(jailMinutes))
    end

    return true, 'Arrest processed.'
end

local function writeReport(src, payload)
    if not isPoliceOnDuty(src) then
        return false, 'Must be on duty.'
    end

    local template = shortTemplate(payload)
    if template.summary == '' then
        return false, 'Report summary is required.'
    end

    local reportBody = {
        location = template.location,
        involved = template.involved,
        forceUsed = template.forceUsed,
        notes = template.notes,
    }

    runInsert([[INSERT INTO police_reports (officer_char_id, subject_char_id, report_type, summary, report_json)
        VALUES (?, ?, ?, ?, ?)]], {
        getCharId(src),
        template.subjectCharId,
        template.reportType,
        template.summary,
        json.encode(reportBody),
    }, function(insertId)
        logEvent('PaLogging:LogInfo', {
            resource = RESOURCE_NAME,
            source = src,
            action = 'report_written',
            message = 'Police report written.',
            meta = {
                reportId = insertId,
                reportType = template.reportType,
                subjectCharId = template.subjectCharId,
            },
        })
    end)

    return true, 'Report submitted.'
end

local function upsertWarrant(src, payload)
    if not isPoliceOnDuty(src) or not hasPermission(src, 'supervisor') then
        return false, 'Supervisor duty required.'
    end

    payload = type(payload) == 'table' and payload or {}
    local targetCharId = tonumber(payload.targetCharId)
    local reason = tostring(payload.reason or '')
    local expiresHours = math.max(1, math.floor(tonumber(payload.expiresHours) or 24))

    if not targetCharId then
        return false, 'Target required.'
    end

    if reason == '' then
        return false, 'Warrant reason is required.'
    end

    runInsert([[INSERT INTO police_warrants (target_char_id, requested_by_char_id, reason, status, expires_at)
        VALUES (?, ?, ?, 'active', DATE_ADD(NOW(), INTERVAL ? HOUR))]], {
        targetCharId,
        getCharId(src),
        reason,
        expiresHours,
    }, function(insertId)
        logEvent('PaLogging:LogWarn', {
            resource = RESOURCE_NAME,
            source = src,
            action = 'warrant_created',
            message = 'Warrant created in MDT.',
            meta = {
                warrantId = insertId,
                targetCharId = targetCharId,
                expiresHours = expiresHours,
            },
        })
    end)

    return true, 'Warrant added.'
end

local function addCaseNote(src, payload)
    if not isPoliceOnDuty(src) then
        return false, 'Must be on duty.'
    end

    payload = type(payload) == 'table' and payload or {}
    local caseType = tostring(payload.caseType or 'general')
    local targetCharId = tonumber(payload.targetCharId)
    local note = tostring(payload.note or '')

    if note == '' then
        return false, 'Case note required.'
    end

    runInsert([[INSERT INTO police_case_notes (officer_char_id, target_char_id, case_type, note)
        VALUES (?, ?, ?, ?)]], {
        getCharId(src),
        targetCharId,
        caseType,
        note,
    }, function(insertId)
        logEvent('PaLogging:LogInfo', {
            resource = RESOURCE_NAME,
            source = src,
            action = 'case_note_added',
            message = 'Case note added in MDT.',
            meta = {
                noteId = insertId,
                targetCharId = targetCharId,
                caseType = caseType,
            },
        })
    end)

    return true, 'Case note added.'
end

local function collectEvidence(src, payload)
    if not isPoliceOnDuty(src) then
        return false, 'Must be on duty.'
    end

    local charId = getCharId(src)
    if not charId then
        return false, 'No active character.'
    end

    if isRateLimited(src, 'police:evidence:collect', 6, 20000) then
        return false, 'Evidence collect cooldown active.'
    end

    payload = type(payload) == 'table' and payload or {}
    local evidenceType = tostring(payload.evidenceType or 'unknown')
    local coords = payload.coords
    local metadata = type(payload.metadata) == 'table' and payload.metadata or {}

    if type(coords) ~= 'table' or not validateDistance(src, coords, 8.0) then
        return false, 'Evidence validation failed (distance mismatch).'
    end

    local cooldownKey = ('%s:%s:%s:%s'):format(evidenceType, math.floor((coords.x or 0) * 10), math.floor((coords.y or 0) * 10), math.floor((coords.z or 0) * 10))
    local now = os.time()
    if EvidenceCollectionCooldown[cooldownKey] and (now - EvidenceCollectionCooldown[cooldownKey]) < 20 then
        return false, 'Evidence node was already collected recently.'
    end

    EvidenceCollectionCooldown[cooldownKey] = now

    local bagMeta = {
        evidenceType = evidenceType,
        collectedAt = nowIso(),
        coords = coords,
        details = metadata,
    }

    if GetResourceState('pa-inventory') == 'started' then
        exports['pa-inventory']['PaInventory:AddItem'](src, 'evidence_bag', 1, bagMeta, 'police_evidence_collection')
    end

    runInsert([[INSERT INTO evidence (report_id, collected_by_char_id, evidence_type, storage_ref)
        VALUES (?, ?, ?, ?)]], {
        tonumber(payload.reportId),
        charId,
        evidenceType,
        json.encode(bagMeta),
    }, function(insertId)
        logEvent('PaLogging:LogAudit', {
            resource = RESOURCE_NAME,
            source = src,
            action = 'evidence_collected',
            message = 'Evidence collected and bagged.',
            meta = {
                evidenceId = insertId,
                evidenceType = evidenceType,
                reportId = tonumber(payload.reportId),
            },
        })
    end)

    return true, 'Evidence bagged.'
end

local function personLookup(src, query)
    if not isPoliceOnDuty(src) then
        TriggerClientEvent('pa:police:mdtResult', src, false, 'Must be on duty.')
        return
    end

    local q = ('%%%s%%'):format(tostring(query or ''))
    runQuery([[SELECT c.id, c.citizen_id, c.first_name, c.last_name,
        (SELECT COUNT(1) FROM police_citations pc WHERE pc.target_char_id = c.id AND pc.status = 'issued') AS open_citations,
        (SELECT COUNT(1) FROM police_warrants pw WHERE pw.target_char_id = c.id AND pw.status = 'active' AND (pw.expires_at IS NULL OR pw.expires_at > NOW())) AS active_warrants
        FROM characters c
        WHERE c.first_name LIKE ? OR c.last_name LIKE ? OR c.citizen_id LIKE ?
        ORDER BY c.last_name ASC
        LIMIT 30]], { q, q, q }, function(rows)
        TriggerClientEvent('pa:police:mdtResult', src, true, { kind = 'person', rows = rows or {} })
    end)
end

local function plateLookup(src, plate)
    if not isPoliceOnDuty(src) then
        TriggerClientEvent('pa:police:mdtResult', src, false, 'Must be on duty.')
        return
    end

    local normalized = string.upper((tostring(plate or ''):gsub('%s+', '')))
    runQuery([[SELECT v.id, v.plate, v.model, v.state, v.garage_key, v.insured,
        c.id AS owner_char_id, c.first_name, c.last_name, c.citizen_id
        FROM vehicles v
        LEFT JOIN characters c ON c.id = v.char_id
        WHERE REPLACE(UPPER(v.plate), ' ', '') = ?
        LIMIT 1]], { normalized }, function(rows)
        TriggerClientEvent('pa:police:mdtResult', src, true, { kind = 'plate', rows = rows or {} })
    end)
end

local function loadMdtRecords(src, targetCharId)
    if not isPoliceOnDuty(src) then
        TriggerClientEvent('pa:police:mdtResult', src, false, 'Must be on duty.')
        return
    end

    targetCharId = tonumber(targetCharId)
    if not targetCharId then
        TriggerClientEvent('pa:police:mdtResult', src, false, 'Target character required.')
        return
    end

    runQuery('SELECT * FROM police_citations WHERE target_char_id = ? ORDER BY created_at DESC LIMIT 25', { targetCharId }, function(citations)
        runQuery("SELECT * FROM police_warrants WHERE target_char_id = ? ORDER BY created_at DESC LIMIT 20", { targetCharId }, function(warrants)
            runQuery('SELECT * FROM police_case_notes WHERE target_char_id = ? ORDER BY created_at DESC LIMIT 30', { targetCharId }, function(notes)
                TriggerClientEvent('pa:police:mdtResult', src, true, {
                    kind = 'records',
                    rows = {
                        citations = citations or {},
                        warrants = warrants or {},
                        caseNotes = notes or {},
                    }
                })
            end)
        end)
    end)
end

RegisterNetEvent('pa:jobs:dutyUpdated', function(payload)
    local src = source
    if payload and payload.onDuty ~= nil then
        refreshDutyState(src)
    end
end)

AddEventHandler('playerDropped', function()
    DutyUnits[source] = nil
    pushDutyRoster()
end)

RegisterNetEvent('pa:police:setDuty', function(onDuty)
    local src = source
    local ok, reason = exports['pa-jobs']['PaJobs:SetDuty'](src, onDuty == true)
    if not ok then
        notify(src, 'error', 'Police Duty', tostring(reason))
        return
    end

    refreshDutyState(src)
    notify(src, 'success', 'Police Duty', onDuty and 'You are now on duty.' or 'You are now off duty.')
end)

RegisterNetEvent('pa:police:updateUnitStatus', function(status)
    local src = source
    if not isPoliceOnDuty(src) then
        notify(src, 'error', 'Police', 'Must be on duty.')
        return
    end

    DutyUnits[src] = DutyUnits[src] or {
        callsign = ('PD-%s'):format(src),
        status = 'available',
        updatedAt = nowIso(),
    }

    DutyUnits[src].status = tostring(status or 'available')
    DutyUnits[src].updatedAt = nowIso()
    pushDutyRoster()
end)

RegisterNetEvent('pa:police:requestMdtSnapshot', function()
    local src = source
    if not isPoliceOnDuty(src) then
        TriggerClientEvent('pa:police:mdtResult', src, false, 'Must be on duty.')
        return
    end

    TriggerClientEvent('pa:police:mdtResult', src, true, {
        kind = 'snapshot',
        rows = {
            loadout = LOADOUT_RESTRICTIONS[getOfficerGrade(src)] or LOADOUT_RESTRICTIONS[0],
            duty = DutyUnits,
        }
    })
end)

RegisterNetEvent('pa:police:mdtPersonLookup', function(query)
    personLookup(source, query)
end)

RegisterNetEvent('pa:police:mdtPlateLookup', function(plate)
    plateLookup(source, plate)
end)

RegisterNetEvent('pa:police:mdtRecords', function(targetCharId)
    loadMdtRecords(source, targetCharId)
end)

RegisterNetEvent('pa:police:createCitation', function(payload)
    local src = source
    local ok, result = createCitation(src, payload)
    TriggerClientEvent('pa:police:actionResult', src, ok, result)
end)

RegisterNetEvent('pa:police:trafficStop', function(payload)
    local src = source
    local ok, result = beginTrafficStop(src, payload)
    TriggerClientEvent('pa:police:actionResult', src, ok, result)
end)

RegisterNetEvent('pa:police:payCitation', function(citationId)
    local src = source
    local ok, result = payCitation(src, citationId)
    TriggerClientEvent('pa:police:actionResult', src, ok, result)
end)

RegisterNetEvent('pa:police:processArrest', function(payload)
    local src = source
    local ok, result = processArrest(src, payload)
    TriggerClientEvent('pa:police:actionResult', src, ok, result)
end)

RegisterNetEvent('pa:police:writeReport', function(payload)
    local src = source
    local ok, result = writeReport(src, payload)
    TriggerClientEvent('pa:police:actionResult', src, ok, result)
end)

RegisterNetEvent('pa:police:addWarrant', function(payload)
    local src = source
    local ok, result = upsertWarrant(src, payload)
    TriggerClientEvent('pa:police:actionResult', src, ok, result)
end)

RegisterNetEvent('pa:police:addCaseNote', function(payload)
    local src = source
    local ok, result = addCaseNote(src, payload)
    TriggerClientEvent('pa:police:actionResult', src, ok, result)
end)

RegisterNetEvent('pa:police:collectEvidence', function(payload)
    local src = source
    local ok, result = collectEvidence(src, payload)
    TriggerClientEvent('pa:police:actionResult', src, ok, result)
end)

exports('PaPolice:SetDuty', function(src, onDuty)
    local ok, reason = exports['pa-jobs']['PaJobs:SetDuty'](src, onDuty == true)
    refreshDutyState(src)
    return ok, reason
end)

exports('PaPolice:CreateCitation', function(src, payload)
    return createCitation(src, payload)
end)

exports('PaPolice:ProcessArrest', function(src, payload)
    return processArrest(src, payload)
end)

exports('PaPolice:PayCitation', function(src, citationId)
    return payCitation(src, citationId)
end)

exports('PaPolice:BeginTrafficStop', function(src, payload)
    return beginTrafficStop(src, payload)
end)

exports('PaPolice:WriteReport', function(src, payload)
    return writeReport(src, payload)
end)

exports('PaPolice:AddWarrant', function(src, payload)
    return upsertWarrant(src, payload)
end)

exports('PaPolice:AddCaseNote', function(src, payload)
    return addCaseNote(src, payload)
end)

exports('PaPolice:CollectEvidence', function(src, payload)
    return collectEvidence(src, payload)
end)

exports('PaPolice:GetAllowedLoadout', function(src)
    if not isPoliceOnDuty(src) then
        return false, 'Must be on duty.'
    end

    local grade = getOfficerGrade(src)
    return true, LOADOUT_RESTRICTIONS[grade] or LOADOUT_RESTRICTIONS[0]
end)
