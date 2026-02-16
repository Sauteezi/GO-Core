local RESOURCE_NAME = GetCurrentResourceName()

local Calls = {}
local CallIdCounter = 0

local ALLOWED_PRIORITY = {
    low = true,
    medium = true,
    high = true,
    critical = true,
}

local ALLOWED_STATUS = {
    open = true,
    assigned = true,
    enroute = true,
    onscene = true,
    closed = true,
    cancelled = true,
}

local function nowIso()
    return os.date('!%Y-%m-%dT%H:%M:%SZ')
end

local function getCharId(src)
    if GetResourceState('pa-core') ~= 'started' then
        return nil
    end

    return exports['pa-core']['PaCore:GetCharId'](src)
end

local function safeLog(levelExport, payload)
    if GetResourceState('pa-logging') ~= 'started' then
        return
    end

    pcall(function()
        exports['pa-logging'][levelExport](payload)
    end)
end

local function isRateLimited(src, key, maxPerWindow, windowMs)
    if GetResourceState('pa-guard') ~= 'started' then
        return false
    end

    local ok = exports['pa-guard']['PaGuard:RateLimit'](src, key, maxPerWindow, windowMs)
    return ok ~= true
end

local function normalizePriority(priority)
    local value = tostring(priority or 'medium'):lower()
    if not ALLOWED_PRIORITY[value] then
        return 'medium'
    end

    return value
end

local function normalizeStatus(status)
    local value = tostring(status or 'open'):lower()
    if not ALLOWED_STATUS[value] then
        return nil
    end

    return value
end

local function ensureCoords(coords)
    if type(coords) ~= 'table' then
        return nil
    end

    local x = tonumber(coords.x)
    local y = tonumber(coords.y)
    local z = tonumber(coords.z)
    if not x or not y or not z then
        return nil
    end

    return { x = x + 0.0, y = y + 0.0, z = z + 0.0 }
end

local function canManageDispatch(src)
    if GetResourceState('pa-perms') ~= 'started' then
        return true
    end

    local ok = exports['pa-perms']['PaPerms:HasAny'](src, {
        'dispatch',
        'police',
        'ems',
        'fire',
        'admin',
        'mod',
    })

    return ok == true
end

local function appendTimeline(call, status, actorSrc, note)
    call.statusTimeline = call.statusTimeline or {}
    call.statusTimeline[#call.statusTimeline + 1] = {
        status = status,
        at = nowIso(),
        actorSource = actorSrc,
        actorCharId = getCharId(actorSrc),
        note = note,
    }
end

local function persistCreate(call)
    if GetResourceState('oxmysql') ~= 'started' then
        return
    end

    exports.oxmysql:execute([[INSERT INTO dispatch_calls
        (id, call_type, priority, coords_json, description, caller_char_id, assigned_units_json, status, status_timeline_json, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())]], {
        call.id,
        call.type,
        call.priority,
        json.encode(call.coords),
        call.description,
        call.callerCharId,
        json.encode(call.assignedUnits),
        call.status,
        json.encode(call.statusTimeline),
    })
end

local function persistUpdate(call)
    if GetResourceState('oxmysql') ~= 'started' then
        return
    end

    exports.oxmysql:execute([[UPDATE dispatch_calls
        SET priority = ?, coords_json = ?, description = ?, assigned_units_json = ?, status = ?, status_timeline_json = ?, updated_at = NOW()
        WHERE id = ?]], {
        call.priority,
        json.encode(call.coords),
        call.description,
        json.encode(call.assignedUnits),
        call.status,
        json.encode(call.statusTimeline),
        call.id,
    })
end

local function sanitizeCallForClient(call)
    return {
        id = call.id,
        type = call.type,
        priority = call.priority,
        coords = call.coords,
        description = call.description,
        callerCharId = call.callerCharId,
        assignedUnits = call.assignedUnits,
        status = call.status,
        statusTimeline = call.statusTimeline,
        createdAt = call.createdAt,
    }
end

