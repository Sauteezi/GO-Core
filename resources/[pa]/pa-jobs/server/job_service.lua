local RESOURCE_NAME = GetCurrentResourceName()

local JobConfig = {
    defaults = {
        paycheckIntervalMinutes = 30,
        dutyRequired = true,
    },
    jobs = {},
    cityHall = {
        coords = vec3(-552.26, -191.03, 38.22),
        radius = 2.0,
    },
}

local PlayerJobs = {}
local PlayerDuty = {}
local LastPaycheckAt = {}

local function loadConfig()
    if GetResourceState('pa-shared') ~= 'started' then
        return
    end

    local ok, cfg = pcall(function()
        return exports['pa-shared']['PaShared:GetConfig']('jobs')
    end)

    if ok and type(cfg) == 'table' then
        JobConfig.defaults = cfg.defaults or JobConfig.defaults
        JobConfig.jobs = cfg.jobs or {}
        JobConfig.cityHall = cfg.cityHall or JobConfig.cityHall
    end
end

local function logEvent(levelExport, payload)
    if GetResourceState('pa-logging') ~= 'started' then
        return
    end

    pcall(function()
        exports['pa-logging'][levelExport](payload)
    end)
end

local function normalizeJobName(jobName)
    return string.lower(tostring(jobName or ''))
end

local function getJobDef(jobName)
    return JobConfig.jobs[normalizeJobName(jobName)]
end

local function getGradeDef(jobDef, grade)
    if type(jobDef) ~= 'table' or type(jobDef.grades) ~= 'table' then
        return nil
    end

    for _, gradeDef in ipairs(jobDef.grades) do
        if tonumber(gradeDef.level) == tonumber(grade) then
            return gradeDef
        end
    end

    return nil
end

local function getPlayerContext(src)
    local player = nil
    if GetResourceState('pa-core') == 'started' then
        player = exports['pa-core']['PaCore:GetPlayer'](src)
    end

    local licenses = {}
    local reputation = 0

    if type(player) == 'table' then
        if type(player.metadata) == 'table' then
            if type(player.metadata.licenses) == 'table' then
                licenses = player.metadata.licenses
            end

            local rep = player.metadata.reputation
            if type(rep) == 'number' then
                reputation = rep
            elseif type(rep) == 'table' then
                reputation = tonumber(rep.civic) or tonumber(rep.general) or 0
            end
        end
    end

    return {
        player = player,
        licenses = licenses,
        reputation = tonumber(reputation) or 0,
    }
end

local function hasLicense(licenses, name)
    if type(licenses) ~= 'table' then
        return false
    end

    local value = licenses[name]
    if value == true then
        return true
    end

    if type(value) == 'table' then
        return value.active == true
    end

    return false
end

local function requirementsMet(src, jobDef)
    local req = type(jobDef.requirements) == 'table' and jobDef.requirements or {}
    local ctx = getPlayerContext(src)

    if req.minReputation and ctx.reputation < tonumber(req.minReputation) then
        return false, ('Requires reputation %s.'):format(req.minReputation)
    end

    if type(req.licenses) == 'table' then
        for _, licenseName in ipairs(req.licenses) do
            if not hasLicense(ctx.licenses, licenseName) then
                return false, ('Missing required license: %s'):format(licenseName)
            end
        end
    end

    return true, nil
end

local function getCurrentJob(src)
    local entry = PlayerJobs[tostring(src)] or { name = 'unemployed', grade = 0, label = 'Unemployed' }
    local duty = PlayerDuty[tostring(src)] == true

    return {
        name = entry.name,
        grade = entry.grade,
        label = entry.label,
        onDuty = duty,
    }
end

local PaJobs = {}

function PaJobs:SetJob(src, jobName, grade)
    local source = tonumber(src)
    local normalized = normalizeJobName(jobName)
    local jobDef = getJobDef(normalized)

    if not source or source <= 0 then
        return false, 'Invalid source.'
    end

    if not jobDef then
        return false, 'Unknown job.'
    end

    local selectedGrade = tonumber(grade) or 0
    local gradeDef = getGradeDef(jobDef, selectedGrade)
    if not gradeDef then
        return false, 'Invalid grade for job.'
    end

    local ok, reason = requirementsMet(source, jobDef)
    if not ok then
        return false, reason
    end

    PlayerJobs[tostring(source)] = {
        name = normalized,
        grade = selectedGrade,
        label = jobDef.label or normalized,
    }

    PlayerDuty[tostring(source)] = false

    TriggerClientEvent('pa:jobs:jobUpdated', source, getCurrentJob(source))

    logEvent('PaLogging:LogAudit', {
        resource = RESOURCE_NAME,
        source = source,
        action = 'set_job',
        message = 'Player job updated through pa-jobs core.',
        actorLicense = exports['pa-core']['PaCore:GetLicense'](source),
        meta = {
            job = normalized,
            grade = selectedGrade,
        },
    })

    return true, nil
end

function PaJobs:SetDuty(src, onDuty)
    local source = tonumber(src)
    if not source or source <= 0 then
        return false, 'Invalid source.'
    end

    local current = getCurrentJob(source)
    if current.name == 'unemployed' then
        return false, 'No active job.'
    end

    local dutyState = onDuty == true
    PlayerDuty[tostring(source)] = dutyState

    if GetResourceState('pa-perms') == 'started' then
        local deptMap = {
            police = 'pd',
            ems = 'ems',
            fire = 'fire',
            doj = 'doj',
        }
        local dept = deptMap[current.name]
        if dept then
            pcall(function()
                exports['pa-perms']['PaPerms:SetDepartmentDuty'](source, dept, dutyState)
            end)
        end
    end

    TriggerClientEvent('pa:jobs:dutyUpdated', source, { onDuty = dutyState })

    return true, nil
