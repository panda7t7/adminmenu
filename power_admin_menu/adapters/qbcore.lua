Framework = Framework or {}; Framework.qbcore = {}
local QBCore
local function qbResource() return Config.FrameworkResources and Config.FrameworkResources.QBCore or 'qb-core' end
function Framework.qbcore.Initialize()
    if GetResourceState(qbResource()) == 'started' then
        local ok, object = pcall(function() return exports[qbResource()]:GetCoreObject() end)
        if ok then QBCore = object end
    end
end
function Framework.qbcore.GetCore() return QBCore end
function Framework.qbcore.GetPlayer(src) return QBCore and QBCore.Functions.GetPlayer(src) or nil end
function Framework.qbcore.GetIdentifier(src)
    local p = Framework.qbcore.GetPlayer(src)
    return p and p.PlayerData and p.PlayerData.license or GetPlayerIdentifierByType(src, 'license')
end
function Framework.qbcore.GetCharacterId(src)
    local p = Framework.qbcore.GetPlayer(src); return p and p.PlayerData and p.PlayerData.citizenid or nil
end
function Framework.qbcore.GetCharacterName(src)
    local p = Framework.qbcore.GetPlayer(src); local c = p and p.PlayerData and p.PlayerData.charinfo
    return c and ((c.firstname or '') .. ' ' .. (c.lastname or '')) or GetPlayerName(src)
end
function Framework.qbcore.GetJob(src)
    local p = Framework.qbcore.GetPlayer(src); local j = p and p.PlayerData and p.PlayerData.job
    return j and (j.label or j.name) or 'Unemployed'
end
function Framework.qbcore.GetMoney(src)
    local p = Framework.qbcore.GetPlayer(src); local m = p and p.PlayerData and p.PlayerData.money
    return m and {cash=m.cash or 0, bank=m.bank or 0} or nil
end
function Framework.qbcore.GetInventory(src)
    if Config.Integrations.Inventory == 'disabled' then return nil end
    local p = Framework.qbcore.GetPlayer(src); return p and p.PlayerData and p.PlayerData.items or nil
end
function Framework.qbcore.IsLoaded(src) return Framework.qbcore.GetPlayer(src) ~= nil end
function Framework.qbcore.AdjustMoney(src, account, amount, reason)
    local p = Framework.qbcore.GetPlayer(src); if not p or not p.Functions then return false, 'Player framework data unavailable.' end
    if account ~= 'cash' and account ~= 'bank' then return false, 'Unsupported account.' end
    local current = tonumber((p.PlayerData.money or {})[account]) or 0
    if amount < 0 and current < -amount then return false, 'Insufficient balance.' end
    local fn = amount > 0 and p.Functions.AddMoney or p.Functions.RemoveMoney
    if not fn then return false, 'Money methods unavailable.' end
    local ok, result = pcall(fn, account, math.abs(amount), 'power-admin-menu: ' .. reason)
    if not ok or result == false then return false, 'Framework money operation failed.' end
    return true
end