local function broadcastFeed()
    local payload = {}

    for _, call in pairs(Calls) do
        payload[#payload + 1] = sanitizeCallForClient(call)
    end

    table.sort(payload, function(a, b)
        return tonumber(a.id) > tonumber(b.id)
    end)

    TriggerClientEvent('pa:dispatch:updateFeed', -1, payload)
end

local function createCallInternal(src, payload)
    if isRateLimited(src, 'dispatch:create', 6, 15000) then
        return false, 'Dispatch create cooldown active.'
    end

    payload = type(payload) == 'table' and payload or {}

    local callType = tostring(payload.type or 'unknown')
    local description = tostring(payload.description or '')
    local priority = normalizePriority(payload.priority)
    local coords = ensureCoords(payload.coords)
    if not coords then
        return false, 'Valid coordinates are required.'
    end

    if description == '' then
        return false, 'Description is required.'
    end

    local charId = getCharId(src)

    CallIdCounter = CallIdCounter + 1
    local callId = CallIdCounter

    local call = {
        id = callId,
        type = callType,
        priority = priority,
        coords = coords,
        description = description,
        callerCharId = charId,
        assignedUnits = {},
        status = 'open',
        statusTimeline = {},
        createdAt = nowIso(),
    }

    appendTimeline(call, 'open', src, 'Call created')
    Calls[callId] = call

    persistCreate(call)
    broadcastFeed()

    safeLog('PaLogging:LogInfo', {
        resource = RESOURCE_NAME,
        source = src,
        action = 'dispatch_call_created',
        message = 'Dispatch call created.',
        meta = {
            callId = call.id,
            callType = call.type,
            priority = call.priority,
            callerCharId = call.callerCharId,
        },
    })

    return true, sanitizeCallForClient(call)
end

local function assignUnitInternal(src, callId, unit)
    if not canManageDispatch(src) then
        return false, 'No permission to assign units.'
    end

    if isRateLimited(src, 'dispatch:assign', 15, 10000) then
        return false, 'Assign cooldown active.'
    end

    local call = Calls[tonumber(callId)]
    if not call then
        return false, 'Call not found.'
    end

    unit = type(unit) == 'table' and unit or {}
    local unitSource = tonumber(unit.source) or src
    local unitCallsign = tostring(unit.callsign or ('Unit-%s'):format(unitSource))
    local unitType = tostring(unit.unitType or 'unit')

    for _, assigned in ipairs(call.assignedUnits) do
        if tonumber(assigned.source) == unitSource then
            return true, sanitizeCallForClient(call)
        end
    end

    call.assignedUnits[#call.assignedUnits + 1] = {
        source = unitSource,
        callsign = unitCallsign,
        unitType = unitType,
        assignedAt = nowIso(),
    }

    if call.status == 'open' then
        call.status = 'assigned'
    end

    appendTimeline(call, call.status, src, ('Unit assigned: %s'):format(unitCallsign))
    persistUpdate(call)
    broadcastFeed()

    safeLog('PaLogging:LogInfo', {
        resource = RESOURCE_NAME,
        source = src,
        action = 'dispatch_unit_assigned',
        message = 'Unit assigned to dispatch call.',
        meta = {
            callId = call.id,
            unitSource = unitSource,
            callsign = unitCallsign,
        },
    })

    return true, sanitizeCallForClient(call)
end

local function updateStatusInternal(src, callId, status, note)
    if not canManageDispatch(src) then
        return false, 'No permission to update status.'
    end

    if isRateLimited(src, 'dispatch:status', 20, 10000) then
        return false, 'Status update cooldown active.'
    end

    local call = Calls[tonumber(callId)]
    if not call then
        return false, 'Call not found.'
    end

    local normalizedStatus = normalizeStatus(status)
    if not normalizedStatus then
        return false, 'Invalid status.'
    end

    call.status = normalizedStatus
    appendTimeline(call, normalizedStatus, src, tostring(note or 'Status update'))

    persistUpdate(call)
    broadcastFeed()

    safeLog('PaLogging:LogInfo', {
        resource = RESOURCE_NAME,
        source = src,
        action = 'dispatch_status_updated',
        message = 'Dispatch call status updated.',
        meta = {
            callId = call.id,
            status = call.status,
            note = note,
        },
    })

    return true, sanitizeCallForClient(call)
end

local function closeCallInternal(src, callId, note)
    local ok, result = updateStatusInternal(src, callId, 'closed', note or 'Call closed')
    if not ok then
        return false, result
    end

    safeLog('PaLogging:LogInfo', {
        resource = RESOURCE_NAME,
        source = src,
        action = 'dispatch_call_closed',
        message = 'Dispatch call closed.',
        meta = {
            callId = tonumber(callId),
            note = note,
        },
    })

    return true, result
end

RegisterNetEvent('pa:dispatch:requestFeed', function()
    local src = source
    local payload = {}

    for _, call in pairs(Calls) do
        payload[#payload + 1] = sanitizeCallForClient(call)
    end

    table.sort(payload, function(a, b)
        return tonumber(a.id) > tonumber(b.id)
    end)

    TriggerClientEvent('pa:dispatch:updateFeed', src, payload)
end)

RegisterNetEvent('pa:dispatch:createCall', function(payload)
    local src = source
    local ok, result = createCallInternal(src, payload)
    TriggerClientEvent('pa:dispatch:createCallResult', src, ok, result)
end)

RegisterNetEvent('pa:dispatch:assignUnit', function(callId, unit)
    local src = source
    local ok, result = assignUnitInternal(src, callId, unit)
    TriggerClientEvent('pa:dispatch:actionResult', src, ok, result)
end)

RegisterNetEvent('pa:dispatch:updateStatus', function(callId, status, note)
    local src = source
    local ok, result = updateStatusInternal(src, callId, status, note)
    TriggerClientEvent('pa:dispatch:actionResult', src, ok, result)
end)

RegisterNetEvent('pa:dispatch:closeCall', function(callId, note)
    local src = source
    local ok, result = closeCallInternal(src, callId, note)
    TriggerClientEvent('pa:dispatch:actionResult', src, ok, result)
end)

exports('PaDispatch:CreateCall', function(src, payload)
    return createCallInternal(src, payload)
end)

exports('PaDispatch:AssignUnit', function(src, callId, unit)
    return assignUnitInternal(src, callId, unit)
end)

exports('PaDispatch:UpdateStatus', function(src, callId, status, note)
    return updateStatusInternal(src, callId, status, note)
end)

exports('PaDispatch:CloseCall', function(src, callId, note)
    return closeCallInternal(src, callId, note)
end)
