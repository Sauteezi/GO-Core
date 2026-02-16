local RESOURCE_NAME = GetCurrentResourceName()

local Businesses = {}
local BusinessAccounts = {}
local BusinessMembers = {}
local Invoices = {}
local Receipts = {}
local SecurityContracts = {}

local InvoiceCounter = 1000
local ReceiptCounter = 2000

local function logEvent(levelExport, payload)
    if GetResourceState('pa-logging') ~= 'started' then
        return
    end

    pcall(function()
        exports['pa-logging'][levelExport](payload)
    end)
end

local function loadBusinessConfig()
    local cfg = exports['pa-shared']['PaShared:GetConfig']('businesses')
    Businesses = type(cfg.businesses) == 'table' and cfg.businesses or {}

    for businessId, def in pairs(Businesses) do
        BusinessAccounts[businessId] = BusinessAccounts[businessId] or (tonumber(def.startingBalance) or 0)
        BusinessMembers[businessId] = BusinessMembers[businessId] or {}
    end
end

local function getLicense(src)
    return exports['pa-core']['PaCore:GetLicense'](src)
end

local function hasBusinessLicense(src, businessId)
    local player = exports['pa-core']['PaCore:GetPlayer'](src)
    if type(player) ~= 'table' or type(player.metadata) ~= 'table' then
        return false
    end

    local licenses = player.metadata.licenses
    if type(licenses) ~= 'table' then
        return false
    end

    local def = Businesses[businessId]
    local required = def and def.license
    if not required then
        return true
    end

    local value = licenses[required]
    return value == true or (type(value) == 'table' and value.active == true)
end

local function getRole(src, businessId)
    local byBusiness = BusinessMembers[businessId] or {}
    local role = byBusiness[getLicense(src)]
    return role or 'none'
end

local function canManage(role)
    return role == 'owner' or role == 'manager'
end

local function requireBusinessRole(src, businessId, allowed)
    local role = getRole(src, businessId)
    for _, name in ipairs(allowed) do
        if role == name then
            return true, role
        end
    end
    return false, role
end

local function buildDashboard(src)
    local items = {}
    local lic = getLicense(src)

    for businessId, def in pairs(Businesses) do
        local role = (BusinessMembers[businessId] or {})[lic] or 'none'
        if role ~= 'none' then
            items[#items + 1] = {
                id = businessId,
                label = def.label,
                type = def.type,
                role = role,
                balance = BusinessAccounts[businessId] or 0,
                payroll = def.payroll or {},
            }
        end
    end

    table.sort(items, function(a, b) return a.label < b.label end)
    return items
end

local PaBusiness = {}

function PaBusiness:GetBusiness(businessId)
    return Businesses[businessId]
end

function PaBusiness:HasRole(src, businessId, role)
    return getRole(src, businessId) == role
end

function PaBusiness:GetServiceDiscount(src, serviceType)
    local highest = 0

    for businessId, members in pairs(BusinessMembers) do
        local role = members[getLicense(src)]
        if role and role ~= 'none' then
            local def = Businesses[businessId]
            if def and def.type == 'mechanic' and type(def.serviceDiscounts) == 'table' then
                local value = tonumber(def.serviceDiscounts[serviceType]) or 0
                if value > highest then
                    highest = value
                end
            end
        end
    end

    return highest
end

function PaBusiness:CreateInvoice(actorSrc, targetSrc, businessId, amount, reason)
    local src = tonumber(actorSrc)
    local target = tonumber(targetSrc)
    local value = math.floor(tonumber(amount) or 0)
    local business = Businesses[businessId]

    if not src or not target or value <= 0 or not business then
        return false, 'Invalid invoice data.'
    end

    local ok = requireBusinessRole(src, businessId, { 'owner', 'manager', 'employee' })
    if not ok then
        return false, 'No business access.'
    end

    InvoiceCounter = InvoiceCounter + 1
    local invoice = {
        id = InvoiceCounter,
        businessId = businessId,
        from = src,
        to = target,
        amount = value,
        reason = tostring(reason or 'service_invoice'),
        status = 'pending',
        createdAt = os.time(),
    }

    Invoices[invoice.id] = invoice

    TriggerClientEvent('pa:business:invoiceCreated', src, invoice)
    TriggerClientEvent('pa:business:invoiceReceived', target, invoice)

    return true, invoice
end

