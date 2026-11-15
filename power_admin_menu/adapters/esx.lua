Framework = Framework or {}; Framework.esx = {}
local ESX
local function esxResource() return Config.FrameworkResources and Config.FrameworkResources.ESX or 'es_extended' end
function Framework.esx.Initialize()
    if GetResourceState(esxResource()) == 'started' then
        local ok, object = pcall(function() return exports[esxResource()]:getSharedObject() end)
        if ok then ESX = object end
    end
end
function Framework.esx.GetCore() return ESX end
function Framework.esx.GetPlayer(src) return ESX and ESX.GetPlayerFromId(src) or nil end
function Framework.esx.GetIdentifier(src)
    local x = Framework.esx.GetPlayer(src)
    return x and (x.identifier or (x.getIdentifier and x.getIdentifier())) or GetPlayerIdentifierByType(src, 'license')
end
function Framework.esx.GetCharacterId(src) return Framework.esx.GetIdentifier(src) end
function Framework.esx.GetCharacterName(src)
    local x = Framework.esx.GetPlayer(src)
    return x and x.getName and x.getName() or GetPlayerName(src)
end
function Framework.esx.GetJob(src)
    local x = Framework.esx.GetPlayer(src); local job = x and x.getJob and x.getJob()
    return job and (job.label or job.name) or 'Unemployed'
end
function Framework.esx.GetMoney(src)
    local x = Framework.esx.GetPlayer(src); if not x then return nil end
    local bank = x.getAccount and x.getAccount('bank')
    return {cash = x.getMoney and x.getMoney() or 0, bank = bank and bank.money or 0}
end
function Framework.esx.GetInventory(src)
    if Config.Integrations.Inventory == 'disabled' then return nil end
    local x = Framework.esx.GetPlayer(src)
    return x and x.getInventory and x.getInventory() or nil
end
function Framework.esx.IsLoaded(src) return Framework.esx.GetPlayer(src) ~= nil end
function Framework.esx.AdjustMoney(src, account, amount, reason)
    local x = Framework.esx.GetPlayer(src); if not x then return false, 'Player framework data unavailable.' end
    if account == 'cash' then
        local current = x.getMoney and x.getMoney() or 0
        if amount < 0 and current < -amount then return false, 'Insufficient cash balance.' end
        if amount > 0 and x.addMoney then x.addMoney(amount, reason) elseif amount < 0 and x.removeMoney then x.removeMoney(-amount, reason) else return false, 'Cash methods unavailable.' end
        return true
    elseif account == 'bank' then
        local bank = x.getAccount and x.getAccount('bank'); if not bank then return false, 'Bank account unavailable.' end
        if amount < 0 and (bank.money or 0) < -amount then return false, 'Insufficient bank balance.' end
        if amount > 0 and x.addAccountMoney then x.addAccountMoney('bank', amount, reason) elseif amount < 0 and x.removeAccountMoney then x.removeAccountMoney('bank', -amount, reason) else return false, 'Bank methods unavailable.' end
        return true
    end
    return false, 'Unsupported account.'
end
