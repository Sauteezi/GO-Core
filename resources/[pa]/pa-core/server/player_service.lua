local RESOURCE_NAME = GetCurrentResourceName()

local PlayerCache = {}
local PendingConnections = {}

local MAX_CHARACTERS_PER_LICENSE = 5

local SPAWN_POINTS = {
    city_hall = {
        id = 'city_hall',
        label = 'City Hall',
        description = 'Start near civic services and onboarding staff.',
        coords = { x = -551.56, y = -191.76, z = 38.22, w = 207.45 },
        requiresJob = nil,
    },
    apartment = {
        id = 'apartment',
        label = 'Starter Apartment',
        description = 'Spawn near your apartment district.',
        coords = { x = -267.05, y = -959.88, z = 31.22, w = 207.45 },
        requiresJob = nil,
    },
    pd = {
        id = 'pd',
        label = 'Police Department',
        description = 'Only available for whitelisted police roles.',
        coords = { x = 440.59, y = -981.89, z = 30.69, w = 89.75 },
        requiresJob = 'police',
    },
}

local function deepCopy(value)
    if type(value) ~= 'table' then
        return value
    end

    local copied = {}
    for k, v in pairs(value) do
        copied[k] = deepCopy(v)
    end

    return copied
end

local function tryLog(methodName, payload)
    if GetResourceState('pa-logging') ~= 'started' then
        return nil
    end

    local ok, result = pcall(function()
        return exports['pa-logging'][methodName](payload)
    end)

    if ok then
        return result
    end

    print(('^3[%s] Logging call failed (%s): %s^7'):format(RESOURCE_NAME, methodName, tostring(result)))
    return nil
end

local function decodeJson(value, fallback)
    if type(value) ~= 'string' or value == '' then
        return fallback or {}
    end

    local ok, decoded = pcall(json.decode, value)
    if ok and type(decoded) == 'table' then
        return decoded
    end

    return fallback or {}
end

local function encodeJson(value)
    local ok, encoded = pcall(json.encode, value)
    if ok then
        return encoded
    end

    return '{}'
end

local function trim(value)
    value = tostring(value or '')
    return (value:gsub('^%s+', ''):gsub('%s+$', ''))
end

local function resolveLicense(source)
    for _, identifier in ipairs(GetPlayerIdentifiers(source)) do
        if identifier:sub(1, 8) == 'license:' then
            return identifier
        end
    end

    return nil
end

local function fetchSingle(query, params)
    local rows = exports.oxmysql:querySync(query, params)
    if type(rows) == 'table' and rows[1] then
        return rows[1]
    end
    return nil
end

local function getSpawnListForSource(source)
    local player = PlayerCache[source]
    local list = {}

    for _, spawn in pairs(SPAWN_POINTS) do
        local allowed = true
        if spawn.requiresJob then
            allowed = player and player.job == spawn.requiresJob
        end

        list[#list + 1] = {
            id = spawn.id,
            label = spawn.label,
            description = spawn.description,
            allowed = allowed,
        }
    end

    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

local function sendCharacterUI(source, message)
    TriggerClientEvent('pa:ui:openCharacterUI', source, {
        message = message or 'Choose a character to begin.',
        characters = {},
        spawns = getSpawnListForSource(source),
    })
end

local function sendCharacterResult(source, ok, message, refresh)
    TriggerClientEvent('pa:ui:characterActionResult', source, {
        ok = ok,
        message = message,
        refresh = refresh == true,
    })
end

local function sendCharacterHydrate(source, characters, message)
    TriggerClientEvent('pa:ui:updateCharacterUI', source, {
        message = message,
        characters = characters,
        spawns = getSpawnListForSource(source),
    })
end

local function sanitizeCharacterPayload(payload)
    payload = type(payload) == 'table' and payload or {}

    local firstName = trim(payload.firstName)
    local lastName = trim(payload.lastName)
    local dob = trim(payload.dob)
    local gender = trim(payload.gender)

    if #firstName < 2 or #firstName > 32 then
        return nil, 'First name must be 2-32 characters.'
    end

    if #lastName < 2 or #lastName > 32 then
        return nil, 'Last name must be 2-32 characters.'
    end

    if not dob:match('^%d%d%d%d%-%d%d%-%d%d$') then
        return nil, 'Date of birth must use YYYY-MM-DD format.'
    end

    if gender == '' then
        gender = 'unspecified'
    end

    local skipTutorial = payload.skipTutorial == true

    return {
        firstName = firstName,
        lastName = lastName,
        dob = dob,
        gender = gender,
        skipTutorial = skipTutorial,
    }, nil
