local RESOURCE_NAME = GetCurrentResourceName()

local HousingConfig = { defaults = {}, properties = {} }
local OwnedProperties = {} -- [propertyKey] = { ownerCharId, rentDueAt, metadata }
local PropertyKeys = {} -- [propertyKey][charId] = keyType
local NeighborhoodRep = {} -- [neighborhood] = rep
local GangPressure = {} -- [neighborhood] = pressure

local function now() return os.time() end

local function logEvent(levelExport, payload)
    if GetResourceState('pa-logging') ~= 'started' then return end
    pcall(function() exports['pa-logging'][levelExport](payload) end)
end

local function loadConfig()
    local cfg = exports['pa-shared']['PaShared:GetConfig']('housing')
    if type(cfg) == 'table' then
        HousingConfig.defaults = cfg.defaults or {}
        HousingConfig.properties = cfg.properties or {}
    end
end

local function getCharId(src)
    return exports['pa-core']['PaCore:GetCharId'](src)
end

local function getLicense(src)
    return exports['pa-core']['PaCore:GetLicense'](src)
end

local function requireChar(src)
    local charId = getCharId(src)
    if not charId then return nil, 'No active character.' end
    return charId, nil
end

local function getPropertyDef(propertyKey)
    return HousingConfig.properties[tostring(propertyKey or '')]
end

local function ensureKeyStore(propertyKey)
    PropertyKeys[propertyKey] = PropertyKeys[propertyKey] or {}
end

local function setPropertyKey(propertyKey, charId, keyType)
    ensureKeyStore(propertyKey)
    PropertyKeys[propertyKey][charId] = keyType

    if GetResourceState('oxmysql') == 'started' then
        local property = OwnedProperties[propertyKey]
        if property and property.id then
            exports.oxmysql:execute([[INSERT INTO property_keys (property_id, char_id, key_type)
                VALUES (?, ?, ?)
                ON DUPLICATE KEY UPDATE key_type = VALUES(key_type)]], { property.id, charId, keyType })
        end
    end
end

local function revokePropertyKey(propertyKey, charId)
    if PropertyKeys[propertyKey] then
        PropertyKeys[propertyKey][charId] = nil
    end

    local property = OwnedProperties[propertyKey]
    if GetResourceState('oxmysql') == 'started' and property and property.id then
        exports.oxmysql:execute('DELETE FROM property_keys WHERE property_id = ? AND char_id = ?', { property.id, charId })
    end
end

local function hasPropertyAccess(charId, propertyKey)
    local keys = PropertyKeys[propertyKey] or {}
    return keys[charId] ~= nil
end

local function registerStash(propertyKey, propertyDef)
    if GetResourceState('ox_inventory') ~= 'started' then
        return
    end

    local slots = tonumber(HousingConfig.defaults.stashSlots) or 50
    local weight = tonumber(HousingConfig.defaults.stashWeight) or 120000

    pcall(function()
        exports.ox_inventory:RegisterStash(('house_%s'):format(propertyKey), propertyDef.label .. ' Storage', slots, weight)
    end)
end

local function persistProperty(propertyKey)
    local entry = OwnedProperties[propertyKey]
    if not entry or GetResourceState('oxmysql') ~= 'started' then return end

    local def = getPropertyDef(propertyKey)
    if not def then return end

    exports.oxmysql:execute([[INSERT INTO properties (property_key, label, owner_char_id, value, entry_coords, rent_amount, interior_type, metadata)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            owner_char_id = VALUES(owner_char_id),
            value = VALUES(value),
            entry_coords = VALUES(entry_coords),
            rent_amount = VALUES(rent_amount),
            interior_type = VALUES(interior_type),
            metadata = VALUES(metadata)]], {
        propertyKey,
        def.label,
        entry.ownerCharId,
        tonumber(def.price) or 0,
        json.encode(def.entryCoords or {}),
        tonumber(def.rent) or 0,
        tostring(def.interiorType or ''),
        json.encode(entry.metadata or {}),
    }, function(result)
        if type(result) == 'table' and result.insertId and result.insertId > 0 then
            entry.id = result.insertId
        end
    end)
end

local function buildPropertyView(src)
    local charId = getCharId(src)
    local list = {}

    for propertyKey, def in pairs(HousingConfig.properties) do
        local owned = OwnedProperties[propertyKey]
        local hasKey = charId and hasPropertyAccess(charId, propertyKey)
        list[#list + 1] = {
            key = propertyKey,
            label = def.label,
            neighborhood = def.neighborhood,
            price = def.price,
            rent = def.rent,
            interiorType = def.interiorType,
            metadata = def.metadata,
            owned = owned ~= nil,
            ownerCharId = owned and owned.ownerCharId or nil,
            hasKey = hasKey,
            gangPressure = GangPressure[def.neighborhood] or 0,
            neighborhoodRep = NeighborhoodRep[def.neighborhood] or 0,
        }
    end

    table.sort(list, function(a, b) return a.label < b.label end)
    return list
