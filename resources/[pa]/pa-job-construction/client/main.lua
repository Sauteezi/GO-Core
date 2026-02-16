local RESOURCE_NAME = GetCurrentResourceName()
local active = false

RegisterNetEvent('pa:job-construction:state', function(payload)
    payload = type(payload) == 'table' and payload or {}
    active = payload.active == true
end)

RegisterNetEvent('pa:job-construction:route', function(payload)
    if type(payload) ~= 'table' or type(payload.coords) ~= 'table' then
        return
    end

    SetNewWaypoint(payload.coords.x + 0.0, payload.coords.y + 0.0)

    TriggerEvent('chat:addMessage', {
        color = { 89, 165, 255 },
        args = { RESOURCE_NAME, 'New route waypoint set. Head to the marker and use /jobdone.' },
    })
end)

RegisterCommand('jobconstruction', function()
    if active then
        TriggerServerEvent('pa:job-construction:stop')
    else
        TriggerServerEvent('pa:job-construction:start')
    end
end, false)

RegisterCommand('jobdone', function()
    local coords = GetEntityCoords(PlayerPedId())
    TriggerServerEvent('pa:job-construction:complete', { x = coords.x, y = coords.y, z = coords.z })
end, false)
