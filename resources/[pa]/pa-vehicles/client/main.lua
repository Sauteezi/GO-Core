local RESOURCE_NAME = GetCurrentResourceName()
local uiOpen = false

local function openUi()
    if uiOpen then return end
    uiOpen = true
    SetNuiFocus(true, true)
    TriggerServerEvent('pa:vehicles:openGarage')
end

local function closeUi()
    if not uiOpen then return end
    uiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'vehicles:close' })
end

RegisterNetEvent('pa:vehicles:openGarageUi', function(payload)
    SendNUIMessage({ action = 'vehicles:open', payload = payload })
end)

RegisterNetEvent('pa:vehicles:spawnAuthorized', function(payload)
    payload = type(payload) == 'table' and payload or {}
    TriggerEvent('chat:addMessage', {
        color = { 89, 165, 255 },
        args = { RESOURCE_NAME, ('Server authorized spawn: %s [%s]'):format(payload.model or 'unknown', payload.plate or 'N/A') },
    })
end)

RegisterNetEvent('pa:vehicles:despawnAuthorized', function(payload)
    payload = type(payload) == 'table' and payload or {}
    TriggerEvent('chat:addMessage', {
        color = { 89, 165, 255 },
        args = { RESOURCE_NAME, ('Server authorized despawn to %s'):format(payload.garageKey or 'garage') },
    })
end)

RegisterNUICallback('vehicles:close', function(_, cb)
    closeUi()
    cb({ ok = true })
end)

RegisterNUICallback('vehicles:spawn', function(data, cb)
    TriggerServerEvent('pa:vehicles:spawn', data)
    cb({ ok = true })
end)

RegisterNUICallback('vehicles:despawn', function(data, cb)
    TriggerServerEvent('pa:vehicles:despawn', data)
    cb({ ok = true })
end)

RegisterNUICallback('vehicles:repair', function(data, cb)
    TriggerServerEvent('pa:vehicles:repair', data)
    cb({ ok = true })
end)

RegisterNUICallback('vehicles:claim', function(data, cb)
    TriggerServerEvent('pa:vehicles:insuranceClaim', data)
    cb({ ok = true })
end)

RegisterNUICallback('vehicles:giveKey', function(data, cb)
    TriggerServerEvent('pa:vehicles:giveKey', data)
    cb({ ok = true })
end)

RegisterNUICallback('vehicles:revokeKey', function(data, cb)
    TriggerServerEvent('pa:vehicles:revokeKey', data)
    cb({ ok = true })
end)

RegisterCommand('garage', function()
    openUi()
end, false)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName == RESOURCE_NAME then
        closeUi()
    end
end)
