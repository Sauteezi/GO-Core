local RESOURCE_NAME = GetCurrentResourceName()

local FactionConfig = {
    factions = {},
    defaults = {
        territoryStep = 1,
        territoryMaxInfluence = 100,
    },
}

local MemberCache = {}
local MemberCacheByChar = {}
local TerritoryCooldowns = {}
local TerritoryInfluence = {}
local FrontLinks = {}

local function toInt(value)
    local n = tonumber(value)
    if not n or n % 1 ~= 0 then
        return nil
    end
    return math.floor(n)
end

local function tableSize(t)
    local count = 0
    for _ in pairs(t or {}) do
        count = count + 1
    end
    return count
end

local function clamp(value, minValue, maxValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
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

local function loadFactionConfig()
    local ok, cfg = pcall(function()
        return exports['pa-shared']['PaShared:GetConfig']('factions')
    end)

    if not ok or type(cfg) ~= 'table' then
        return
    end

    FactionConfig.factions = cfg.factions or {}
    FactionConfig.defaults = cfg.defaults or FactionConfig.defaults
end

local function getRankDef(factionId, rankName)
    local faction = FactionConfig.factions[factionId]
    if type(faction) ~= 'table' or type(faction.ranks) ~= 'table' then
        return nil
    end

    return faction.ranks[rankName]
end

local function hasPermission(memberData, permission)
    if type(memberData) ~= 'table' then
        return false
    end

    local rank = getRankDef(memberData.factionName, memberData.rankName)
    if type(rank) ~= 'table' then
        return false
    end

    local perms = rank.permissions
    if type(perms) ~= 'table' then
        return false
    end

    for _, name in ipairs(perms) do
        if name == permission or name == '*' then
            return true
        end
    end

    return false
end

local function fetchMemberByCharId(charId)
    local rows = exports.oxmysql:querySync([[
        SELECT faction_name, rank_name
        FROM faction_members
        WHERE char_id = ?
        ORDER BY id DESC
        LIMIT 1
    ]], { charId }) or {}

    local row = rows[1]
    if not row then
        return nil
    end

    return {
        charId = charId,
        factionName = row.faction_name,
        rankName = row.rank_name,
    }
end

local function ensureFactionBusinessAccount(factionId, label)
    local businessKey = ('faction:%s'):format(factionId)

    local rows = exports.oxmysql:querySync([[
        SELECT id
        FROM business_registry
        WHERE business_key = ?
        LIMIT 1
    ]], { businessKey }) or {}

    local registryId = rows[1] and tonumber(rows[1].id)

    if not registryId then
        registryId = exports.oxmysql:insertSync([[
            INSERT INTO business_registry (business_key, business_name, status)
            VALUES (?, ?, 'active')
        ]], { businessKey, ('Faction Treasury: %s'):format(label or factionId) })
    end

    exports.oxmysql:executeSync([[
        INSERT INTO business_accounts (business_id, balance)
        VALUES (?, 0)
        ON DUPLICATE KEY UPDATE business_id = VALUES(business_id)
    ]], { registryId })

    return tonumber(registryId)
end

local function getFactionBalance(factionId)
    local rows = exports.oxmysql:querySync([[
        SELECT ba.balance
        FROM business_registry br
        INNER JOIN business_accounts ba ON ba.business_id = br.id
        WHERE br.business_key = ?
        LIMIT 1
    ]], { ('faction:%s'):format(factionId) }) or {}

    return tonumber(rows[1] and rows[1].balance) or 0
end

local function setFactionBalance(factionId, nextBalance)
    exports.oxmysql:executeSync([[
        UPDATE business_accounts ba
        INNER JOIN business_registry br ON br.id = ba.business_id
        SET ba.balance = ?, ba.updated_at = CURRENT_TIMESTAMP
        WHERE br.business_key = ?
    ]], { nextBalance, ('faction:%s'):format(factionId) })
end

local function loadFrontLinks()
    FrontLinks = {}

    local rows = exports.oxmysql:querySync([[
        SELECT faction_name, business_key, laundering_enabled
        FROM faction_fronts
    ]], {}) or {}

    for _, row in ipairs(rows) do
        local factionName = row.faction_name
        FrontLinks[factionName] = FrontLinks[factionName] or {}
        FrontLinks[factionName][row.business_key] = {
            launderingEnabled = tonumber(row.laundering_enabled) == 1,
        }
    end
end

local function loadTerritoryInfluence()
    TerritoryInfluence = {}

    local rows = exports.oxmysql:querySync([[
        SELECT faction_name, territory_key, influence
        FROM faction_territory
    ]], {}) or {}

    for _, row in ipairs(rows) do
        TerritoryInfluence[row.territory_key] = TerritoryInfluence[row.territory_key] or {}
        TerritoryInfluence[row.territory_key][row.faction_name] = tonumber(row.influence) or 0
    end
end

local function getOrCacheMember(src)
    local cached = MemberCache[src]
    if cached then
        return cached
    end

    local charId = getCharId(src)
    if not charId then
        return nil
    end

    local byChar = MemberCacheByChar[charId]
    if byChar then
        MemberCache[src] = byChar
        return byChar
    end

    local member = fetchMemberByCharId(charId)
    if member then
        MemberCache[src] = member
        MemberCacheByChar[charId] = member
    end

    return member
end

local function upsertReputation(charId, key, delta)
    exports.oxmysql:executeSync([[
        INSERT INTO reputation (char_id, rep_key, score)
        VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE score = GREATEST(-1000, LEAST(1000, score + VALUES(score))), updated_at = CURRENT_TIMESTAMP
    ]], { charId, key, delta })
end

local function registerFactionStashes()
    if GetResourceState('ox_inventory') ~= 'started' then
        return
    end

    for factionId, faction in pairs(FactionConfig.factions) do
        local stash = faction.storage or {}
        local slots = toInt(stash.slots) or 80
        local weight = toInt(stash.weight) or 180000
        local label = stash.label or ((faction.label or factionId) .. ' Storage')

        pcall(function()
            exports.ox_inventory:RegisterStash(('faction_%s'):format(factionId), label, slots, weight)
        end)
    end
end

local PaFactions = {}

function PaFactions:GetFaction(src)
    local member = getOrCacheMember(src)
    if not member then
        return nil
    end

    local faction = FactionConfig.factions[member.factionName]
    if not faction then
        return nil
    end

    return {
        factionName = member.factionName,
        rankName = member.rankName,
        label = faction.label,
        type = faction.type,
    }
end

function PaFactions:HasPermission(src, permission)
    local member = getOrCacheMember(src)
    return hasPermission(member, permission)
end

function PaFactions:SetMemberFaction(actorSrc, targetSrc, factionId, rankName)
    local actor = tonumber(actorSrc)
    local target = tonumber(targetSrc)

    if not actor or not target then
        return false, 'Invalid source.'
    end

    if not self:HasPermission(actor, 'member_manage') and not exports['pa-perms']['PaPerms:HasAny'](actor, { 'owner', 'dev', 'admin' }) then
        return false, 'You are not allowed to manage faction members.'
    end

    local charId = getCharId(target)
    if not charId then
        return false, 'Target has no active character.'
    end

    if not FactionConfig.factions[factionId] then
        return false, 'Unknown faction.'
    end

    local rank = rankName or 'member'
    if not getRankDef(factionId, rank) then
        return false, 'Invalid faction rank.'
    end

    exports.oxmysql:executeSync('DELETE FROM faction_members WHERE char_id = ?', { charId })

    exports.oxmysql:executeSync([[
        INSERT INTO faction_members (faction_name, char_id, rank_name)
        VALUES (?, ?, ?)
    ]], { factionId, charId, rank })

    local member = {
        charId = charId,
        factionName = factionId,
        rankName = rank,
    }

    MemberCache[target] = member
    MemberCacheByChar[charId] = member

    logEvent('PaLogging:LogAdmin', actor, 'faction_member_assigned', 'Faction member assignment changed.', {
        targetSrc = target,
        targetCharId = charId,
        factionName = factionId,
        rankName = rank,
    })

    return true
end

function PaFactions:LinkFrontBusiness(actorSrc, factionId, businessKey, launderingEnabled)
    local actor = tonumber(actorSrc)
    if not actor then
        return false, 'Invalid source.'
    end

    if not self:HasPermission(actor, 'front_manage') and not exports['pa-perms']['PaPerms:HasAny'](actor, { 'owner', 'dev', 'admin' }) then
        return false, 'Not allowed to manage front businesses.'
    end

    if not FactionConfig.factions[factionId] then
        return false, 'Unknown faction.'
    end

    local key = tostring(businessKey or '')
    if key == '' then
        return false, 'Business key required.'
    end

    local factionDef = FactionConfig.factions[factionId] or {}
    local allowedKeys = type(factionDef.frontBusinessKeys) == 'table' and factionDef.frontBusinessKeys or {}
    local allowed = false
    for _, candidate in ipairs(allowedKeys) do
        if candidate == key then
            allowed = true
            break
        end
    end

    if not allowed then
        return false, 'Business key is not allowed for this faction configuration.'
    end

    exports.oxmysql:executeSync([[
        INSERT INTO faction_fronts (faction_name, business_key, laundering_enabled)
        VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE laundering_enabled = VALUES(laundering_enabled), updated_at = CURRENT_TIMESTAMP
    ]], { factionId, key, launderingEnabled and 1 or 0 })

    FrontLinks[factionId] = FrontLinks[factionId] or {}
    FrontLinks[factionId][key] = { launderingEnabled = launderingEnabled and true or false }

    return true
end

function PaFactions:AddTerritoryPressure(src, factionId, territoryKey, actionType, payload)
    local actor = tonumber(src)
    local data = type(payload) == 'table' and payload or {}

    if not actor then
        return false, 'Invalid source.'
    end

    local member = getOrCacheMember(actor)
    if not member or member.factionName ~= factionId then
        return false, 'You are not in this faction.'
    end

    local territory = tostring(territoryKey or '')
    if territory == '' then
        return false, 'Territory key required.'
    end

    local rateOk = exports['pa-guard']['PaGuard:RateLimit'](actor, ('factions:territory:%s'):format(territory), 4, 120000)
    if not rateOk then
        return false, 'Territory action rate limited.'
    end

    local cdKey = ('%s:%s:%s'):format(actor, factionId, territory)
    local now = GetGameTimer()
    local cdUntil = TerritoryCooldowns[cdKey] or 0
    if now < cdUntil then
        return false, 'Territory action cooling down.'
    end
    TerritoryCooldowns[cdKey] = now + 180000

    local distOk = exports['pa-guard']['PaGuard:ValidateDistance'](actor, data.targetCoords, tonumber(data.maxDistance) or 12.0)
    if not distOk then
        return false, 'Distance check failed.'
    end

    local shift = clamp(toInt(data.influenceShift) or FactionConfig.defaults.territoryStep or 1, -3, 3)
    if shift == 0 then
        shift = 1
    end

    TerritoryInfluence[territory] = TerritoryInfluence[territory] or {}
    local current = TerritoryInfluence[territory][factionId] or 0
    local nextValue = clamp(current + shift, 0, FactionConfig.defaults.territoryMaxInfluence or 100)

    TerritoryInfluence[territory][factionId] = nextValue

    exports.oxmysql:executeSync([[
        INSERT INTO faction_territory (faction_name, territory_key, influence)
        VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE influence = VALUES(influence), updated_at = CURRENT_TIMESTAMP
    ]], { factionId, territory, nextValue })

    local charId = getCharId(actor)
    if charId then
        upsertReputation(charId, ('faction:%s'):format(factionId), math.max(1, math.abs(shift)))
    end

    logEvent('PaLogging:LogAudit', actor, 'territory_pressure', 'Faction territory pressure updated.', {
        factionName = factionId,
        territoryKey = territory,
        influence = nextValue,
        shift = shift,
        actionType = actionType,
    })

    return true, nil, { territoryKey = territory, influence = nextValue }
end

function PaFactions:DepositFunds(src, factionId, amount, reason)
    local actor = tonumber(src)
    local value = toInt(amount)

    if not actor or not value or value <= 0 then
        return false, 'Invalid amount.'
    end

    local member = getOrCacheMember(actor)
    if not member or member.factionName ~= factionId then
        return false, 'Not a member of this faction.'
    end

    if not hasPermission(member, 'funds_deposit') then
        return false, 'You cannot deposit to faction funds.'
    end

    local removed = exports['pa-economy']['PaEconomy:RemoveMoney'](actor, 'bank', value, reason or 'faction_deposit', {
        factionName = factionId,
        amount = value,
    })

    if not removed then
        return false, 'Insufficient funds.'
    end

    local balance = getFactionBalance(factionId)
    setFactionBalance(factionId, balance + value)

    logEvent('PaLogging:LogEconomy', actor, 'faction_funds_deposit', 'Faction funds deposit completed.', {
        factionName = factionId,
        amount = value,
        balance = balance + value,
    })

    return true, nil, balance + value
end

function PaFactions:WithdrawFunds(src, factionId, amount, reason)
    local actor = tonumber(src)
    local value = toInt(amount)

    if not actor or not value or value <= 0 then
        return false, 'Invalid amount.'
    end

    local member = getOrCacheMember(actor)
    if not member or member.factionName ~= factionId then
        return false, 'Not a member of this faction.'
    end

    if not hasPermission(member, 'funds_withdraw') then
        return false, 'You cannot withdraw faction funds.'
    end

    local balance = getFactionBalance(factionId)
    if balance < value then
        return false, 'Faction funds too low.'
    end

    setFactionBalance(factionId, balance - value)

    local added = exports['pa-economy']['PaEconomy:AddMoney'](actor, 'bank', value, reason or 'faction_withdraw', {
        factionName = factionId,
        amount = value,
    })

    if not added then
        setFactionBalance(factionId, balance)
        return false, 'Withdraw failed; rolled back.'
    end

    logEvent('PaLogging:LogEconomy', actor, 'faction_funds_withdraw', 'Faction funds withdrawal completed.', {
        factionName = factionId,
        amount = value,
        balance = balance - value,
    })

    return true, nil, balance - value
end

function PaFactions:GetFactionInfluence(territoryKey)
    return TerritoryInfluence[tostring(territoryKey or '')] or {}
end

RegisterNetEvent('pa:factions:territoryAction', function(payload)
    local src = source
    payload = type(payload) == 'table' and payload or {}

    local ok, err, result = PaFactions:AddTerritoryPressure(src, payload.factionName, payload.territoryKey, payload.actionType, payload)
    if not ok then
        notify(src, 'warn', 'Territory action denied', err or 'Denied.')
        TriggerClientEvent('pa:factions:territoryResult', src, { ok = false, error = err })
        return
    end

    notify(src, 'success', 'Territory pressure', ('%s influence now %s'):format(result.territoryKey, result.influence))
    TriggerClientEvent('pa:factions:territoryResult', src, { ok = true, result = result })
end)

RegisterNetEvent('pa:factions:requestLaunder', function(payload)
    local src = source
    payload = type(payload) == 'table' and payload or {}

    local faction = PaFactions:GetFaction(src)
    if not faction then
        notify(src, 'warn', 'Laundering denied', 'You are not in a faction.')
        return
    end

    local links = FrontLinks[faction.factionName] or {}
    if not PaFactions:HasPermission(src, 'launder') then
        notify(src, 'warn', 'Laundering denied', 'Your rank cannot launder through faction fronts.')
        return
    end
    local link = links[payload.businessKey]
    if not link or link.launderingEnabled ~= true then
        notify(src, 'warn', 'Laundering denied', 'This business is not approved as a faction front.')
        return
    end

    local ok, err = exports['pa-crime']['PaCrime:LaunderMoney'](src, payload.businessKey, payload.amount, payload)
    if not ok then
        notify(src, 'error', 'Laundering failed', err or 'Could not process laundering.')
        return
    end

    notify(src, 'success', 'Laundering complete', 'Funds moved through linked front business.')
end)

RegisterNetEvent('pa:factions:fundsDeposit', function(payload)
    local src = source
    payload = type(payload) == 'table' and payload or {}

    local ok, err, balance = PaFactions:DepositFunds(src, payload.factionName, payload.amount, payload.reason)
    if not ok then
        notify(src, 'error', 'Deposit failed', err or 'Could not deposit.')
        return
    end

    notify(src, 'success', 'Faction funds', ('New balance: $%s'):format(balance))
end)

RegisterNetEvent('pa:factions:fundsWithdraw', function(payload)
    local src = source
    payload = type(payload) == 'table' and payload or {}

    local ok, err, balance = PaFactions:WithdrawFunds(src, payload.factionName, payload.amount, payload.reason)
    if not ok then
        notify(src, 'error', 'Withdraw failed', err or 'Could not withdraw.')
        return
    end

    notify(src, 'success', 'Faction funds', ('New balance: $%s'):format(balance))
end)

RegisterNetEvent('pa:factions:openStorage', function(payload)
    local src = source
    payload = type(payload) == 'table' and payload or {}

    local faction = PaFactions:GetFaction(src)
    if not faction or faction.factionName ~= payload.factionName then
        notify(src, 'error', 'Storage denied', 'You are not a member of this faction.')
        return
    end

    local member = getOrCacheMember(src)
    if not hasPermission(member, 'storage_access') then
        notify(src, 'error', 'Storage denied', 'Your rank cannot access faction storage.')
        return
    end

    TriggerClientEvent('ox_inventory:openInventory', src, 'stash', ('faction_%s'):format(faction.factionName))
end)

exports('PaFactions:GetFaction', function(src)
    return PaFactions:GetFaction(src)
end)

exports('PaFactions:HasPermission', function(src, permission)
    return PaFactions:HasPermission(src, permission)
end)

exports('PaFactions:SetMemberFaction', function(actorSrc, targetSrc, factionId, rankName)
    return PaFactions:SetMemberFaction(actorSrc, targetSrc, factionId, rankName)
end)

exports('PaFactions:AddTerritoryPressure', function(src, factionId, territoryKey, actionType, payload)
    return PaFactions:AddTerritoryPressure(src, factionId, territoryKey, actionType, payload)
end)

exports('PaFactions:DepositFunds', function(src, factionId, amount, reason)
    return PaFactions:DepositFunds(src, factionId, amount, reason)
end)

exports('PaFactions:WithdrawFunds', function(src, factionId, amount, reason)
    return PaFactions:WithdrawFunds(src, factionId, amount, reason)
end)

exports('PaFactions:LinkFrontBusiness', function(actorSrc, factionId, businessKey, launderingEnabled)
    return PaFactions:LinkFrontBusiness(actorSrc, factionId, businessKey, launderingEnabled)
end)

exports('PaFactions:GetFactionInfluence', function(territoryKey)
    return PaFactions:GetFactionInfluence(territoryKey)
end)

CreateThread(function()
    loadFactionConfig()
    for factionId, faction in pairs(FactionConfig.factions) do
        ensureFactionBusinessAccount(factionId, faction.label or factionId)
    end

    loadFrontLinks()
    loadTerritoryInfluence()
    registerFactionStashes()

    print(('^2[%s] Faction service initialized (%d factions).^7'):format(RESOURCE_NAME, tableSize(FactionConfig.factions)))
end)

AddEventHandler('playerDropped', function()
    MemberCache[source] = nil
end)
