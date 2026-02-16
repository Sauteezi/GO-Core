local RESOURCE_NAME = GetCurrentResourceName()

local REQUIRED_DEPENDENCIES = {
    { name = 'pa-core', reason = 'pa-core provides player identity and metadata context.' },
    { name = 'pa-shared', reason = 'pa-shared provides business, license, and sink configs.' },
    { name = 'pa-economy', reason = 'pa-economy handles all money movement for invoices/payroll.' },
    { name = 'pa-jobs', reason = 'pa-jobs provides role integration for business workforces.' },
    { name = 'pa-target', reason = 'pa-target provides stable target interaction hooks.' },
    { name = 'pa-ui', reason = 'pa-ui provides branded notifications and NUI wrappers.' },
    { name = 'pa-logging', reason = 'pa-logging provides invoice/tax/audit traces.' },
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
