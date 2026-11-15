Actions = {}

local function notifyResult(src, requestId, success, message, action)
    TriggerClientEvent(PAM.Events.ActionResult, src, {
        requestId = requestId,
        success = success,
        message = message,
        action = action
    })
end

local function requirePermission(src, permission)
    if not Permissions.Has(src, permission) then
        Audit.Record(src, 'unauthorized.' .. permission, nil, {}, false)
        return false
    end
    return true
end

function Actions.Execute(src, payload)
    if type(payload) ~= 'table' then return false, 'Invalid request.' end
    local action = PAM.SafeString(payload.action, 80)
    local requestId = PAM.SafeString(payload.requestId, 80) or ''
    if not action then return false, 'Invalid action.' end
    payload.action = action

    if Catalog then
        local catalogHandled, catalogOk, catalogMessage = Catalog.Handle(src, payload)
        if catalogHandled ~= nil then return catalogOk, catalogMessage end
    end

    if PlayerIntel then
        local callOk, handled, intelMessage = pcall(PlayerIntel.Handle, src, payload)
        if not callOk then
            print(('^1[PAM] Player Intelligence action %s failed: %s^7'):format(action, tostring(handled)))
            return false, 'Player Intelligence operation failed. Check server logs and database schema.'
        end
        if handled ~= nil then return handled, intelMessage end
    end

    if action == 'players.refresh' then
        if not requirePermission(src, 'players.view') then return false, 'Permission denied.' end
        TriggerClientEvent('pam:client:playerList', src, Server.BuildPlayers())
        return true, 'Connected player list refreshed.'
    elseif action == 'player.freeze' then
        if not requirePermission(src, 'players.freeze') then return false, 'Permission denied.' end
        if not Security.ValidTarget(src, payload.target) then return false, 'Invalid target.' end
        local reasonOk, reason = Security.ValidReason(payload.reason, false)
        if not reasonOk then return false, 'Invalid reason.' end
        TriggerClientEvent(PAM.Events.FreezeTarget, payload.target, payload.value == true)
        Audit.Record(src, 'player.freeze', payload.target, { frozen = payload.value == true, reason = reason }, true)
        if PlayerIntel then PlayerIntel.RecordActivity(payload.target, 'admin.freeze', { by = GetPlayerName(src), frozen = payload.value == true }) end
        return true, payload.value == true and 'Player frozen.' or 'Player unfrozen.'
    elseif action == 'player.heal' then
        if not requirePermission(src, 'players.heal') then return false, 'Permission denied.' end
        if not Security.ValidTarget(src, payload.target) then return false, 'Invalid target.' end
        TriggerClientEvent(PAM.Events.HealTarget, payload.target)
        Audit.Record(src, 'player.heal', payload.target, {}, true)
        if PlayerIntel then PlayerIntel.RecordActivity(payload.target, 'admin.heal', { by = GetPlayerName(src) }) end
        return true, 'Player healed.'
    elseif action == 'player.teleportTo' then
        if not requirePermission(src, 'players.teleport') then return false, 'Permission denied.' end
        if not Security.ValidTarget(src, payload.target) then return false, 'Invalid target.' end
        TriggerClientEvent(PAM.Events.TeleportTarget, src, payload.target)
        Audit.Record(src, 'player.teleportTo', payload.target, {}, true)
        if PlayerIntel then PlayerIntel.RecordActivity(src, 'admin.teleport_to_player', { target = payload.target }) end
        return true, 'Teleport requested.'
    elseif action == 'player.bring' then
        if not requirePermission(src, 'players.bring') then return false, 'Permission denied.' end
        if not Security.ValidTarget(src, payload.target) then return false, 'Invalid target.' end
        TriggerClientEvent(PAM.Events.BringTarget, payload.target, src)
        Audit.Record(src, 'player.bring', payload.target, {}, true)
        if PlayerIntel then PlayerIntel.RecordActivity(payload.target, 'admin.brought_by_staff', { by = GetPlayerName(src) }) end
        return true, 'Bring requested.'
    elseif action == 'player.kick' then
        if not requirePermission(src, 'players.kick') then return false, 'Permission denied.' end
        if not Security.ValidTarget(src, payload.target) then return false, 'Invalid target.' end
        local ok, reason = Security.ValidReason(payload.reason, Config.Security.RequireReasonForSensitiveActions)
        if not ok then return false, 'A valid reason is required.' end
        Audit.Record(src, 'player.kick', payload.target, { reason = reason }, true)
        if PlayerIntel then PlayerIntel.RecordActivity(payload.target, 'moderation.kick', { reason = reason, by = GetPlayerName(src) }) end
        DropPlayer(payload.target, ('Kicked by staff: %s'):format(reason ~= '' and reason or 'No reason supplied'))
        return true, 'Player kicked.'
    elseif action == 'world.weather' then
        if not requirePermission(src, 'world.weather') then return false, 'Permission denied.' end
        local weather = type(payload.weather) == 'string' and string.upper(payload.weather) or ''
        local allowed = false
        for _, value in ipairs(Config.AllowedWeather) do if value == weather then allowed = true break end end
        if not allowed then return false, 'Weather type is not allowed.' end
        TriggerClientEvent(PAM.Events.SetWeather, -1, weather)
        Audit.Record(src, 'world.weather', nil, { weather = weather }, true)
        return true, 'Weather updated.'
    elseif action == 'world.time' then
        if not requirePermission(src, 'world.time') then return false, 'Permission denied.' end
        local hour, minute = tonumber(payload.hour), tonumber(payload.minute)
        if not hour or not minute or hour % 1 ~= 0 or minute % 1 ~= 0 or hour < 0 or hour > 23 or minute < 0 or minute > 59 then
            return false, 'Invalid time.'
        end
        TriggerClientEvent(PAM.Events.SetTime, -1, hour, minute)
        Audit.Record(src, 'world.time', nil, { hour = hour, minute = minute }, true)
        return true, 'World time updated.'
    end
    return false, 'Unknown or unavailable action.'
end

RegisterNetEvent(PAM.Events.ActionRequest, function(payload)
    local src = source
    if Config.Database.RequireDatabase and not Database.Ready then
        TriggerClientEvent(PAM.Events.ActionResult, src, { success = false, message = 'Database unavailable. Administrative actions are temporarily disabled.' })
        return
    end
    if not Security.AllowRequest(src) then
        Audit.Record(src, 'security.rate_limit', nil, {}, false)
        return
    end
    local requestId = type(payload) == 'table' and PAM.SafeString(payload.requestId, 80) or nil
    if not Security.ClaimRequestId(src, requestId) then
        Audit.Record(src, 'security.replayed_or_missing_request_id', nil, {}, false)
        TriggerClientEvent(PAM.Events.ActionResult, src, { success = false, message = 'Invalid or repeated request. Please try again.' })
        return
    end
    local ok, message = Actions.Execute(src, payload)
    notifyResult(src, requestId, ok, message, type(payload) == 'table' and payload.action or nil)
end)
