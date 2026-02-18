local RESOURCE_NAME = GetCurrentResourceName()

local function notify(src, messageType, title, message)
    TriggerClientEvent('pa:ui:notify', src, {
        type = messageType,
        title = title,
        message = message,
        duration = 4500,
    })
end

local function logWarn(src, action, message, meta)
    if GetResourceState('pa-logging') ~= 'started' then
        return
    end

    pcall(function()
        exports['pa-logging']['PaLogging:LogWarn']({
            resource = RESOURCE_NAME,
            source = src,
            action = action,
            message = message,
            meta = meta,
        })
    end)
end

RegisterNetEvent('pa:crime:requestRobbery', function(payload)
    local src = source
    payload = type(payload) == 'table' and payload or {}

    local ok, err, result = exports['pa-crime']['PaCrime:CommitIllegalActivity'](src, {
        activityKey = 'robbery',
        eventType = 'robbery',
        targetCoords = payload.robberyCoords,
        maxDistance = 6.0,
        cooldownMs = 45000,
        requiredItem = payload.requiredItem or 'lockpick',
        requiredItemCount = payload.requiredItemCount or 1,
        heatDelta = payload.heatDelta or 12,
        evidenceChance = payload.evidenceChance or 0.35,
        summary = 'Robbery action validated and processed server-side.',
        evidenceNote = 'Forced entry traces recovered from robbery scene.',
    })

    if not ok then
        logWarn(src, 'robbery_blocked', 'Blocked robbery request after crime validation.', {
            reason = err,
            coords = payload.robberyCoords,
        })
        notify(src, 'error', 'Robbery blocked', err or 'Validation failed.')
        TriggerClientEvent('pa:crime:robberyResult', src, { ok = false, error = err })
        return
    end

    notify(src, 'success', 'Robbery request', ('Robbery accepted. Heat: %s (Case #%s).'):format(result.heat, result.caseId))
    TriggerClientEvent('pa:crime:robberyResult', src, { ok = true, result = result })
end)
