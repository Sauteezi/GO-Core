local RESOURCE_NAME = GetCurrentResourceName()

local REQUIRED_DEPENDENCIES = {
    { name = 'ox_target', reason = 'pa-target wraps ox_target APIs for stable framework usage.' },
}

local function isResourceStarted(resourceName)
    local state = GetResourceState(resourceName)
    return state == 'started' or state == 'starting'
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= RESOURCE_NAME then
        return
    end

    for _, dependency in ipairs(REQUIRED_DEPENDENCIES) do
        if not isResourceStarted(dependency.name) then
            print(('^1[%s] Missing dependency: %s^7'):format(RESOURCE_NAME, dependency.name))
            print(('^3[%s] Why it matters:^7 %s'):format(RESOURCE_NAME, dependency.reason))
            StopResource(RESOURCE_NAME)
            return
        end
    end

    print(('^2[%s] Dependency check passed.^7'):format(RESOURCE_NAME))
end)