end

local function applyStoryHooks(src, propertyDef)
    local n = propertyDef.neighborhood
    NeighborhoodRep[n] = (NeighborhoodRep[n] or 0) + 2

    if propertyDef.territoryFaction then
        GangPressure[n] = math.min(100, (GangPressure[n] or 0) + 4)
    else
        GangPressure[n] = math.max(0, (GangPressure[n] or 0) - 1)
    end

    local grant = tonumber(HousingConfig.defaults.rebuildingGrant) or 0
    if grant > 0 and GetResourceState('pa-economy') == 'started' then
        exports['pa-economy']['PaEconomy:AddMoney'](src, 'bank', grant, 'housing_rebuild_grant', {
            neighborhood = n,
            storyNode = propertyDef.metadata and propertyDef.metadata.storyNode,
        })
    end

    TriggerEvent('pa:story:housingRebuildProgress', {
        source = src,
        neighborhood = n,
        reputation = NeighborhoodRep[n],
        pressure = GangPressure[n],
    })
end

local function purchaseProperty(src, propertyKey)
    local charId, err = requireChar(src)
    if not charId then return false, err end

    local def = getPropertyDef(propertyKey)
    if not def then return false, 'Unknown property.' end
    if OwnedProperties[propertyKey] then return false, 'Property already owned.' end

    local amount = math.floor(tonumber(def.price) or 0)
    if amount <= 0 then return false, 'Invalid property price.' end

    local ok = exports['pa-economy']['PaEconomy:RemoveMoney'](src, 'bank', amount, 'housing_purchase', { propertyKey = propertyKey })
    if not ok then return false, 'Insufficient funds.' end

    OwnedProperties[propertyKey] = {
        ownerCharId = charId,
        rentDueAt = now() + ((tonumber(HousingConfig.defaults.rentIntervalHours) or 24) * 3600),
        metadata = {
            purchasedAt = now(),
            neighborhoodRepAtPurchase = NeighborhoodRep[def.neighborhood] or 0,
        },
    }

    setPropertyKey(propertyKey, charId, 'owner')
    registerStash(propertyKey, def)
    persistProperty(propertyKey)
    applyStoryHooks(src, def)

    logEvent('PaLogging:LogEconomy', {
        resource = RESOURCE_NAME,
        source = src,
        action = 'housing_purchase',
        message = 'Property purchase completed.',
        actorLicense = getLicense(src),
        meta = { propertyKey = propertyKey, amount = amount },
    })

    return true, nil
end

local function rentProperty(src, propertyKey)
    local charId, err = requireChar(src)
    if not charId then return false, err end

    local def = getPropertyDef(propertyKey)
    if not def then return false, 'Unknown property.' end

    local existing = OwnedProperties[propertyKey]
    if existing and existing.ownerCharId ~= charId then
        return false, 'Property is currently occupied.'
    end

    local amount = math.floor(tonumber(def.rent) or 0)
    if amount <= 0 then return false, 'Invalid rent value.' end

    local ok = exports['pa-economy']['PaEconomy:RemoveMoney'](src, 'bank', amount, 'housing_rent', { propertyKey = propertyKey })
    if not ok then return false, 'Could not pay rent.' end

    OwnedProperties[propertyKey] = OwnedProperties[propertyKey] or {}
    OwnedProperties[propertyKey].ownerCharId = charId
    OwnedProperties[propertyKey].rentDueAt = now() + ((tonumber(HousingConfig.defaults.rentIntervalHours) or 24) * 3600)
    OwnedProperties[propertyKey].metadata = OwnedProperties[propertyKey].metadata or {}
    OwnedProperties[propertyKey].metadata.rented = true
    OwnedProperties[propertyKey].metadata.rentStartedAt = now()

    setPropertyKey(propertyKey, charId, 'owner')
    registerStash(propertyKey, def)
    persistProperty(propertyKey)
    applyStoryHooks(src, def)

    logEvent('PaLogging:LogEconomy', {
        resource = RESOURCE_NAME,
        source = src,
        action = 'housing_rent',
        message = 'Rent payment completed.',
        actorLicense = getLicense(src),
        meta = { propertyKey = propertyKey, amount = amount },
    })

    return true, nil
end

