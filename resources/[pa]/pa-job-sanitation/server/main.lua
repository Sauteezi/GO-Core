local RESOURCE_NAME = GetCurrentResourceName()

local ROUTE_POINTS = {
    vector3(-548.6, -190.8, 38.2),
    vector3(122.1, -1034.2, 29.3),
    vector3(-311.4, -904.6, 31.1),
    vector3(253.5, -377.4, 44.1),
    vector3(805.3, -775.0, 26.3),
}

local BASE_PAYOUT = 150
local ALLOWED_JOBS = { ['garbage'] = true }
local COOLDOWN_SECONDS = 25

local ActiveRoutes = {}
local LastCompleteAt = {}
local GlobalProgress = 0

local function logEvent(levelExport, payload)
    if GetResourceState('pa-logging') ~= 'started' then
        return
    end

    pcall(function()
        exports['pa-logging'][levelExport](payload)
    end)
end

local function getReputationMultiplier(src)
    local player = exports['pa-core']['PaCore:GetPlayer'](src)
    local rep = 0

    if type(player) == 'table' and type(player.metadata) == 'table' then
        local value = player.metadata.reputation
        if type(value) == 'number' then
            rep = value
        elseif type(value) == 'table' then
            rep = tonumber(value.civic) or tonumber(value.general) or 0
        end
    end

    rep = math.max(0, math.min(50, tonumber(rep) or 0))
    return 1.0 + (rep / 100.0), rep
end

