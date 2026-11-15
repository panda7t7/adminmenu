Permissions = {}

local function getIdentifiers(src)
    local found = {}
    for _, identifier in ipairs(GetPlayerIdentifiers(src)) do found[identifier] = true end
    local license = GetPlayerIdentifierByType(src, 'license')
    if license then found[license] = true end
    return found
end

function Permissions.GetRole(src)
    local identifiers = getIdentifiers(src)
    for identifier, role in pairs(Config.Staff) do
        if identifiers[identifier] and Config.Roles[role] then return role end
    end
    if Config.Ace.Enabled then
        for roleName in pairs(Config.Roles) do
            if IsPlayerAceAllowed(src, ('%s.%s'):format(Config.Ace.Prefix, roleName)) then
                return roleName
            end
        end
        if IsPlayerAceAllowed(src, Config.Ace.Prefix .. '.owner') then return 'owner' end
    end
    return nil
end

function Permissions.Has(src, permission)
    if src == 0 then return true end -- server console
    if type(permission) ~= 'string' then return false end
    if Config.Ace.Enabled and IsPlayerAceAllowed(src, Config.Ace.Prefix .. '.' .. permission) then
        return true
    end
    local role = Permissions.GetRole(src)
    return role ~= nil and PAM.RoleHasPermission(role, permission)
end

function Permissions.GetClientPermissions(src)
    local result = {}
    for _, permission in ipairs(PAM.Permissions) do
        result[permission] = Permissions.Has(src, permission)
    end
    return result
end

function Permissions.IsStaff(src)
    if Permissions.GetRole(src) ~= nil then return true end
    return Config.Ace.Enabled and IsPlayerAceAllowed(src, Config.Ace.Prefix .. '.dashboard.view') or false
end
