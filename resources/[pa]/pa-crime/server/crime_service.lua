local RESOURCE_NAME = GetCurrentResourceName()

local CrimeConfig = {
    heat = {
        maxHeat = 200,
        decayIntervalSeconds = 120,
        decayPerTick = 2,
        eventCooldownMs = 30000,
    },
    evidence = {
        defaultChance = 0.25,
        caseEvidenceThreshold = 45,
        warrantThreshold = 70,
    },
    laundering = {
        minAmount = 250,
        maxAmount = 50000,
        feePercent = 0.15,
        riskHeatMultiplier = 1.0,
    },
}

local HeatByChar = {}
local Cooldowns = {}

local function nowMs()
    return GetGameTimer()
end

local function toInt(value)
    local n = tonumber(value)
    if not n or n % 1 ~= 0 then
        return nil
    end
    return math.floor(n)
end

local function clamp(value, minValue, maxValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function getCharId(src)
    local ok, charId = pcall(function()
        return exports['pa-core']['PaCore:GetCharId'](src)
    end)
    if ok then
        return tonumber(charId)
    end
    return nil
end

local function getLicense(src)
    local ok, license = pcall(function()
        return exports['pa-core']['PaCore:GetLicense'](src)
    end)
    if ok then
        return license
    end
    return nil
end

local function notify(src, messageType, title, message)
    TriggerClientEvent('pa:ui:notify', src, {
        type = messageType,
        title = title,
        message = message,
        duration = 5000,
    })
end

local function logEvent(levelExport, src, action, message, meta)
    if GetResourceState('pa-logging') ~= 'started' then
        return
    end

    pcall(function()
        exports['pa-logging'][levelExport]({
            resource = RESOURCE_NAME,
            source = src,
            actorLicense = getLicense(src),
            action = action,
            message = message,
            meta = meta,
        })
    end)
end

local function loadCrimeConfig()
    if GetResourceState('pa-shared') ~= 'started' then
        return
    end

    local ok, cfg = pcall(function()
        return exports['pa-shared']['PaShared:GetConfig']('crime')
    end)

    if not ok or type(cfg) ~= 'table' then
        return
    end

    if type(cfg.heat) == 'table' then
        CrimeConfig.heat.maxHeat = tonumber(cfg.heat.maxHeat) or CrimeConfig.heat.maxHeat
        CrimeConfig.heat.decayIntervalSeconds = tonumber(cfg.heat.decayIntervalSeconds) or CrimeConfig.heat.decayIntervalSeconds
        CrimeConfig.heat.decayPerTick = tonumber(cfg.heat.decayPerTick) or CrimeConfig.heat.decayPerTick
        CrimeConfig.heat.eventCooldownMs = tonumber(cfg.heat.eventCooldownMs) or CrimeConfig.heat.eventCooldownMs
    end

    if type(cfg.evidence) == 'table' then
        CrimeConfig.evidence.defaultChance = tonumber(cfg.evidence.defaultChance) or CrimeConfig.evidence.defaultChance
        CrimeConfig.evidence.caseEvidenceThreshold = tonumber(cfg.evidence.caseEvidenceThreshold) or CrimeConfig.evidence.caseEvidenceThreshold
        CrimeConfig.evidence.warrantThreshold = tonumber(cfg.evidence.warrantThreshold) or CrimeConfig.evidence.warrantThreshold
    end

    if type(cfg.laundering) == 'table' then
        CrimeConfig.laundering.minAmount = tonumber(cfg.laundering.minAmount) or CrimeConfig.laundering.minAmount
        CrimeConfig.laundering.maxAmount = tonumber(cfg.laundering.maxAmount) or CrimeConfig.laundering.maxAmount
        CrimeConfig.laundering.feePercent = tonumber(cfg.laundering.feePercent) or CrimeConfig.laundering.feePercent
        CrimeConfig.laundering.riskHeatMultiplier = tonumber(cfg.laundering.riskHeatMultiplier) or CrimeConfig.laundering.riskHeatMultiplier
    end
end

local function requireDistance(src, targetCoords, maxDist)
    local ok, meta = exports['pa-guard']['PaGuard:ValidateDistance'](src, targetCoords, maxDist)
    if ok then
        return true, meta
    end

    logEvent('PaLogging:LogWarn', src, 'crime_distance_failed', 'Blocked crime action due to failed distance check.', meta)
    return false, meta
end

local function requireRateLimit(src, key, maxPerWindow, windowMs)
    local allowed, meta = exports['pa-guard']['PaGuard:RateLimit'](src, key, maxPerWindow, windowMs)
    if allowed then
        return true, meta
    end

    logEvent('PaLogging:LogWarn', src, 'crime_rate_limited', 'Blocked crime action due to rate limit.', meta)
    return false, meta
end

local function requireItem(src, itemName, count)
    if not itemName then
        return true
    end

    local required = toInt(count) or 1
    local ok, result = pcall(function()
        return exports['pa-inventory']['PaInventory:HasItem'](src, itemName, required)
    end)

    if not ok or result ~= true then
        logEvent('PaLogging:LogWarn', src, 'crime_missing_item', 'Blocked crime action: required item missing.', {
            item = itemName,
            count = required,
        })
        return false
    end

    return true
end

local function enforceCooldown(src, key, cooldownMs)
    local stamp = nowMs()
    local k = ('%s:%s'):format(src, key)
    local wait = tonumber(cooldownMs) or CrimeConfig.heat.eventCooldownMs
    local untilAt = Cooldowns[k] or 0

    if stamp < untilAt then
        return false, untilAt - stamp
    end

    Cooldowns[k] = stamp + wait
    return true, 0
end

local function getOrCreateHeat(charId)
    local data = HeatByChar[charId]
    if data then
        return data
    end

    data = {
        score = 0,
        updatedAt = os.time(),
    }

    HeatByChar[charId] = data
    return data
end

local function getOrCreateCase(charId, reason)
    local rows = exports.oxmysql:querySync([[
        SELECT id, evidence_score
        FROM crime_cases
        WHERE suspect_char_id = ?
          AND case_status IN ('open', 'investigating')
        ORDER BY id DESC
        LIMIT 1
    ]], { charId }) or {}

    local row = rows[1]
    if row then
        return tonumber(row.id), tonumber(row.evidence_score) or 0
    end

    local caseId = exports.oxmysql:insertSync([[
        INSERT INTO crime_cases (suspect_char_id, case_status, heat_score, title, summary, last_heat_at, evidence_score, evidence_json)
        VALUES (?, 'open', 0, ?, ?, CURRENT_TIMESTAMP, 0, ?)
    ]], {
        charId,
        'Active criminal activity pattern',
        tostring(reason or 'Auto-generated case from heat events.'),
        json.encode({ traces = {} }),
    })

    return tonumber(caseId), 0
end

local function appendCaseEvidence(caseId, evidenceEntry)
    local rows = exports.oxmysql:querySync([[
        SELECT evidence_json
        FROM crime_cases
        WHERE id = ?
        LIMIT 1
    ]], { caseId }) or {}

    local evidence = { traces = {} }
    local raw = rows[1] and rows[1].evidence_json

    if type(raw) == 'string' and raw ~= '' then
        local decoded = json.decode(raw)
        if type(decoded) == 'table' then
            evidence = decoded
            evidence.traces = type(decoded.traces) == 'table' and decoded.traces or {}
        end
    end

    evidence.traces[#evidence.traces + 1] = evidenceEntry

    exports.oxmysql:executeSync([[
        UPDATE crime_cases
        SET evidence_json = ?, updated_at = CURRENT_TIMESTAMP
        WHERE id = ?
    ]], { json.encode(evidence), caseId })
end

local function recommendWarrant(caseId, charId, evidenceScore)
    if evidenceScore < CrimeConfig.evidence.warrantThreshold then
        return
    end

    exports.oxmysql:executeSync([[
        UPDATE crime_cases
        SET warrant_recommended = 1,
            updated_at = CURRENT_TIMESTAMP
        WHERE id = ?
    ]], { caseId })

    TriggerEvent('pa:crime:warrantRecommended', {
        caseId = caseId,
        suspectCharId = charId,
        evidenceScore = evidenceScore,
    })
end

local function emitHeat(src, actionType, heatDelta, caseId, details)
    local charId = getCharId(src)
    if not charId then
        return false, 'No active character.'
    end

    local heatInt = toInt(heatDelta)
    if not heatInt or heatInt <= 0 then
        return false, 'Invalid heat delta.'
    end

    local state = getOrCreateHeat(charId)
    state.score = clamp((state.score or 0) + heatInt, 0, CrimeConfig.heat.maxHeat)
    state.updatedAt = os.time()

    local activeCaseId = tonumber(caseId)
    if not activeCaseId then
        activeCaseId = select(1, getOrCreateCase(charId, details and details.summary))
    end

    exports.oxmysql:executeSync([[
        INSERT INTO heat_events (char_id, case_id, event_type, heat_delta, coords_json, meta_json)
        VALUES (?, ?, ?, ?, ?, ?)
    ]], {
        charId,
        activeCaseId,
        tostring(actionType or 'unknown'),
        heatInt,
        json.encode(details and details.coords or nil),
        json.encode(details or {}),
    })

    exports.oxmysql:executeSync([[
        UPDATE crime_cases
        SET heat_score = ?,
            last_heat_at = CURRENT_TIMESTAMP,
            case_status = CASE WHEN case_status = 'open' THEN 'investigating' ELSE case_status END,
            updated_at = CURRENT_TIMESTAMP
        WHERE id = ?
    ]], { state.score, activeCaseId })

    return true, nil, {
        charId = charId,
        caseId = activeCaseId,
        heat = state.score,
    }
end

local PaCrime = {}

function PaCrime:GetHeat(src)
    local charId = getCharId(src)
    if not charId then
        return 0
    end

    local state = HeatByChar[charId]
    return state and state.score or 0
end

function PaCrime:CommitIllegalActivity(src, payload)
    local actor = tonumber(src)
    local data = type(payload) == 'table' and payload or {}

    if not actor then
        return false, 'Invalid source.'
    end

    local activityKey = tostring(data.activityKey or data.eventType or 'crime:generic')
    local eventType = tostring(data.eventType or activityKey)
    local heatDelta = toInt(data.heatDelta) or 8
    local evidenceChance = tonumber(data.evidenceChance) or CrimeConfig.evidence.defaultChance

    if heatDelta <= 0 then
        return false, 'Heat delta must be positive.'
    end

    local okRate = requireRateLimit(actor, ('crime:event:%s'):format(activityKey), 5, 15000)
    if not okRate then
        return false, 'Too many actions in a short time.'
    end

    local okCooldown, remaining = enforceCooldown(actor, activityKey, data.cooldownMs)
    if not okCooldown then
        return false, ('Action is cooling down for %d ms.'):format(remaining)
    end

    local okDistance = requireDistance(actor, data.targetCoords, tonumber(data.maxDistance) or 6.0)
    if not okDistance then
        return false, 'Distance validation failed.'
    end

    if not requireItem(actor, data.requiredItem, data.requiredItemCount) then
        return false, 'Missing required item.'
    end

    local emitted, emitErr, result = emitHeat(actor, eventType, heatDelta, data.caseId, {
        summary = data.summary,
        coords = data.targetCoords,
        activityKey = activityKey,
        cooldownMs = data.cooldownMs,
    })

    if not emitted then
        return false, emitErr
    end

    local evidenceRolled = math.random() < clamp(evidenceChance, 0.0, 1.0)
    local evidenceAdded = false

    if evidenceRolled then
        local evidenceScoreAdd = toInt(data.evidenceScoreAdd) or 8

        exports.oxmysql:executeSync([[
            UPDATE crime_cases
            SET evidence_score = LEAST(100, evidence_score + ?),
                updated_at = CURRENT_TIMESTAMP
            WHERE id = ?
        ]], { evidenceScoreAdd, result.caseId })

        appendCaseEvidence(result.caseId, {
            createdAt = os.time(),
            type = eventType,
            score = evidenceScoreAdd,
            note = tostring(data.evidenceNote or 'Scene traces recovered.'),
        })

        local rows = exports.oxmysql:querySync([[
            SELECT evidence_score
            FROM crime_cases
            WHERE id = ?
            LIMIT 1
        ]], { result.caseId }) or {}

        local evidenceScore = tonumber(rows[1] and rows[1].evidence_score) or 0
        recommendWarrant(result.caseId, result.charId, evidenceScore)
        evidenceAdded = true
    end

    logEvent('PaLogging:LogAudit', actor, 'crime_activity_recorded', 'Illegal activity recorded with heat/case update.', {
        activityKey = activityKey,
        eventType = eventType,
        caseId = result.caseId,
        heat = result.heat,
        evidenceAdded = evidenceAdded,
    })

    return true, nil, {
        caseId = result.caseId,
        heat = result.heat,
        evidenceAdded = evidenceAdded,
    }
end


function PaCrime:CanAccessBlackMarket(src, payload)
    local actor = tonumber(src)
    local data = type(payload) == 'table' and payload or {}

    if not actor then
        return false, 'Invalid source.'
    end

    local minHeat = toInt(data.minHeat) or 20
    local maxHeat = toInt(data.maxHeat) or 140
    local requiredItem = data.requiredItem or 'lockpick'

    local okRate = requireRateLimit(actor, 'crime:blackmarket', 5, 20000)
    if not okRate then
        return false, 'Access request throttled.'
    end

    local heat = self:GetHeat(actor)
    if heat < minHeat then
        return false, ('Need at least %d heat to get noticed by black market contacts.'):format(minHeat)
    end

    if heat > maxHeat then
        return false, ('Heat is too high (%d). Lay low before using black market channels.'):format(maxHeat)
    end

    if not requireDistance(actor, data.targetCoords, tonumber(data.maxDistance) or 5.0) then
        return false, 'You are too far from the contact point.'
    end

    if not requireItem(actor, requiredItem, 1) then
        return false, ('Missing required contact item: %s.'):format(requiredItem)
    end

    return true, nil, { heat = heat }
end

function PaCrime:LaunderMoney(src, businessId, amount, payload)
    local actor = tonumber(src)
    local dirtyAmount = toInt(amount)
    local meta = type(payload) == 'table' and payload or {}

    if not actor then
        return false, 'Invalid source.'
    end

    if not dirtyAmount or dirtyAmount < CrimeConfig.laundering.minAmount then
        return false, ('Minimum laundering amount is %d.'):format(CrimeConfig.laundering.minAmount)
    end

    if dirtyAmount > CrimeConfig.laundering.maxAmount then
        return false, ('Maximum laundering amount is %d.'):format(CrimeConfig.laundering.maxAmount)
    end

    local okRate = requireRateLimit(actor, 'crime:launder', 3, 60000)
    if not okRate then
        return false, 'Too many laundering attempts.'
    end

    local okCooldown = enforceCooldown(actor, 'crime:launder', 45000)
    if not okCooldown then
        return false, 'Laundering station cooling down.'
    end

    local businessName = tostring(businessId or '')
    local hasBizAccess = false

    if businessName ~= '' and GetResourceState('pa-business') == 'started' then
        local okRole, hasRole = pcall(function()
            return exports['pa-business']['PaBusiness:HasRole'](actor, businessName, 'owner')
                or exports['pa-business']['PaBusiness:HasRole'](actor, businessName, 'manager')
                or exports['pa-business']['PaBusiness:HasRole'](actor, businessName, 'employee')
        end)
        hasBizAccess = okRole and hasRole == true
    end

    if not hasBizAccess then
        logEvent('PaLogging:LogWarn', actor, 'launder_denied_business_access', 'Laundering blocked: no business access.', {
            businessId = businessName,
        })
        return false, 'No laundering access at this business.'
    end

    local fee = math.floor(dirtyAmount * CrimeConfig.laundering.feePercent)
    local cleanAmount = dirtyAmount - fee
    if cleanAmount <= 0 then
        return false, 'Laundering fee consumes this amount.'
    end

    local removeOk = exports['pa-economy']['PaEconomy:RemoveMoney'](actor, 'dirty', dirtyAmount, 'crime_launder_remove', {
        businessId = businessName,
        amount = dirtyAmount,
        fee = fee,
        step = 'remove_dirty',
    })

    if not removeOk then
        return false, 'Not enough dirty funds.'
    end

    local addOk = exports['pa-economy']['PaEconomy:AddMoney'](actor, 'bank', cleanAmount, 'crime_launder_add', {
        businessId = businessName,
        amount = cleanAmount,
        fee = fee,
        step = 'add_clean',
    })

    if not addOk then
        exports['pa-economy']['PaEconomy:AddMoney'](actor, 'dirty', dirtyAmount, 'crime_launder_rollback', {
            businessId = businessName,
            amount = dirtyAmount,
        })
        return false, 'Laundering failed. Transaction rolled back.'
    end

    local heatGain = math.max(1, math.floor((dirtyAmount / 1000) * CrimeConfig.laundering.riskHeatMultiplier))
    local emitted, _, result = emitHeat(actor, 'laundering', heatGain, meta.caseId, {
        summary = 'Money laundering transaction traced via business channel.',
        businessId = businessName,
        amount = dirtyAmount,
    })

    logEvent('PaLogging:LogEconomy', actor, 'launder_complete', 'Dirty funds laundered through business.', {
        businessId = businessName,
        dirtyAmount = dirtyAmount,
        cleanAmount = cleanAmount,
        fee = fee,
        heatApplied = emitted and heatGain or 0,
        caseId = emitted and result.caseId or nil,
    })

    return true, nil, {
        dirtyAmount = dirtyAmount,
        cleanAmount = cleanAmount,
        fee = fee,
        caseId = emitted and result.caseId or nil,
        heat = emitted and result.heat or nil,
    }
end

CreateThread(function()
    math.randomseed(os.time())
    loadCrimeConfig()

    while true do
        Wait(math.max(30, CrimeConfig.heat.decayIntervalSeconds) * 1000)

        for charId, state in pairs(HeatByChar) do
            if type(state) == 'table' and (state.score or 0) > 0 then
                state.score = math.max(0, state.score - CrimeConfig.heat.decayPerTick)
                state.updatedAt = os.time()

                if state.score == 0 then
                    local rows = exports.oxmysql:querySync([[
                        SELECT id
                        FROM crime_cases
                        WHERE suspect_char_id = ?
                          AND case_status IN ('open', 'investigating')
                        ORDER BY id DESC
                        LIMIT 1
                    ]], { charId }) or {}

                    local row = rows[1]
                    if row then
                        exports.oxmysql:executeSync([[
                            UPDATE crime_cases
                            SET case_status = CASE WHEN evidence_score >= ? THEN 'investigating' ELSE 'closed' END,
                                updated_at = CURRENT_TIMESTAMP
                            WHERE id = ?
                        ]], { CrimeConfig.evidence.caseEvidenceThreshold, tonumber(row.id) })
                    end
                end
            end
        end
    end
end)

RegisterNetEvent('pa:crime:commitIllegalActivity', function(payload)
    local src = source
    local ok, err, result = PaCrime:CommitIllegalActivity(src, payload)

    if not ok then
        notify(src, 'error', 'Crime action blocked', err or 'Validation failed.')
        TriggerClientEvent('pa:crime:activityResult', src, { ok = false, error = err })
        return
    end

    notify(src, 'warn', 'Heat increased', ('Case #%s now at heat %s.'):format(result.caseId, result.heat))
    TriggerClientEvent('pa:crime:activityResult', src, { ok = true, result = result })
end)


RegisterNetEvent('pa:crime:requestBlackMarketAccess', function(payload)
    local src = source
    local ok, err, result = PaCrime:CanAccessBlackMarket(src, payload)

    if not ok then
        notify(src, 'warn', 'Black market denied', err or 'Access denied.')
        TriggerClientEvent('pa:crime:blackMarketAccessResult', src, { ok = false, error = err })
        return
    end

    notify(src, 'success', 'Black market contact', 'Access granted. Stay discreet.')
    TriggerClientEvent('pa:crime:blackMarketAccessResult', src, { ok = true, result = result })
end)

RegisterNetEvent('pa:crime:requestLaunder', function(payload)
    local src = source
    payload = type(payload) == 'table' and payload or {}

    local ok, err, result = PaCrime:LaunderMoney(src, payload.businessId, payload.amount, payload)
    if not ok then
        notify(src, 'error', 'Laundering failed', err or 'Unknown error.')
        TriggerClientEvent('pa:crime:launderResult', src, { ok = false, error = err })
        return
    end

    notify(src, 'success', 'Laundering complete', ('Cleaned $%s after fees.'):format(result.cleanAmount))
    TriggerClientEvent('pa:crime:launderResult', src, { ok = true, result = result })
end)

exports('PaCrime:CommitIllegalActivity', function(src, payload)
    return PaCrime:CommitIllegalActivity(src, payload)
end)

exports('PaCrime:LaunderMoney', function(src, businessId, amount, payload)
    return PaCrime:LaunderMoney(src, businessId, amount, payload)
end)

exports('PaCrime:CanAccessBlackMarket', function(src, payload)
    return PaCrime:CanAccessBlackMarket(src, payload)
end)

exports('PaCrime:GetHeat', function(src)
    return PaCrime:GetHeat(src)
end)
