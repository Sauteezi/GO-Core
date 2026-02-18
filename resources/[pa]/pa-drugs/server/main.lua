local RESOURCE_NAME = GetCurrentResourceName()
local MODULE_KEY = "drugs"
local EVENT_PREFIX = "pa:drugs"

local ModuleConfig = {
    cooldownSeconds = 300,
    tiers = {},
    rpHooks = {},
}

local ActiveRuns = {}

local function toInt(value)
    local n = tonumber(value)
    if not n or n % 1 ~= 0 then
        return nil
    end
    return math.floor(n)
end

local function notify(src, messageType, title, message)
    TriggerClientEvent('pa:ui:notify', src, {
        type = messageType,
        title = title,
        message = message,
        duration = 4500,
    })
end

local function getCharId(src)
    local ok, charId = pcall(function()
        return exports['pa-core']['PaCore:GetCharId'](src)
    end)
    return ok and tonumber(charId) or nil
end

local function getLicense(src)
    local ok, license = pcall(function()
        return exports['pa-core']['PaCore:GetLicense'](src)
    end)
    return ok and license or nil
end

local function getFactionInfo(src)
    local ok, faction = pcall(function()
        return exports['pa-factions']['PaFactions:GetFaction'](src)
    end)
    if ok and type(faction) == 'table' then
        return faction
    end
    return nil
end

local function getRankOrder(factionName, rankName)
    if not factionName or not rankName then
        return 0
    end

    local ok, cfg = pcall(function()
        return exports['pa-shared']['PaShared:GetConfig']('factions')
    end)
    if not ok or type(cfg) ~= 'table' then
        return 0
    end

    local f = cfg.factions and cfg.factions[factionName]
    local r = f and f.ranks and f.ranks[rankName]
    return toInt(r and r.order) or 0
end

local function getPlayerMeta(src)
    local ok, player = pcall(function()
        return exports['pa-core']['PaCore:GetPlayer'](src)
    end)
    if not ok or type(player) ~= 'table' then
        return {}
    end
    return type(player.metadata) == 'table' and player.metadata or {}
end

local function getReputationScore(src)
    local charId = getCharId(src)
    if not charId then
        return 0
    end

    local rows = exports.oxmysql:querySync([[
        SELECT score
        FROM reputation
        WHERE char_id = ?
          AND rep_key = ?
        LIMIT 1
    ]], { charId, ('crime:%s'):format(MODULE_KEY) }) or {}

    return toInt(rows[1] and rows[1].score) or 0
end

local function logAudit(src, action, message, meta)
    if GetResourceState('pa-logging') ~= 'started' then
        return
    end

    pcall(function()
        exports['pa-logging']['PaLogging:LogAudit']({
            resource = RESOURCE_NAME,
            source = src,
            actorLicense = getLicense(src),
            action = action,
            message = message,
            meta = meta,
        })
    end)
end

local function loadModuleConfig()
    local ok, cfg = pcall(function()
        return exports['pa-shared']['PaShared:GetConfig']('crime_activities')
    end)

    if not ok or type(cfg) ~= 'table' then
        return
    end

    local moduleCfg = cfg.modules and cfg.modules[MODULE_KEY]
    if type(moduleCfg) ~= 'table' then
        return
    end

    ModuleConfig.cooldownSeconds = tonumber(moduleCfg.cooldownSeconds) or ModuleConfig.cooldownSeconds
    ModuleConfig.requiredItem = moduleCfg.requiredItem
    ModuleConfig.rpHooks = moduleCfg.rpHooks or {}
    ModuleConfig.tiers = moduleCfg.tiers or {}
end

local function findTier(tierId)
    for _, tier in ipairs(ModuleConfig.tiers) do
        if tier.id == tierId then
            return tier
        end
    end
    return nil
end

local function meetsUnlocks(src, tier)
    local rep = getReputationScore(src)
    if rep < (toInt(tier.minReputation) or 0) then
        return false, ('Need reputation %s.'):format(tier.minReputation or 0)
    end

    local metadata = getPlayerMeta(src)
    local requiredLicense = tier.minLicense
    if requiredLicense then
        local licenses = type(metadata.licenses) == 'table' and metadata.licenses or {}
        local licValue = licenses[requiredLicense]
        local hasLicense = licValue == true or (type(licValue) == 'table' and licValue.active == true)
        if not hasLicense then
            return false, ('Missing required license: %s'):format(requiredLicense)
        end
    end

    local minRank = toInt(tier.minFactionRank) or 0
    if minRank > 0 then
        local faction = getFactionInfo(src)
        local order = faction and getRankOrder(faction.factionName, faction.rankName) or 0
        if order < minRank then
            return false, ('Need faction rank order %s.'):format(minRank)
        end
    end

    return true
end

local function runRpHooks(src, tier, payload)
    local hooks = ModuleConfig.rpHooks or {}

    if hooks.hostages then
        TriggerEvent('pa:crime:rpHook:hostageOpportunity', { module = MODULE_KEY, tier = tier.id, source = src, payload = payload })
    end

    if hooks.negotiator then
        TriggerEvent('pa:crime:rpHook:negotiatorRequest', { module = MODULE_KEY, tier = tier.id, source = src, payload = payload })
    end

    if hooks.fences then
        TriggerEvent('pa:crime:rpHook:fenceContact', { module = MODULE_KEY, tier = tier.id, source = src, payload = payload })
    end

    if hooks.chopShops then
        TriggerEvent('pa:crime:rpHook:chopShopLead', { module = MODULE_KEY, tier = tier.id, source = src, payload = payload })
    end

    local informantChance = tonumber(hooks.informantChance) or 0
    if informantChance > 0 and math.random() < informantChance then
        TriggerEvent('pa:crime:rpHook:informantChance', { module = MODULE_KEY, tier = tier.id, source = src, payload = payload })
    end
