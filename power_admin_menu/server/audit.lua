Audit = {}

function Audit.Record(actor, action, target, details, success)
    local actorName = actor == 0 and 'Server Console' or (GetPlayerName(actor) or 'Unknown')
    local targetName = target and GetPlayerName(target) or nil
    local targetIdentifier = target and Framework.GetIdentifier(target) or nil
    local actorIdentifier = actor == 0 and 'console' or Framework.GetIdentifier(actor)
    local record = {
        actorIdentifier = actorIdentifier,
        actorName = actorName,
        action = action,
        targetIdentifier = targetIdentifier,
        targetName = targetName,
        details = details or {},
        success = success == true
    }
    Database.InsertAudit(record)
    print(('[PAM AUDIT] %s | actor=%s | target=%s | success=%s'):format(action, actorName, targetName or 'none', tostring(record.success)))
end
