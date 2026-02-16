local RESOURCE_NAME = GetCurrentResourceName()

local function sendMessage(source, message)
    if source == 0 then
        print(('[%s] %s'):format(RESOURCE_NAME, message))
    else
        TriggerClientEvent('chat:addMessage', source, {
            color = { 255, 190, 120 },
            multiline = false,
            args = { RESOURCE_NAME, message }
        })
    end
end

local function splitSqlStatements(sql)
    local statements = {}
    for statement in sql:gmatch('([^;]+);') do
        local trimmed = statement:gsub('^%s+', ''):gsub('%s+$', '')
        if trimmed ~= '' and not trimmed:match('^%-%-') then
            statements[#statements + 1] = trimmed
        end
    end
    return statements
end

local function applySchemaSafe(source)
    if GetResourceState('oxmysql') ~= 'started' then
        sendMessage(source, 'Cannot apply schema: oxmysql is not started. Ensure oxmysql first in server.cfg.')
        return
    end

    local schemaSql = LoadResourceFile(RESOURCE_NAME, 'sql/pa_schema.sql')
    if not schemaSql then
        sendMessage(source, 'Cannot load sql/pa_schema.sql from pa-devtools resource.')
        return
    end

    local statements = splitSqlStatements(schemaSql)
    if #statements == 0 then
        sendMessage(source, 'No SQL statements found in pa_schema.sql.')
        return
    end

    local executed = 0
    for _, statement in ipairs(statements) do
        local ok, err = pcall(function()
            exports.oxmysql:executeSync(statement)
        end)

        if not ok then
            sendMessage(source, ('Schema apply stopped on statement %d. Error: %s'):format(executed + 1, tostring(err)))
            return
        end

        executed = executed + 1
    end

    sendMessage(source, ('Schema safe apply complete. Executed %d statements.'):format(executed))
    sendMessage(source, 'Beginner tip: Use sql/pa_schema.sql manually in production change workflows.')
end

RegisterCommand('pa-devtools', function(source, args)
    local sub = args[1]

    if not sub then
        sendMessage(source, 'Usage: /pa-devtools apply-schema')
        return
    end

    if sub ~= 'apply-schema' then
        sendMessage(source, 'Unknown subcommand. Available: apply-schema')
        return
    end

    applySchemaSafe(source)
end, true)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= RESOURCE_NAME then
        return
    end

    print(('^2[%s] Command ready: /pa-devtools apply-schema (safe mode).^7'):format(RESOURCE_NAME))
end)
