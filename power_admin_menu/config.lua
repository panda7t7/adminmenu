Config = {}
Config.Debug = false
Config.ResourceName = 'power_admin_menu'
Config.DisplayName = 'POWER ADMIN MENU'
Config.Framework = 'auto' -- auto | esx | qbcore | qbox | standalone | custom
Config.OpenCommand = 'poweradmin'
Config.OpenKey = 'F10'
Config.AllowCommand = true
Config.AllowKeybind = true
Config.Database = { Enabled = true, RequireDatabase = true, AuditRetentionDays = 90 }
Config.AI = { Enabled = false, Provider = 'external' }
Config.Security = {
    RateLimitWindowMs = 5000, RateLimitMaxRequests = 12,
    RequireReasonForSensitiveActions = true, MaxReasonLength = 250,
    MaxTeleportDistance = 10000.0, AllowSelfTarget = false
}
Config.Staff = {
    -- ['license:YOUR_LICENSE_IDENTIFIER'] = 'owner',
}
Config.Ace = { Enabled = true, Prefix = 'poweradmin' }
Config.Roles = {
    owner = { label = 'Owner', permissions = { '*' } },
    headadmin = { label = 'Head Administrator', permissions = {
        'dashboard.view','entities.delete','entities.spawn','entities.manage','players.view','players.dossier','players.identifiers','players.inventory','players.money.view','players.money.modify',
        'players.notes.view','players.notes.add','players.history','players.spectate','players.warn','players.ban','players.unban',
        'players.teleport','players.bring','players.freeze','players.heal','players.kick','world.view','world.weather','world.time',
        'vehicles.view','vehicles.spawn','vehicles.give','items.view','items.give','items.create','jobs.view','jobs.create','staff.view','audit.view','resources.view'
    } },
    admin = { label = 'Administrator', permissions = {
        'dashboard.view','entities.delete','entities.spawn','entities.manage','players.view','players.dossier','players.inventory','players.money.view','players.notes.view','players.notes.add',
        'players.history','players.spectate','players.warn','players.ban','players.teleport','players.bring','players.freeze',
        'players.heal','players.kick','world.view','world.weather','world.time','vehicles.view','vehicles.spawn','vehicles.give','items.view','items.give','jobs.view','audit.view','resources.view'
    } },
    moderator = { label = 'Moderator', permissions = {
        'dashboard.view','players.view','players.dossier','players.notes.view','players.notes.add','players.history',
        'players.spectate','players.warn','players.kick','audit.view'
    } }
}
Config.DefaultWeather = 'CLEAR'
Config.AllowedWeather = { 'EXTRASUNNY','CLEAR','CLOUDS','OVERCAST','RAIN','THUNDER','CLEARING','NEUTRAL','SMOG','FOGGY','XMAS','SNOW','BLIZZARD' }
Config.PlayerIntelligence = {
    Enabled = true, PageSize = 25, ExposeIdentifiers = false,
    MaxMoneyAdjustment = 10000000, MaxBanDays = 3650,
    InventoryReadOnly = true, TrackConnections = true, TrackResourceActions = true,
    SpectateRestoreTimeoutMs = 300000,
    OwnedVehicles = { Enabled = false, Table = 'owned_vehicles', OwnerColumn = 'owner', PlateColumn = 'plate', VehicleColumn = 'vehicle' }
}
-- Provider selection is independent from the framework. Set explicit resource names for renamed/forked resources.
Config.Integrations = {
    Inventory = 'auto', -- auto | ox_inventory | qb-inventory | qs-inventory | framework | custom | disabled
    OxInventoryResource = 'ox_inventory',
    QBInventoryResource = 'qb-inventory',
    QSInventoryResource = 'qs-inventory',
    QSInventoryGetExport = 'GetInventory',
    QSInventoryAddExport = 'AddItem',
    -- For custom inventories, implement the functions in integrations/custom_inventory.lua.
    -- Optional provider override for the item catalog; defaults to Inventory provider.
    CustomInventory = true,
    Catalogs = { Vehicles = 'framework', Items = 'inventory', Jobs = 'framework' } -- custom | framework/inventory
}

-- Vehicle key handoff. Auto detects common resources; set Provider explicitly on renamed/forked scripts.
Config.VehicleKeys = {
    Provider = 'auto', -- auto | qbx_vehiclekeys | qb-vehiclekeys | qs-vehiclekeys | renewed | wasabi | custom | disabled
    Resource = nil, -- optional resource-name override
    ClientEvent = nil, -- custom client event receiving (vehicleEntity, plate)
    CustomExport = nil, -- optional custom client export name; receives vehicleEntity, plate
    ServerExport = 'GiveKeys' -- qbx_vehiclekeys:GiveKeys(source, vehicleEntity); qb-vehiclekeys:GiveKeys(source, plate)
}

-- Persistent vehicle ownership / garage integration.
Config.VehicleGarage = {
    Provider = 'qbox', -- qbox | qbcore | esx | jg_advancedgarages | cd_garage | qs_advancedgarages | custom | disabled
    Resource = 'qbx_vehicles', -- Qbox provider uses qbx_vehicles:CreatePlayerVehicle; override only for a compatible fork
    Table = 'player_vehicles',
    -- Standard Qbox/QBCore-compatible player_vehicles schema. Adjust columns for forks.
    Columns = { License='license', CitizenId='citizenid', Vehicle='vehicle', Hash='hash', Mods='mods', Plate='plate', Garage='garage', Fuel='fuel', Engine='engine', Body='body', State='state' },
    DefaultGarage = 'pillboxgarage',
    DefaultFuel = 100, DefaultEngine = 1000, DefaultBody = 1000,
    -- ESX owned_vehicles schema (used when Provider='esx').
    ESX = { Table='owned_vehicles', Owner='owner', Plate='plate', Vehicle='vehicle', Type='type', Stored='stored', DefaultType='car', DefaultStored=1 },
    -- Custom providers implement integrations/custom_garage.lua: AddVehicle(target, vehicleData).
    Custom = true
}

Config.FrameworkResources = { Qbox = 'qbx_core', QBCore = 'qb-core', ESX = 'es_extended' } -- resource folder names

Config.Locale = 'en'
