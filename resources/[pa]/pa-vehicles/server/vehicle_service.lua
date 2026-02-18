local RESOURCE_NAME = GetCurrentResourceName()

local Garages = {
    cityhall = { key = 'cityhall', label = 'City Hall Garage', spawn = vec3(-330.12, -780.32, 33.96), impound = false },
    pillbox = { key = 'pillbox', label = 'Pillbox Garage', spawn = vec3(213.45, -810.16, 30.73), impound = false },
    impound = { key = 'impound', label = 'City Impound', spawn = vec3(408.72, -1625.29, 29.29), impound = true },
}

local Vehicles = {}
local VehicleKeys = {}
local ActiveSpawnCooldown = {}
local ActiveDespawnCooldown = {}
local ClaimsCooldown = {}

local function now()
    return os.time()
end

local function logEvent(levelExport, payload)
    if GetResourceState('pa-logging') ~= 'started' then
        return
    end

    pcall(function()
        exports['pa-logging'][levelExport](payload)
    end)
end

local function getCharId(src)
    if GetResourceState('pa-core') ~= 'started' then
        return nil
    end
    return exports['pa-core']['PaCore:GetCharId'](src)
end

local function getLicense(src)
    if GetResourceState('pa-core') ~= 'started' then
        return nil
    end
    return exports['pa-core']['PaCore:GetLicense'](src)
end

local function ensurePlayerRecord(src)
    local charId = getCharId(src)
    if not charId then
        return nil, 'No active character.'
    end
    return charId, nil
end

local function isRateLimited(src, key, maxPerWindow, windowMs)
    if GetResourceState('pa-guard') ~= 'started' then
        return false
    end

    local ok = exports['pa-guard']['PaGuard:RateLimit'](src, key, maxPerWindow, windowMs)
    return ok ~= true
end

local function plateKey(plate)
    return string.upper((tostring(plate or ''):gsub('%s+', '')))
end

local function hasVehicleKey(charId, vehicleId)
    local keys = VehicleKeys[vehicleId] or {}
    return keys[charId] == true
end

local function assignVehicleKey(vehicleId, charId)
    VehicleKeys[vehicleId] = VehicleKeys[vehicleId] or {}
    VehicleKeys[vehicleId][charId] = true
end

local function removeVehicleKey(vehicleId, charId)
    if VehicleKeys[vehicleId] then
        VehicleKeys[vehicleId][charId] = nil
    end
end

local function ensureVehicleStorage(charId)
    Vehicles[charId] = Vehicles[charId] or {}
end

local function findVehicleByPlate(plate)
    local normalized = plateKey(plate)
    for charId, list in pairs(Vehicles) do
        for _, vehicle in ipairs(list) do
            if plateKey(vehicle.plate) == normalized then
                return vehicle, charId
            end
        end
    end
    return nil, nil
end

local function syncDbUpsert(vehicle, ownerCharId)
    if GetResourceState('oxmysql') ~= 'started' then
        return
    end

    local query = [[
        INSERT INTO vehicles (char_id, plate, model, props_json, state, garage_key, insured, metadata)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            char_id = VALUES(char_id),
            model = VALUES(model),
            props_json = VALUES(props_json),
            state = VALUES(state),
            garage_key = VALUES(garage_key),
            insured = VALUES(insured),
            metadata = VALUES(metadata)
    ]]

    exports.oxmysql:execute(query, {
        ownerCharId,
        vehicle.plate,
        vehicle.model,
        json.encode(vehicle.props or {}),
        vehicle.state,
        vehicle.garage,
        vehicle.insured and 1 or 0,
        json.encode(vehicle.metadata or {}),
    })
end

local function syncVehicleKeyDb(vehicleId, charId, keyType, remove)
    if GetResourceState('oxmysql') ~= 'started' then
        return
    end

    if remove then
        exports.oxmysql:execute('DELETE FROM vehicle_keys WHERE vehicle_id = ? AND char_id = ?', { vehicleId, charId })
    else
        exports.oxmysql:execute([[INSERT INTO vehicle_keys (vehicle_id, char_id, key_type) VALUES (?, ?, ?)
            ON DUPLICATE KEY UPDATE key_type = VALUES(key_type)]], { vehicleId, charId, keyType or 'shared' })
    end
