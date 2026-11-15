-- Native Qbox adapter: no dependency on the legacy QBCore core object.
Framework = Framework or {}; Framework.qbox = {}
local function qboxResource() return Config.FrameworkResources and Config.FrameworkResources.Qbox or 'qbx_core' end
function Framework.qbox.Initialize()
    if GetResourceState(qboxResource()) ~= 'started' then
        print('^1[PAM] Qbox selected but qbx_core is not started.^7')
    end
end
function Framework.qbox.GetCore() return nil end
function Framework.qbox.GetPlayer(src)
    if GetResourceState(qboxResource()) ~= 'started' then return nil end
    local ok, player = pcall(function() return exports[qboxResource()]:GetPlayer(src) end)
    return ok and player or nil
end
function Framework.qbox.GetIdentifier(src)
    local p = Framework.qbox.GetPlayer(src)
    return p and p.PlayerData and p.PlayerData.license or GetPlayerIdentifierByType(src, 'license')
end
function Framework.qbox.GetCharacterId(src)
    local p = Framework.qbox.GetPlayer(src); return p and p.PlayerData and p.PlayerData.citizenid or nil
end
function Framework.qbox.GetCharacterName(src)
    local p = Framework.qbox.GetPlayer(src); local c = p and p.PlayerData and p.PlayerData.charinfo
    return c and ((c.firstname or '') .. ' ' .. (c.lastname or '')) or GetPlayerName(src)
end
function Framework.qbox.GetJob(src)
    local p = Framework.qbox.GetPlayer(src); local j = p and p.PlayerData and p.PlayerData.job
    return j and (j.label or j.name) or 'Unemployed'
end
function Framework.qbox.GetMoney(src)
    local p = Framework.qbox.GetPlayer(src); local m = p and p.PlayerData and p.PlayerData.money
    return m and {cash=m.cash or 0, bank=m.bank or 0} or nil
end
function Framework.qbox.GetInventory(src)
    local resource = (Config.Integrations and Config.Integrations.OxInventoryResource) or 'ox_inventory'
    if GetResourceState(resource) ~= 'started' then return nil end
    local ok, items = pcall(function() return exports[resource]:GetInventoryItems(src) end)
    return ok and items or nil
end
function Framework.qbox.IsLoaded(src) return Framework.qbox.GetPlayer(src) ~= nil end
function Framework.qbox.AdjustMoney(src, account, amount, reason)
    if account ~= 'cash' and account ~= 'bank' then return false, 'Unsupported account.' end
    local ok, result = pcall(function()
        if amount > 0 then
            return exports[qboxResource()]:AddMoney(src, account, amount, 'power-admin-menu: ' .. tostring(reason))
        end
        return exports[qboxResource()]:RemoveMoney(src, account, -amount, 'power-admin-menu: ' .. tostring(reason))
    end)
    if not ok or result ~= true then return false, 'Qbox money export failed.' end
    return true
end
