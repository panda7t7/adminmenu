PAM = PAM or {}

function PAM.RoleHasPermission(roleName, permission)
    local role = Config.Roles[roleName]
    if not role or type(role.permissions) ~= 'table' then return false end
    for _, granted in ipairs(role.permissions) do
        if granted == '*' or granted == permission then return true end
    end
    return false
end