end

local function fetchCharactersForLicense(license)
    local rows = exports.oxmysql:querySync([[
        SELECT c.id, c.first_name, c.last_name, c.date_of_birth, jd.job_name
        FROM characters c
        LEFT JOIN job_duty jd ON jd.char_id = c.id
        WHERE c.license = ?
          AND c.active = 1
        ORDER BY c.id ASC
    ]], { license }) or {}

    local characters = {}
    for _, row in ipairs(rows) do
        characters[#characters + 1] = {
            charId = tonumber(row.id),
            name = ('%s %s'):format(row.first_name or 'Unknown', row.last_name or ''),
            dob = row.date_of_birth,
            job = row.job_name or 'unemployed',
        }
    end

    return characters
end

local function fetchCharacterSnapshot(charId)
    local character = fetchSingle([[
        SELECT id, license, first_name, last_name, date_of_birth
        FROM characters
        WHERE id = ? AND active = 1
        LIMIT 1
    ]], { charId })

    if not character then
        return nil, 'Character not found or inactive.'
    end

    local profile = fetchSingle([[
        SELECT pronouns, bio, emergency_contact, licenses_json
        FROM character_profiles
        WHERE char_id = ?
        LIMIT 1
    ]], { charId }) or {}

    local duty = fetchSingle([[
        SELECT job_name, grade, on_duty
        FROM job_duty
        WHERE char_id = ?
        ORDER BY updated_at DESC
        LIMIT 1
    ]], { charId }) or {}

    local accountRows = exports.oxmysql:querySync([[
        SELECT account_type, balance
        FROM accounts
        WHERE char_id = ?
    ]], { charId }) or {}

    local accountSnapshot = {}
    for _, row in ipairs(accountRows) do
        accountSnapshot[row.account_type] = tonumber(row.balance) or 0
    end

    local metadataJson = decodeJson(profile.licenses_json, {})
    if metadataJson.licenses == nil then
        metadataJson = {
            licenses = metadataJson,
            skipTutorial = false,
        }
    end

    return {
        charId = tonumber(character.id),
        license = character.license,
        name = ('%s %s'):format(character.first_name or 'Unknown', character.last_name or ''),
        dob = character.date_of_birth,
        gender = profile.pronouns or 'unspecified',
        job = duty.job_name or 'unemployed',
        jobGrade = tonumber(duty.grade) or 0,
        onDuty = (tonumber(duty.on_duty) or 0) == 1,
        accounts = accountSnapshot,
        metadata = {
            bio = profile.bio,
            emergencyContact = profile.emergency_contact,
            licenses = metadataJson.licenses or {},
            skipTutorial = metadataJson.skipTutorial == true,
        },
    }, nil
end

