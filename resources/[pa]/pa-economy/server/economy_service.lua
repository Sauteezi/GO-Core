local RESOURCE_NAME = GetCurrentResourceName()

local VALID_ACCOUNTS = {
    cash = true,
    bank = true,
    dirty = true,
    business = true,
}

local STAFF_ROLES = { 'owner', 'dev', 'admin', 'mod', 'support' }

local EconomyConfig = {
    minTransaction = 1,
    maxTransaction = 250000,
}

local function toInteger(value)
    local number = tonumber(value)
    if not number then
        return nil
    end

    if number % 1 ~= 0 then
        return nil
    end

    return math.floor(number)
end

local function notify(src, messageType, title, message)
    TriggerClientEvent('pa:ui:notify', src, {
        type = messageType,
        title = title,
        message = message,
        duration = 4500,
    })
end

local function loadConfig()
    if GetResourceState('pa-shared') ~= 'started' then
        return
    end

    local ok, config = pcall(function()
        return exports['pa-shared']['PaShared:GetConfig']('economy')
    end)

    if not ok or type(config) ~= 'table' then
        return
    end

    if type(config.defaults) == 'table' then
        EconomyConfig.minTransaction = tonumber(config.defaults.minTransaction) or EconomyConfig.minTransaction
        EconomyConfig.maxTransaction = tonumber(config.defaults.maxTransaction) or EconomyConfig.maxTransaction
    end

    EconomyConfig.sinks = config.sinks or {}
end

local function getLicense(src)
    local ok, license = pcall(function()
        return exports['pa-core']['PaCore:GetLicense'](src)
    end)

    if ok then
        return license
    end

    return nil
end

local function getCharId(src)
    local ok, charId = pcall(function()
        return exports['pa-core']['PaCore:GetCharId'](src)
    end)

    if ok then
        return tonumber(charId)
    end

    return nil
end

local function tryRateLimit(src, key, maxPerWindow, windowMs)
    if GetResourceState('pa-guard') ~= 'started' then
        return true
    end

    local ok, _ = exports['pa-guard']['PaGuard:RateLimit'](src, key, maxPerWindow, windowMs)
    return ok
end

local function logWarn(src, action, message, meta)
    if GetResourceState('pa-logging') ~= 'started' then
        return
    end

    pcall(function()
        exports['pa-logging']['PaLogging:LogWarn']({
            resource = RESOURCE_NAME,
            source = src,
            action = action,
            message = message,
            meta = meta,
        })
    end)
end

local function logInfo(src, action, message, meta)
    if GetResourceState('pa-logging') ~= 'started' then
        return
    end

    pcall(function()
        exports['pa-logging']['PaLogging:LogInfo']({
            resource = RESOURCE_NAME,
            source = src,
            action = action,
            message = message,
            meta = meta,
        })
    end)
end

local function logAudit(src, action, message, meta)
    if GetResourceState('pa-logging') ~= 'started' then
        return
    end

    pcall(function()
        exports['pa-logging']['PaLogging:LogAudit']({
            resource = RESOURCE_NAME,
            source = src,
            action = action,
            message = message,
            actorLicense = getLicense(src),
            meta = meta,
        })
    end)
end

local function ensureValidAccount(account)
    local normalized = string.lower(tostring(account or ''))
    if VALID_ACCOUNTS[normalized] then
        return normalized
    end
    return nil
end

local function ensureValidAmount(amount)
    local integer = toInteger(amount)
    if not integer then
        return nil, 'Amount must be an integer.'
    end

    if integer == 0 then
        return nil, 'Amount cannot be zero.'
    end

    local absValue = math.abs(integer)
    if absValue < EconomyConfig.minTransaction then
        return nil, ('Amount must be at least %s.'):format(EconomyConfig.minTransaction)
    end

    if absValue > EconomyConfig.maxTransaction then
        return nil, ('Amount must be <= %s.'):format(EconomyConfig.maxTransaction)
    end

    return integer, nil
end

local function getOrCreateAccount(charId, accountType)
    local rows = exports.oxmysql:querySync([[
        SELECT id, balance
        FROM accounts
        WHERE char_id = ?
          AND account_type = ?
        LIMIT 1
    ]], { charId, accountType }) or {}

    local row = rows[1]
    if row then
        return tonumber(row.id), tonumber(row.balance) or 0
    end

    local accountId = exports.oxmysql:insertSync([[
        INSERT INTO accounts (char_id, account_type, balance)
        VALUES (?, ?, 0)
    ]], { charId, accountType })

    return tonumber(accountId), 0
end

