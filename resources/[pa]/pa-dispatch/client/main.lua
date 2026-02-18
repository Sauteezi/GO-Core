local Feed = {}
local DispatchVisible = false

local function sendNui(action, data)
    SendNUIMessage({
        action = action,
        data = data,
    })
end

local function setUi(visible)
    DispatchVisible = visible == true
    SetNuiFocus(DispatchVisible, DispatchVisible)
    sendNui('setVisible', { visible = DispatchVisible })

    if DispatchVisible then
        TriggerServerEvent('pa:dispatch:requestFeed')
    end
end

RegisterCommand('dispatch', function()
    setUi(not DispatchVisible)
end, false)

RegisterNetEvent('pa:dispatch:updateFeed', function(feed)
    Feed = type(feed) == 'table' and feed or {}
    sendNui('setFeed', { feed = Feed })
end)

RegisterNetEvent('pa:dispatch:createCallResult', function(ok, result)
    if ok then
        if GetResourceState('pa-ui') == 'started' then
            exports['pa-ui']['PaUI:Notify']('success', 'Dispatch', ('Call #%s created.'):format(result.id), 3500)
        end
    else
        if GetResourceState('pa-ui') == 'started' then
            exports['pa-ui']['PaUI:Notify']('error', 'Dispatch', tostring(result), 4000)
        end
    end
end)

RegisterNetEvent('pa:dispatch:actionResult', function(ok, result)
    if ok then
        if GetResourceState('pa-ui') == 'started' then
            exports['pa-ui']['PaUI:Notify']('success', 'Dispatch', 'Action completed.', 2500)
        end
    else
        if GetResourceState('pa-ui') == 'started' then
            exports['pa-ui']['PaUI:Notify']('error', 'Dispatch', tostring(result), 4000)
        end
    end
end)

RegisterNUICallback('dispatch:close', function(_, cb)
    setUi(false)
    cb({ ok = true })
end)

RegisterNUICallback('dispatch:createCall', function(payload, cb)
    payload = type(payload) == 'table' and payload or {}
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    payload.coords = {
        x = coords.x,
        y = coords.y,
        z = coords.z,
    }

    TriggerServerEvent('pa:dispatch:createCall', payload)
    cb({ ok = true })
end)

RegisterNUICallback('dispatch:assignSelf', function(payload, cb)
    payload = type(payload) == 'table' and payload or {}

    TriggerServerEvent('pa:dispatch:assignUnit', payload.callId, {
        source = GetPlayerServerId(PlayerId()),
        callsign = payload.callsign or 'Unit',
        unitType = payload.unitType or 'patrol',
    })

    cb({ ok = true })
end)

RegisterNUICallback('dispatch:updateStatus', function(payload, cb)
    payload = type(payload) == 'table' and payload or {}
    TriggerServerEvent('pa:dispatch:updateStatus', payload.callId, payload.status, payload.note)
    cb({ ok = true })
end)

RegisterNUICallback('dispatch:closeCall', function(payload, cb)
    payload = type(payload) == 'table' and payload or {}
    TriggerServerEvent('pa:dispatch:closeCall', payload.callId, payload.note)
    cb({ ok = true })
end)

CreateThread(function()
    sendNui('setFeed', { feed = Feed })
    sendNui('setVisible', { visible = false })
end)
