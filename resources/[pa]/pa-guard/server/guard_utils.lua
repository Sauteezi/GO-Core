local RESOURCE_NAME = GetCurrentResourceName()

local Buckets = {}

local function tryLogWarn(payload)
    if GetResourceState('pa-logging') ~= 'started' then
        return
    end

    pcall(function()
        exports['pa-logging']['PaLogging:LogWarn'](payload)
    end)
end

local function normalizeCoords(coords)
    if type(coords) == 'vector3' then
        return coords
    end

    if type(coords) == 'table' and coords.x and coords.y and coords.z then
        return vector3(coords.x + 0.0, coords.y + 0.0, coords.z + 0.0)
    end

    return nil
end

local Guard = {}

function Guard:RateLimit(src, key, maxPerWindow, windowMs)
    local source = tonumber(src)
    local limitKey = tostring(key or 'unknown')
    local max = tonumber(maxPerWindow) or 1
    local window = tonumber(windowMs) or 1000

    if not source or source <= 0 or max <= 0 or window <= 0 then
        return false, { reason = 'invalid_rate_limit_arguments' }
    end

    local bucketId = ('%s:%s'):format(source, limitKey)
    local now = GetGameTimer()
    local bucket = Buckets[bucketId]

    if not bucket then
        bucket = { tokens = max, lastRefillAt = now }
        Buckets[bucketId] = bucket
    end

    local refillRatePerMs = max / window
    local elapsed = math.max(0, now - bucket.lastRefillAt)
    bucket.tokens = math.min(max, bucket.tokens + (elapsed * refillRatePerMs))
    bucket.lastRefillAt = now

    if bucket.tokens >= 1 then
        bucket.tokens = bucket.tokens - 1
        return true, { tokensRemaining = bucket.tokens }
    end

    local waitMs = math.ceil((1 - bucket.tokens) / refillRatePerMs)
    local meta = {
        source = source,
        key = limitKey,
        maxPerWindow = max,
        windowMs = window,
        retryAfterMs = waitMs,
    }

    tryLogWarn({
        resource = RESOURCE_NAME,
        source = source,
        action = 'rate_limit_violation',
        message = 'Rate limit violation detected by pa-guard',
        meta = meta,
    })

    return false, meta
end

function Guard:ValidateDistance(src, targetCoords, maxDist)
    local source = tonumber(src)
    local allowed = tonumber(maxDist) or 3.0

    if not source or source <= 0 then
        return false, { reason = 'invalid_source' }
    end

    local ped = GetPlayerPed(source)
    if not ped or ped <= 0 or not DoesEntityExist(ped) then
        local meta = { source = source, reason = 'player_ped_missing' }
        tryLogWarn({
            resource = RESOURCE_NAME,
            source = source,
            action = 'distance_validation_failed',
            message = 'Distance check failed because player ped is missing.',
            meta = meta,
        })
        return false, meta
    end

    local normalizedTarget = normalizeCoords(targetCoords)
    if not normalizedTarget then
        local meta = { source = source, reason = 'target_coords_invalid' }
        tryLogWarn({
            resource = RESOURCE_NAME,
            source = source,
            action = 'distance_validation_failed',
            message = 'Distance check failed because target coordinates were nil/invalid.',
            meta = meta,
        })
        return false, meta
    end

    local playerCoords = GetEntityCoords(ped)
    if not playerCoords then
        local meta = { source = source, reason = 'player_coords_invalid' }
        tryLogWarn({
            resource = RESOURCE_NAME,
            source = source,
            action = 'distance_validation_failed',
            message = 'Distance check failed because player coordinates were unavailable.',
            meta = meta,
        })
        return false, meta
    end

    local distance = #(playerCoords - normalizedTarget)
    if distance <= allowed then
        return true, { distance = distance, maxDist = allowed }
    end

    local meta = {
        source = source,
        distance = distance,
        maxDist = allowed,
        targetCoords = { x = normalizedTarget.x, y = normalizedTarget.y, z = normalizedTarget.z },
    }

    tryLogWarn({
        resource = RESOURCE_NAME,
        source = source,
        action = 'distance_violation',
        message = 'Distance validation failed: player too far from target coordinates.',
        meta = meta,
    })

    return false, meta
end

exports('PaGuard:RateLimit', function(src, key, maxPerWindow, windowMs)
    return Guard:RateLimit(src, key, maxPerWindow, windowMs)
end)

exports('PaGuard:ValidateDistance', function(src, targetCoords, maxDist)
    return Guard:ValidateDistance(src, targetCoords, maxDist)
end)

AddEventHandler('playerDropped', function()
    local src = source
    local prefix = tostring(src) .. ':'

    for bucketId in pairs(Buckets) do
        if bucketId:sub(1, #prefix) == prefix then
            Buckets[bucketId] = nil
        end
    end
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= RESOURCE_NAME then
        return
    end

    print(('^2[%s] Guard utilities ready: PaGuard:RateLimit + PaGuard:ValidateDistance.^7'):format(RESOURCE_NAME))
end)
