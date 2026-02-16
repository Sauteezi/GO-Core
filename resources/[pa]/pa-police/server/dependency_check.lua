local RESOURCE_NAME = GetCurrentResourceName()

local REQUIRED_DEPENDENCIES = {
    { name = 'oxmysql', reason = 'Required before pa-police can persist reports, citations, warrants, and case notes.' },
    { name = 'pa-core', reason = 'pa-core provides authoritative character linkage.' },
    { name = 'pa-jobs', reason = 'pa-jobs provides police duty and grade state.' },
    { name = 'pa-economy', reason = 'pa-economy is required for citation payment integration.' },
    { name = 'pa-inventory', reason = 'pa-inventory is required for evidence bagging.' },
    { name = 'pa-vehicles', reason = 'pa-vehicles supports plate lookup integration.' },
    { name = 'pa-ui', reason = 'pa-ui is required for branded notifications and MDT UX consistency.' },
    { name = 'pa-logging', reason = 'pa-logging is required for audit trails.' },
    { name = 'pa-guard', reason = 'pa-guard is required for rate-limit and distance validation.' },
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
