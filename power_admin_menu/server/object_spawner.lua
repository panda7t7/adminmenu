local lastObjectSpawnRequest = {}

RegisterNetEvent('pam:server:spawnObjectRequest', function(modelName, persistence)
    local src = source
    if not Permissions or not Permissions.IsStaff(src) or not Permissions.Has(src, 'entities.spawn') then
        if Audit then Audit.Record(src, 'entity.spawn.denied', nil, {}, false) end
        TriggerClientEvent('chat:addMessage', src, { args = { '^1POWER ADMIN', 'You do not have permission to spawn objects.' } })
        return
    end

    local now = GetGameTimer()
    if lastObjectSpawnRequest[src] and now - lastObjectSpawnRequest[src] < 1500 then
        TriggerClientEvent('chat:addMessage', src, { args = { '^1POWER ADMIN', 'Please wait before requesting another object.' } })
        return
    end
    lastObjectSpawnRequest[src] = now

    if type(modelName) ~= 'string' then
        TriggerClientEvent('chat:addMessage', src, { args = { '^1POWER ADMIN', 'Enter a valid object model name.' } })
        return
    end
    modelName = modelName:lower():gsub('^%s+', ''):gsub('%s+$', '')
    if #modelName < 3 or #modelName > 64 or not modelName:match('^[%w_]+$') then
        TriggerClientEvent('chat:addMessage', src, { args = { '^1POWER ADMIN', 'Model names must be 3–64 letters, numbers or underscores.' } })
        return
    end

    if Audit then Audit.Record(src, 'entity.spawn.begin', nil, { model = modelName }, true) end
    persistence = persistence == 'persistent' and 'persistent' or 'temporary'
    TriggerClientEvent('pam:client:beginObjectPlacement', src, modelName, { persistence = persistence })
end)

AddEventHandler('playerDropped', function()
    lastObjectSpawnRequest[source] = nil
end)