local function savePlayer(source)
    local player = PlayerCache[source]
    if not player then
        return true
    end

    local metadata = player.metadata or {}

    local ok, err = pcall(function()
        exports.oxmysql:executeSync([[
            INSERT INTO character_profiles (char_id, bio, pronouns, emergency_contact, licenses_json)
            VALUES (?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE
                bio = VALUES(bio),
                pronouns = VALUES(pronouns),
                emergency_contact = VALUES(emergency_contact),
                licenses_json = VALUES(licenses_json),
                updated_at = CURRENT_TIMESTAMP
        ]], {
            player.charId,
            metadata.bio,
            player.gender,
            metadata.emergencyContact,
            encodeJson({
                licenses = metadata.licenses or {},
                skipTutorial = metadata.skipTutorial == true,
            }),
        })

        exports.oxmysql:executeSync([[
            INSERT INTO job_duty (char_id, job_name, grade, on_duty, last_toggled_at)
            VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP)
            ON DUPLICATE KEY UPDATE
                grade = VALUES(grade),
                on_duty = VALUES(on_duty),
                last_toggled_at = CURRENT_TIMESTAMP,
                updated_at = CURRENT_TIMESTAMP
        ]], {
            player.charId,
            player.job or 'unemployed',
            tonumber(player.jobGrade) or 0,
            player.onDuty and 1 or 0,
        })

        for accountType, balance in pairs(player.accounts or {}) do
            exports.oxmysql:executeSync([[
                INSERT INTO accounts (char_id, account_type, balance)
                VALUES (?, ?, ?)
                ON DUPLICATE KEY UPDATE
                    balance = VALUES(balance),
                    updated_at = CURRENT_TIMESTAMP
            ]], { player.charId, accountType, tonumber(balance) or 0 })
        end
    end)

    if not ok then
        print(('^1[%s] Failed to save player %s (%s): %s^7'):format(RESOURCE_NAME, tostring(source), tostring(player.charId), tostring(err)))
        tryLog('PaLogging:LogError', {
            resource = RESOURCE_NAME,
            source = source,
            action = 'savePlayer',
            message = 'Failed to save player state',
            meta = { charId = player.charId, error = tostring(err) },
        })
        return false
    end

    player.lastSaveAt = os.time()
    return true
end

local function wipePlayer(source)
    PlayerCache[source] = nil
    PendingConnections[source] = nil
end

local function buildPlayer(source, snapshot)
    return {
        source = source,
        license = snapshot.license,
        charId = snapshot.charId,
        name = snapshot.name,
        dob = snapshot.dob,
        gender = snapshot.gender,
        job = snapshot.job,
        jobGrade = snapshot.jobGrade,
        onDuty = snapshot.onDuty,
        accounts = snapshot.accounts,
        metadata = snapshot.metadata,
        lastSaveAt = os.time(),
    }
end

local function ensureServerAuthorityGuards()
    local guardedEvents = {
        'pa:core:setMoney',
        'pa:core:addMoney',
        'pa:core:removeMoney',
        'pa:core:setJob',
        'pa:core:addItem',
        'pa:core:removeItem',
    }

    for _, eventName in ipairs(guardedEvents) do
        RegisterNetEvent(eventName, function()
            local source = source
            print(('^1[%s] Blocked unauthorized client authority event %s from source %s.^7'):format(RESOURCE_NAME, eventName, tostring(source)))
            tryLog('PaLogging:LogWarn', {
                resource = RESOURCE_NAME,
                source = source,
                action = eventName,
                message = 'Blocked client-side restricted state mutation attempt',
                meta = { event = eventName },
            })
            DropPlayer(source, 'Server-authoritative protection: client attempted restricted state mutation.')
        end)
    end
end

AddEventHandler('playerConnecting', function(playerName, setKickReason)
    local source = source
    local license = resolveLicense(source)

    if not license then
        setKickReason('Missing Rockstar license identifier. Please restart FiveM and reconnect.')
        CancelEvent()
        return
    end

    PendingConnections[source] = {
        license = license,
        name = playerName,
        connectedAt = os.time(),
    }
end)

AddEventHandler('playerDropped', function()
    local source = source
    savePlayer(source)
    wipePlayer(source)
end)

RegisterNetEvent('pa:core:requestCharacterList', function()
    local source = source
    local license = (PendingConnections[source] and PendingConnections[source].license) or resolveLicense(source)
    if not license then
        sendCharacterResult(source, false, 'Unable to resolve license for character list.', false)
        return
    end

    local characters = fetchCharactersForLicense(license)
    TriggerClientEvent('pa:ui:openCharacterUI', source, {
        message = 'Choose a character or create a new one.',
        characters = characters,
        spawns = getSpawnListForSource(source),
    })
end)