function PaBusiness:PayInvoice(src, invoiceId)
    local actor = tonumber(src)
    local invoice = Invoices[tonumber(invoiceId)]
    if not actor or not invoice or invoice.status ~= 'pending' then
        return false, 'Invoice not payable.'
    end

    if invoice.to ~= actor then
        return false, 'Invoice target mismatch.'
    end

    local reason = ('business_invoice:%s:%s'):format(invoice.businessId, invoice.id)
    local ok = exports['pa-economy']['PaEconomy:TransferMoney'](actor, invoice.from, 'bank', invoice.amount, reason, {
        invoiceId = invoice.id,
        businessId = invoice.businessId,
    })

    if not ok then
        return false, 'Payment failed.'
    end

    invoice.status = 'paid'
    invoice.paidAt = os.time()

    local businessBalance = BusinessAccounts[invoice.businessId] or 0
    BusinessAccounts[invoice.businessId] = businessBalance + invoice.amount

    ReceiptCounter = ReceiptCounter + 1
    local receipt = {
        id = ReceiptCounter,
        invoiceId = invoice.id,
        businessId = invoice.businessId,
        amount = invoice.amount,
        paidBy = actor,
        paidTo = invoice.from,
        paidAt = invoice.paidAt,
    }
    Receipts[receipt.id] = receipt

    logEvent('PaLogging:LogEconomy', {
        resource = RESOURCE_NAME,
        source = actor,
        action = 'invoice_paid',
        message = 'Invoice payment processed.',
        actorLicense = getLicense(actor),
        meta = {
            invoiceId = invoice.id,
            businessId = invoice.businessId,
            amount = invoice.amount,
            reason = reason,
            receiptId = receipt.id,
        },
    })

    TriggerClientEvent('pa:business:invoicePaid', actor, { invoice = invoice, receipt = receipt })
    TriggerClientEvent('pa:business:invoicePaid', invoice.from, { invoice = invoice, receipt = receipt })

    return true, receipt
end

function PaBusiness:RunPayroll(src, businessId)
    local actor = tonumber(src)
    local business = Businesses[businessId]
    if not actor or not business then
        return false, 'Unknown business.'
    end

    local ok = requireBusinessRole(actor, businessId, { 'owner', 'manager' })
    if not ok then
        return false, 'Insufficient role for payroll.'
    end

    local payroll = business.payroll or {}
    local paid = 0

    for license, role in pairs(BusinessMembers[businessId] or {}) do
        local salary = math.floor(tonumber(payroll[role] or 0) or 0)
        if salary > 0 then
            for _, srcId in ipairs(GetPlayers()) do
                srcId = tonumber(srcId)
                if srcId and getLicense(srcId) == license then
                    local cost = salary
                    if (BusinessAccounts[businessId] or 0) >= cost then
                        local okPay = exports['pa-economy']['PaEconomy:AddMoney'](srcId, 'bank', salary, ('business_payroll:%s'):format(businessId), {
                            businessId = businessId,
                            role = role,
                        })
                        if okPay then
                            BusinessAccounts[businessId] = BusinessAccounts[businessId] - cost
                            paid = paid + salary
                        end
                    end
                end
            end
        end
    end

    return true, paid
end

function PaBusiness:ChargePeriodicTaxes()
    local econ = exports['pa-shared']['PaShared:GetConfig']('economy')
    local sink = econ and econ.sinks and econ.sinks.business_taxes
    local taxRate = sink and tonumber(sink.amount) or 0.03

    for businessId, balance in pairs(BusinessAccounts) do
        local tax = math.floor(math.max(0, balance * taxRate))
        if tax > 0 then
            BusinessAccounts[businessId] = math.max(0, balance - tax)
            logEvent('PaLogging:LogEconomy', {
                resource = RESOURCE_NAME,
                source = 0,
                action = 'business_tax_charged',
                message = 'Periodic business tax charged.',
                meta = { businessId = businessId, amount = tax, rate = taxRate },
            })
        end
    end
end