local function recordTransaction(accountId, charId, txnType, amount, direction, reason, beforeBalance, afterBalance, meta)
    local payload = meta or {}
    payload.beforeBalance = beforeBalance
    payload.afterBalance = afterBalance

    exports.oxmysql:executeSync([[
        INSERT INTO transactions (account_id, char_id, txn_type, amount, direction, reference, metadata)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], {
        accountId,
        charId,
        txnType,
        amount,
        direction,
        reason,
        json.encode(payload),
    })
end

local function updateBalance(charId, account, delta, reason, meta)
    local accountId, before = getOrCreateAccount(charId, account)
    local after = before + delta

    if after < 0 then
        return false, 'Insufficient funds.', before, before
    end

    exports.oxmysql:executeSync([[
        UPDATE accounts
        SET balance = ?, updated_at = CURRENT_TIMESTAMP
        WHERE id = ?
    ]], { after, accountId })

    recordTransaction(
        accountId,
        charId,
        delta >= 0 and 'add_money' or 'remove_money',
        math.abs(delta),
        delta >= 0 and 'credit' or 'debit',
        reason,
        before,
        after,
        meta
    )

    return true, nil, before, after
end

local PaEconomy = {}

function PaEconomy:GetBalance(src, account)
    local charId = getCharId(src)
    if not charId then
        return nil, 'No active character.'
    end

    local accountType = ensureValidAccount(account)
    if not accountType then
        return nil, 'Invalid account type.'
    end

    local _, balance = getOrCreateAccount(charId, accountType)
    return balance, nil
end

function PaEconomy:AddMoney(src, account, amount, reason, meta)
    local charId = getCharId(src)
    if not charId then
        return false, 'No active character.'
    end

    if not tryRateLimit(src, 'economy:add', 20, 10000) then
        return false, 'Rate limit exceeded.'
    end

    local accountType = ensureValidAccount(account)
    if not accountType then
        return false, 'Invalid account type.'
    end

    local intAmount, amountErr = ensureValidAmount(amount)
    if not intAmount or intAmount < 0 then
        return false, amountErr or 'Amount must be positive integer.'
    end

    local ok, err, before, after = updateBalance(charId, accountType, intAmount, reason or 'add_money', meta)
    if not ok then
        return false, err
    end

    logInfo(src, 'add_money', 'Money credited.', { account = accountType, amount = intAmount, before = before, after = after, reason = reason })
    return true, nil
end

function PaEconomy:RemoveMoney(src, account, amount, reason, meta)
    local charId = getCharId(src)
    if not charId then
        return false, 'No active character.'
    end

    if not tryRateLimit(src, 'economy:remove', 20, 10000) then
        return false, 'Rate limit exceeded.'
    end

    local accountType = ensureValidAccount(account)
    if not accountType then
        return false, 'Invalid account type.'
    end

    local intAmount, amountErr = ensureValidAmount(amount)
    if not intAmount or intAmount < 0 then
        return false, amountErr or 'Amount must be positive integer.'
    end

    local ok, err, before, after = updateBalance(charId, accountType, -intAmount, reason or 'remove_money', meta)
    if not ok then
        return false, err
    end

    logInfo(src, 'remove_money', 'Money debited.', { account = accountType, amount = intAmount, before = before, after = after, reason = reason })
    return true, nil
end

function PaEconomy:TransferMoney(src, targetSrc, account, amount, reason, meta)
    local toSrc = tonumber(targetSrc)
    if not toSrc then
        return false, 'Invalid target source.'
    end

    local charId = getCharId(src)
    local targetCharId = getCharId(toSrc)
    if not charId or not targetCharId then
        return false, 'Source or target has no active character.'
    end

    local accountType = ensureValidAccount(account)
    if not accountType then
        return false, 'Invalid account type.'
    end

    local intAmount, amountErr = ensureValidAmount(amount)
    if not intAmount or intAmount < 0 then
        return false, amountErr or 'Amount must be positive integer.'
    end

    if not tryRateLimit(src, 'economy:transfer', 10, 10000) then
        return false, 'Rate limit exceeded.'
    end

    local okRemove, removeErr = self:RemoveMoney(src, accountType, intAmount, reason or 'transfer_out', meta)
    if not okRemove then
        return false, removeErr
    end

    local okAdd, addErr = self:AddMoney(toSrc, accountType, intAmount, reason or 'transfer_in', meta)
    if not okAdd then
        self:AddMoney(src, accountType, intAmount, 'transfer_rollback', { reason = addErr })
        return false, addErr
    end

    logInfo(src, 'transfer_money', 'Transfer completed.', { to = toSrc, account = accountType, amount = intAmount, reason = reason })
    return true, nil
end

function PaEconomy:SetBalance(actorSrc, targetSrc, account, amount, reason, meta)
    if not exports['pa-perms']['PaPerms:Require'](actorSrc, STAFF_ROLES, 'Staff permission required to set balances.') then
        return false, 'Not permitted.'
    end

    local target = tonumber(targetSrc)
    if not target then
        return false, 'Invalid target source.'
    end

    local targetCharId = getCharId(target)
    if not targetCharId then
        return false, 'Target has no active character.'
    end

    local accountType = ensureValidAccount(account)
    if not accountType then
        return false, 'Invalid account type.'
    end

    local intAmount, amountErr = ensureValidAmount(amount)
    if not intAmount or intAmount < 0 then
        return false, amountErr or 'Amount must be positive integer.'
    end

    local accountId, before = getOrCreateAccount(targetCharId, accountType)
    exports.oxmysql:executeSync([[
        UPDATE accounts
        SET balance = ?, updated_at = CURRENT_TIMESTAMP
        WHERE id = ?
    ]], { intAmount, accountId })

    recordTransaction(
        accountId,
        targetCharId,
        'set_balance',
        intAmount,
        intAmount >= before and 'credit' or 'debit',
        reason or 'set_balance',
        before,
        intAmount,
        meta
    )

    logAudit(actorSrc, 'set_balance', 'Staff set balance.', {
        targetSrc = target,
        account = accountType,
        before = before,
        after = intAmount,
        reason = reason,
    })

    return true, nil
end

exports('PaEconomy:AddMoney', function(src, account, amount, reason, meta)
    return PaEconomy:AddMoney(src, account, amount, reason, meta)
end)

exports('PaEconomy:RemoveMoney', function(src, account, amount, reason, meta)
    return PaEconomy:RemoveMoney(src, account, amount, reason, meta)
end)

exports('PaEconomy:TransferMoney', function(src, targetSrc, account, amount, reason, meta)
    return PaEconomy:TransferMoney(src, targetSrc, account, amount, reason, meta)
end)

exports('PaEconomy:GetBalance', function(src, account)
    return PaEconomy:GetBalance(src, account)
end)

exports('PaEconomy:SetBalance', function(actorSrc, targetSrc, account, amount, reason, meta)
    return PaEconomy:SetBalance(actorSrc, targetSrc, account, amount, reason, meta)
end)

RegisterCommand('balance', function(src, args)
    local target = tonumber(args[1]) or src
    local account = args[2] or 'bank'

    if src ~= 0 and not exports['pa-perms']['PaPerms:Require'](src, STAFF_ROLES, 'Staff permission required for /balance.') then
        return
    end

    local balance, err = PaEconomy:GetBalance(target, account)
    if not balance then
        if src > 0 then notify(src, 'error', 'Balance check failed', err) end
        return
    end

    if src > 0 then
        notify(src, 'info', 'Balance', ('Src %s %s balance: %s'):format(target, account, balance))
    else
        print(('[%s] /balance src=%s account=%s balance=%s'):format(RESOURCE_NAME, target, account, balance))
    end
end, false)

RegisterCommand('pay', function(src, args)
    if src ~= 0 and not exports['pa-perms']['PaPerms:Require'](src, STAFF_ROLES, 'Staff permission required for /pay.') then
        return
    end

    local target = tonumber(args[1])
    local amount = tonumber(args[2])
    local account = args[3] or 'bank'
    local reason = args[4] or 'staff_pay'

    if not target or not amount then
        if src > 0 then notify(src, 'error', 'Usage', '/pay <targetSrc> <amount> [account] [reason]') end
        return
    end

    local ok, err = PaEconomy:AddMoney(target, account, amount, reason, { actor = src, command = 'pay' })
    if not ok then
        if src > 0 then notify(src, 'error', 'Pay failed', err) end
        return
    end

    if src > 0 then
        notify(src, 'success', 'Pay success', ('Credited %s to src %s (%s).'):format(amount, target, account))
    end
    logAudit(src, 'command_pay', 'Staff used /pay command.', { target = target, amount = amount, account = account, reason = reason })
end, false)

RegisterCommand('fine', function(src, args)
    if src ~= 0 and not exports['pa-perms']['PaPerms:Require'](src, STAFF_ROLES, 'Staff permission required for /fine.') then
        return
    end

    local target = tonumber(args[1])
    local amount = tonumber(args[2])
    local account = args[3] or 'bank'
    local reason = args[4] or 'staff_fine'

    if not target or not amount then
        if src > 0 then notify(src, 'error', 'Usage', '/fine <targetSrc> <amount> [account] [reason]') end
        return
    end

    local ok, err = PaEconomy:RemoveMoney(target, account, amount, reason, { actor = src, command = 'fine' })
    if not ok then
        if src > 0 then notify(src, 'error', 'Fine failed', err) end
        return
    end

    if src > 0 then
        notify(src, 'success', 'Fine success', ('Debited %s from src %s (%s).'):format(amount, target, account))
    end
    logAudit(src, 'command_fine', 'Staff used /fine command.', { target = target, amount = amount, account = account, reason = reason })
end, false)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= RESOURCE_NAME then
        return
    end

    loadConfig()
    print(('^2[%s] Economy service ready (ledger + authoritative account ops).^7'):format(RESOURCE_NAME))
end)
