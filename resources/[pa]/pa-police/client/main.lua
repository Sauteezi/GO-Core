local MdtVisible = false

local function sendNui(action, data)
    SendNUIMessage({ action = action, data = data })
end

local function setMdtVisible(state)
    MdtVisible = state == true
    SetNuiFocus(MdtVisible, MdtVisible)
    sendNui('setVisible', { visible = MdtVisible })

    if MdtVisible then
        TriggerServerEvent('pa:police:requestMdtSnapshot')
    end
end

RegisterCommand('pdmdt', function()
    setMdtVisible(not MdtVisible)
end, false)

RegisterNetEvent('pa:police:updateDutyRoster', function(roster)
    sendNui('setRoster', { roster = roster or {} })
end)

RegisterNetEvent('pa:police:mdtResult', function(ok, payload)
    sendNui('mdtResult', { ok = ok, payload = payload })
end)

RegisterNetEvent('pa:police:actionResult', function(ok, message)
    if GetResourceState('pa-ui') == 'started' then
        exports['pa-ui']['PaUI:Notify'](ok and 'success' or 'error', 'PD', tostring(message), 4500)
    end
end)

RegisterNUICallback('police:close', function(_, cb)
    setMdtVisible(false)
    cb({ ok = true })
end)

RegisterNUICallback('police:lookupPerson', function(payload, cb)
    TriggerServerEvent('pa:police:mdtPersonLookup', payload and payload.query or '')
    cb({ ok = true })
end)

RegisterNUICallback('police:lookupPlate', function(payload, cb)
    TriggerServerEvent('pa:police:mdtPlateLookup', payload and payload.plate or '')
    cb({ ok = true })
end)

RegisterNUICallback('police:loadRecords', function(payload, cb)
    TriggerServerEvent('pa:police:mdtRecords', payload and payload.targetCharId)
    cb({ ok = true })
end)

RegisterNUICallback('police:setDuty', function(payload, cb)
    TriggerServerEvent('pa:police:setDuty', payload and payload.onDuty == true)
    cb({ ok = true })
end)

RegisterNUICallback('police:status', function(payload, cb)
    TriggerServerEvent('pa:police:updateUnitStatus', payload and payload.status or 'available')
    cb({ ok = true })
end)

RegisterNUICallback('police:createCitation', function(payload, cb)
    TriggerServerEvent('pa:police:createCitation', payload)
    cb({ ok = true })
end)

RegisterNUICallback('police:processArrest', function(payload, cb)
    TriggerServerEvent('pa:police:processArrest', payload)
    cb({ ok = true })
end)

RegisterNUICallback('police:writeReport', function(payload, cb)
    TriggerServerEvent('pa:police:writeReport', payload)
    cb({ ok = true })
end)

RegisterNUICallback('police:addWarrant', function(payload, cb)
    TriggerServerEvent('pa:police:addWarrant', payload)
    cb({ ok = true })
end)

RegisterNUICallback('police:addCaseNote', function(payload, cb)
    TriggerServerEvent('pa:police:addCaseNote', payload)
    cb({ ok = true })
end)

RegisterNUICallback('police:collectEvidence', function(payload, cb)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    payload = type(payload) == 'table' and payload or {}
    payload.coords = {
        x = coords.x,
        y = coords.y,
        z = coords.z,
    }

    TriggerServerEvent('pa:police:collectEvidence', payload)
    cb({ ok = true })
end)