RegisterNetEvent('pa:core:createCharacter', function(payload)
    local source = source
    local license = (PendingConnections[source] and PendingConnections[source].license) or resolveLicense(source)
    if not license then
        sendCharacterResult(source, false, 'Unable to resolve license for character creation.', false)
        return
    end

    local sanitized, err = sanitizeCharacterPayload(payload)
    if not sanitized then
        sendCharacterResult(source, false, err, false)
        return
    end

    local existing = fetchCharactersForLicense(license)
    if #existing >= MAX_CHARACTERS_PER_LICENSE then
        sendCharacterResult(source, false, ('Character limit reached (%s).'):format(MAX_CHARACTERS_PER_LICENSE), false)
        return
    end

    local ok, insertErr = pcall(function()
        local insertId = exports.oxmysql:insertSync([[
            INSERT INTO characters (license, citizen_id, first_name, last_name, date_of_birth, active)
            VALUES (?, UUID(), ?, ?, ?, 1)
        ]], {
            license,
            sanitized.firstName,
            sanitized.lastName,
            sanitized.dob,
        })

        exports.oxmysql:executeSync([[
            INSERT INTO character_profiles (char_id, pronouns, licenses_json)
            VALUES (?, ?, ?)
            ON DUPLICATE KEY UPDATE
                pronouns = VALUES(pronouns),
                licenses_json = VALUES(licenses_json),
                updated_at = CURRENT_TIMESTAMP
        ]], {
            insertId,
            sanitized.gender,
            encodeJson({ licenses = {}, skipTutorial = sanitized.skipTutorial }),
        })

        exports.oxmysql:executeSync([[
            INSERT INTO job_duty (char_id, job_name, grade, on_duty, last_toggled_at)
            VALUES (?, 'unemployed', 0, 0, CURRENT_TIMESTAMP)
            ON DUPLICATE KEY UPDATE updated_at = CURRENT_TIMESTAMP
        ]], { insertId })

        exports.oxmysql:executeSync([[
            INSERT INTO accounts (char_id, account_type, balance)
            VALUES (?, 'cash', 500), (?, 'bank', 1500)
            ON DUPLICATE KEY UPDATE updated_at = CURRENT_TIMESTAMP
        ]], { insertId, insertId })
    end)

    if not ok then
        sendCharacterResult(source, false, 'Failed to create character. Try again.', false)
        tryLog('PaLogging:LogError', {
            resource = RESOURCE_NAME,
            source = source,
            action = 'createCharacter',
            message = 'Character creation failed.',
            meta = { error = tostring(insertErr) },
        })
        return
    end

    local refreshed = fetchCharactersForLicense(license)
    sendCharacterHydrate(source, refreshed, 'Character created successfully.')
    sendCharacterResult(source, true, 'Character created.', true)
end)

RegisterNetEvent('pa:core:deleteCharacter', function(payload)
    local source = source
    payload = type(payload) == 'table' and payload or {}
    local charId = tonumber(payload.charId)

    if payload.confirm ~= true then
        sendCharacterResult(source, false, 'Delete confirmation is required.', false)
        return
    end

    if not charId then
        sendCharacterResult(source, false, 'Invalid character id.', false)
        return
    end

    local license = (PendingConnections[source] and PendingConnections[source].license) or resolveLicense(source)
    if not license then
        sendCharacterResult(source, false, 'Unable to resolve license for deletion.', false)
        return
    end

    local owned = fetchSingle([[
        SELECT id FROM characters WHERE id = ? AND license = ? AND active = 1 LIMIT 1
    ]], { charId, license })

    if not owned then
        sendCharacterResult(source, false, 'Character not found for your account.', false)
        return
    end

    exports.oxmysql:executeSync('UPDATE characters SET active = 0 WHERE id = ? LIMIT 1', { charId })

    if PlayerCache[source] and PlayerCache[source].charId == charId then
        wipePlayer(source)
    end

    local refreshed = fetchCharactersForLicense(license)
    sendCharacterHydrate(source, refreshed, 'Character deleted successfully.')
    sendCharacterResult(source, true, 'Character deleted.', true)

    tryLog('PaLogging:LogAdmin', {
        resource = RESOURCE_NAME,
        source = source,
        action = 'delete_character',
        message = 'Character deleted by owner request.',
        actorLicense = license,
        meta = { charId = charId },
    })
end)

