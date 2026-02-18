local RESOURCE_NAME = GetCurrentResourceName()

local function deepCopy(value)
    if type(value) ~= 'table' then
        return value
    end

    local copied = {}
    for k, v in pairs(value) do
        copied[deepCopy(k)] = deepCopy(v)
    end

    return copied
end

local function freezeTable(value)
    if type(value) ~= 'table' then
        return value
    end

    local frozen = {}
    for k, v in pairs(value) do
        frozen[k] = freezeTable(v)
    end

    return setmetatable({}, {
        __index = frozen,
        __newindex = function()
            error('Attempted to modify read-only pa-shared config table.', 2)
        end,
        __pairs = function()
            return next, frozen, nil
        end,
        __ipairs = function()
            return ipairs(frozen)
        end,
        __len = function()
            return #frozen
        end,
        __metatable = false,
    })
end

local function getConfigByName(name)
    if type(name) ~= 'string' or name == '' then
        error('PaShared:GetConfig(name) requires a non-empty string name.', 2)
    end

    local registry = rawget(_G, 'PaSharedConfigRegistry') or {}
    local config = registry[name]

    if not config then
        error(('Unknown shared config "%s". Valid names: items, jobs, factions, licenses, story_chapters, economy, businesses, housing, crime, strings.'):format(name), 2)
    end

    return freezeTable(deepCopy(config))
end

local PaShared = {}

function PaShared:GetConfig(name)
    return getConfigByName(name)
end

exports('PaShared:GetConfig', function(name)
    return PaShared:GetConfig(name)
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= RESOURCE_NAME then
        return
    end

    local registry = rawget(_G, 'PaSharedConfigRegistry') or {}
    local requiredKeys = {
        'items',
        'jobs',
        'factions',
        'licenses',
        'story_chapters',
        'economy',
        'businesses',
        'housing',
        'crime',
        'strings',
    }

    for _, key in ipairs(requiredKeys) do
        if type(registry[key]) ~= 'table' then
            print(('^1[%s] Missing config table: %s^7'):format(RESOURCE_NAME, key))
            print(('^3[%s] Fix:^7 Ensure shared/%s.lua exists and assigns PaSharedConfigRegistry.%s'):format(RESOURCE_NAME, key, key))
            StopResource(RESOURCE_NAME)
            return
        end
    end

    print(('^2[%s] Shared config registry ready. Use export PaShared:GetConfig(name).^7'):format(RESOURCE_NAME))
end)
