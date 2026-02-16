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

RegisterNetEvent('pa:economy:requestPayout', function(payload)
    local src = source
    payload = type(payload) == 'table' and payload or {}

    local allowed, rateMeta = exports['pa-guard']['PaGuard:RateLimit'](src, 'economy:payout', 3, 10000)
    if not allowed then
        logWarn(src, 'payout_rate_limit', 'Blocked payout request due to rate limit.', rateMeta)
        notify(src, 'warn', 'Rate limit', 'Too many payout requests in a short time.')
        return
    end

    local distanceOk, distMeta = exports['pa-guard']['PaGuard:ValidateDistance'](src, payload.payoutCoords, 20.0)
    if not distanceOk then
        logWarn(src, 'payout_distance_invalid', 'Blocked payout request due to distance validation.', distMeta)
        notify(src, 'error', 'Distance check failed', 'Move closer to the payout location and try again.')
        return
    end

    local ok, err = exports['pa-economy']['PaEconomy:AddMoney'](
        src,
        payload.account or 'bank',
        tonumber(payload.amount) or 0,
        payload.reason or 'payout_request',
        { distance = distMeta and distMeta.distance, payoutType = payload.payoutType }
    )

    if not ok then
        notify(src, 'error', 'Payout failed', err or 'Could not process payout.')
        return
    end

    TriggerClientEvent('pa:economy:payoutResult', src, { ok = true })
    notify(src, 'success', 'Payout queued', 'Your payout request was accepted.')
end)
