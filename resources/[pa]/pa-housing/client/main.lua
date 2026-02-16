local RESOURCE_NAME = GetCurrentResourceName()
local uiOpen = false

local realtorCoords = vec3(-716.92, 261.43, 84.13)

local function openUi()
    if uiOpen then return end
    uiOpen = true
    SetNuiFocus(true, true)
    TriggerServerEvent('pa:housing:openRealtor')
end

local function closeUi()
    if not uiOpen then return end
    uiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'housing:close' })
end

RegisterNetEvent('pa:housing:openUi', function(payload)
    SendNUIMessage({ action = 'housing:open', payload = payload })
end)

RegisterNetEvent('pa:housing:enterAuthorized', function(payload)
    TriggerEvent('chat:addMessage', {
        color = { 89, 165, 255 },
        args = { RESOURCE_NAME, ('Entry authorized for property %s.'):format(payload.propertyKey or 'unknown') },
    })
end)

RegisterNetEvent('pa:housing:openStashAuthorized', function(payload)
    if GetResourceState('ox_inventory') == 'started' then
        exports.ox_inventory:openInventory('stash', payload.stash)
    end
end)

RegisterNUICallback('housing:close', function(_, cb)
    closeUi()
    cb({ ok = true })
end)

RegisterNUICallback('housing:purchase', function(data, cb)
    TriggerServerEvent('pa:housing:purchase', data)
    cb({ ok = true })
end)

RegisterNUICallback('housing:rent', function(data, cb)
    TriggerServerEvent('pa:housing:rent', data)
    cb({ ok = true })
end)

RegisterNUICallback('housing:shareKey', function(data, cb)
    TriggerServerEvent('pa:housing:shareKey', data)
    cb({ ok = true })
end)

RegisterNUICallback('housing:revokeKey', function(data, cb)
    TriggerServerEvent('pa:housing:revokeKey', data)
    cb({ ok = true })
end)

RegisterNUICallback('housing:enter', function(data, cb)
    TriggerServerEvent('pa:housing:enter', data)
    cb({ ok = true })
end)

RegisterNUICallback('housing:stash', function(data, cb)
    TriggerServerEvent('pa:housing:openStash', data)
    cb({ ok = true })
end)

RegisterCommand('realtor', function()
    openUi()
end, false)

CreateThread(function()
    while true do
        Wait(200)

        if uiOpen then
            Wait(300)
        else
            local dist = #(GetEntityCoords(PlayerPedId()) - realtorCoords)
            if dist <= 2.0 then
                if IsControlJustReleased(0, 38) then
                    openUi()
                end
                SendNUIMessage({ action = 'housing:hint', payload = { text = 'Press [E] to talk to Realtor' } })
            end
        end
    end
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName == RESOURCE_NAME then
        closeUi()
    end
end)