local function shareKey(src, propertyKey, targetSrc)
    local charId, err = requireChar(src)
    if not charId then return false, err end

    local target = tonumber(targetSrc)
    local targetChar = target and getCharId(target) or nil
    if not targetChar then return false, 'Target character unavailable.' end

    local owned = OwnedProperties[propertyKey]
    if not owned or owned.ownerCharId ~= charId then
        return false, 'Only owner can share keys.'
    end

    setPropertyKey(propertyKey, targetChar, 'tenant')
    return true, nil
end

local function revokeKey(src, propertyKey, targetSrc)
    local charId, err = requireChar(src)
    if not charId then return false, err end

    local target = tonumber(targetSrc)
    local targetChar = target and getCharId(target) or nil
    if not targetChar then return false, 'Target character unavailable.' end

    local owned = OwnedProperties[propertyKey]
    if not owned or owned.ownerCharId ~= charId then
        return false, 'Only owner can revoke keys.'
    end

    revokePropertyKey(propertyKey, targetChar)
    return true, nil
end

local function requestEnter(src, propertyKey)
    local charId, err = requireChar(src)
    if not charId then return false, err end

    local def = getPropertyDef(propertyKey)
    if not def then return false, 'Unknown property.' end

    local allowed = hasPropertyAccess(charId, propertyKey)
    if not allowed then
        local pressure = GangPressure[def.neighborhood] or 0
        if pressure >= 80 then
            return false, 'Gang pressure is high; access denied without keys.'
        end
        return false, 'You do not have keys.'
    end

    if isRateLimited(src, ('housing:enter:%s'):format(propertyKey), 6, 60000) then
        return false, 'Entry rate limited.'
    end

    return true, nil
end

local function loadFromDb()
    if GetResourceState('oxmysql') ~= 'started' then
        return
    end

    exports.oxmysql:execute('SELECT id, property_key, owner_char_id, metadata FROM properties', {}, function(rows)
        if type(rows) ~= 'table' then return end

        for _, row in ipairs(rows) do
            local key = row.property_key
            if key and HousingConfig.properties[key] then
                OwnedProperties[key] = {
                    id = row.id,
                    ownerCharId = row.owner_char_id,
                    metadata = row.metadata and json.decode(row.metadata) or {},
                    rentDueAt = now() + ((tonumber(HousingConfig.defaults.rentIntervalHours) or 24) * 3600),
                }

                if row.owner_char_id then
                    setPropertyKey(key, row.owner_char_id, 'owner')
                end
            end
        end
    end)

    exports.oxmysql:execute('SELECT p.property_key, pk.char_id, pk.key_type FROM property_keys pk JOIN properties p ON p.id = pk.property_id', {}, function(rows)
        if type(rows) ~= 'table' then return end
        for _, row in ipairs(rows) do
            if row.property_key and row.char_id then
                setPropertyKey(row.property_key, row.char_id, row.key_type or 'tenant')
            end
        end
    end)
end

RegisterNetEvent('pa:housing:openRealtor', function()
    local src = source
    TriggerClientEvent('pa:housing:openUi', src, {
        properties = buildPropertyView(src),
        neighborhoodRep = NeighborhoodRep,
        gangPressure = GangPressure,
    })
end)

RegisterNetEvent('pa:housing:purchase', function(payload)
    local src = source
    payload = type(payload) == 'table' and payload or {}
    local propertyKey = tostring(payload.propertyKey or '')

    local ok, err = purchaseProperty(src, propertyKey)
    if not ok then
        TriggerClientEvent('pa:ui:notify', src, { type = 'error', title = 'Realtor', message = err, duration = 4500 })
        return
    end

    TriggerClientEvent('pa:ui:notify', src, { type = 'success', title = 'Realtor', message = 'Property purchased successfully.', duration = 4500 })
end)

RegisterNetEvent('pa:housing:rent', function(payload)
    local src = source
    payload = type(payload) == 'table' and payload or {}
    local propertyKey = tostring(payload.propertyKey or '')

    local ok, err = rentProperty(src, propertyKey)
    if not ok then
        TriggerClientEvent('pa:ui:notify', src, { type = 'warn', title = 'Rent', message = err, duration = 4500 })
        return
    end

    TriggerClientEvent('pa:ui:notify', src, { type = 'success', title = 'Rent', message = 'Rent paid and keys issued.', duration = 4500 })
end)

RegisterNetEvent('pa:housing:shareKey', function(payload)
    local src = source
    payload = type(payload) == 'table' and payload or {}

    local ok, err = shareKey(src, tostring(payload.propertyKey or ''), payload.targetSrc)
    if not ok then
        TriggerClientEvent('pa:ui:notify', src, { type = 'error', title = 'Housing Keys', message = err, duration = 3500 })
        return
    end

    TriggerClientEvent('pa:ui:notify', src, { type = 'success', title = 'Housing Keys', message = 'Key shared.', duration = 3500 })
end)

