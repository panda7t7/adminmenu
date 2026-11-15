Server = {}

function Server.BuildPlayers()
    if PlayerIntel then return PlayerIntel.ListPlayers() end
    local players = {}
    for _, rawId in ipairs(GetPlayers()) do
        local id = tonumber(rawId)
        players[#players + 1] = {
            id = id,
            name = Framework.GetCharacterName(id) or GetPlayerName(id) or ('Player %s'):format(id),
            ping = GetPlayerPing(id),
            job = Framework.GetJob(id) or 'Unknown',
        }
    end
    table.sort(players, function(a, b) return a.id < b.id end)
    return players
end

function Server.BuildBootstrap(src)
    local role = Permissions.GetRole(src)
    local players = Permissions.Has(src, 'players.view') and Server.BuildPlayers() or {}
    return {
        product = Config.DisplayName,
        selfId = src,
        version = PAM.Version,
        framework = Framework.Type,
        inventoryProvider = PAMInventory and PAMInventory.Provider() or 'unknown',
        canCreateItems = PAMInventory and PAMInventory.CanRegisterItem() or false,
        role = role and (Config.Roles[role].label or role) or 'Staff',
        playerCount = #GetPlayers(),
        maxPlayers = GetConvarInt('sv_maxclients', 48),
        players = players,
        permissions = Permissions.GetClientPermissions(src),
        aiEnabled = Config.AI.Enabled,
        phase = 2,
        playerPageSize = Config.PlayerIntelligence.PageSize or 25
    }
end

RegisterNetEvent(PAM.Events.OpenRequest, function()
    local src = source
    if not Security.AllowRequest(src) then return end
    if (Config.Database.RequireDatabase and not Database.Ready) or not Permissions.IsStaff(src) or not Permissions.Has(src, 'dashboard.view') then
        Audit.Record(src, 'menu.open.denied', nil, {}, false)
        TriggerClientEvent(PAM.Events.ActionResult, src, { success = false, message = 'You do not have permission to use Power Admin Menu.' })
        return
    end
    TriggerClientEvent(PAM.Events.Bootstrap, src, Server.BuildBootstrap(src))
end)

CreateThread(function()
    Wait(500)
    Framework.Initialize()
    Database.Initialize()
    local inventoryProvider = PAMInventory and PAMInventory.Provider() or 'unavailable'
    print(('^2[PAM] Integration providers: framework=%s inventory=%s^7'):format(Framework.Type or 'unknown', inventoryProvider))
    if Framework.Type == 'qbox' and inventoryProvider == 'disabled' then
        print('^3[PAM] Qbox detected but no inventory provider was found. Configure Config.Integrations.Inventory and its resource name.^7')
    end
    if Config.Database.RequireDatabase and not Database.Ready then
        print('^1[PAM] Database is required but unavailable. Administrative actions are disabled until the database is ready.^7')
    end
end)

AddEventHandler('onResourceStart', function(resource)
    if resource == GetCurrentResourceName() then
        print(('^5[PAM] %s v%s started.^7'):format(Config.DisplayName, PAM.Version))
    end
end)
