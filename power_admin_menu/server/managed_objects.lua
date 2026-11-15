ManagedObjects = { Temporary = {}, Ready = false }

local function canManage(src)
    return Permissions and Permissions.IsStaff(src) and Permissions.Has(src, 'entities.manage')
end

local function notify(src, message, success)
    TriggerClientEvent('pam:client:managedObjectNotice', src, message, success == true)
end

local function spawnStored(row)
    local ok, coords = pcall(json.decode, row.coords or '{}')
    local okRot, rotation = pcall(json.decode, row.rotation or '{}')
    if not ok or type(coords) ~= 'table' or not okRot or type(rotation) ~= 'table' then
        print(('^1[PAM] Skipping malformed persistent prop #%s.^7'):format(row.id))
        return
    end
    local model = tostring(row.model or '')
    if not model:match('^[%w_]+$') or #model < 3 or #model > 64 then return end
    local entity = CreateObjectNoOffset(joaat(model), tonumber(coords.x) or 0.0, tonumber(coords.y) or 0.0, tonumber(coords.z) or 0.0, true, true, false)
    if entity and entity ~= 0 and DoesEntityExist(entity) then
        SetEntityRotation(entity, tonumber(rotation.x) or 0.0, tonumber(rotation.y) or 0.0, tonumber(rotation.z) or 0.0, 2, true)
        FreezeEntityPosition(entity, true)
        local netId = NetworkGetNetworkIdFromEntity(entity)
        ManagedObjects.Restored = ManagedObjects.Restored or {}
        ManagedObjects.Restored[tonumber(row.id)] = { netId = netId, model = model, coords = coords, rotation = rotation, persistence = 'persistent', id = tonumber(row.id), createdBy = row.created_by or 'Unknown' }
    else
        print(('^1[PAM] Failed to restore persistent prop #%s (%s).^7'):format(row.id, model))
    end
end

