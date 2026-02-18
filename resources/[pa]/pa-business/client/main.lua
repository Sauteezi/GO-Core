local RESOURCE_NAME = GetCurrentResourceName()
local uiOpen = false

local function openBusinessUi()
    if uiOpen then return end
    uiOpen = true
    SetNuiFocus(true, true)
    TriggerServerEvent('pa:business:requestDashboard')
end

local function closeBusinessUi()
    if not uiOpen then return end
    uiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'business:close' })
end

RegisterNetEvent('pa:business:openDashboard', function(payload)
    SendNUIMessage({ action = 'business:open', payload = payload })
end)

RegisterNetEvent('pa:business:invoiceReceived', function(invoice)
    TriggerEvent('chat:addMessage', {
        color = { 255, 184, 77 },
        args = { RESOURCE_NAME, ('New invoice #%s for $%s'):format(invoice.id, invoice.amount) },
    })
end)

RegisterNUICallback('business:close', function(_, cb)
    closeBusinessUi()
    cb({ ok = true })
end)

RegisterNUICallback('business:createInvoice', function(data, cb)
    TriggerServerEvent('pa:business:createInvoice', data)
    cb({ ok = true })
end)

RegisterNUICallback('business:payInvoice', function(data, cb)
    TriggerServerEvent('pa:business:payInvoice', data)
    cb({ ok = true })
end)

RegisterNUICallback('business:runPayroll', function(data, cb)
    TriggerServerEvent('pa:business:runPayroll', data)
    cb({ ok = true })
end)

RegisterNUICallback('business:startProduction', function(data, cb)
    TriggerServerEvent('pa:business:startProduction', data)
    cb({ ok = true })
end)

RegisterNUICallback('business:purchaseLicense', function(data, cb)
    TriggerServerEvent('pa:business:purchaseLicense', data)
    cb({ ok = true })
end)

RegisterNUICallback('business:buyMeal', function(data, cb)
    TriggerServerEvent('pa:business:buyMeal', data)
    cb({ ok = true })
end)

RegisterNUICallback('business:hireSecurity', function(data, cb)
    TriggerServerEvent('pa:business:hireSecurity', data)
    cb({ ok = true })
end)

RegisterCommand('business', function()
    openBusinessUi()
end, false)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName == RESOURCE_NAME then
        closeBusinessUi()
    end
end)
