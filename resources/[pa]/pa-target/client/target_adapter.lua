local function safeCall(fn)
    local ok, result = pcall(fn)
    if ok then
        return result
    end
    return false
end

exports('PaTarget:AddBoxZone', function(name, coords, size, options)
    return safeCall(function()
        local zone = {
            name = name,
            coords = coords,
            size = size,
        }

        if type(options) == 'table' then
            for key, value in pairs(options) do
                zone[key] = value
            end
        end

        return exports.ox_target:addBoxZone(zone)
    end)
end)

exports('PaTarget:RemoveZone', function(name)
    return safeCall(function()
        return exports.ox_target:removeZone(name)
    end)
end)
