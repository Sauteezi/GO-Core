local RESOURCE_NAME = GetCurrentResourceName()

local hudVisible = true
local needs = { hunger = 100, thirst = 100, stress = 8 }
local money = { cash = 0, bank = 0 }

local function pushHud()
    local ped = PlayerPedId()
    local health = math.max(0, GetEntityHealth(ped) - 100)
    local armor = GetPedArmour(ped)
    local talking = NetworkIsPlayerTalking(PlayerId())

    SendNUIMessage({
        action = 'hud:update',
        payload = {
            health = health,
            armor = armor,
            hunger = needs.hunger,
            thirst = needs.thirst,
            stress = needs.stress,
            voice = talking and 'talking' or 'idle',
            radio = LocalPlayer.state and LocalPlayer.state.radioChannel and LocalPlayer.state.radioChannel > 0,
            cash = money.cash,
            bank = money.bank,
            visible = hudVisible,
        },
    })
end

RegisterNetEvent('pa:hud:needsSync', function(payload)
    payload = type(payload) == 'table' and payload or {}
    needs.hunger = tonumber(payload.hunger) or needs.hunger
    needs.thirst = tonumber(payload.thirst) or needs.thirst
    needs.stress = tonumber(payload.stress) or needs.stress
    pushHud()
end)

RegisterNetEvent('pa:hud:moneySync', function(payload)
    payload = type(payload) == 'table' and payload or {}
    money.cash = tonumber(payload.cash) or money.cash
    money.bank = tonumber(payload.bank) or money.bank
    pushHud()
end)

RegisterCommand('hudtoggle', function()
    hudVisible = not hudVisible
    pushHud()

    TriggerEvent('chat:addMessage', {
        color = { 90, 165, 255 },
        multiline = false,
        args = { 'pa-hud', hudVisible and 'HUD shown.' or 'HUD hidden.' },
    })
end, false)

RegisterCommand('therapy', function()
    TriggerServerEvent('pa:hud:therapyComplete')
end, false)

RegisterCommand('rest', function()
    TriggerServerEvent('pa:hud:restComplete')
end, false)

CreateThread(function()
    Wait(1500)
    TriggerServerEvent('pa:hud:requestNeedsSync')
    TriggerServerEvent('pa:hud:requestMoneySnapshot')

    while true do
        Wait(1000)
        pushHud()
    end
end)

CreateThread(function()
    while true do
        Wait(10000)
        TriggerServerEvent('pa:hud:requestMoneySnapshot')
    end
end)

CreateThread(function()
    local shootingSeconds = 0

    while true do
        Wait(1000)

        local ped = PlayerPedId()
        if IsPedShooting(ped) then
            shootingSeconds = shootingSeconds + 1
        else
            shootingSeconds = 0
        end

        if shootingSeconds >= 3 then
            TriggerServerEvent('pa:hud:stressEvent', { category = 'shooting', amount = 2 })
            shootingSeconds = 0
        end

        if IsPedInAnyVehicle(ped, false) then
            local vehicle = GetVehiclePedIsIn(ped, false)
            local speedMph = GetEntitySpeed(vehicle) * 2.236936
            if speedMph > 120 then
                TriggerServerEvent('pa:hud:stressEvent', { category = 'chase', amount = 1 })
            end
        end
    end
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= RESOURCE_NAME then
        return
    end

    SetNuiFocus(false, false)
    pushHud()
end)