function PaBusiness:PurchaseBusinessLicense(src, businessId)
    local actor = tonumber(src)
    local business = Businesses[businessId]
    if not actor or not business then
        return false, 'Unknown business.'
    end

    if hasBusinessLicense(actor, businessId) then
        return true, 'Already licensed.'
    end

    local fee = math.floor(tonumber(business.licenseFee) or 500)
    local reason = ('business_license:%s'):format(businessId)
    local ok = exports['pa-economy']['PaEconomy:RemoveMoney'](actor, 'bank', fee, reason, { businessId = businessId })
    if not ok then
        return false, 'Could not pay license fee.'
    end

    logEvent('PaLogging:LogEconomy', {
        resource = RESOURCE_NAME,
        source = actor,
        action = 'business_license_paid',
        message = 'Business license fee paid.',
        actorLicense = getLicense(actor),
        meta = { businessId = businessId, amount = fee, reason = reason },
    })

    return true, nil
end

function PaBusiness:StartProduction(src, businessId, recipeId)
    local actor = tonumber(src)
    local business = Businesses[businessId]
    if not actor or not business then
        return false, 'Unknown business.'
    end

    local recipe = business.production and business.production[recipeId]
    if not recipe then
        return false, 'Unknown recipe.'
    end

    local allowed = requireBusinessRole(actor, businessId, { 'owner', 'manager', 'employee' })
    if not allowed then
        return false, 'No production access.'
    end

    if GetResourceState('pa-inventory') == 'started' then
        local count = tonumber(recipe.outputCount) or 1
        exports['pa-inventory']['PaInventory:AddItem'](actor, recipe.outputItem, count, { businessId = businessId, recipe = recipeId }, 'business_production')
    end

    return true, nil
end

function PaBusiness:ApplyCivilianEffect(src, businessId)
    local business = Businesses[businessId]
    if not business then
        return false
    end

    if business.type == 'restaurant' or business.type == 'bar' then
        TriggerEvent('pa:hud:businessMeal', src, businessId)
        TriggerClientEvent('pa:ui:notify', src, {
            type = 'success',
            title = business.label,
            message = 'Meal service reduced stress and restored hunger.',
            duration = 4500,
        })
        return true
    end

    return false
end