RegisterNetEvent('pa:housing:revokeKey', function(payload)
    local src = source
    payload = type(payload) == 'table' and payload or {}

    local ok, err = revokeKey(src, tostring(payload.propertyKey or ''), payload.targetSrc)
    if not ok then
        TriggerClientEvent('pa:ui:notify', src, { type = 'error', title = 'Housing Keys', message = err, duration = 3500 })
        return
    end

    TriggerClientEvent('pa:ui:notify', src, { type = 'success', title = 'Housing Keys', message = 'Key revoked.', duration = 3500 })
end)

RegisterNetEvent('pa:housing:enter', function(payload)
    local src = source
    payload = type(payload) == 'table' and payload or {}

    local propertyKey = tostring(payload.propertyKey or '')
    local ok, err = requestEnter(src, propertyKey)
    if not ok then
        TriggerClientEvent('pa:ui:notify', src, { type = 'warn', title = 'Housing', message = err, duration = 3500 })
        return
    end

    TriggerClientEvent('pa:housing:enterAuthorized', src, { propertyKey = propertyKey })
end)

RegisterNetEvent('pa:housing:openStash', function(payload)
    local src = source
    payload = type(payload) == 'table' and payload or {}
    local propertyKey = tostring(payload.propertyKey or '')

    local charId, err = requireChar(src)
    if not charId then
        TriggerClientEvent('pa:ui:notify', src, { type = 'error', title = 'Storage', message = err, duration = 3500 })
        return
    end

    if not hasPropertyAccess(charId, propertyKey) then
        TriggerClientEvent('pa:ui:notify', src, { type = 'error', title = 'Storage', message = 'No access to this stash.', duration = 3500 })
        return
    end

    TriggerClientEvent('pa:housing:openStashAuthorized', src, { stash = ('house_%s'):format(propertyKey) })
end)

CreateThread(function()
    while true do
        Wait(300000)

        local rentInterval = (tonumber(HousingConfig.defaults.rentIntervalHours) or 24) * 3600
        local grace = (tonumber(HousingConfig.defaults.graceHours) or 12) * 3600

        for propertyKey, entry in pairs(OwnedProperties) do
            if entry.ownerCharId and entry.rentDueAt and now() >= entry.rentDueAt then
                local dueAmount = math.floor(tonumber(HousingConfig.properties[propertyKey].rent) or 0)
                local paid = false

                for _, src in ipairs(GetPlayers()) do
                    src = tonumber(src)
                    if src and getCharId(src) == entry.ownerCharId then
                        paid = exports['pa-economy']['PaEconomy:RemoveMoney'](src, 'bank', dueAmount, 'housing_rent_due', {
                            propertyKey = propertyKey,
                            auto = true,
                        }) == true

                        if paid then
                            TriggerClientEvent('pa:ui:notify', src, {
                                type = 'info',
                                title = 'Housing Rent',
                                message = ('Auto-paid rent: $%s'):format(dueAmount),
                                duration = 3500,
                            })
                        end
                        break
                    end
                end

                if paid then
                    entry.rentDueAt = now() + rentInterval
                elseif now() >= (entry.rentDueAt + grace) then
                    local owner = entry.ownerCharId
                    OwnedProperties[propertyKey] = nil
                    PropertyKeys[propertyKey] = {}

                    logEvent('PaLogging:LogWarn', {
                        resource = RESOURCE_NAME,
                        source = 0,
                        action = 'rent_eviction',
                        message = 'Property revoked after rent grace period.',
                        meta = { propertyKey = propertyKey, ownerCharId = owner, amount = dueAmount },
                    })
                end
            end
        end
    end
end)

exports('PaHousing:HasAccess', function(src, propertyKey)
    local charId = getCharId(src)
    if not charId then return false end
    return hasPropertyAccess(charId, propertyKey)
end)

exports('PaHousing:GetNeighborhoodPressure', function(neighborhood)
    return GangPressure[tostring(neighborhood or '')] or 0
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= RESOURCE_NAME then return end
    loadConfig()
    loadFromDb()

    for propertyKey, def in pairs(HousingConfig.properties) do
        registerStash(propertyKey, def)
        NeighborhoodRep[def.neighborhood] = NeighborhoodRep[def.neighborhood] or 0
        GangPressure[def.neighborhood] = GangPressure[def.neighborhood] or 0
    end

    print(('^2[%s] Housing service ready (purchase/rent/keys/storage/realtor).^7'):format(RESOURCE_NAME))
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == 'pa-shared' and GetResourceState(RESOURCE_NAME) == 'started' then
        loadConfig()
    end
end)
