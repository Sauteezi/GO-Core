local RESOURCE_NAME = GetCurrentResourceName()

local function notify(src, messageType, title, message)
    TriggerClientEvent('pa:ui:notify', src, {
        type = messageType,
        title = title,
        message = message,
        duration = 4500,
    })
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

local function logViolation(src, action, message, meta)
    if GetResourceState('pa-logging') ~= 'started' then
        return
    end

    pcall(function()
        exports['pa-logging']['PaLogging:LogAdmin']({
            resource = RESOURCE_NAME,
            source = src,
            action = action,
            message = message,
            actorLicense = getLicense(src),
            targetLicense = meta and meta.targetLicense or nil,
            meta = meta,
        })
    end)
end

RegisterNetEvent('pa:admin:requestAction', function(payload)
    local src = source
    payload = type(payload) == 'table' and payload or {}

    local allowed, rateMeta = exports['pa-guard']['PaGuard:RateLimit'](src, 'admin:action', 10, 60000)
    if not allowed then
        logViolation(src, 'admin_rate_limit', 'Blocked admin request due to rate limit.', rateMeta)
        notify(src, 'warn', 'Rate limit', 'Too many admin actions in a short time.')
        return
    end

    local distanceOk, distMeta = exports['pa-guard']['PaGuard:ValidateDistance'](src, payload.targetCoords, 50.0)
    if not distanceOk then
        logViolation(src, 'admin_distance_invalid', 'Blocked admin request due to distance validation.', distMeta)
        notify(src, 'error', 'Distance check failed', 'Admin action requires a valid nearby target.')
        return
    end

    local permitted = exports['pa-perms']['PaPerms:Require'](
        src,
        { 'owner', 'dev', 'admin', 'mod', 'support' },
        'Staff permission required for this action.'
    )

    if not permitted then
        return
    end

    if GetResourceState('pa-logging') == 'started' then
        pcall(function()
            exports['pa-logging']['PaLogging:LogAdmin']({
                resource = RESOURCE_NAME,
                source = src,
                action = payload.action or 'admin_action',
                message = 'Guarded admin action accepted for server-side processing.',
                actorLicense = getLicense(src),
                targetLicense = payload.targetLicense,
                meta = {
                    distance = distMeta and distMeta.distance,
                    target = payload.targetLicense,
                },
            })
        end)
    end

    TriggerClientEvent('pa:admin:actionResult', src, { ok = true })
    notify(src, 'success', 'Admin action', 'Admin action accepted for server processing.')
end)
