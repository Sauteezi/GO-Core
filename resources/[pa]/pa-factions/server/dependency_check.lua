local RESOURCE_NAME = GetCurrentResourceName()

local REQUIRED_DEPENDENCIES = {
    { name = 'oxmysql', reason = 'Required before pa-factions can initialize safely.' },
    { name = 'ox_lib', reason = 'Required before pa-factions can initialize safely.' },
    { name = 'pma-voice', reason = 'Required before pa-factions can initialize safely.' },
    { name = 'ox_target', reason = 'Required before pa-factions can initialize safely.' },
    { name = 'pa-core', reason = 'pa-core is the only hard gameplay dependency and must start first.' },
    { name = 'pa-perms', reason = 'Required for admin/staff fallback access in faction management.' },
    { name = 'pa-logging', reason = 'pa-logging is required for economy/inventory/perms/admin/suspicious behavior audit traces.' },
    { name = 'pa-crime', reason = 'Required for faction-linked laundering actions.' },
    { name = 'pa-inventory', reason = 'Required for faction storage access patterns.' },
    { name = 'pa-guard', reason = 'Required for territory pressure validation and anti-spam checks.' },
    { name = 'pa-business', reason = 'Required for faction front-business linking.' },
    { name = 'pa-economy', reason = 'Required for faction funds and payouts.' },
    { name = 'pa-shared', reason = 'Required for faction config/ranks/territory definitions.' },
}

local function printDependencyError(missingDependency, reason)
    print(('^1[%s] Missing dependency: %s^7'):format(RESOURCE_NAME, missingDependency))
    print(('^3[%s] Why it matters:^7 %s'):format(RESOURCE_NAME, reason))
    print(('^3[%s] Fix:^7 Add `ensure %s` above `ensure %s` in server.cfg.'):format(RESOURCE_NAME, missingDependency, RESOURCE_NAME))
    print(('^3[%s] Beginner tip:^7 Use docs/server_cfg_example.txt for the correct order.'):format(RESOURCE_NAME))
end

local function isResourceStarted(resourceName)
    local state = GetResourceState(resourceName)
    return state == 'started' or state == 'starting'
end

local function checkDependencies()
    local missing = false

    for _, dependency in ipairs(REQUIRED_DEPENDENCIES) do
        if not isResourceStarted(dependency.name) then
            missing = true
            printDependencyError(dependency.name, dependency.reason)
        end
    end

    if missing then
        print(('^1[%s] Dependency check failed. Resource startup aborted.^7'):format(RESOURCE_NAME))
        return false
    end

    print(('^2[%s] Dependency check passed.^7'):format(RESOURCE_NAME))
    return true
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= RESOURCE_NAME then
        return
    end

    if not checkDependencies() then
        StopResource(RESOURCE_NAME)
    end
end)
