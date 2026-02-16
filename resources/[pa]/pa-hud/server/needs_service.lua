local RESOURCE_NAME = GetCurrentResourceName()

local DEFAULTS = {
    hungerMax = 100,
    thirstMax = 100,
    stressMax = 100,
    hungerDecay = 1,
    thirstDecay = 2,
    tickMs = 120000,
}

local NEEDS = {}
local ConsumablesRegistered = false

local function logEvent(levelExport, payload)
    if GetResourceState('pa-logging') ~= 'started' then
        return
    end

    pcall(function()
        exports['pa-logging'][levelExport](payload)
    end)
end

local function clampNeeds(entry)
    entry.hunger = math.max(0, math.min(DEFAULTS.hungerMax, math.floor(entry.hunger)))
    entry.thirst = math.max(0, math.min(DEFAULTS.thirstMax, math.floor(entry.thirst)))
    entry.stress = math.max(0, math.min(DEFAULTS.stressMax, math.floor(entry.stress)))
end

local function getNeeds(src)
    local key = tostring(src)
    if not NEEDS[key] then
        NEEDS[key] = {
            hunger = DEFAULTS.hungerMax,
            thirst = DEFAULTS.thirstMax,
            stress = 8,
            updatedAt = os.time(),
        }
    end
    return NEEDS[key]
end

local function pushNeeds(src)
    local entry = getNeeds(src)
    TriggerClientEvent('pa:hud:needsSync', src, {
        hunger = entry.hunger,
        thirst = entry.thirst,
        stress = entry.stress,
    })
end

local function applyNeeds(src, delta, reason, logAs)
    local entry = getNeeds(src)
    entry.hunger = entry.hunger + (delta.hunger or 0)
    entry.thirst = entry.thirst + (delta.thirst or 0)
    entry.stress = entry.stress + (delta.stress or 0)
    entry.updatedAt = os.time()
    clampNeeds(entry)
    pushNeeds(src)

    if logAs then
        logEvent(logAs, {
            resource = RESOURCE_NAME,
            source = src,
            action = reason,
            message = 'Needs state updated.',
            actorLicense = (GetResourceState('pa-core') == 'started' and exports['pa-core']['PaCore:GetLicense'](src)) or nil,
            meta = {
                hunger = entry.hunger,
                thirst = entry.thirst,
                stress = entry.stress,
                delta = delta,
            },
        })
    end
end

local function registerConsumables()
    if ConsumablesRegistered then
        return
    end

    if GetResourceState('pa-inventory') ~= 'started' then
        return
    end

    local okWater = exports['pa-inventory']['PaInventory:RegisterUsableItem']('water_bottle', function(src)
        exports['pa-inventory']['PaInventory:RemoveItem'](src, 'water_bottle', 1, nil, 'drink_water')
        applyNeeds(src, { thirst = 20, stress = -2 }, 'drink_water_bottle', 'PaLogging:LogAudit')
        TriggerClientEvent('pa:ui:notify', src, {
            type = 'success',
            title = 'Hydrated',
            message = 'You feel refreshed.',
            duration = 4000,
        })
    end)

    local okSandwich = exports['pa-inventory']['PaInventory:RegisterUsableItem']('sandwich', function(src)
        exports['pa-inventory']['PaInventory:RemoveItem'](src, 'sandwich', 1, nil, 'eat_sandwich')
        applyNeeds(src, { hunger = 22, stress = -3 }, 'eat_sandwich', 'PaLogging:LogAudit')
        TriggerClientEvent('pa:ui:notify', src, {
            type = 'success',
            title = 'Fed',
            message = 'That hit the spot.',
            duration = 4000,
        })
    end)

    if not okWater then
        print(('^3[%s] Could not register water_bottle usable item yet.^7'):format(RESOURCE_NAME))
    end

    if not okSandwich then
        print(('^3[%s] Could not register sandwich usable item yet.^7'):format(RESOURCE_NAME))
        return
    end

    ConsumablesRegistered = true
end

RegisterNetEvent('pa:hud:requestNeedsSync', function()
    pushNeeds(source)
end)

RegisterNetEvent('pa:hud:stressEvent', function(payload)
    local src = source
    payload = type(payload) == 'table' and payload or {}

    local category = tostring(payload.category or 'unknown')
    local amount = tonumber(payload.amount) or 0
    amount = math.floor(amount)

    if amount == 0 then
        return
    end

    local allowed = true
    if GetResourceState('pa-guard') == 'started' then
        allowed = exports['pa-guard']['PaGuard:RateLimit'](src, ('hud:stress:%s'):format(category), 8, 60000) == true
    end

    if not allowed then
        logEvent('PaLogging:LogWarn', {
            resource = RESOURCE_NAME,
            source = src,
            action = 'stress_rate_limited',
            message = 'Blocked stress event due to rate limit.',
            meta = { category = category, amount = amount },
        })
        return
    end

    if category == 'therapy' or category == 'rest' then
        amount = -math.abs(amount)
    elseif category == 'shooting' or category == 'chase' then
        amount = math.abs(amount)
    else
        amount = math.max(-8, math.min(8, amount))
    end

    applyNeeds(src, { stress = amount }, ('stress_%s'):format(category), 'PaLogging:LogInfo')
end)


RegisterNetEvent('pa:hud:businessMeal', function(srcOrBusinessId, maybeBusinessId)
    local src = source
    local businessId = maybeBusinessId

    if type(srcOrBusinessId) == 'number' then
        src = srcOrBusinessId
        businessId = maybeBusinessId
    elseif type(srcOrBusinessId) == 'string' then
        businessId = srcOrBusinessId
    end

    applyNeeds(src, { hunger = 18, thirst = 10, stress = -6 }, 'business_meal', 'PaLogging:LogAudit')

    if businessId then
        logEvent('PaLogging:LogInfo', {
            resource = RESOURCE_NAME,
            source = src,
            action = 'business_meal_effect',
            message = 'Applied business meal effect.',
            meta = { businessId = businessId },
        })
    end
end)

RegisterNetEvent('pa:hud:therapyComplete', function()
    applyNeeds(source, { stress = -14 }, 'therapy_complete', 'PaLogging:LogAudit')
end)

RegisterNetEvent('pa:hud:restComplete', function()
    applyNeeds(source, { stress = -8 }, 'rest_complete', 'PaLogging:LogInfo')
end)

RegisterNetEvent('pa:hud:requestMoneySnapshot', function()
    local src = source

    local cash, bank = 0, 0
    if GetResourceState('pa-economy') == 'started' then
        cash = tonumber(exports['pa-economy']['PaEconomy:GetBalance'](src, 'cash')) or 0
        bank = tonumber(exports['pa-economy']['PaEconomy:GetBalance'](src, 'bank')) or 0
    end

    TriggerClientEvent('pa:hud:moneySync', src, {
        cash = cash,
        bank = bank,
    })
end)

AddEventHandler('playerDropped', function()
    NEEDS[tostring(source)] = nil
end)

CreateThread(function()
    while true do
        Wait(DEFAULTS.tickMs)

        for _, src in ipairs(GetPlayers()) do
            src = tonumber(src)
            if src then
                applyNeeds(src, {
                    hunger = -DEFAULTS.hungerDecay,
                    thirst = -DEFAULTS.thirstDecay,
                }, 'passive_decay', nil)
            end
        end
    end
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= RESOURCE_NAME then
        return
    end

    registerConsumables()
    print(('^2[%s] Needs service started (semi-serious profile).^7'):format(RESOURCE_NAME))
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == 'pa-inventory' and GetResourceState(RESOURCE_NAME) == 'started' then
        registerConsumables()
    end
end)
