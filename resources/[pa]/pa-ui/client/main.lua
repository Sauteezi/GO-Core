local uiOpen = false
local promptActive = false
local pendingPrompts = {}

local function setFocusForCurrentState()
    SetNuiFocus(uiOpen or promptActive, uiOpen or promptActive)
end

local function setUIState(state)
    uiOpen = state
    setFocusForCurrentState()
    SendNUIMessage({
        action = 'setVisible',
        visible = state,
    })
end

local function showToast(data)
    SendNUIMessage({
        action = 'showToast',
        payload = data,
    })
end

RegisterNetEvent('pa:ui:notify', function(payload)
    showToast(payload or {})
end)

RegisterNetEvent('pa:ui:openCharacterUI', function(payload)
    SendNUIMessage({
        action = 'hydrate',
        payload = payload or {},
    })
    setUIState(true)
end)

RegisterNetEvent('pa:ui:updateCharacterUI', function(payload)
    SendNUIMessage({
        action = 'hydrate',
        payload = payload or {},
    })
end)

RegisterNetEvent('pa:ui:characterActionResult', function(payload)
    local body = payload or {}
    SendNUIMessage({
        action = 'result',
        payload = body,
    })

    showToast({
        type = body.ok and 'success' or 'error',
        title = body.ok and 'Success' or 'Action failed',
        message = body.message or 'No details provided.',
        duration = 4500,
    })
end)

RegisterNetEvent('pa:core:spawnChosen', function(payload)
    if type(payload) ~= 'table' or type(payload.coords) ~= 'table' then
        return
    end

    local ped = PlayerPedId()
    SetEntityCoords(ped, payload.coords.x + 0.0, payload.coords.y + 0.0, payload.coords.z + 0.0, false, false, false, false)
    SetEntityHeading(ped, (payload.coords.w or 0.0) + 0.0)

    setUIState(false)
    showToast({
        type = 'success',
        title = 'Spawn selected',
        message = ('You spawned at %s.'):format(payload.label or 'selected location'),
        duration = 3000,
    })
end)

RegisterNUICallback('requestCharacters', function(_, cb)
    TriggerServerEvent('pa:core:requestCharacterList')
    cb({ ok = true })
end)

RegisterNUICallback('createCharacter', function(data, cb)
    TriggerServerEvent('pa:core:createCharacter', data)
    cb({ ok = true })
end)

RegisterNUICallback('deleteCharacter', function(data, cb)
    TriggerServerEvent('pa:core:deleteCharacter', data)
    cb({ ok = true })
end)

RegisterNUICallback('selectCharacter', function(data, cb)
    TriggerServerEvent('pa:core:selectCharacter', data and data.charId)
    cb({ ok = true })
end)

RegisterNUICallback('selectSpawn', function(data, cb)
    TriggerServerEvent('pa:core:selectSpawn', data)
    cb({ ok = true })
end)

RegisterNUICallback('promptResponse', function(data, cb)
    local key = data and data.key
    local resolver = key and pendingPrompts[key]

    if resolver then
        resolver({
            ok = data.ok == true,
            value = data.value,
        })
        pendingPrompts[key] = nil
    end

    promptActive = false
    setFocusForCurrentState()
    cb({ ok = true })
end)

RegisterNUICallback('close', function(_, cb)
    if uiOpen then
        setUIState(false)
    end
    cb({ ok = true })
end)

exports('PaUI:Notify', function(messageType, title, message, duration)
    showToast({
        type = messageType or 'info',
        title = title or 'Port Aurora',
        message = message or '',
        duration = tonumber(duration) or 4000,
    })
end)

exports('PaUI:Prompt', function(key, text)
    local promptKey = tostring(key or ('prompt-' .. GetGameTimer()))
    local promptText = tostring(text or 'Enter a value')

    local promiseObj = promise.new()
    pendingPrompts[promptKey] = function(result)
        promiseObj:resolve(result)
    end

    promptActive = true
    setFocusForCurrentState()

    SendNUIMessage({
        action = 'openPrompt',
        payload = {
            key = promptKey,
            text = promptText,
        },
    })

    local response = Citizen.Await(promiseObj)
    return response and response.ok == true, response and response.value or nil
end)

RegisterCommand('pa-character', function()
    TriggerServerEvent('pa:core:requestCharacterList')
end, false)

CreateThread(function()
    Wait(1500)
    TriggerServerEvent('pa:core:requestCharacterList')
end)
