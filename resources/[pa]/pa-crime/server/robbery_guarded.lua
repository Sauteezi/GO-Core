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

    local allowed, rateMeta = exports['pa-guard']['PaGuard:RateLimit'](src, 'crime:robbery', 2, 20000)
    if not allowed then
        logWarn(src, 'robbery_rate_limit', 'Blocked robbery request due to rate limit.', rateMeta)
        notify(src, 'warn', 'Rate limit', 'Too many robbery requests in a short time.')
        return
    end

    local distanceOk, distMeta = exports['pa-guard']['PaGuard:ValidateDistance'](src, payload.robberyCoords, 6.0)
    if not distanceOk then
        logWarn(src, 'robbery_distance_invalid', 'Blocked robbery request due to distance validation.', distMeta)
        notify(src, 'error', 'Distance check failed', 'You are too far from the robbery target.')
        return
    end

    if GetResourceState('pa-logging') == 'started' then
        pcall(function()
            exports['pa-logging']['PaLogging:LogAudit']({
                resource = RESOURCE_NAME,
                source = src,
                action = 'robbery_request',
                message = 'Guarded robbery request accepted for server-side processing.',
                actorLicense = exports['pa-core']['PaCore:GetLicense'](src),
                meta = { distance = distMeta and distMeta.distance },
            })
        end)
    end

    TriggerClientEvent('pa:crime:robberyResult', src, { ok = true })
    notify(src, 'success', 'Robbery request', 'Robbery request accepted for server processing.')
end)