local function pickRoute(src)
    local idx = math.random(1, #ROUTE_POINTS)
    local coords = ROUTE_POINTS[idx]
    ActiveRoutes[tostring(src)] = {
        index = idx,
        coords = coords,
        startedAt = os.time(),
    }

    TriggerClientEvent('pa:job-sanitation:route', src, {
        coords = { x = coords.x, y = coords.y, z = coords.z },
    })
end

local function ensureJobActive(src)
    local job = exports['pa-jobs']['PaJobs:GetJob'](src)
    if type(job) ~= 'table' then
        return false, 'Job profile unavailable.'
    end

    if job.name == 'unemployed' then
        return false, 'Take a job at City Hall first.'
    end

    if not ALLOWED_JOBS[job.name] then
        return false, 'You are not assigned to this job role.'
    end

    return true, nil
end

RegisterNetEvent('pa:job-sanitation:start', function()
    local src = source
    local ok, err = ensureJobActive(src)
    if not ok then
        TriggerClientEvent('pa:ui:notify', src, { type = 'warn', title = 'Sanitation', message = err, duration = 4500 })
        return
    end

    TriggerClientEvent('pa:job-sanitation:state', src, { active = true })
    pickRoute(src)
    TriggerClientEvent('pa:ui:notify', src, { type = 'info', title = 'Sanitation', message = 'Shift started. Follow your route.', duration = 3500 })
end)

RegisterNetEvent('pa:job-sanitation:stop', function()
    local src = source
    ActiveRoutes[tostring(src)] = nil
    TriggerClientEvent('pa:job-sanitation:state', src, { active = false })
    TriggerClientEvent('pa:ui:notify', src, { type = 'info', title = 'Sanitation', message = 'Shift ended.', duration = 3000 })
end)

RegisterNetEvent('pa:job-sanitation:complete', function(payload)
    local src = source
    payload = type(payload) == 'table' and payload or {}

    local route = ActiveRoutes[tostring(src)]
    if not route then
        TriggerClientEvent('pa:ui:notify', src, { type = 'warn', title = 'Sanitation', message = 'No active route.', duration = 3000 })
        return
    end

    local now = os.time()
    local key = tostring(src)
    local last = LastCompleteAt[key] or 0
    if (now - last) < COOLDOWN_SECONDS then
        TriggerClientEvent('pa:ui:notify', src, { type = 'warn', title = 'Sanitation', message = 'Slow down, route cooldown active.', duration = 3000 })
        logEvent('PaLogging:LogWarn', { resource = RESOURCE_NAME, source = src, action = 'cooldown_block', message = 'Blocked route completion by cooldown.', meta = { remaining = COOLDOWN_SECONDS - (now - last) } })
        return
    end

    local target = route.coords
    local coords = vector3(tonumber(payload.x) or 0.0, tonumber(payload.y) or 0.0, tonumber(payload.z) or 0.0)

    local distanceOk = true
    if GetResourceState('pa-guard') == 'started' then
        distanceOk = exports['pa-guard']['PaGuard:ValidateDistance'](src, { x = target.x, y = target.y, z = target.z }, 15.0) == true
    else
        distanceOk = #(coords - target) <= 15.0
    end

    if not distanceOk then
        TriggerClientEvent('pa:ui:notify', src, { type = 'error', title = 'Sanitation', message = 'Route validation failed.', duration = 4000 })
        logEvent('PaLogging:LogWarn', { resource = RESOURCE_NAME, source = src, action = 'distance_block', message = 'Blocked route completion by distance validation.' })
        return
    end

    LastCompleteAt[key] = now

    local multiplier, rep = getReputationMultiplier(src)
    local payout = math.floor(BASE_PAYOUT * multiplier)
    local reason = 'pa-job-sanitation:route_complete'

    local extraMessage = ''
    local extraMeta = {}

    if 'rare_find' == 'npc_tip' then
        local tip = math.random(10, 70)
        payout = payout + tip
        extraMeta.tip = tip
        extraMessage = (' + $%s NPC tip'):format(tip)
    elseif 'rare_find' == 'rare_find' then
        if math.random(1, 100) <= 20 and GetResourceState('pa-inventory') == 'started' then
            exports['pa-inventory']['PaInventory:AddItem'](src, 'evidence_bag', 1, { origin = 'sanitation_rare_find' }, 'sanitation_rare_find')
            extraMeta.rareFind = 'evidence_bag'
            extraMessage = ' and found a rare item'
        end
    elseif 'rare_find' == 'city_project_progress' then
        GlobalProgress = math.min(100, GlobalProgress + math.random(2, 6))
        TriggerEvent('pa:story:cityProjectProgress', { project = 'downtown_refit', progress = GlobalProgress, source = src })
        extraMeta.projectProgress = GlobalProgress
        extraMessage = (' (city project %s%%)'):format(GlobalProgress)
    elseif 'rare_find' == 'impound_bonus' then
        local bonus = math.random(0, 40)
        payout = payout + bonus
        extraMeta.impoundBonus = bonus
        if bonus > 0 then extraMessage = (' + $%s impound bonus'):format(bonus) end
    elseif 'rare_find' == 'package_quality_bonus' then
        local quality = math.random(1, 3)
        local qualityBonus = quality * 15
        payout = payout + qualityBonus
        extraMeta.packageQuality = quality
        extraMeta.qualityBonus = qualityBonus
        extraMessage = (' + $%s quality bonus'):format(qualityBonus)
    end

    local ok = exports['pa-economy']['PaEconomy:AddMoney'](src, 'bank', payout, reason, {
        routeIndex = route.index,
        reputation = rep,
        multiplier = multiplier,
        resource = RESOURCE_NAME,
        extra = extraMeta,
    })

    if ok then
        TriggerClientEvent('pa:ui:notify', src, {
            type = 'success',
            title = 'Sanitation',
            message = ('Route complete: +$%s%s'):format(payout, extraMessage),
            duration = 4500,
        })

        logEvent('PaLogging:LogEconomy', {
            resource = RESOURCE_NAME,
            source = src,
            action = 'route_payout',
            message = 'Issued job payout.',
            actorLicense = exports['pa-core']['PaCore:GetLicense'](src),
            meta = { payout = payout, reason = reason, reputation = rep, multiplier = multiplier, extra = extraMeta },
        })
    end

    pickRoute(src)
end)

AddEventHandler('playerDropped', function()
    local key = tostring(source)
    ActiveRoutes[key] = nil
    LastCompleteAt[key] = nil
end)
