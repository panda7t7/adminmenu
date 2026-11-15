-- OPTIONAL CUSTOM FRAMEWORK ADAPTER
-- Set Config.Framework = 'custom' and implement the PAMCustomFramework methods below.
-- Return the same shapes used by the native adapters; missing methods fall back safely.
PAMCustomFramework = PAMCustomFramework or {}
Framework = Framework or {}; Framework.custom = {}

function Framework.custom.Initialize()
    if PAMCustomFramework.Initialize then
        local ok, err = pcall(PAMCustomFramework.Initialize)
        if not ok then print(('^1[PAM] Custom framework initialization failed: %s^7'):format(tostring(err))) end
    end
end
function Framework.custom.GetCore() return nil end
function Framework.custom.GetPlayer(source)
    if PAMCustomFramework.GetPlayer then local ok, value = pcall(PAMCustomFramework.GetPlayer, source); if ok then return value end end
end
function Framework.custom.GetIdentifier(source)
    if PAMCustomFramework.GetIdentifier then local ok, value = pcall(PAMCustomFramework.GetIdentifier, source); if ok then return value end end
    return GetPlayerIdentifierByType(source, 'license')
end
function Framework.custom.GetCharacterId(source)
    if PAMCustomFramework.GetCharacterId then local ok, value = pcall(PAMCustomFramework.GetCharacterId, source); if ok then return value end end
    return Framework.custom.GetIdentifier(source)
end
function Framework.custom.GetCharacterName(source)
    if PAMCustomFramework.GetCharacterName then local ok, value = pcall(PAMCustomFramework.GetCharacterName, source); if ok then return value end end
    return GetPlayerName(source)
end
function Framework.custom.GetJob(source)
    if PAMCustomFramework.GetJob then local ok, value = pcall(PAMCustomFramework.GetJob, source); if ok then return value end end
    return 'Unknown'
end
function Framework.custom.GetMoney(source)
    if PAMCustomFramework.GetMoney then local ok, value = pcall(PAMCustomFramework.GetMoney, source); if ok then return value end end
end
function Framework.custom.GetInventory(source)
    if PAMCustomFramework.GetInventory then local ok, value = pcall(PAMCustomFramework.GetInventory, source); if ok then return value end end
end
function Framework.custom.IsLoaded(source)
    if PAMCustomFramework.IsLoaded then local ok, value = pcall(PAMCustomFramework.IsLoaded, source); if ok then return value == true end end
    return Framework.custom.GetPlayer(source) ~= nil
end
function Framework.custom.AdjustMoney(source, account, amount, reason)
    if not PAMCustomFramework.AdjustMoney then return false, 'Implement PAMCustomFramework.AdjustMoney in integrations/custom_framework.lua.' end
    local ok, success, message = pcall(PAMCustomFramework.AdjustMoney, source, account, amount, reason)
    return ok and success == true, ok and message or tostring(success)
end

-- Optional: register a framework job at runtime. Return true on success.
-- function PAMCustomFramework.RegisterJob(jobName, definition)
--     return exports['your_framework']:CreateJob(jobName, definition)
-- end