end

local function registerOwnedVehicle(src, payload)
    local charId, err = ensurePlayerRecord(src)
    if not charId then
        return false, err
    end

    payload = type(payload) == 'table' and payload or {}
    local plate = plateKey(payload.plate)
    local model = tostring(payload.model or '')

    if plate == '' or model == '' then
        return false, 'Model and plate are required.'
    end

    local existing = findVehicleByPlate(plate)
    if existing then
        logEvent('PaLogging:LogWarn', {
            resource = RESOURCE_NAME,
            source = src,
            action = 'suspicious_plate_duplication',
            message = 'Blocked duplicate plate registration attempt.',
            actorLicense = getLicense(src),
            meta = { plate = plate, model = model },
        })
        return false, 'Plate already exists.'
    end

    ensureVehicleStorage(charId)
    local vehicleId = (#Vehicles[charId] * 100000) + math.random(1000, 99999)

    local vehicle = {
        id = vehicleId,
        plate = plate,
        model = model,
        props = type(payload.props) == 'table' and payload.props or {},
        state = 'garage',
        garage = tostring(payload.garage or 'cityhall'),
        insured = payload.insured == true,
        metadata = type(payload.metadata) == 'table' and payload.metadata or {},
    }

    table.insert(Vehicles[charId], vehicle)
    assignVehicleKey(vehicleId, charId)
    syncDbUpsert(vehicle, charId)
    syncVehicleKeyDb(vehicleId, charId, 'owner', false)

    return true, vehicle
end

local function listOwnedVehicles(src)
    local charId, err = ensurePlayerRecord(src)
    if not charId then
        return false, err
    end

    ensureVehicleStorage(charId)

    local results = {}
    for _, vehicle in ipairs(Vehicles[charId]) do
        results[#results + 1] = {
            id = vehicle.id,
            plate = vehicle.plate,
            model = vehicle.model,
            state = vehicle.state,
            garage = vehicle.garage,
            insured = vehicle.insured,
        }
    end

    return true, results
end

local function getOwnedVehicleForPlayer(src, vehicleId)
    local charId, err = ensurePlayerRecord(src)
    if not charId then
        return nil, nil, err
    end

    ensureVehicleStorage(charId)
    for _, vehicle in ipairs(Vehicles[charId]) do
        if tonumber(vehicle.id) == tonumber(vehicleId) then
            return vehicle, charId, nil
        end
    end

    return nil, charId, 'Vehicle not owned by character.'
end

local function chargeRepairCost(src, vehicle)
    local sinkCfg = exports['pa-shared']['PaShared:GetConfig']('economy')
    local repairSink = sinkCfg and sinkCfg.sinks and sinkCfg.sinks.repairs or { amount = 300, account = 'cash' }
    local base = tonumber(repairSink.amount) or 300

    if GetResourceState('pa-business') == 'started' then
        local discount = exports['pa-business']['PaBusiness:GetServiceDiscount'](src, 'repairs') or 0
        base = math.floor(base * (1.0 - math.min(0.5, math.max(0, tonumber(discount) or 0))))
    end

    if base <= 0 then
        return true, 0
    end

    local ok = exports['pa-economy']['PaEconomy:RemoveMoney'](src, repairSink.account or 'cash', base, 'vehicle_repair_cost', {
        vehicleId = vehicle.id,
        plate = vehicle.plate,
    })

    return ok == true, base
end

local function tryInsuranceClaim(src, vehicle)
    local key = tostring(src)
    local stamp = ClaimsCooldown[key] or 0
    if (now() - stamp) < 300 then
        return false, 'Insurance claim cooldown active.'
    end

    if not vehicle.insured then
        return false, 'Vehicle is not insured.'
    end

    ClaimsCooldown[key] = now()

    local claimAmount = 850
    local ok = exports['pa-economy']['PaEconomy:AddMoney'](src, 'bank', claimAmount, 'vehicle_insurance_claim', {
        vehicleId = vehicle.id,
        plate = vehicle.plate,
    })

    if ok then
        logEvent('PaLogging:LogEconomy', {
            resource = RESOURCE_NAME,
            source = src,
            action = 'insurance_claim_paid',
            message = 'Insurance claim paid.',
            actorLicense = getLicense(src),
            meta = { vehicleId = vehicle.id, plate = vehicle.plate, amount = claimAmount },
        })
    end

    return ok == true, ok and claimAmount or 'Claim failed.'
end

local function markVehicleState(vehicle, state, garage)
    vehicle.state = state
    vehicle.garage = garage or vehicle.garage
end

RegisterNetEvent('pa:vehicles:registerOwnedVehicle', function(payload)
    local src = source
    local ok, result = registerOwnedVehicle(src, payload)

    if not ok then
        TriggerClientEvent('pa:ui:notify', src, { type = 'error', title = 'Vehicles', message = result, duration = 4500 })
        return
    end

    TriggerClientEvent('pa:ui:notify', src, { type = 'success', title = 'Vehicles', message = ('Registered %s [%s]'):format(result.model, result.plate), duration = 3500 })
end)

RegisterNetEvent('pa:vehicles:openGarage', function()
    local src = source
    local ok, listOrErr = listOwnedVehicles(src)
    if not ok then
        TriggerClientEvent('pa:ui:notify', src, { type = 'error', title = 'Garage', message = listOrErr, duration = 4000 })
        return
    end

    TriggerClientEvent('pa:vehicles:openGarageUi', src, {
        garages = Garages,
        vehicles = listOrErr,
    })
end)

RegisterNetEvent('pa:vehicles:spawn', function(payload)
    local src = source
    payload = type(payload) == 'table' and payload or {}

    if isRateLimited(src, 'vehicles:spawn', 4, 60000) then
        TriggerClientEvent('pa:ui:notify', src, { type = 'warn', title = 'Garage', message = 'Spawn rate limit reached.', duration = 3500 })
        return
    end

    local vehicle, charId, err = getOwnedVehicleForPlayer(src, payload.vehicleId)
    if not vehicle then
        TriggerClientEvent('pa:ui:notify', src, { type = 'error', title = 'Garage', message = err, duration = 3500 })
        return
    end

    if vehicle.state == 'out' then
        TriggerClientEvent('pa:ui:notify', src, { type = 'warn', title = 'Garage', message = 'Vehicle is already out.', duration = 3500 })
        return
    end

    markVehicleState(vehicle, 'out', payload.garageKey or vehicle.garage)
    syncDbUpsert(vehicle, charId)

    TriggerClientEvent('pa:vehicles:spawnAuthorized', src, {
        vehicleId = vehicle.id,
        model = vehicle.model,
        plate = vehicle.plate,
        props = vehicle.props,
        garageKey = payload.garageKey or vehicle.garage,
    })
end)

RegisterNetEvent('pa:vehicles:despawn', function(payload)
    local src = source
    payload = type(payload) == 'table' and payload or {}

    if isRateLimited(src, 'vehicles:despawn', 8, 60000) then
        TriggerClientEvent('pa:ui:notify', src, { type = 'warn', title = 'Garage', message = 'Despawn rate limit reached.', duration = 3500 })
        return
    end

    local vehicle, charId, err = getOwnedVehicleForPlayer(src, payload.vehicleId)
    if not vehicle then
        TriggerClientEvent('pa:ui:notify', src, { type = 'error', title = 'Garage', message = err, duration = 3500 })
        return
    end

    local targetGarage = tostring(payload.garageKey or vehicle.garage or 'cityhall')
    markVehicleState(vehicle, targetGarage == 'impound' and 'impound' or 'garage', targetGarage)
    syncDbUpsert(vehicle, charId)

    TriggerClientEvent('pa:vehicles:despawnAuthorized', src, { vehicleId = vehicle.id, garageKey = targetGarage })
end)

RegisterNetEvent('pa:vehicles:repair', function(payload)
    local src = source
    payload = type(payload) == 'table' and payload or {}

    local vehicle, _, err = getOwnedVehicleForPlayer(src, payload.vehicleId)
    if not vehicle then
        TriggerClientEvent('pa:ui:notify', src, { type = 'error', title = 'Repair', message = err, duration = 3500 })
        return
    end

    local ok, amount = chargeRepairCost(src, vehicle)
    if not ok then
        TriggerClientEvent('pa:ui:notify', src, { type = 'error', title = 'Repair', message = 'Insufficient funds for repair.', duration = 3500 })
        return
    end

    TriggerClientEvent('pa:ui:notify', src, { type = 'success', title = 'Repair', message = ('Vehicle repaired for $%s'):format(amount), duration = 3500 })
end)

RegisterNetEvent('pa:vehicles:insuranceClaim', function(payload)
    local src = source
    payload = type(payload) == 'table' and payload or {}

    local vehicle, _, err = getOwnedVehicleForPlayer(src, payload.vehicleId)
    if not vehicle then
        TriggerClientEvent('pa:ui:notify', src, { type = 'error', title = 'Insurance', message = err, duration = 3500 })
        return
    end

    local ok, result = tryInsuranceClaim(src, vehicle)
    if not ok then
        TriggerClientEvent('pa:ui:notify', src, { type = 'warn', title = 'Insurance', message = tostring(result), duration = 4000 })
        return
    end

    TriggerClientEvent('pa:ui:notify', src, { type = 'success', title = 'Insurance', message = ('Claim paid: $%s'):format(result), duration = 4000 })
end)

RegisterNetEvent('pa:vehicles:giveKey', function(payload)
    local src = source
    payload = type(payload) == 'table' and payload or {}

    local target = tonumber(payload.targetSrc)
    if not target or target <= 0 then
        TriggerClientEvent('pa:ui:notify', src, { type = 'error', title = 'Keys', message = 'Invalid target.', duration = 3500 })
        return
    end

    local vehicle, _, err = getOwnedVehicleForPlayer(src, payload.vehicleId)
    if not vehicle then
        TriggerClientEvent('pa:ui:notify', src, { type = 'error', title = 'Keys', message = err, duration = 3500 })
        return
    end

    local ownerChar = getCharId(src)
    local targetChar = getCharId(target)
    if not ownerChar or not targetChar then
        TriggerClientEvent('pa:ui:notify', src, { type = 'error', title = 'Keys', message = 'Player character missing.', duration = 3500 })
        return
    end

    if not hasVehicleKey(ownerChar, vehicle.id) then
        TriggerClientEvent('pa:ui:notify', src, { type = 'error', title = 'Keys', message = 'You do not have keys for this vehicle.', duration = 3500 })
        return
    end

    assignVehicleKey(vehicle.id, targetChar)
    syncVehicleKeyDb(vehicle.id, targetChar, 'shared', false)

    TriggerClientEvent('pa:ui:notify', src, { type = 'success', title = 'Keys', message = 'Shared key granted.', duration = 3000 })
    TriggerClientEvent('pa:ui:notify', target, { type = 'info', title = 'Keys', message = ('You received keys for %s'):format(vehicle.plate), duration = 4000 })
end)

RegisterNetEvent('pa:vehicles:revokeKey', function(payload)
    local src = source
    payload = type(payload) == 'table' and payload or {}

    local target = tonumber(payload.targetSrc)
    local vehicle, _, err = getOwnedVehicleForPlayer(src, payload.vehicleId)
    if not vehicle then
        TriggerClientEvent('pa:ui:notify', src, { type = 'error', title = 'Keys', message = err, duration = 3500 })
        return
    end

    local targetChar = target and getCharId(target) or nil
    if not targetChar then
        TriggerClientEvent('pa:ui:notify', src, { type = 'error', title = 'Keys', message = 'Target missing.', duration = 3500 })
        return
    end

    removeVehicleKey(vehicle.id, targetChar)
    syncVehicleKeyDb(vehicle.id, targetChar, nil, true)

    TriggerClientEvent('pa:ui:notify', src, { type = 'success', title = 'Keys', message = 'Shared key revoked.', duration = 3000 })
end)

exports('PaVehicles:RegisterOwnedVehicle', function(src, payload)
    return registerOwnedVehicle(src, payload)
end)

exports('PaVehicles:GetOwnedVehicles', function(src)
    return listOwnedVehicles(src)
end)

exports('PaVehicles:HasKey', function(src, vehicleId)
    local charId = getCharId(src)
    if not charId then return false end
    return hasVehicleKey(charId, vehicleId)
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= RESOURCE_NAME then
        return
    end

    print(('^2[%s] Vehicle service ready (ownership + keys + garages + insurance).^7'):format(RESOURCE_NAME))
end)