end

RegisterNetEvent(EVENT_PREFIX .. ':start', function(payload)
    local src = source
    payload = type(payload) == 'table' and payload or {}

    local tier = findTier(payload.tierId)
    if not tier then
        notify(src, 'error', 'Start denied', 'Unknown tier.')
        return
    end

    if ActiveRuns[src] then
        notify(src, 'warn', 'Start denied', 'You already have an active run.')
        return
    end

    local okRate = exports['pa-guard']['PaGuard:RateLimit'](src, MODULE_KEY .. ':start', 3, 60000)
    if not okRate then
        notify(src, 'warn', 'Start denied', 'Too many activity starts.')
        return
    end

    local unlockOk, unlockErr = meetsUnlocks(src, tier)
    if not unlockOk then
        notify(src, 'warn', 'Tier locked', unlockErr)
        return
    end

    if ModuleConfig.requiredItem then
        local hasItem = exports['pa-inventory']['PaInventory:HasItem'](src, ModuleConfig.requiredItem, 1)
        if not hasItem then
            notify(src, 'warn', 'Start denied', ('Missing required item: %s'):format(ModuleConfig.requiredItem))
            return
        end
    end

    ActiveRuns[src] = {
        tierId = tier.id,
        startedAt = os.time(),
        targetCoords = payload.targetCoords,
    }

    logAudit(src, 'crime_activity_start', 'Crime activity started.', { module = MODULE_KEY, tierId = tier.id })
    TriggerClientEvent(EVENT_PREFIX .. ':state', src, { ok = true, state = ActiveRuns[src] })
end)

RegisterNetEvent(EVENT_PREFIX .. ':finish', function(payload)
    local src = source
    payload = type(payload) == 'table' and payload or {}

    local active = ActiveRuns[src]
    if not active then
        notify(src, 'error', 'Finish denied', 'No active run found.')
        return
    end

    local tier = findTier(active.tierId)
    if not tier then
        ActiveRuns[src] = nil
        notify(src, 'error', 'Finish denied', 'Tier config missing.')
        return
    end

    local okDist = exports['pa-guard']['PaGuard:ValidateDistance'](src, payload.targetCoords or active.targetCoords, tonumber(payload.maxDistance) or 10.0)
    if not okDist then
        notify(src, 'error', 'Finish denied', 'Distance validation failed.')
        logAudit(src, 'crime_activity_distance_fail', 'Finish blocked by distance validation.', { module = MODULE_KEY, tierId = tier.id })
        return
    end

    local payoutMin = toInt(tier.payoutDirtyMin) or 500
    local payoutMax = toInt(tier.payoutDirtyMax) or payoutMin
    local dirtyPayout = math.random(math.min(payoutMin, payoutMax), math.max(payoutMin, payoutMax))

    local crimeOk = exports['pa-crime']['PaCrime:CommitIllegalActivity'](src, {
        activityKey = MODULE_KEY .. ':' .. tier.id,
        eventType = MODULE_KEY,
        targetCoords = payload.targetCoords or active.targetCoords,
        maxDistance = tonumber(payload.maxDistance) or 10.0,
        cooldownMs = (toInt(ModuleConfig.cooldownSeconds) or 300) * 1000,
        requiredItem = ModuleConfig.requiredItem,
        requiredItemCount = 1,
        heatDelta = toInt(tier.heatDelta) or 10,
        evidenceChance = tonumber(tier.evidenceChance) or 0.3,
        summary = ('%s completion for tier %s'):format(MODULE_KEY, tier.id),
    })

    if not crimeOk then
        notify(src, 'error', 'Finish denied', 'Crime validation failed.')
        return
    end

    local ecoOk = exports['pa-economy']['PaEconomy:AddMoney'](src, 'dirty', dirtyPayout, MODULE_KEY .. ':payout', { tierId = tier.id })
    if not ecoOk then
        notify(src, 'error', 'Payout failed', 'Could not apply dirty payout.')
        return
    end

    local charId = getCharId(src)
    if charId then
        exports.oxmysql:executeSync([[
            INSERT INTO reputation (char_id, rep_key, score)
            VALUES (?, ?, 3)
            ON DUPLICATE KEY UPDATE score = score + 3, updated_at = CURRENT_TIMESTAMP
        ]], { charId, ('crime:%s'):format(MODULE_KEY) })
    end

    runRpHooks(src, tier, payload)

    logAudit(src, 'crime_activity_finish', 'Crime activity paid out dirty money.', { module = MODULE_KEY, tierId = tier.id, dirtyPayout = dirtyPayout })

    ActiveRuns[src] = nil
    notify(src, 'success', 'Run complete', ('Dirty payout: $%s'):format(dirtyPayout))
    TriggerClientEvent(EVENT_PREFIX .. ':state', src, { ok = true, completed = true, payout = dirtyPayout })
end)

RegisterNetEvent(EVENT_PREFIX .. ':cancel', function()
    local src = source
    ActiveRuns[src] = nil
    TriggerClientEvent(EVENT_PREFIX .. ':state', src, { ok = true, cancelled = true })
end)

exports('Pa' .. MODULE_KEY .. ':GetTiers', function()
    return ModuleConfig.tiers
end)

CreateThread(function()
    math.randomseed(os.time())
    loadModuleConfig()
end)

AddEventHandler('playerDropped', function()
    ActiveRuns[source] = nil
end)
