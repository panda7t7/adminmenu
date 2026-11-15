RegisterNetEvent('pam:server:vectorRequest', function()
    local src = source
    if not Permissions or not Permissions.IsStaff(src) or not Permissions.Has(src, 'dashboard.view') then
        TriggerClientEvent('chat:addMessage', src, { args = { '^1POWER ADMIN', 'You do not have permission to use /vector.' } })
        return
    end
    TriggerClientEvent('pam:client:vectorToggle', src)
end)

RegisterNetEvent('pam:server:laserDelete', function(netId, localHandle)
    local src = source
    if not Permissions or not Permissions.IsStaff(src) or not Permissions.Has(src, 'entities.delete') then
        TriggerClientEvent('pam:client:laserDeleteResult', src, false, 'You do not have permission to delete entities.')
        if Audit then Audit.Record(src, 'entity.delete.denied', nil, {}, false) end
        return
    end
    netId = tonumber(netId) or 0
    localHandle = tonumber(localHandle) or 0
    if netId > 0 then
        local entity = NetworkGetEntityFromNetworkId(netId)
        if entity == 0 or not DoesEntityExist(entity) then
            TriggerClientEvent('pam:client:laserDeleteResult', src, false, 'Target entity no longer exists.')
            return
        end
        local entityType = GetEntityType(entity)
        -- Let the requesting client obtain network control before deleting. This avoids
        -- relying on server-side entity deletion for client-owned network objects.
        TriggerClientEvent('pam:client:laserDeleteNetwork', src, netId)
        if Audit then Audit.Record(src, 'entity.delete.request', nil, { networkId = netId, entityType = entityType }, true) end
    else
        -- Non-networked map props cannot be resolved by the server. Authorize first, then
        -- ask only the requesting client to delete its currently targeted local handle.
        if localHandle <= 0 then
            TriggerClientEvent('pam:client:laserDeleteResult', src, false, 'Invalid entity target.')
            return
        end
        TriggerClientEvent('pam:client:laserDeleteLocal', src, localHandle)
        if Audit then Audit.Record(src, 'entity.delete.local', nil, { entityHandle = localHandle }, true) end
        TriggerClientEvent('pam:client:laserDeleteResult', src, true, 'Delete request sent for local entity.')
    end
end)
