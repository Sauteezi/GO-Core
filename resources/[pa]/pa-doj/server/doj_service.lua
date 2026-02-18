local RESOURCE_NAME = GetCurrentResourceName()

local DOJ_ROLES = {
    judge = true,
    prosecutor = true,
    public_defender = true,
}

local CASE_TEMPLATES = {
    arraignment = {
        title = 'Arraignment Review',
        summary = 'Review charges, rights acknowledgment, and preliminary bail recommendation.',
    },
    plea = {
        title = 'Plea Deal Discussion',
        summary = 'Prosecutor and defender negotiate plea terms for judge approval.',
    },
    trial = {
        title = 'Bench Trial (Short Form)',
        summary = 'Summarize evidence list, witness notes, and final ruling block.',
    },
}

local function toInt(value)
    local n = tonumber(value)
    if not n or n % 1 ~= 0 then
        return nil
    end
    return math.floor(n)
end

local function getLicense(src)
    local ok, license = pcall(function()
        return exports['pa-core']['PaCore:GetLicense'](src)
    end)
    return ok and license or nil
end

local function getCharId(src)
    local ok, charId = pcall(function()
        return exports['pa-core']['PaCore:GetCharId'](src)
    end)
    return ok and tonumber(charId) or nil
end

local function notify(src, messageType, title, message)
    TriggerClientEvent('pa:ui:notify', src, {
        type = messageType,
        title = title,
        message = message,
        duration = 5000,
    })
end

local function logJudicial(src, action, message, meta)
    if GetResourceState('pa-logging') ~= 'started' then
        return
    end

    pcall(function()
        exports['pa-logging']['PaLogging:LogAdmin']({
            resource = RESOURCE_NAME,
            source = src,
            actorLicense = getLicense(src),
            action = action,
            message = message,
            meta = meta,
        })
    end)
end

local function getRole(src)
    local license = getLicense(src)
    if not license then
        return nil
    end

    local rows = exports.oxmysql:querySync([[
        SELECT role_name
        FROM staff_roles
        WHERE license = ?
    ]], { license }) or {}

    for _, row in ipairs(rows) do
        local role = row.role_name
        if DOJ_ROLES[role] then
            return role
        end
    end

    return nil
end

local function requireRole(src, allowedRoles, failMessage)
    local role = getRole(src)
    if role and allowedRoles[role] then
        return true, role
    end

    notify(src, 'error', 'DOJ permission', failMessage or 'You are not whitelisted for this DOJ action.')
    logJudicial(src, 'doj_permission_denied', 'DOJ action denied due to whitelist role check.', {
        requiredRoles = allowedRoles,
        currentRole = role,
    })
    return false, role
end

local function nextWeeklySchedule(dayOfWeek, hour24)
    local targetDay = toInt(dayOfWeek) or 3
    local targetHour = toInt(hour24) or 20

    local now = os.time()
    local t = os.date('*t', now)

    local weekday = (t.wday + 5) % 7 + 1 -- convert to Monday=1
    local daysToAdd = targetDay - weekday
    if daysToAdd < 0 or (daysToAdd == 0 and t.hour >= targetHour) then
        daysToAdd = daysToAdd + 7
    end

    t.day = t.day + daysToAdd
    t.hour = targetHour
    t.min = 0
    t.sec = 0

    return os.time(t)
end