end

function PaJobs:GetJob(src)
    return getCurrentJob(src)
end

local function buildStarterJobsForPlayer(src)
    local list = {}

    for jobName, jobDef in pairs(JobConfig.jobs) do
        if jobDef.starter == true then
            local ok, failReason = requirementsMet(src, jobDef)
            list[#list + 1] = {
                name = jobName,
                label = jobDef.label or jobName,
                requirements = jobDef.requirements or {},
                payRules = jobDef.payRules or {},
                dutyLocations = jobDef.dutyLocations or {},
                available = ok,
                unavailableReason = failReason,
            }
        end
    end

    table.sort(list, function(a, b)
        return tostring(a.label) < tostring(b.label)
    end)

    return list
end

local function issuePaycheck(src)
    local source = tonumber(src)
    if not source then
        return
    end

    local job = getCurrentJob(source)
    local jobDef = getJobDef(job.name)
    if not jobDef then
        return
    end

    local gradeDef = getGradeDef(jobDef, job.grade)
    if not gradeDef then
        return
    end

    local payRules = jobDef.payRules or {}
    local dutyRequired = payRules.dutyRequired
    if dutyRequired == nil then
        dutyRequired = JobConfig.defaults.dutyRequired
    end

    if dutyRequired and not job.onDuty then
        return
    end

    local salary = tonumber(gradeDef.salary) or 0
    if salary <= 0 then
        return
    end

    if GetResourceState('pa-economy') ~= 'started' then
        return
    end

    local reason = ('paycheck:%s:g%s'):format(job.name, job.grade)
    local ok = exports['pa-economy']['PaEconomy:AddMoney'](source, 'bank', salary, reason, {
        job = job.name,
        grade = job.grade,
        kind = 'paycheck',
    })

    if ok then
        logEvent('PaLogging:LogEconomy', {
            resource = RESOURCE_NAME,
            source = source,
            action = 'paycheck_issued',
            message = 'Issued paycheck through pa-economy.',
            actorLicense = exports['pa-core']['PaCore:GetLicense'](source),
            meta = {
                job = job.name,
                grade = job.grade,
                amount = salary,
                reason = reason,
            },
        })
    end
end

CreateThread(function()
    while true do
        Wait(60000)

        local intervalMinutes = tonumber(JobConfig.defaults.paycheckIntervalMinutes) or 30
        local intervalSeconds = math.max(60, math.floor(intervalMinutes * 60))
        local now = os.time()

        for _, src in ipairs(GetPlayers()) do
            src = tonumber(src)
            if src then
                local key = tostring(src)
                local lastPaid = LastPaycheckAt[key] or 0
                if (now - lastPaid) >= intervalSeconds then
                    LastPaycheckAt[key] = now
                    issuePaycheck(src)
                end
            end
        end
    end
end)

RegisterNetEvent('pa:jobs:requestCityHall', function()
    local src = source
    TriggerClientEvent('pa:jobs:openCityHall', src, {
        jobs = buildStarterJobsForPlayer(src),
        cityHall = JobConfig.cityHall,
    })
end)

RegisterNetEvent('pa:jobs:applyStarterJob', function(payload)
    local src = source
    payload = type(payload) == 'table' and payload or {}

    local jobName = normalizeJobName(payload.jobName)
    local grade = tonumber(payload.grade) or 0
    local jobDef = getJobDef(jobName)

    if not jobDef or jobDef.starter ~= true then
        TriggerClientEvent('pa:ui:notify', src, {
            type = 'error',
            title = 'Job Center',
            message = 'That starter job is not available.',
            duration = 5000,
        })
        return
    end

    local ok, err = PaJobs:SetJob(src, jobName, grade)
    if not ok then
        TriggerClientEvent('pa:ui:notify', src, {
            type = 'error',
            title = 'Job Center',
            message = err or 'Unable to assign job.',
            duration = 5000,
        })
        return
    end

    TriggerClientEvent('pa:ui:notify', src, {
        type = 'success',
        title = 'Job Center',
        message = ('You joined %s.'):format(jobDef.label or jobName),
        duration = 5000,
    })

    TriggerClientEvent('pa:jobs:jobUpdated', src, getCurrentJob(src))
end)

RegisterNetEvent('pa:jobs:setDuty', function(payload)
    local src = source
    payload = type(payload) == 'table' and payload or {}

    local ok, err = PaJobs:SetDuty(src, payload.onDuty == true)
    if not ok then
        TriggerClientEvent('pa:ui:notify', src, {
            type = 'warn',
            title = 'Duty',
            message = err or 'Could not toggle duty.',
            duration = 4000,
        })
        return
    end

    local current = getCurrentJob(src)
    TriggerClientEvent('pa:ui:notify', src, {
        type = 'info',
        title = 'Duty',
        message = current.onDuty and 'You are now on duty.' or 'You are now off duty.',
        duration = 3500,
    })
end)

AddEventHandler('playerDropped', function()
    local key = tostring(source)
    PlayerJobs[key] = nil
    PlayerDuty[key] = nil
    LastPaycheckAt[key] = nil
end)

exports('PaJobs:SetJob', function(src, jobName, grade)
    return PaJobs:SetJob(src, jobName, grade)
end)

exports('PaJobs:SetDuty', function(src, onDuty)
    return PaJobs:SetDuty(src, onDuty)
end)

exports('PaJobs:GetJob', function(src)
    return PaJobs:GetJob(src)
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= RESOURCE_NAME then
        return
    end

    loadConfig()
    print(('^2[%s] Job core ready with City Hall starter flow.^7'):format(RESOURCE_NAME))
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == 'pa-shared' and GetResourceState(RESOURCE_NAME) == 'started' then
        loadConfig()
    end
end)
