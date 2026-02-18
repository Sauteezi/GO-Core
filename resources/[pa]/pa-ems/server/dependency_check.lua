local RESOURCE_NAME = GetCurrentResourceName()

local REQUIRED_DEPENDENCIES = {
    { name = 'oxmysql', reason = 'Required before pa-ems can persist medical records and billing.' },
    { name = 'pa-core', reason = 'pa-core provides authoritative character linkage.' },
    { name = 'pa-jobs', reason = 'pa-jobs provides EMS duty state.' },
    { name = 'pa-dispatch', reason = 'pa-dispatch is required for 911 call routing.' },
    { name = 'pa-inventory', reason = 'pa-inventory is required for revive item checks.' },
    { name = 'pa-economy', reason = 'pa-economy is required for hospital billing and insurance handling.' },
    { name = 'pa-ui', reason = 'pa-ui is required for EMS notifications and UX consistency.' },
    { name = 'pa-logging', reason = 'pa-logging is required for medical and billing audit trails.' },
    { name = 'pa-guard', reason = 'pa-guard is required for rate-limit and proximity anti-abuse checks.' },
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
