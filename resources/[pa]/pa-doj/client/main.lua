local isOpen = false

local function setUI(open, payload)
    isOpen = open
    SetNuiFocus(open, open)
    SendNUIMessage({
        action = 'doj:setVisible',
        visible = open,
        payload = payload,
    })
end

RegisterCommand('doj', function()
    if isOpen then
        setUI(false)
        return
    end

    TriggerServerEvent('pa:doj:requestDocket')
end, false)

RegisterNetEvent('pa:doj:docketData', function(payload)
    if type(payload) ~= 'table' or payload.ok ~= true then
        TriggerEvent('chat:addMessage', { args = { '^1DOJ', 'Unable to load docket (check whitelist role).' } })
        return
    end

    setUI(true, payload)
end)

RegisterNetEvent('pa:doj:caseCreated', function(newCase)
    SendNUIMessage({ action = 'doj:caseCreated', payload = newCase })
end)

RegisterNUICallback('dojClose', function(_, cb)
    setUI(false)
    cb({ ok = true })
end)

RegisterNUICallback('dojCreateCase', function(data, cb)
    TriggerServerEvent('pa:doj:createCase', data)
    cb({ ok = true })
end)

RegisterNUICallback('dojScheduleCourt', function(data, cb)
    TriggerServerEvent('pa:doj:scheduleCourt', data)
    cb({ ok = true })
end)

RegisterNUICallback('dojProposePlea', function(data, cb)
    TriggerServerEvent('pa:doj:proposePlea', data)
    cb({ ok = true })
end)

RegisterNUICallback('dojReviewPlea', function(data, cb)
    TriggerServerEvent('pa:doj:reviewPlea', data)
    cb({ ok = true })
end)

RegisterNUICallback('dojIssueWarrant', function(data, cb)
    TriggerServerEvent('pa:doj:issueWarrant', data)
    cb({ ok = true })
end)

RegisterNUICallback('dojSetBail', function(data, cb)
    TriggerServerEvent('pa:doj:setBail', data)
    cb({ ok = true })
end)
