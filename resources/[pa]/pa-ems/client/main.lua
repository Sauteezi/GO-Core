local EmsVisible = false

local function sendNui(action, data)
    SendNUIMessage({ action = action, data = data })
end

local function setVisible(state)
    EmsVisible = state == true
    SetNuiFocus(EmsVisible, EmsVisible)
    sendNui('setVisible', { visible = EmsVisible })
end

RegisterCommand('emsmdt', function()
    setVisible(not EmsVisible)
end, false)

RegisterNetEvent('pa:ems:actionResult', function(ok, result)
    if GetResourceState('pa-ui') == 'started' then
        exports['pa-ui']['PaUI:Notify'](ok and 'success' or 'error', 'EMS', type(result) == 'string' and result or 'Action processed.', 4500)
    end
    sendNui('actionResult', { ok = ok, result = result })
end)

RegisterNetEvent('pa:ems:injuryUpdated', function(data)
    sendNui('injuryUpdated', data)
end)

RegisterNetEvent('pa:ems:transported', function(data)
    sendNui('transported', data)
end)

RegisterNetEvent('pa:ems:revived', function(data)
    sendNui('revived', data)
end)

RegisterNUICallback('ems:close', function(_, cb)
    setVisible(false)
    cb({ ok = true })
end)

RegisterNUICallback('ems:setDuty', function(payload, cb)
    TriggerServerEvent('pa:ems:setDuty', payload and payload.onDuty == true)
    cb({ ok = true })
end)

RegisterNUICallback('ems:setInjury', function(payload, cb)
    TriggerServerEvent('pa:ems:setInjuryState', payload and payload.injury or 'minor')
    cb({ ok = true })
end)

RegisterNUICallback('ems:revive', function(payload, cb)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    payload = type(payload) == 'table' and payload or {}
    payload.coords = { x = coords.x, y = coords.y, z = coords.z }
    TriggerServerEvent('pa:ems:revive', payload.targetSrc, payload)
    cb({ ok = true })
end)

RegisterNUICallback('ems:transport', function(payload, cb)
    TriggerServerEvent('pa:ems:transport', payload and payload.targetSrc, payload and payload.bedId)
    cb({ ok = true })
end)

RegisterNUICallback('ems:bill', function(payload, cb)
    TriggerServerEvent('pa:ems:billPatient', payload and payload.patientSrc, payload)
    cb({ ok = true })
end)

RegisterNUICallback('ems:record', function(payload, cb)
    TriggerServerEvent('pa:ems:recordIncident', payload)
    cb({ ok = true })
end)

RegisterNUICallback('ems:call911', function(payload, cb)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    payload = type(payload) == 'table' and payload or {}
    payload.coords = { x = coords.x, y = coords.y, z = coords.z }
    TriggerServerEvent('pa:ems:goodSamaritan911', payload)
    cb({ ok = true })
end)

RegisterNUICallback('ems:cpr', function(payload, cb)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    payload = type(payload) == 'table' and payload or {}
    payload.coords = { x = coords.x, y = coords.y, z = coords.z }
    TriggerServerEvent('pa:ems:goodSamaritanCPR', payload.targetSrc, payload)
    cb({ ok = true })
end)