RegisterNetEvent('pa:core:selectCharacter', function(payload)
    local source = source
    local numericCharId = tonumber(type(payload) == 'table' and payload.charId or payload)

    if not numericCharId then
        DropPlayer(source, 'Invalid character selection payload.')
        return
    end

    local expectedLicense = (PendingConnections[source] and PendingConnections[source].license) or resolveLicense(source)
    if not expectedLicense then
        DropPlayer(source, 'Unable to resolve license for selected character.')
        return
    end

    local snapshot, err = fetchCharacterSnapshot(numericCharId)
    if not snapshot then
        DropPlayer(source, err or 'Character load failed.')
        return
    end

    if snapshot.license ~= expectedLicense then
        DropPlayer(source, 'Character ownership mismatch.')
        return
    end

    PlayerCache[source] = buildPlayer(source, snapshot)
    tryLog('PaLogging:LogInfo', {
        resource = RESOURCE_NAME,
        source = source,
        action = 'selectCharacter',
        message = 'Character selected and loaded',
        meta = { charId = snapshot.charId, job = snapshot.job },
    })

    TriggerClientEvent('pa:core:playerLoaded', source, {
        charId = snapshot.charId,
        name = snapshot.name,
        job = snapshot.job,
        jobGrade = snapshot.jobGrade,
        onDuty = snapshot.onDuty,
        skipTutorial = snapshot.metadata.skipTutorial == true,
    })

    sendCharacterHydrate(source, fetchCharactersForLicense(expectedLicense), 'Character loaded. Select your spawn point.')
end)

RegisterNetEvent('pa:core:selectSpawn', function(payload)
    local source = source
    payload = type(payload) == 'table' and payload or {}

    local player = PlayerCache[source]
    if not player then
        sendCharacterResult(source, false, 'Select a character before choosing a spawn.', false)
        return
    end

    local spawnId = tostring(payload.spawnId or '')
    local spawn = SPAWN_POINTS[spawnId]
    if not spawn then
        sendCharacterResult(source, false, 'Unknown spawn point selected.', false)
        return
    end

    if spawn.requiresJob and player.job ~= spawn.requiresJob then
        sendCharacterResult(source, false, 'You are not whitelisted for this spawn point.', false)
        tryLog('PaLogging:LogWarn', {
            resource = RESOURCE_NAME,
            source = source,
            action = 'spawn_whitelist_violation',
            message = 'Player attempted restricted spawn selection.',
            meta = { spawnId = spawnId, requiredJob = spawn.requiresJob, playerJob = player.job },
        })
        return
    end

    TriggerClientEvent('pa:core:spawnChosen', source, {
        id = spawn.id,
        label = spawn.label,
        coords = spawn.coords,
        skipTutorial = player.metadata and player.metadata.skipTutorial == true,
    })

    sendCharacterResult(source, true, ('Spawn selected: %s'):format(spawn.label), false)
end)

RegisterNetEvent('pa:core:logout', function()
    local source = source
    savePlayer(source)
    tryLog('PaLogging:LogInfo', {
        resource = RESOURCE_NAME,
        source = source,
        action = 'logout',
        message = 'Player logout completed',
        meta = { charId = PlayerCache[source] and PlayerCache[source].charId or nil },
    })
    wipePlayer(source)
    sendCharacterUI(source, 'Logged out. Choose another character.')
    TriggerClientEvent('pa:core:loggedOut', source)
end)

local PaCore = {}

function PaCore:GetPlayer(src)
    return deepCopy(PlayerCache[src])
end

function PaCore:GetCharId(src)
    local player = PlayerCache[src]
    return player and player.charId or nil
end

function PaCore:GetLicense(src)
    local player = PlayerCache[src]
    if player then
        return player.license
    end

    if PendingConnections[src] then
        return PendingConnections[src].license
    end

    return resolveLicense(src)
end

function PaCore:Kick(src, reason)
    DropPlayer(src, reason or 'Removed by server.')
end

exports('PaCore:GetPlayer', function(src)
    return PaCore:GetPlayer(src)
end)

exports('PaCore:GetCharId', function(src)
    return PaCore:GetCharId(src)
end)

exports('PaCore:GetLicense', function(src)
    return PaCore:GetLicense(src)
end)

exports('PaCore:Kick', function(src, reason)
    return PaCore:Kick(src, reason)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= RESOURCE_NAME then
        return
    end

    for src in pairs(PlayerCache) do
        savePlayer(src)
    end
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= RESOURCE_NAME then
        return
    end

    ensureServerAuthorityGuards()
    print(('^2[%s] Player service ready. Server-authoritative state enabled.^7'):format(RESOURCE_NAME))
end)