local function listFor(src)
    local rows = {}
    if not Database or not Database.Ready then return rows end
    local ok, persistent = pcall(function()
        return MySQL.query.await('SELECT id, model, coords, rotation, created_by, created_at FROM pam_managed_props ORDER BY id DESC')
    end)
    if ok and type(persistent) == 'table' then
        for _, row in ipairs(persistent) do
            local c = json.decode(row.coords or '{}') or {}
            local r = json.decode(row.rotation or '{}') or {}
            rows[#rows + 1] = { id = tonumber(row.id), model = row.model, coords = c, rotation = r, persistence = 'persistent', createdBy = row.created_by, createdAt = row.created_at }
        end
    end
    for id, row in pairs(ManagedObjects.Temporary) do
        rows[#rows + 1] = { id = 'temp:' .. tostring(id), model = row.model, coords = row.coords, rotation = row.rotation, persistence = 'temporary', createdBy = row.createdBy }
    end
    return rows
end

RegisterNetEvent('pam:server:managedPropsList', function()
    local src = source
    if not canManage(src) then return notify(src, 'You do not have permission to manage placed props.', false) end
    TriggerClientEvent('pam:client:managedPropsList', src, listFor(src))
end)

RegisterNetEvent('pam:server:managedPropRegister', function(netId, model, persistence)
    local src = source
    if not canManage(src) then return end
    netId = tonumber(netId)
    persistence = persistence == 'persistent' and 'persistent' or 'temporary'
    if not netId or netId <= 0 or type(model) ~= 'string' or not model:match('^[%w_]+$') or #model < 3 or #model > 64 then return end
    local entity = NetworkGetEntityFromNetworkId(netId)
    if not entity or entity == 0 or not DoesEntityExist(entity) or GetEntityType(entity) ~= 3 or GetEntityModel(entity) ~= joaat(model) then
        return notify(src, 'The placed entity could not be verified by the server.', false)
    end
    local owner = NetworkGetEntityOwner(entity)
    if owner ~= src then return notify(src, 'The server could not verify ownership of this placed prop.', false) end
    local p = GetEntityCoords(GetPlayerPed(src))
    local c = GetEntityCoords(entity)
    if #(p - c) > 60.0 then return notify(src, 'The prop is too far away to register.', false) end
    local rot = GetEntityRotation(entity, 2)
    local data = {
        model = model,
        coords = { x = c.x, y = c.y, z = c.z },
        rotation = { x = rot.x, y = rot.y, z = rot.z },
        netId = netId,
        createdBy = GetPlayerName(src) or ('ID ' .. src)
    }
    if persistence == 'persistent' then
        if not Database or not Database.Ready then return notify(src, 'Database is unavailable; persistent props cannot be saved.', false) end
        local ok, id = pcall(function()
            return MySQL.insert.await('INSERT INTO pam_managed_props (model, coords, rotation, created_by) VALUES (?, ?, ?, ?)', {
                model, json.encode(data.coords), json.encode(data.rotation), data.createdBy
            })
        end)
        if not ok or not id then return notify(src, 'Could not save this persistent prop.', false) end
        data.id = tonumber(id)
    else
        data.id = netId
        data.netId = netId
        ManagedObjects.Temporary[netId] = data
    end
    if Audit then Audit.Record(src, 'entity.prop.create', nil, { model = model, persistence = persistence, netId = netId, propId = data.id }, true) end
    notify(src, persistence == 'persistent' and 'Persistent prop saved. It will return after server restarts.' or 'Temporary prop registered. It will not return after a server restart.', true)
end)


RegisterNetEvent('pam:server:managedPropEdit', function(id, coords, rotation)
    local src = source
    if not canManage(src) then return end
    if type(coords) ~= 'table' or type(rotation) ~= 'table' then return end
    local x,y,z = tonumber(coords.x),tonumber(coords.y),tonumber(coords.z)
    local rx,ry,rz = tonumber(rotation.x),tonumber(rotation.y),tonumber(rotation.z)
    if not x or not y or not z or not rx or not ry or not rz then return end
    if math.abs(x)>20000 or math.abs(y)>20000 or math.abs(z)>3000 or math.abs(rx)>360 or math.abs(ry)>360 or math.abs(rz)>360 then return end
    local key=tostring(id or '')
    local isTemp=key:sub(1,5)=='temp:'
    local numeric=tonumber(isTemp and key:sub(6) or key)
    if not numeric then return end
    local row=isTemp and ManagedObjects.Temporary[numeric] or (ManagedObjects.Restored and ManagedObjects.Restored[numeric])
    if not row then return notify(src,'Managed prop not found.',false) end
    local entity=row.netId and NetworkGetEntityFromNetworkId(row.netId) or 0
    if not entity or entity==0 or not DoesEntityExist(entity) or GetEntityType(entity)~=3 then return notify(src,'Managed entity is not currently available.',false) end
    if #(GetEntityCoords(GetPlayerPed(src))-vector3(x,y,z))>100.0 then return notify(src,'Edited position is too far away.',false) end
    SetEntityCoords(entity,x,y,z,false,false,false,false)
    SetEntityRotation(entity,rx,ry,rz,2,true)
    FreezeEntityPosition(entity,true)
    row.coords,row.rotation={x=x,y=y,z=z},{x=rx,y=ry,z=rz}
    if not isTemp then MySQL.update.await('UPDATE pam_managed_props SET coords = ?, rotation = ? WHERE id = ?', {json.encode(row.coords),json.encode(row.rotation),numeric}) end
    if Audit then Audit.Record(src,'entity.prop.edit',nil,{propId=id,coords=row.coords,rotation=row.rotation},true) end
    notify(src,'Managed prop updated.',true)
    TriggerClientEvent('pam:client:managedPropsList',src,listFor(src))
end)

RegisterNetEvent('pam:server:managedPropDelete', function(id)
    local src = source
    if not canManage(src) then return end
    local key = tostring(id or '')
    if key:sub(1, 5) == 'temp:' then key = key:sub(6) end
    local numeric = tonumber(key)
    if not numeric then return end
    local row
    if tostring(id):sub(1, 5) == 'temp:' or ManagedObjects.Temporary[numeric] then
        row = ManagedObjects.Temporary[numeric]
        if not row then return notify(src, 'Temporary prop not found in this session.', false) end
        local entity = NetworkGetEntityFromNetworkId(row.netId)
        if entity and entity ~= 0 and DoesEntityExist(entity) then DeleteEntity(entity) end
        ManagedObjects.Temporary[numeric] = nil
    else
        if not Database or not Database.Ready then return notify(src, 'Database unavailable.', false) end
        local rows = MySQL.query.await('SELECT id FROM pam_managed_props WHERE id = ?', { numeric })
        if not rows or not rows[1] then return notify(src, 'Persistent prop record not found.', false) end
        local restored = ManagedObjects.Restored and ManagedObjects.Restored[numeric]
        if restored and restored.netId then
            local entity = NetworkGetEntityFromNetworkId(restored.netId)
            if entity and entity ~= 0 and DoesEntityExist(entity) then DeleteEntity(entity) end
        end
        MySQL.update.await('DELETE FROM pam_managed_props WHERE id = ?', { numeric })
        if ManagedObjects.Restored then ManagedObjects.Restored[numeric] = nil end
    end
    if Audit then Audit.Record(src, 'entity.prop.delete', nil, { propId = id }, true) end
    notify(src, 'Managed prop deleted.', true)
    TriggerClientEvent('pam:client:managedPropsList', src, listFor(src))
end)


AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for _, row in pairs(ManagedObjects.Temporary) do
        local entity=row.netId and NetworkGetEntityFromNetworkId(row.netId) or 0
        if entity and entity~=0 and DoesEntityExist(entity) then DeleteEntity(entity) end
    end
    for _, row in pairs(ManagedObjects.Restored or {}) do
        local entity=row.netId and NetworkGetEntityFromNetworkId(row.netId) or 0
        if entity and entity~=0 and DoesEntityExist(entity) then DeleteEntity(entity) end
    end
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    CreateThread(function()
        local deadline = GetGameTimer() + 30000
        while (not Database or not Database.Ready) and GetGameTimer() < deadline do Wait(500) end
        if not Database or not Database.Ready then
            print('^1[PAM] Managed props: database unavailable; persistent props were not restored.^7')
            return
        end
        local ok, rows = pcall(function()
            return MySQL.query.await('SELECT id, model, coords, rotation, created_by FROM pam_managed_props ORDER BY id ASC')
        end)
        if not ok or type(rows) ~= 'table' then
            print('^1[PAM] Managed props: failed to load persistent records. Check sql/managed_props.sql.^7')
            return
        end
        for _, row in ipairs(rows) do spawnStored(row); Wait(50) end
        print(('^2[PAM] Restored %s persistent props.^7'):format(#rows))
    end)
end)