local function buildDocketCase(caseId)
    local cases = exports.oxmysql:querySync([[
        SELECT id, title, status, defendant_char_id, created_by_char_id, assigned_judge_char_id,
               scheduled_for, bail_amount, summary, created_at
        FROM doj_cases
        WHERE id = ?
        LIMIT 1
    ]], { caseId }) or {}

    local docketCase = cases[1]
    if not docketCase then
        return nil
    end

    local links = exports.oxmysql:querySync([[
        SELECT link_type, reference_id
        FROM doj_case_links
        WHERE case_id = ?
    ]], { caseId }) or {}

    local refs = {
        reportIds = {},
        citationIds = {},
        warrantIds = {},
        evidenceIds = {},
    }

    for _, link in ipairs(links) do
        if link.link_type == 'report' then
            refs.reportIds[#refs.reportIds + 1] = tonumber(link.reference_id)
        elseif link.link_type == 'citation' then
            refs.citationIds[#refs.citationIds + 1] = tonumber(link.reference_id)
        elseif link.link_type == 'warrant' then
            refs.warrantIds[#refs.warrantIds + 1] = tonumber(link.reference_id)
        elseif link.link_type == 'evidence' then
            refs.evidenceIds[#refs.evidenceIds + 1] = tonumber(link.reference_id)
        end
    end

    docketCase.references = refs
    return docketCase
end

local PaDOJ = {}

function PaDOJ:HasRole(src, role)
    local resolved = getRole(src)
    return resolved == role
end

function PaDOJ:HasAny(src, roles)
    local resolved = getRole(src)
    if not resolved then
        return false
    end

    for _, role in ipairs(roles or {}) do
        if resolved == role then
            return true
        end
    end

    return false
end

function PaDOJ:GetDocket(src)
    local ok = requireRole(src, { judge = true, prosecutor = true, public_defender = true }, 'DOJ docket is restricted to whitelisted legal roles.')
    if not ok then
        return false, 'Not permitted.'
    end

    local rows = exports.oxmysql:querySync([[
        SELECT id
        FROM doj_cases
        ORDER BY created_at DESC
        LIMIT 50
    ]], {}) or {}

    local docket = {}
    for _, row in ipairs(rows) do
        local c = buildDocketCase(tonumber(row.id))
        if c then
            docket[#docket + 1] = c
        end
    end

    return true, docket
end

function PaDOJ:CreateCase(src, payload)
    local ok, role = requireRole(src, { judge = true, prosecutor = true, public_defender = true }, 'Only DOJ legal roles can create a case.')
    if not ok then
        return false, 'Not permitted.'
    end

    payload = type(payload) == 'table' and payload or {}

    local title = tostring(payload.title or 'DOJ Case')
    local defendantCharId = toInt(payload.defendantCharId)
    local createdBy = getCharId(src)

    if not defendantCharId or not createdBy then
        return false, 'Invalid case participants.'
    end

    local summary = tostring(payload.summary or CASE_TEMPLATES.arraignment.summary)
    local scheduled = payload.scheduledFor and tonumber(payload.scheduledFor) or nextWeeklySchedule(payload.dayOfWeek, payload.hour24)

    local caseId = exports.oxmysql:insertSync([[
        INSERT INTO doj_cases (title, status, defendant_char_id, created_by_char_id, scheduled_for, summary)
        VALUES (?, 'draft', ?, ?, FROM_UNIXTIME(?), ?)
    ]], { title, defendantCharId, createdBy, scheduled, summary })

    local function addLinks(kind, ids)
        if type(ids) ~= 'table' then
            return
        end
        for _, id in ipairs(ids) do
            local refId = toInt(id)
            if refId then
                exports.oxmysql:executeSync([[
                    INSERT INTO doj_case_links (case_id, link_type, reference_id)
                    VALUES (?, ?, ?)
                ]], { caseId, kind, refId })
            end
        end
    end

    addLinks('report', payload.reportIds)
    addLinks('citation', payload.citationIds)
    addLinks('warrant', payload.warrantIds)
    addLinks('evidence', payload.evidenceIds)

    logJudicial(src, 'doj_case_created', 'DOJ case created.', {
        caseId = caseId,
        defendantCharId = defendantCharId,
        actorRole = role,
    })

    return true, buildDocketCase(caseId)
end

function PaDOJ:ScheduleCourt(src, caseId, dayOfWeek, hour24)
    local ok = requireRole(src, { judge = true }, 'Only judges can schedule court sessions.')
    if not ok then
        return false, 'Not permitted.'
    end

    local id = toInt(caseId)
    if not id then
        return false, 'Invalid case id.'
    end

    local scheduledAt = nextWeeklySchedule(dayOfWeek, hour24)

    exports.oxmysql:executeSync([[
        UPDATE doj_cases
        SET status = 'scheduled',
            scheduled_for = FROM_UNIXTIME(?),
            updated_at = CURRENT_TIMESTAMP
        WHERE id = ?
    ]], { scheduledAt, id })

    exports.oxmysql:executeSync([[
        INSERT INTO doj_court_sessions (case_id, scheduled_for, status)
        VALUES (?, FROM_UNIXTIME(?), 'scheduled')
    ]], { id, scheduledAt })

    logJudicial(src, 'doj_case_scheduled', 'Court session scheduled.', {
        caseId = id,
        scheduledUnix = scheduledAt,
    })

    return true, scheduledAt
end

function PaDOJ:ProposePlea(src, payload)
    local ok, role = requireRole(src, { prosecutor = true, public_defender = true }, 'Only prosecutor/public defender can propose plea deals.')
    if not ok then
        return false, 'Not permitted.'
    end

    payload = type(payload) == 'table' and payload or {}
    local caseId = toInt(payload.caseId)
    local actorCharId = getCharId(src)
    if not caseId or not actorCharId then
        return false, 'Invalid case/actor.'
    end

    local pleaText = tostring(payload.pleaText or CASE_TEMPLATES.plea.summary)
    local recommendedBail = math.max(0, toInt(payload.recommendedBail) or 0)

    local pleaId = exports.oxmysql:insertSync([[
        INSERT INTO doj_plea_deals (case_id, proposed_by_char_id, proposed_role, plea_text, recommended_bail, status)
        VALUES (?, ?, ?, ?, ?, 'proposed')
    ]], { caseId, actorCharId, role, pleaText, recommendedBail })

    logJudicial(src, 'doj_plea_proposed', 'Plea deal proposed.', {
        caseId = caseId,
        pleaId = pleaId,
        proposedRole = role,
    })

    return true, pleaId
end

function PaDOJ:ReviewPlea(src, pleaId, accept)
    local ok = requireRole(src, { judge = true }, 'Only judges can approve/reject plea deals.')
    if not ok then
        return false, 'Not permitted.'
    end

    local id = toInt(pleaId)
    if not id then
        return false, 'Invalid plea id.'
    end

    local status = accept and 'accepted' or 'rejected'
    exports.oxmysql:executeSync([[
        UPDATE doj_plea_deals
        SET status = ?, reviewed_at = CURRENT_TIMESTAMP
        WHERE id = ?
    ]], { status, id })

    logJudicial(src, 'doj_plea_reviewed', 'Plea deal reviewed by judge.', {
        pleaId = id,
        status = status,
    })

    return true
end

function PaDOJ:IssueWarrant(src, payload)
    local ok = requireRole(src, { judge = true }, 'Only judges can issue warrants.')
    if not ok then
        return false, 'Not permitted.'
    end

    payload = type(payload) == 'table' and payload or {}
    local targetCharId = toInt(payload.targetCharId)
    local judgeCharId = getCharId(src)
    local reason = tostring(payload.reason or 'Judicial warrant issued.')

    if not targetCharId or not judgeCharId then
        return false, 'Invalid warrant fields.'
    end

    local expiresAt = tonumber(payload.expiresUnix) or (os.time() + (48 * 3600))

    local warrantId = exports.oxmysql:insertSync([[
        INSERT INTO police_warrants (target_char_id, requested_by_char_id, reason, status, expires_at)
        VALUES (?, ?, ?, 'active', FROM_UNIXTIME(?))
    ]], { targetCharId, judgeCharId, reason, expiresAt })

    logJudicial(src, 'doj_warrant_issued', 'Judge issued warrant.', {
        warrantId = warrantId,
        targetCharId = targetCharId,
    })

    return true, warrantId
end

function PaDOJ:SetBail(src, caseId, amount)
    local ok = requireRole(src, { judge = true }, 'Only judges can set bail.')
    if not ok then
        return false, 'Not permitted.'
    end

    local id = toInt(caseId)
    local bail = math.max(0, toInt(amount) or -1)
    if not id or bail < 0 then
        return false, 'Invalid case or bail amount.'
    end

    exports.oxmysql:executeSync([[
        UPDATE doj_cases
        SET bail_amount = ?, updated_at = CURRENT_TIMESTAMP
        WHERE id = ?
    ]], { bail, id })

    logJudicial(src, 'doj_bail_set', 'Judge set bail on case.', {
        caseId = id,
        bailAmount = bail,
    })

    return true
end

RegisterNetEvent('pa:doj:requestDocket', function()
    local src = source
    local ok, payload = PaDOJ:GetDocket(src)
    TriggerClientEvent('pa:doj:docketData', src, { ok = ok, docket = ok and payload or nil, error = ok and nil or payload })
end)

RegisterNetEvent('pa:doj:createCase', function(payload)
    local src = source
    local ok, result = PaDOJ:CreateCase(src, payload)
    if not ok then
        notify(src, 'error', 'Case create failed', result or 'Could not create case.')
        return
    end

    notify(src, 'success', 'Case created', ('Case #%s added to docket.'):format(result.id))
    TriggerClientEvent('pa:doj:caseCreated', src, result)
end)

RegisterNetEvent('pa:doj:scheduleCourt', function(payload)
    local src = source
    payload = type(payload) == 'table' and payload or {}

    local ok, scheduled = PaDOJ:ScheduleCourt(src, payload.caseId, payload.dayOfWeek, payload.hour24)
    if not ok then
        notify(src, 'error', 'Scheduling failed', scheduled or 'Could not schedule court.')
        return
    end

    notify(src, 'success', 'Court scheduled', ('Session scheduled at unix %s.'):format(scheduled))
end)

RegisterNetEvent('pa:doj:proposePlea', function(payload)
    local src = source
    local ok, pleaId = PaDOJ:ProposePlea(src, payload)
    if not ok then
        notify(src, 'error', 'Plea failed', pleaId or 'Could not propose plea.')
        return
    end

    notify(src, 'success', 'Plea submitted', ('Plea #%s proposed.'):format(pleaId))
end)

RegisterNetEvent('pa:doj:reviewPlea', function(payload)
    local src = source
    payload = type(payload) == 'table' and payload or {}

    local ok, err = PaDOJ:ReviewPlea(src, payload.pleaId, payload.accept == true)
    if not ok then
        notify(src, 'error', 'Plea review failed', err or 'Could not review plea.')
        return
    end

    notify(src, 'success', 'Plea reviewed', 'Plea review recorded.')
end)

RegisterNetEvent('pa:doj:issueWarrant', function(payload)
    local src = source
    local ok, result = PaDOJ:IssueWarrant(src, payload)
    if not ok then
        notify(src, 'error', 'Warrant failed', result or 'Could not issue warrant.')
        return
    end

    notify(src, 'success', 'Warrant issued', ('Warrant #%s created.'):format(result))
end)

RegisterNetEvent('pa:doj:setBail', function(payload)
    local src = source
    payload = type(payload) == 'table' and payload or {}

    local ok, err = PaDOJ:SetBail(src, payload.caseId, payload.amount)
    if not ok then
        notify(src, 'error', 'Set bail failed', err or 'Could not set bail.')
        return
    end

    notify(src, 'success', 'Bail updated', 'Bail amount saved.')
end)

exports('PaDOJ:HasRole', function(src, role)
    return PaDOJ:HasRole(src, role)
end)

exports('PaDOJ:HasAny', function(src, roles)
    return PaDOJ:HasAny(src, roles)
end)

exports('PaDOJ:Require', function(src, roles, failMessage)
    local allowed = {}
    for _, role in ipairs(roles or {}) do
        allowed[role] = true
    end
    return requireRole(src, allowed, failMessage)
end)

exports('PaDOJ:GetDocket', function(src)
    return PaDOJ:GetDocket(src)
end)
