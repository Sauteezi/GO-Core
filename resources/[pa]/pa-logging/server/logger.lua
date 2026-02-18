local RESOURCE_NAME = GetCurrentResourceName()

local function nowIso()
    return os.date('!%Y-%m-%dT%H:%M:%SZ')
end

local function encodeJson(data)
    local ok, encoded = pcall(json.encode, data or {})
    if ok then
        return encoded
    end
    return '{}'
end

local function parseBoolConvar(name, defaultValue)
    local raw = GetConvar(name, defaultValue and 'true' or 'false')
    raw = string.lower(raw)
    return raw == '1' or raw == 'true' or raw == 'yes' or raw == 'on'
end

local LoggerConfig = {
    sinkConsole = parseBoolConvar('pa:log:sinkConsole', true),
    sinkDb = parseBoolConvar('pa:log:sinkDb', true),
    sinkWebhook = parseBoolConvar('pa:log:sinkWebhook', false),
    webhookUrl = GetConvar('pa:webhook:logging', ''),
}

local function buildCorrelationId(source, action)
    local src = tonumber(source) or 0
    local random = math.random(100000, 999999)
    local stamp = os.time()
    return ('pa-%s-%s-%s'):format(stamp, src, random) .. (action and ('-' .. tostring(action)) or '')
end

local function writeConsole(level, resource, message, correlationId, meta)
    if not LoggerConfig.sinkConsole then
        return
    end

    local text = ('[%s][%s][%s][cid:%s] %s | meta=%s'):format(
        RESOURCE_NAME,
        level,
        resource,
        correlationId,
        message,
        encodeJson(meta)
    )

    if level == 'error' then
        print(('^1%s^7'):format(text))
    elseif level == 'warn' then
        print(('^3%s^7'):format(text))
    else
        print(('^2%s^7'):format(text))
    end
end

local function writeWebhook(level, resource, message, correlationId, meta)
    if not LoggerConfig.sinkWebhook or LoggerConfig.webhookUrl == '' then
        return
    end

    PerformHttpRequest(LoggerConfig.webhookUrl, function() end, 'POST', json.encode({
        username = 'Port Aurora Logs',
        embeds = {
            {
                title = ('[%s] %s'):format(level:upper(), resource),
                description = message,
                fields = {
                    { name = 'Correlation ID', value = correlationId, inline = false },
                    { name = 'Metadata', value = ('```json\n%s\n```'):format(encodeJson(meta)), inline = false },
                    { name = 'Timestamp', value = nowIso(), inline = false },
                },
            }
        }
    }), { ['Content-Type'] = 'application/json' })
end

local function writeGeneralLog(level, resource, message, correlationId, meta)
    if not LoggerConfig.sinkDb then
        return
    end

    exports.oxmysql:executeSync([[
        INSERT INTO logs (level, resource, message, meta, correlation_id)
        VALUES (?, ?, ?, ?, ?)
    ]], {
        level,
        resource,
        message,
        encodeJson(meta),
        correlationId,
    })
end

local function writeAdminAction(actionType, actorLicense, targetLicense, details)
    if not LoggerConfig.sinkDb then
        return
    end

    exports.oxmysql:executeSync([[
        INSERT INTO admin_actions (actor_license, target_license, action_type, action_details)
        VALUES (?, ?, ?, ?)
    ]], {
        actorLicense or 'license:system',
        targetLicense,
        actionType,
        encodeJson(details),
    })
end

local function writeTransaction(accountId, charId, txnType, amount, direction, reference, meta)
    if not LoggerConfig.sinkDb then
        return
    end

    exports.oxmysql:executeSync([[
        INSERT INTO transactions (account_id, char_id, txn_type, amount, direction, reference, metadata)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], {
        accountId,
        charId,
        txnType,
        amount,
        direction,
        reference,
        encodeJson(meta),
    })
end

local function baseLog(level, payload)
    local resource = payload.resource or 'unknown-resource'
    local message = payload.message or 'No message'
    local correlationId = payload.correlationId or buildCorrelationId(payload.source, payload.action)
    local meta = payload.meta or {}

    writeConsole(level, resource, message, correlationId, meta)
    writeGeneralLog(level, resource, message, correlationId, meta)
    writeWebhook(level, resource, message, correlationId, meta)

    return correlationId
end

local function LogInfo(payload)
    return baseLog('info', payload)
end

local function LogWarn(payload)
    return baseLog('warn', payload)
end

local function LogError(payload)
    return baseLog('error', payload)
end

local function LogAudit(payload)
    local correlationId = baseLog('audit', payload)
    writeAdminAction(
        payload.action or 'audit',
        payload.actorLicense,
        payload.targetLicense,
        {
            correlationId = correlationId,
            message = payload.message,
            meta = payload.meta,
        }
    )
    return correlationId
end

local function LogEconomy(payload)
    local correlationId = baseLog('economy', payload)
    writeTransaction(
        payload.accountId or 0,
        payload.charId,
        payload.txnType or 'economy_event',
        payload.amount or 0,
        payload.direction or 'debit',
        payload.reference or 'pa-logging',
        {
            correlationId = correlationId,
            resource = payload.resource,
            message = payload.message,
            meta = payload.meta,
        }
    )
    return correlationId
end

local function LogAdmin(payload)
    local correlationId = baseLog('admin', payload)
    writeAdminAction(
        payload.action or 'admin_action',
        payload.actorLicense,
        payload.targetLicense,
        {
            correlationId = correlationId,
            message = payload.message,
            meta = payload.meta,
        }
    )
    return correlationId
end

exports('PaLogging:NewCorrelationId', function(source, action)
    return buildCorrelationId(source, action)
end)

exports('PaLogging:LogInfo', function(payload)
    return LogInfo(payload or {})
end)

exports('PaLogging:LogWarn', function(payload)
    return LogWarn(payload or {})
end)

exports('PaLogging:LogError', function(payload)
    return LogError(payload or {})
end)

exports('PaLogging:LogAudit', function(payload)
    return LogAudit(payload or {})
end)

exports('PaLogging:LogEconomy', function(payload)
    return LogEconomy(payload or {})
end)

exports('PaLogging:LogAdmin', function(payload)
    return LogAdmin(payload or {})
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= RESOURCE_NAME then
        return
    end

    math.randomseed(GetGameTimer())
    print(('^2[%s] Structured logger ready. Sinks(console=%s, db=%s, webhook=%s).^7'):format(
        RESOURCE_NAME,
        tostring(LoggerConfig.sinkConsole),
        tostring(LoggerConfig.sinkDb),
        tostring(LoggerConfig.sinkWebhook)
    ))
end)
