Framework = Framework or {}

local function resourceStarted(name) return GetResourceState(name) == 'started' end
local function frameworkResource(key, fallback)
    return Config.FrameworkResources and Config.FrameworkResources[key] or fallback
end
function Framework.Detect()
    local selected = string.lower(Config.Framework or 'auto')
    if selected ~= 'auto' then return selected end
    if resourceStarted(frameworkResource('Qbox', 'qbx_core')) then return 'qbox' end
    if resourceStarted(frameworkResource('QBCore', 'qb-core')) then return 'qbcore' end
    if resourceStarted(frameworkResource('ESX', 'es_extended')) then return 'esx' end
    return 'standalone'
end
function Framework.Initialize()
    Framework.Type = Framework.Detect()
    local adapter = Framework[Framework.Type]
    if not adapter then
        print(('^1[PAM] Unknown framework "%s". Falling back to standalone.^7'):format(Framework.Type))
        Framework.Type, adapter = 'standalone', Framework.standalone
    end
    Framework.Adapter = adapter
    if adapter and adapter.Initialize then adapter.Initialize() end
    print(('^2[PAM] Framework adapter loaded: %s^7'):format(Framework.Type))
end
function Framework.GetCore() return Framework.Adapter and Framework.Adapter.GetCore and Framework.Adapter.GetCore() or nil end
function Framework.GetPlayer(src) return Framework.Adapter.GetPlayer and Framework.Adapter.GetPlayer(src) or nil end
function Framework.GetIdentifier(src) return Framework.Adapter.GetIdentifier and Framework.Adapter.GetIdentifier(src) or GetPlayerIdentifierByType(src, 'license') end
function Framework.GetCharacterId(src) return Framework.Adapter.GetCharacterId and Framework.Adapter.GetCharacterId(src) or Framework.GetIdentifier(src) end
function Framework.GetCharacterName(src) return Framework.Adapter.GetCharacterName and Framework.Adapter.GetCharacterName(src) or GetPlayerName(src) end
function Framework.GetJob(src) return Framework.Adapter.GetJob and Framework.Adapter.GetJob(src) or 'Unknown' end
function Framework.GetMoney(src) return Framework.Adapter.GetMoney and Framework.Adapter.GetMoney(src) or nil end
function Framework.GetInventory(src) return Framework.Adapter.GetInventory and Framework.Adapter.GetInventory(src) or nil end
function Framework.IsLoaded(src) return Framework.Adapter.IsLoaded and Framework.Adapter.IsLoaded(src) or false end
function Framework.AdjustMoney(src, account, amount, reason)
    if not Framework.Adapter or not Framework.Adapter.AdjustMoney then return false, 'Money integration unavailable.' end
    return Framework.Adapter.AdjustMoney(src, account, amount, reason)
end
