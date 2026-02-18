local RESOURCE_NAME = GetCurrentResourceName()

local cityHall = vec3(-552.26, -191.03, 38.22)
local cityHallRadius = 2.0
local uiOpen = false

local function openCityHallMenu()
    if uiOpen then
        return
    end

    uiOpen = true
    SetNuiFocus(true, true)
    TriggerServerEvent('pa:jobs:requestCityHall')
end

local function closeCityHallMenu()
    if not uiOpen then
        return
    end

    uiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'jobs:close' })
end

RegisterNetEvent('pa:jobs:openCityHall', function(payload)
    SendNUIMessage({
        action = 'jobs:open',
        payload = payload,
    })
end)

RegisterNetEvent('pa:jobs:jobUpdated', function(payload)
    SendNUIMessage({ action = 'jobs:current', payload = payload })
end)

RegisterNUICallback('jobs:apply', function(data, cb)
    data = type(data) == 'table' and data or {}
    TriggerServerEvent('pa:jobs:applyStarterJob', {
        jobName = data.jobName,
        grade = tonumber(data.grade) or 0,
    })
    cb({ ok = true })
end)

RegisterNUICallback('jobs:close', function(_, cb)
    closeCityHallMenu()
    cb({ ok = true })
end)

RegisterCommand('jobcenter', function()
    openCityHallMenu()
end, false)

RegisterCommand('duty', function(_, args)
    local toggle = tostring(args[1] or ''):lower()
    local onDuty = toggle == 'on'
    if toggle ~= 'on' and toggle ~= 'off' then
        TriggerEvent('chat:addMessage', {
            color = { 89, 165, 255 },
            args = { 'pa-jobs', 'Usage: /duty on|off' },
        })
        return
    end

    TriggerServerEvent('pa:jobs:setDuty', { onDuty = onDuty })
end, false)

CreateThread(function()
    while true do
        Wait(0)
        if uiOpen then
            Wait(250)
        else
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local dist = #(coords - cityHall)

            if dist <= cityHallRadius then
                SendNUIMessage({
                    action = 'jobs:hint',
                    payload = { text = 'Press [E] to open City Hall Job Center' },
                })

                if IsControlJustReleased(0, 38) then
                    openCityHallMenu()
                end
            end

            Wait(200)
        end
    end
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= RESOURCE_NAME then
        return
    end

    closeCityHallMenu()
end)
