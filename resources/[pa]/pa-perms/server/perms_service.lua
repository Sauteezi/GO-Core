local RESOURCE_NAME = GetCurrentResourceName()

local STAFF_GROUPS = {
    owner = true,
    dev = true,
    admin = true,
    mod = true,
    support = true,
}

local DEPARTMENT_ROLE_MAP = {
    pd = 'whitelisted_pd',
    ems = 'whitelisted_ems',
    fire = 'whitelisted_fire',
    doj = 'whitelisted_doj',
}

local function normalizeRole(role)
    return string.lower(tostring(role or ''))
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

local function getCharId(src)
    local ok, charId = pcall(function()
        return exports['pa-core']['PaCore:GetCharId'](src)
    end)

    if ok then
        return tonumber(charId)
    end

    return nil
end

local function loadRolesForLicense(license)
    if not license then
        return {}
    end

    local rows = exports.oxmysql:querySync([[
        SELECT role_name
        FROM staff_roles
        WHERE license = ?
    ]], { license }) or {}

    local roleSet = {}
    for _, row in ipairs(rows) do
        roleSet[normalizeRole(row.role_name)] = true
    end

    return roleSet
end

local function logStaffCheckFailure(src, requestedRoles, failMessage)
    local license = getLicense(src)
    if GetResourceState('pa-logging') ~= 'started' then
        return
    end

    pcall(function()
        exports['pa-logging']['PaLogging:LogAdmin']({
            resource = RESOURCE_NAME,
            source = src,
            action = 'staff_check_failed',
            message = failMessage or 'Staff action denied due to missing role.',
            actorLicense = license,
            meta = {
                requestedRoles = requestedRoles,
            },
        })
    end)
end

local function requestedRolesIncludeStaff(roles)
    for _, role in ipairs(roles) do
        if STAFF_GROUPS[normalizeRole(role)] then
            return true
        end
    end

    return false
end

local function asRoleArray(roles)
    if type(roles) == 'string' then
        return { roles }
    end

    if type(roles) == 'table' then
        return roles
    end

    return {}
end

local PaPerms = {}

function PaPerms:HasRole(src, role)
    local license = getLicense(src)
    local roles = loadRolesForLicense(license)
    return roles[normalizeRole(role)] == true
end

function PaPerms:HasAny(src, roles)
    local roleList = asRoleArray(roles)
    local license = getLicense(src)
    local roleSet = loadRolesForLicense(license)

    for _, role in ipairs(roleList) do
        if roleSet[normalizeRole(role)] then
            return true
        end
    end

    return false
end

function PaPerms:IsWhitelisted(src, dept)
    local role = DEPARTMENT_ROLE_MAP[normalizeRole(dept)]
    if not role then
        return false
    end

    return self:HasRole(src, role)
end

function PaPerms:Require(src, roles, failMessage)
    local roleList = asRoleArray(roles)
    local ok = self:HasAny(src, roleList)

    if ok then
        return true
    end

    if requestedRolesIncludeStaff(roleList) then
        logStaffCheckFailure(src, roleList, failMessage)
    end

    TriggerClientEvent('pa:ui:notify', src, {
        type = 'error',
        title = 'Access denied',
        message = failMessage or 'You do not have permission for this action.',
        duration = 4500,
    })

    return false
end

function PaPerms:SetDepartmentDuty(src, dept, onDuty)
    local department = normalizeRole(dept)
    local jobName = department
    local charId = getCharId(src)

    if not charId then
        return false, 'No active character selected.'
    end

    if DEPARTMENT_ROLE_MAP[department] == nil then
        return false, 'Unknown department for duty.'
    end

    if not self:IsWhitelisted(src, department) then
        return false, 'You are not whitelisted for this department.'
    end

    exports.oxmysql:executeSync([[
        INSERT INTO job_duty (char_id, job_name, grade, on_duty, last_toggled_at)
        VALUES (?, ?, 0, ?, CURRENT_TIMESTAMP)
        ON DUPLICATE KEY UPDATE
            on_duty = VALUES(on_duty),
            last_toggled_at = CURRENT_TIMESTAMP,
            updated_at = CURRENT_TIMESTAMP
    ]], { charId, jobName, onDuty and 1 or 0 })

    if GetResourceState('pa-logging') == 'started' then
        pcall(function()
            exports['pa-logging']['PaLogging:LogAudit']({
                resource = RESOURCE_NAME,
                source = src,
                action = 'set_department_duty',
                message = 'Department duty status updated.',
                actorLicense = getLicense(src),
                meta = { department = department, onDuty = onDuty == true },
            })
        end)
    end

    return true, nil
end

exports('PaPerms:HasRole', function(src, role)
    return PaPerms:HasRole(src, role)
end)

exports('PaPerms:HasAny', function(src, roles)
    return PaPerms:HasAny(src, roles)
end)

exports('PaPerms:IsWhitelisted', function(src, dept)
    return PaPerms:IsWhitelisted(src, dept)
end)

exports('PaPerms:Require', function(src, roles, failMessage)
    return PaPerms:Require(src, roles, failMessage)
end)

exports('PaPerms:SetDepartmentDuty', function(src, dept, onDuty)
    return PaPerms:SetDepartmentDuty(src, dept, onDuty)
end)

RegisterNetEvent('pa:perms:setDuty', function(payload)
    local src = source
    payload = type(payload) == 'table' and payload or {}

    local ok, err = PaPerms:SetDepartmentDuty(src, payload.dept, payload.onDuty == true)
    if not ok then
        TriggerClientEvent('pa:ui:notify', src, {
            type = 'error',
            title = 'Duty update failed',
            message = err,
            duration = 4500,
        })
        return
    end

    TriggerClientEvent('pa:ui:notify', src, {
        type = 'success',
        title = 'Duty updated',
        message = ('%s duty is now %s.'):format(tostring(payload.dept), payload.onDuty and 'on' or 'off'),
        duration = 3500,
    })
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= RESOURCE_NAME then
        return
    end

    print(('^2[%s] Permissions service ready (staff + whitelist + department duty).^7'):format(RESOURCE_NAME))
end)
