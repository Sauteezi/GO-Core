local RESOURCE_NAME = GetCurrentResourceName()
local active = false

RegisterNetEvent('pa:job-sanitation:state', function(payload)
    payload = type(payload) == 'table' and payload or {}
    active = payload.active == true
end)

RegisterNetEvent('pa:job-sanitation:route', function(payload)
    if type(payload) ~= 'table' or type(payload.coords) ~= 'table' then
        return
    end

    SetNewWaypoint(payload.coords.x + 0.0, payload.coords.y + 0.0)

    TriggerEvent('chat:addMessage', {
        color = { 89, 165, 255 },
        args = { RESOURCE_NAME, 'New route waypoint set. Head to the marker and use /jobdone.' },
    })
end)

RegisterCommand('jobsanitation', function()
    if active then
        TriggerServerEvent('pa:job-sanitation:stop')
    else
        TriggerServerEvent('pa:job-sanitation:start')
    end
end, false)

RegisterCommand('jobdone', function()
    local coords = GetEntityCoords(PlayerPedId())
    TriggerServerEvent('pa:job-sanitation:complete', { x = coords.x, y = coords.y, z = coords.z })
end, false)
