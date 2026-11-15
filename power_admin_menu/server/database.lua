Database = { Ready = false }

function Database.Initialize()
    if not Config.Database.Enabled then
        Database.Ready = not Config.Database.RequireDatabase
        print('^3[PAM] Database integration disabled.^7')
        return
    end
    if GetResourceState('oxmysql') ~= 'started' then
        print('^1[PAM] oxmysql is not started. Import sql/install.sql and start oxmysql before this resource.^7')
        Database.Ready = false
        return
    end
    local ok, result = pcall(function()
        return MySQL.scalar.await('SELECT 1')
    end)
    Database.Ready = ok and result == 1
    if Database.Ready then
        print('^2[PAM] Database connection verified.^7')
    else
        print('^1[PAM] Database connection check failed.^7')
    end
end

function Database.InsertAudit(data)
    if not Database.Ready then return false end
    local ok, err = pcall(function()
        MySQL.insert.await([[INSERT INTO pam_audit_logs
            (actor_identifier, actor_name, action, target_identifier, target_name, details, success)
            VALUES (?, ?, ?, ?, ?, ?, ?)]], {
            data.actorIdentifier, data.actorName, data.action,
            data.targetIdentifier, data.targetName, json.encode(data.details or {}),
            data.success and 1 or 0
        })
    end)
    if not ok then print(('^1[PAM] Audit insert failed: %s^7'):format(err)) end
    return ok
end
