local RESOURCE_NAME = GetCurrentResourceName()

local MAX_PER_TRANSACTION = 100
local HIGH_VALUE_RATE_LIMIT_MAX = 2
local HIGH_VALUE_RATE_LIMIT_WINDOW_MS = 60000

local ItemConfig = {
    defaults = {
        weight = 1,
        illegal = false,
        isEvidence = false,
        isMedical = false,
        isFood = false,
    },
    items = {},
}

local function loadItemConfig()
    if GetResourceState('pa-shared') ~= 'started' then
        return
    end

    local ok, cfg = pcall(function()
        return exports['pa-shared']['PaShared:GetConfig']('items')
    end)

    if ok and type(cfg) == 'table' then
        ItemConfig.defaults = cfg.defaults or ItemConfig.defaults
        ItemConfig.items = cfg.items or {}
    end
end

local function summarizeMetadata(metadata)
    if type(metadata) ~= 'table' then
        return {}
    end

    local summary = {}
    local count = 0
    for key, value in pairs(metadata) do
        if count >= 8 then break end
        local valueType = type(value)
        if valueType == 'table' then
            summary[key] = '[table]'
        elseif valueType == 'string' then
            summary[key] = (#value > 64) and (value:sub(1, 64) .. '...') or value
        else
            summary[key] = value
        end
        count = count + 1
    end

    return summary
end

local function log(levelExport, payload)
    if GetResourceState('pa-logging') ~= 'started' then
        return
    end

    pcall(function()
        exports['pa-logging'][levelExport](payload)
    end)
end

local function guardRateLimit(src, key, maxPerWindow, windowMs)
    if GetResourceState('pa-guard') ~= 'started' then
        return true
    end

    local ok = exports['pa-guard']['PaGuard:RateLimit'](src, key, maxPerWindow, windowMs)
    return ok == true
end

local function isOxInventoryReady()
    local state = GetResourceState('ox_inventory')
    return state == 'started' or state == 'starting'
end

local function normalizeItem(item)
    return string.lower(tostring(item or ''))
end

local function getItemDefinition(item)
    local key = normalizeItem(item)
    local definition = ItemConfig.items[key] or {}

    return {
        name = key,
        label = definition.label or key,
        weight = tonumber(definition.weight) or ItemConfig.defaults.weight,
        illegal = definition.illegal == true,
        isEvidence = definition.isEvidence == true,
        isMedical = definition.isMedical == true,
        isFood = definition.isFood == true,
        category = definition.category or ItemConfig.defaults.category,
    }
end

local function validateCount(count)
    local number = tonumber(count)
    if not number or number % 1 ~= 0 then
        return nil, 'Item count must be an integer.'
    end

    number = math.floor(number)
    if number <= 0 then
        return nil, 'Item count must be greater than zero.'
    end

    if number > MAX_PER_TRANSACTION then
        return nil, ('Item count exceeds max per transaction (%s).'):format(MAX_PER_TRANSACTION)
    end

    return number, nil
end

local PaInventory = {}

function PaInventory:AddItem(src, item, count, metadata, reason)
    local source = tonumber(src)
    local itemDef = getItemDefinition(item)
    local itemCount, err = validateCount(count)

    if not source or source <= 0 then
        return false, 'Invalid source.'
    end

    if not itemDef.name or itemDef.name == '' then
        return false, 'Invalid item.'
    end

    if not itemCount then
        return false, err
    end

    if not isOxInventoryReady() then
        return false, 'ox_inventory is not started.'
    end

    if itemDef.illegal or itemDef.isEvidence then
        local limited = guardRateLimit(source, ('inventory:high_grant:%s'):format(itemDef.name), HIGH_VALUE_RATE_LIMIT_MAX, HIGH_VALUE_RATE_LIMIT_WINDOW_MS)
        if not limited then
            log('PaLogging:LogWarn', {
                resource = RESOURCE_NAME,
                source = source,
                action = 'high_value_grant_rate_limited',
                message = 'Blocked high-value item grant due to rate limit.',
                meta = { item = itemDef.name, count = itemCount, reason = reason },
            })
            return false, 'High-value item grant rate limit exceeded.'
        end
    end

    local ok = exports.ox_inventory:AddItem(source, itemDef.name, itemCount, metadata)
    log('PaLogging:LogAudit', {
        resource = RESOURCE_NAME,
        source = source,
        action = 'inventory_add',
        message = ok and 'Inventory add successful.' or 'Inventory add failed.',
        actorLicense = exports['pa-core']['PaCore:GetLicense'](source),
        meta = {
            item = itemDef.name,
            label = itemDef.label,
            count = itemCount,
            reason = reason,
            metadata = summarizeMetadata(metadata),
            success = ok == true,
        },
    })

    if not ok then
        return false, 'ox_inventory add failed.'
    end

    return true, nil
end

function PaInventory:RemoveItem(src, item, count, metadata, reason)
    local source = tonumber(src)
    local itemDef = getItemDefinition(item)
    local itemCount, err = validateCount(count)

    if not source or source <= 0 then
        return false, 'Invalid source.'
    end

    if not itemCount then
        return false, err
    end

    if not isOxInventoryReady() then
        return false, 'ox_inventory is not started.'
    end

    local ok = exports.ox_inventory:RemoveItem(source, itemDef.name, itemCount, metadata)
    log('PaLogging:LogAudit', {
        resource = RESOURCE_NAME,
        source = source,
        action = 'inventory_remove',
        message = ok and 'Inventory remove successful.' or 'Inventory remove failed.',
        actorLicense = exports['pa-core']['PaCore:GetLicense'](source),
        meta = {
            item = itemDef.name,
            label = itemDef.label,
            count = itemCount,
            reason = reason,
            metadata = summarizeMetadata(metadata),
            success = ok == true,
        },
    })

    if not ok then
        return false, 'ox_inventory remove failed.'
    end

    return true, nil
end

function PaInventory:GetItemCount(src, item, metadata)
    local source = tonumber(src)
    local itemDef = getItemDefinition(item)
    if not source or source <= 0 then
        return 0
    end

    if not isOxInventoryReady() then
        return 0
    end

    local count = exports.ox_inventory:Search(source, 'count', itemDef.name, metadata)
    return tonumber(count) or 0
end

function PaInventory:HasItem(src, item, count, metadata)
    local needed = tonumber(count) or 1
    return self:GetItemCount(src, item, metadata) >= needed
end

function PaInventory:RegisterUsableItem(item, cb)
    local itemDef = getItemDefinition(item)
    if type(cb) ~= 'function' then
        return false, 'Callback must be a function.'
    end

    if not isOxInventoryReady() then
        return false, 'ox_inventory is not started.'
    end

    exports.ox_inventory:RegisterUsableItem(itemDef.name, function(source, itemData)
        cb(source, itemData)
    end)

    return true, nil
end

exports('PaInventory:AddItem', function(src, item, count, metadata, reason)
    return PaInventory:AddItem(src, item, count, metadata, reason)
end)

exports('PaInventory:RemoveItem', function(src, item, count, metadata, reason)
    return PaInventory:RemoveItem(src, item, count, metadata, reason)
end)

exports('PaInventory:GetItemCount', function(src, item, metadata)
    return PaInventory:GetItemCount(src, item, metadata)
end)

exports('PaInventory:HasItem', function(src, item, count, metadata)
    return PaInventory:HasItem(src, item, count, metadata)
end)

exports('PaInventory:RegisterUsableItem', function(item, cb)
    return PaInventory:RegisterUsableItem(item, cb)
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= RESOURCE_NAME then
        return
    end

    loadItemConfig()
    print(('^2[%s] Inventory adapter ready (ox_inventory backend + PA stable API).^7'):format(RESOURCE_NAME))
end)
