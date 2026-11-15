Framework = Framework or {}; Framework.standalone = {}
function Framework.standalone.Initialize() end
function Framework.standalone.GetPlayer(src) return GetPlayerName(src) and {source=src} or nil end
function Framework.standalone.GetIdentifier(src) return GetPlayerIdentifierByType(src, 'license') or GetPlayerIdentifier(src, 0) end
function Framework.standalone.GetCharacterId(src) return Framework.standalone.GetIdentifier(src) end
function Framework.standalone.GetCharacterName(src) return GetPlayerName(src) or ('Player %s'):format(src) end
function Framework.standalone.GetJob() return 'Standalone' end
function Framework.standalone.GetMoney() return nil end
function Framework.standalone.GetInventory() return nil end
function Framework.standalone.IsLoaded(src) return GetPlayerName(src) ~= nil end
function Framework.standalone.AdjustMoney() return false, 'Economy integration unavailable in Standalone mode.' end
