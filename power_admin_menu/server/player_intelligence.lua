PlayerIntel = { Sessions = {}, ConnectStarted = {}, ConnectIdentifiers = {} }

local function cleanString(v, max)
    if type(v) ~= 'string' then return nil end
    v = PAM.Trim(v)
    if v == '' or #v > (max or 250) then return nil end
    return v
end
local function onlineTarget(src)
    return PAM.IsInteger(tonumber(src)) and tonumber(src) > 0 and GetPlayerName(tonumber(src)) ~= nil
end
local function identifierList(src)
    local ids = {}
    for _, value in ipairs(GetPlayerIdentifiers(src)) do
        if value:sub(1,8) == 'license:' or value:sub(1,9) == 'license2:' or value:sub(1,6) == 'fivem:' or value:sub(1,8) == 'discord:' or value:sub(1,6) == 'steam:' then ids[#ids + 1] = value end
    end
    local char = Framework.GetCharacterId(src)
    if char and char ~= '' then ids[#ids + 1] = ('character:%s'):format(char) end
    return ids
end
local function primaryIdentifier(src)
    local ids = identifierList(src)
    for _, id in ipairs(ids) do if id:sub(1, 8) == 'license:' then return id end end
    return ids[1] or ('serverid:%s'):format(src)
end
local function jsonDecode(v)
    if type(v) ~= 'string' then return v end
    local ok, result = pcall(json.decode, v)
    return ok and result or {}
end
local function targetSummary(target)
    target = tonumber(target)
    if not onlineTarget(target) then return nil end
    local data = {
        id = target,
        name = Framework.GetCharacterName(target) or GetPlayerName(target),
        playerName = GetPlayerName(target),
        job = Framework.GetJob(target) or 'Unknown',
        ping = GetPlayerPing(target),
        framework = Framework.Type
    }
    return data
end

function PlayerIntel.ListPlayers()
    local out = {}
    for _, raw in ipairs(GetPlayers()) do
        local id = tonumber(raw)
        local row = targetSummary(id)
        if row then out[#out + 1] = row end
    end
    table.sort(out, function(a,b) return a.id < b.id end)
    return out
end

function PlayerIntel.GetDossier(src, target)
    target = tonumber(target)
    if not onlineTarget(target) then return nil, 'Player is no longer online.' end
    local base = targetSummary(target)
    local identifier = Framework.GetCharacterId(target) or primaryIdentifier(target)
    if Config.PlayerIntelligence.ExposeIdentifiers and Permissions.Has(src, 'players.identifiers') then base.characterId = Framework.GetCharacterId(target) end
    base.connection = { connectedAt = PlayerIntel.ConnectStarted[target], playtimeSeconds = PlayerIntel.ConnectStarted[target] and (os.time() - PlayerIntel.ConnectStarted[target]) or nil }
    if Config.PlayerIntelligence.ExposeIdentifiers and Permissions.Has(src, 'players.identifiers') then base.identifiers = GetPlayerIdentifiers(target) end
    base.inventory = nil
    if Permissions.Has(src, 'players.inventory') then
        local inv, err = PlayerIntel.GetInventory(target)
        base.inventory = inv
        base.inventoryStatus = err or 'available'
    else base.inventoryStatus = 'permission_required' end
    if Permissions.Has(src, 'players.money.view') then base.money = Framework.GetMoney(target) end
    if Permissions.Has(src, 'players.history') and Database.Ready then
        base.activity = MySQL.query.await('SELECT id, event_type, details, created_at FROM pam_player_activity WHERE player_identifier = ? ORDER BY id DESC LIMIT 50', { identifier }) or {}
        for _, event in ipairs(base.activity) do event.details = jsonDecode(event.details) end
        base.warnings = MySQL.query.await('SELECT id, reason, staff_name, created_at FROM pam_warnings WHERE player_identifier = ? ORDER BY id DESC LIMIT 25', { identifier }) or {}
        base.bans = MySQL.query.await('SELECT id, reason, staff_name, created_at, expires_at, active FROM pam_bans WHERE player_identifier = ? ORDER BY id DESC LIMIT 25', { identifier }) or {}
        if Permissions.Has(src, 'players.money.view') then
            base.transactions = MySQL.query.await('SELECT id, account, amount, reason, staff_name, status, created_at FROM pam_money_transactions WHERE player_identifier = ? ORDER BY id DESC LIMIT 25', { identifier }) or {}
        end
    else base.historyStatus = 'History permission required or database unavailable.' end
    if Permissions.Has(src, 'players.notes.view') and Database.Ready then
        base.notes = MySQL.query.await('SELECT id, staff_name, note, created_at FROM pam_staff_notes WHERE player_identifier = ? ORDER BY id DESC LIMIT 50', { identifier }) or {}
    else base.notesStatus = 'Notes permission required or database unavailable.' end
    if Config.PlayerIntelligence.OwnedVehicles.Enabled then
        base.vehicles = PlayerIntel.GetOwnedVehicles(target)
        base.vehiclesStatus = base.vehicles and 'available' or 'integration_unavailable'
    else
        base.vehicles = nil
        base.vehiclesStatus = 'not_configured'
    end
    return base
end

function PlayerIntel.GetOwnedVehicles(target)
    if not Database.Ready then return nil end
    local cfg = Config.PlayerIntelligence.OwnedVehicles or {}
    local tableName, ownerCol, plateCol, vehicleCol = cfg.Table, cfg.OwnerColumn, cfg.PlateColumn, cfg.VehicleColumn
    local function safeIdentifier(value) return type(value) == 'string' and value:match('^[%w_]+$') ~= nil end
    if not safeIdentifier(tableName) or not safeIdentifier(ownerCol) or not safeIdentifier(plateCol) or not safeIdentifier(vehicleCol) then return nil end
    local owner = Framework.GetCharacterId(target)
    if not owner then return nil end
    local sql = ('SELECT `%s` AS plate, `%s` AS vehicle FROM `%s` WHERE `%s` = ? LIMIT 100'):format(plateCol, vehicleCol, tableName, ownerCol)
    local ok, rows = pcall(function() return MySQL.query.await(sql, { owner }) end)
    if ok and type(rows) == 'table' then return rows end
    return nil
end

function PlayerIntel.GetInventory(target)
    if not PAMInventory then return nil, 'integration_unavailable' end
    return PAMInventory.GetPlayerItems(target)
end

function PlayerIntel.RecordActivity(target, eventType, details)
    if not Database.Ready or not Config.PlayerIntelligence.TrackResourceActions then return end
    if not onlineTarget(target) then return end
    local identifier = Framework.GetCharacterId(target) or primaryIdentifier(target)
    pcall(function()
        MySQL.insert.await('INSERT INTO pam_player_activity (player_identifier, event_type, details) VALUES (?, ?, ?)', {
            identifier, eventType, json.encode(details or {})
        })
    end)
end

local function addWarning(src, target, reason)
    local ident = Framework.GetCharacterId(target) or primaryIdentifier(target)
    MySQL.insert.await('INSERT INTO pam_warnings (player_identifier, player_name, staff_identifier, staff_name, reason) VALUES (?, ?, ?, ?, ?)', {
        ident, Framework.GetCharacterName(target), Framework.GetIdentifier(src) or primaryIdentifier(src), GetPlayerName(src), reason
    })
end
local function applyBan(src, target, reason, days)
    local ident = Framework.GetCharacterId(target) or primaryIdentifier(target)
    local expires = nil
    if days > 0 then expires = os.date('!%Y-%m-%d %H:%M:%S', os.time() + days * 86400) end
    local createdId = nil
    local ok, err = pcall(function()
        createdId = MySQL.insert.await('INSERT INTO pam_bans (player_identifier, player_name, reason, staff_identifier, staff_name, expires_at, active) VALUES (?, ?, ?, ?, ?, ?, 1)', {
            ident, Framework.GetCharacterName(target), reason, Framework.GetIdentifier(src) or primaryIdentifier(src), GetPlayerName(src), expires
        })
        if not createdId then error('Ban record insert returned no ID.') end
        for _, value in ipairs(identifierList(target)) do
            MySQL.insert.await('INSERT IGNORE INTO pam_ban_identifiers (ban_id, identifier) VALUES (?, ?)', { createdId, value })
        end
        MySQL.insert.await('INSERT IGNORE INTO pam_ban_identifiers (ban_id, identifier) VALUES (?, ?)', { createdId, ident })
    end)
    if not ok then
        if createdId then pcall(function() MySQL.update.await('UPDATE pam_bans SET active = 0 WHERE id = ?', { createdId }) end) end
        print(('^1[PAM] Ban persistence failed: %s^7'):format(tostring(err)))
        return false, 'Could not safely persist ban identifiers; player was not disconnected.'
    end
    Audit.Record(src, 'player.ban', target, { banId = createdId, reason = reason, days = days }, true)
    PlayerIntel.RecordActivity(target, 'moderation.ban', { banId = createdId, reason = reason, days = days, by = GetPlayerName(src) })
    DropPlayer(target, ('Banned: %s'):format(reason))
    return true
end

function PlayerIntel.Handle(src, payload)
    if not Config.PlayerIntelligence.Enabled then return nil end
    local action = payload.action
    local databaseActions = { ['player.money.adjust'] = true, ['player.note.add'] = true, ['player.warn'] = true, ['player.ban'] = true, ['player.unban'] = true, ['bans.search'] = true }
    if databaseActions[action] and not Database.Ready then return false, 'Player Intelligence database is unavailable.' end
    if action == 'players.list' then
        if not Permissions.Has(src, 'players.view') then Audit.Record(src, 'unauthorized.' .. action, nil, {}, false); return false, 'Permission denied.' end
        TriggerClientEvent('pam:client:playerList', src, PlayerIntel.ListPlayers())
        return true, 'Player list updated.'
    elseif action == 'player.dossier' then
        if not Permissions.Has(src, 'players.dossier') then Audit.Record(src, 'unauthorized.' .. action, payload.target, {}, false); return false, 'Permission denied.' end
        if not Security.ValidTarget(src, payload.target) then return false, 'Invalid target.' end
        local dossier, err = PlayerIntel.GetDossier(src, payload.target)
        if not dossier then return false, err end
        TriggerClientEvent('pam:client:dossier', src, dossier)
        return true, 'Player dossier loaded.'
    elseif action == 'player.money.adjust' then
        if not Permissions.Has(src, 'players.money.modify') then Audit.Record(src, 'unauthorized.' .. action, payload.target, {}, false); return false, 'Permission denied.' end
        if not Security.ValidTarget(src, payload.target) then return false, 'Invalid target.' end
        local account = payload.account
        if account ~= 'cash' and account ~= 'bank' then return false, 'Invalid account.' end
        local amount = tonumber(payload.amount)
        if not amount or amount ~= math.floor(amount) or amount == 0 or math.abs(amount) > Config.PlayerIntelligence.MaxMoneyAdjustment then return false, 'Invalid amount.' end
        local okReason, reason = Security.ValidReason(payload.reason, true)
        if not okReason then return false, 'A valid reason is required.' end
        local current = Framework.GetMoney(payload.target)
        if not current or type(current[account]) ~= 'number' or (current[account] + amount) < 0 then return false, 'Account balance is unavailable or the adjustment would make it negative.' end
        local ident = Framework.GetCharacterId(payload.target) or primaryIdentifier(payload.target)
        local txOk, transactionId = pcall(function()
            return MySQL.insert.await("INSERT INTO pam_money_transactions (player_identifier, player_name, staff_identifier, staff_name, account, amount, reason, status) VALUES (?, ?, ?, ?, ?, ?, ?, 'pending')", {
                ident, Framework.GetCharacterName(payload.target), Framework.GetIdentifier(src) or primaryIdentifier(src), GetPlayerName(src), account, amount, reason
            })
        end)
        if not txOk or not transactionId then return false, 'Could not create transaction record; balance was not changed.' end
        local success, err = Framework.AdjustMoney(payload.target, account, amount, ('Power Admin: %s'):format(reason))
        if not success then
            MySQL.update.await("UPDATE pam_money_transactions SET status = 'failed' WHERE id = ?", { transactionId })
            Audit.Record(src, 'player.money.adjust', payload.target, { account = account, amount = amount, reason = reason, error = err }, false)
            return false, err or 'Money adjustment failed.'
        end
        local statusOk = pcall(function() MySQL.update.await("UPDATE pam_money_transactions SET status = 'success' WHERE id = ?", { transactionId }) end)
        Audit.Record(src, 'player.money.adjust', payload.target, { account = account, amount = amount, reason = reason, transactionId = transactionId, transactionStatusUpdated = statusOk }, true)
        PlayerIntel.RecordActivity(payload.target, 'money.adjusted', { account = account, amount = amount, by = GetPlayerName(src) })
        return true, 'Money adjustment completed.'
    elseif action == 'player.note.add' then
        if not Permissions.Has(src, 'players.notes.add') then Audit.Record(src, 'unauthorized.' .. action, payload.target, {}, false); return false, 'Permission denied.' end
        if not Security.ValidTarget(src, payload.target) then return false, 'Invalid target.' end
        local note = cleanString(payload.note, 1000)
        if not note then return false, 'Enter a note (maximum 1000 characters).' end
        local ident = Framework.GetCharacterId(payload.target) or primaryIdentifier(payload.target)
        MySQL.insert.await('INSERT INTO pam_staff_notes (player_identifier, staff_identifier, staff_name, note) VALUES (?, ?, ?, ?)', {
            ident, Framework.GetIdentifier(src) or primaryIdentifier(src), GetPlayerName(src), note
        })
        Audit.Record(src, 'player.note.add', payload.target, { note = note }, true)
        PlayerIntel.RecordActivity(payload.target, 'staff_note.added', { by = GetPlayerName(src) })
        return true, 'Staff note saved.'
    elseif action == 'player.warn' then
        if not Permissions.Has(src, 'players.warn') then Audit.Record(src, 'unauthorized.' .. action, payload.target, {}, false); return false, 'Permission denied.' end
        if not Security.ValidTarget(src, payload.target) then return false, 'Invalid target.' end
        local okReason, reason = Security.ValidReason(payload.reason, true)
        if not okReason then return false, 'A valid reason is required.' end
        addWarning(src, payload.target, reason)
        Audit.Record(src, 'player.warn', payload.target, { reason = reason }, true)
        PlayerIntel.RecordActivity(payload.target, 'moderation.warning', { reason = reason, by = GetPlayerName(src) })
        return true, 'Warning recorded.'
    elseif action == 'player.ban' then
        if not Permissions.Has(src, 'players.ban') then Audit.Record(src, 'unauthorized.' .. action, payload.target, {}, false); return false, 'Permission denied.' end
        if not Security.ValidTarget(src, payload.target) then return false, 'Invalid target.' end
        local okReason, reason = Security.ValidReason(payload.reason, true)
        local days = tonumber(payload.days or 0)
        if not okReason or not days or days ~= math.floor(days) or days < 0 or days > Config.PlayerIntelligence.MaxBanDays then return false, 'Invalid ban reason or duration.' end
        local banOk, banError = applyBan(src, payload.target, reason, days)
        if not banOk then return false, banError or 'Ban could not be safely persisted.' end
        return true, 'Ban recorded and player disconnected.'
    elseif action == 'bans.search' then
        if not Permissions.Has(src, 'players.unban') then Audit.Record(src, 'unauthorized.' .. action, nil, {}, false); return false, 'Permission denied.' end
        local rows = MySQL.query.await('SELECT id, player_name, reason, staff_name, created_at, expires_at FROM pam_bans WHERE active = 1 AND (expires_at IS NULL OR expires_at > UTC_TIMESTAMP()) ORDER BY id DESC LIMIT 100') or {}
        TriggerClientEvent('pam:client:banList', src, rows)
        return true, 'Active bans loaded.'
    elseif action == 'player.unban' then
        if not Permissions.Has(src, 'players.unban') then Audit.Record(src, 'unauthorized.' .. action, payload.target, {}, false); return false, 'Permission denied.' end
        local banId = tonumber(payload.banId)
        if not banId or banId < 1 or banId ~= math.floor(banId) then return false, 'Invalid ban ID.' end
        local changed = MySQL.update.await('UPDATE pam_bans SET active = 0, revoked_at = UTC_TIMESTAMP(), revoked_by = ? WHERE id = ? AND active = 1', { Framework.GetIdentifier(src) or primaryIdentifier(src), banId })
        if changed < 1 then return false, 'Active ban not found.' end
        Audit.Record(src, 'player.unban', nil, { banId = banId }, true)
        return true, 'Ban revoked.'
    elseif action == 'player.spectate.start' then
        if not Permissions.Has(src, 'players.spectate') then Audit.Record(src, 'unauthorized.' .. action, payload.target, {}, false); return false, 'Permission denied.' end
        if not Security.ValidTarget(src, payload.target) then return false, 'Invalid target.' end
        PlayerIntel.Sessions[src] = tonumber(payload.target)
        local targetPed = GetPlayerPed(tonumber(payload.target))
        local targetCoords = targetPed and targetPed ~= 0 and GetEntityCoords(targetPed) or nil
        local coords = targetCoords and { x = targetCoords.x, y = targetCoords.y, z = targetCoords.z } or nil
        TriggerClientEvent(PAM.Events.SpectateStart, src, tonumber(payload.target), coords)
        Audit.Record(src, 'player.spectate.start', payload.target, {}, true)
        return true, 'Spectate started.'
    elseif action == 'player.spectate.stop' then
        if not Permissions.Has(src, 'players.spectate') and not PlayerIntel.Sessions[src] then Audit.Record(src, 'unauthorized.' .. action, payload.target, {}, false); return false, 'Permission denied.' end
        PlayerIntel.Sessions[src] = nil
        TriggerClientEvent(PAM.Events.SpectateStop, src)
        return true, 'Spectate stopped.'
    end
    return nil
end

local function recordActivityIdentifier(identifier, eventType, details)
    if not Database.Ready or not identifier then return end
    pcall(function()
        MySQL.insert.await('INSERT INTO pam_player_activity (player_identifier, event_type, details) VALUES (?, ?, ?)', {
            identifier, eventType, json.encode(details or {})
        })
    end)
end

AddEventHandler('playerJoining', function()
    local src = source
    PlayerIntel.ConnectStarted[src] = os.time()
    SetTimeout(2000, function()
        if GetPlayerName(src) then
            PlayerIntel.ConnectIdentifiers[src] = Framework.GetCharacterId(src) or primaryIdentifier(src)
            if Config.PlayerIntelligence.TrackConnections then
                recordActivityIdentifier(PlayerIntel.ConnectIdentifiers[src], 'connection.joined', { name = GetPlayerName(src) })
            end
        end
    end)
end)

AddEventHandler('playerDropped', function(reason)
    local src = source
    local identifier = PlayerIntel.ConnectIdentifiers[src] or Framework.GetCharacterId(src) or primaryIdentifier(src)
    if Config.PlayerIntelligence.TrackConnections then
        recordActivityIdentifier(identifier, 'connection.left', {
            reason = tostring(reason or ''),
            sessionSeconds = PlayerIntel.ConnectStarted[src] and (os.time() - PlayerIntel.ConnectStarted[src]) or nil
        })
    end
    PlayerIntel.ConnectStarted[src] = nil
    PlayerIntel.ConnectIdentifiers[src] = nil
    PlayerIntel.Sessions[src] = nil
    for admin, target in pairs(PlayerIntel.Sessions) do
        if target == src then
            PlayerIntel.Sessions[admin] = nil
            TriggerClientEvent(PAM.Events.SpectateStop, admin)
        end
    end
end)

AddEventHandler('playerConnecting', function(playerName, setKickReason, deferrals)
    local src = source
    if not Database.Ready then return end
    deferrals.defer(); Wait(0); deferrals.update('Checking Power Admin Menu moderation records...')
    local ids = GetPlayerIdentifiers(src)
    pcall(function() MySQL.update.await('UPDATE pam_bans SET active = 0 WHERE active = 1 AND expires_at IS NOT NULL AND expires_at <= UTC_TIMESTAMP()') end)
    local placeholders, params = {}, {}
    for _, id in ipairs(ids) do
        placeholders[#placeholders + 1] = '?'; params[#params + 1] = id
    end
    if #params == 0 then deferrals.done(); return end
    local query = ('SELECT b.id, b.reason, b.expires_at FROM pam_bans b INNER JOIN pam_ban_identifiers i ON i.ban_id = b.id WHERE b.active = 1 AND i.identifier IN (%s) AND (b.expires_at IS NULL OR b.expires_at > UTC_TIMESTAMP()) ORDER BY b.id DESC LIMIT 1'):format(table.concat(placeholders, ','))
    local ok, ban = pcall(function() return MySQL.single.await(query, params) end)
    if not ok then
        print(('^1[PAM] Ban lookup failed during connection for %s: %s^7'):format(playerName, tostring(ban)))
        deferrals.done('Moderation database check failed. Please reconnect shortly.')
    elseif ban then
        deferrals.done(('You are banned from this server. Ban #%s | Reason: %s | Expires: %s'):format(ban.id, ban.reason, ban.expires_at or 'Permanent'))
    else deferrals.done() end
end)