function PaBusiness:HireSecurity(src, businessId, eventName)
    local actor = tonumber(src)
    local business = Businesses[businessId]
    if not actor or not business then
        return false, 'Unknown business.'
    end

    if business.type ~= 'security' then
        return false, 'Business cannot provide security contracts.'
    end

    SecurityContracts[#SecurityContracts + 1] = {
        id = #SecurityContracts + 1,
        businessId = businessId,
        eventName = tostring(eventName or 'private_event'),
        hiredBy = actor,
        hiredAt = os.time(),
    }

    TriggerEvent('pa:story:securityContractHired', SecurityContracts[#SecurityContracts])
    return true, SecurityContracts[#SecurityContracts]
end

RegisterNetEvent('pa:business:requestDashboard', function()
    local src = source
    TriggerClientEvent('pa:business:openDashboard', src, {
        businesses = buildDashboard(src),
        invoices = Invoices,
    })
end)

RegisterNetEvent('pa:business:createInvoice', function(payload)
    local src = source
    payload = type(payload) == 'table' and payload or {}

    local ok, result = PaBusiness:CreateInvoice(src, payload.targetSrc, payload.businessId, payload.amount, payload.reason)
    if not ok then
        TriggerClientEvent('pa:ui:notify', src, { type = 'error', title = 'Invoice', message = result, duration = 4000 })
        return
    end

    TriggerClientEvent('pa:ui:notify', src, { type = 'success', title = 'Invoice', message = ('Invoice #%s sent.'):format(result.id), duration = 3500 })
end)

RegisterNetEvent('pa:business:payInvoice', function(payload)
    local src = source
    payload = type(payload) == 'table' and payload or {}

    local ok, result = PaBusiness:PayInvoice(src, payload.invoiceId)
    if not ok then
        TriggerClientEvent('pa:ui:notify', src, { type = 'error', title = 'Invoice Payment', message = result, duration = 4000 })
        return
    end

    TriggerClientEvent('pa:ui:notify', src, { type = 'success', title = 'Invoice Payment', message = ('Receipt #%s generated.'):format(result.id), duration = 4000 })
end)

RegisterNetEvent('pa:business:runPayroll', function(payload)
    local src = source
    payload = type(payload) == 'table' and payload or {}

    local ok, amount = PaBusiness:RunPayroll(src, payload.businessId)
    if not ok then
        TriggerClientEvent('pa:ui:notify', src, { type = 'error', title = 'Payroll', message = amount, duration = 4000 })
        return
    end

    TriggerClientEvent('pa:ui:notify', src, { type = 'success', title = 'Payroll', message = ('Paid $%s in payroll.'):format(amount), duration = 4000 })
end)

RegisterNetEvent('pa:business:startProduction', function(payload)
    local src = source
    payload = type(payload) == 'table' and payload or {}

    local ok, err = PaBusiness:StartProduction(src, payload.businessId, payload.recipeId)
    if not ok then
        TriggerClientEvent('pa:ui:notify', src, { type = 'warn', title = 'Production', message = err, duration = 3500 })
        return
    end

    TriggerClientEvent('pa:ui:notify', src, { type = 'success', title = 'Production', message = 'Batch completed.', duration = 3000 })
end)

RegisterNetEvent('pa:business:purchaseLicense', function(payload)
    local src = source
    payload = type(payload) == 'table' and payload or {}
    local ok, err = PaBusiness:PurchaseBusinessLicense(src, payload.businessId)
    if not ok then
        TriggerClientEvent('pa:ui:notify', src, { type = 'error', title = 'Business License', message = err, duration = 4000 })
        return
    end

    TriggerClientEvent('pa:ui:notify', src, { type = 'success', title = 'Business License', message = 'License fee paid.', duration = 3500 })
end)

RegisterNetEvent('pa:business:buyMeal', function(payload)
    local src = source
    payload = type(payload) == 'table' and payload or {}
    PaBusiness:ApplyCivilianEffect(src, payload.businessId)
end)

RegisterNetEvent('pa:business:hireSecurity', function(payload)
    local src = source
    payload = type(payload) == 'table' and payload or {}
    local ok, result = PaBusiness:HireSecurity(src, payload.businessId, payload.eventName)
    if not ok then
        TriggerClientEvent('pa:ui:notify', src, { type = 'error', title = 'Security Contract', message = result, duration = 4000 })
        return
    end

    TriggerClientEvent('pa:ui:notify', src, { type = 'success', title = 'Security Contract', message = ('Contract #%s created.'):format(result.id), duration = 4000 })
end)

exports('PaBusiness:GetBusiness', function(businessId)
    return PaBusiness:GetBusiness(businessId)
end)

exports('PaBusiness:HasRole', function(src, businessId, role)
    return PaBusiness:HasRole(src, businessId, role)
end)

exports('PaBusiness:GetServiceDiscount', function(src, serviceType)
    return PaBusiness:GetServiceDiscount(src, serviceType)
end)

exports('PaBusiness:CreateInvoice', function(actorSrc, targetSrc, businessId, amount, reason)
    return PaBusiness:CreateInvoice(actorSrc, targetSrc, businessId, amount, reason)
end)

exports('PaBusiness:PayInvoice', function(src, invoiceId)
    return PaBusiness:PayInvoice(src, invoiceId)
end)


RegisterCommand('bizrole', function(src, args)
    if src <= 0 then
        return
    end

    local target = tonumber(args[1] or src) or src
    local businessId = tostring(args[2] or '')
    local role = tostring(args[3] or 'employee')

    if not Businesses[businessId] then
        TriggerClientEvent('pa:ui:notify', src, { type = 'error', title = 'Business', message = 'Unknown business id.', duration = 3500 })
        return
    end

    if role ~= 'owner' and role ~= 'manager' and role ~= 'employee' then
        TriggerClientEvent('pa:ui:notify', src, { type = 'error', title = 'Business', message = 'Role must be owner/manager/employee.', duration = 3500 })
        return
    end

    local targetLicense = getLicense(target)
    if not targetLicense then
        TriggerClientEvent('pa:ui:notify', src, { type = 'error', title = 'Business', message = 'Target player not found.', duration = 3500 })
        return
    end

    BusinessMembers[businessId][targetLicense] = role
    TriggerClientEvent('pa:ui:notify', src, { type = 'success', title = 'Business', message = ('Assigned %s to %s (%s).'):format(targetLicense, businessId, role), duration = 4000 })
end, false)

CreateThread(function()
    while true do
        Wait(3600000)
        PaBusiness:ChargePeriodicTaxes()
    end
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= RESOURCE_NAME then
        return
    end

    loadBusinessConfig()
    print(('^2[%s] Business service ready.^7'):format(RESOURCE_NAME))
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == 'pa-shared' and GetResourceState(RESOURCE_NAME) == 'started' then
        loadBusinessConfig()
    end
end)

