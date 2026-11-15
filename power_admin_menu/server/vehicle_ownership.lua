VehicleOwnership = {}
local function ident(v)
    v = tostring(v or '')
    assert(v:match('^[%w_]+$'), 'Unsafe SQL identifier')
    return ('`%s`'):format(v)
end
local function makePlate()
    local chars='ABCDEFGHJKLMNPQRSTUVWXYZ0123456789'; local plate=''
    for i=1,8 do local n=math.random(#chars); plate=plate..chars:sub(n,n) end
    return plate
end
local function insertGeneric(target, data)
    local cfg=Config.VehicleGarage
    local cols=cfg.Columns or {}
    local player=Framework.GetPlayer(target)
    local pd=player and player.PlayerData or {}
    local mapping={
        [cols.License]=data.license,[cols.CitizenId]=data.citizenid,[cols.Vehicle]=data.model,
        [cols.Hash]=data.hash,[cols.Mods]=json.encode(data.props),[cols.Plate]=data.plate,
        [cols.Garage]=cfg.DefaultGarage,[cols.Fuel]=cfg.DefaultFuel,[cols.Engine]=cfg.DefaultEngine,
        [cols.Body]=cfg.DefaultBody,[cols.State]=1
    }
    local columns,marks,values={}, {}, {}
    for col,val in pairs(mapping) do if col and val~=nil then columns[#columns+1]=ident(col); marks[#marks+1]='?'; values[#values+1]=val end end
    if #columns==0 then return false,'No garage columns configured.' end
    local query=('INSERT INTO %s (%s) VALUES (%s)'):format(ident(cfg.Table),table.concat(columns,','),table.concat(marks,','))
    local ok,err=pcall(function() MySQL.insert.await(query,values) end)
    if not ok then print(('^1[PAM] Vehicle garage insert failed: %s^7'):format(err)); return false,'Garage database insert failed. Check VehicleGarage column settings.' end
    return true
end

function VehicleOwnership.Give(admin, target, model)
    local cfg=Config.VehicleGarage or {}
    if cfg.Provider=='disabled' then return false,'Garage integration is disabled.' end
    local plate=makePlate()
    local hash=joaat(model)
    local player=Framework.GetPlayer(target); if not player then return false,'Target player is not loaded.' end
    local pd=player.PlayerData or {}
    local data={model=model,hash=hash,plate=plate,props={model=hash,plate=plate,engineHealth=cfg.DefaultEngine or 1000.0,bodyHealth=cfg.DefaultBody or 1000.0,fuelLevel=cfg.DefaultFuel or 100.0,tankHealth=1000.0,dirtLevel=0.0},citizenid=pd.citizenid,license=pd.license,garage=cfg.DefaultGarage,fuel=cfg.DefaultFuel or 100,engine=cfg.DefaultEngine or 1000,body=cfg.DefaultBody or 1000}
    local ok,msg
    if cfg.Provider=='custom' or cfg.Provider=='jg_advancedgarages' or cfg.Provider=='cd_garage' or cfg.Provider=='qs_advancedgarages' then
        if not PAMCustomGarage or type(PAMCustomGarage.AddVehicle)~='function' then return false,'Custom garage bridge missing.' end
        ok,msg=PAMCustomGarage.AddVehicle(target,data)
    elseif cfg.Provider=='esx' then
        local esx=cfg.ESX or {}; local owner=Framework.GetIdentifier(target)
        local columns={ident(esx.Owner or 'owner'),ident(esx.Plate or 'plate'),ident(esx.Vehicle or 'vehicle'),ident(esx.Type or 'type'),ident(esx.Stored or 'stored')}
        local query=('INSERT INTO %s (%s) VALUES (?, ?, ?, ?, ?)'):format(ident(esx.Table or 'owned_vehicles'),table.concat(columns,','))
        ok,msg=pcall(function() MySQL.insert.await(query,{owner,plate,json.encode(data.props),esx.DefaultType or 'car',esx.DefaultStored or 1}) end)
        if not ok then msg='ESX garage insert failed. Check VehicleGarage.ESX schema.' end
    elseif cfg.Provider=='qbox' then
        -- Use Qbox's supported vehicle-ownership API rather than inserting a partial
        -- player_vehicles row. qbx_garages reads engineHealth/bodyHealth/fuelLevel
        -- from props and expects the complete ox_lib vehicle-properties shape.
        local vehiclesResource=cfg.Resource or 'qbx_vehicles'
        if GetResourceState(vehiclesResource)~='started' then
            return false,('Qbox vehicle resource %s is not started. Ensure qbx_vehicles starts before power_admin_menu.'):format(vehiclesResource)
        end
        if not pd.citizenid then return false,'Target player has no Qbox citizen ID.' end
        local callOk,vehicleId,result=pcall(function()
            return exports[vehiclesResource]:CreatePlayerVehicle({
                model=model, citizenid=pd.citizenid, garage=cfg.DefaultGarage, props=data.props
            })
        end)
        if not callOk then
            print(('^1[PAM] qbx_vehicles CreatePlayerVehicle failed: %s^7'):format(vehicleId))
            return false,'Qbox could not register this vehicle. Check the qbx_vehicles server console.'
        end
        if not vehicleId then
            local detail=result and result.message or 'No vehicle ID was returned.'
            print(('^1[PAM] qbx_vehicles rejected vehicle registration: %s^7'):format(detail))
            return false,'Qbox rejected the vehicle registration: '..tostring(detail)
        end
        ok=true
    elseif cfg.Provider=='qbcore' then
        if not Database.Ready then return false,'Database is unavailable.' end
        ok,msg=insertGeneric(target,data)
    else return false,'Unknown garage provider: '..tostring(cfg.Provider) end
    if ok~=true then return false,tostring(msg or 'Garage registration failed.') end
    TriggerClientEvent('pam:client:receiveVehicle',target,model,plate)
    Audit.Record(admin,'vehicle.give',target,{model=model,plate=plate,garage=cfg.DefaultGarage},true)
    return true,plate
end


local function keyProvider()
    local cfg=Config.VehicleKeys or {}
    local provider=cfg.Provider or 'auto'
    if provider~='auto' then
        local defaults={qbx_vehiclekeys='qbx_vehiclekeys',['qb-vehiclekeys']='qb-vehiclekeys',['qs-vehiclekeys']='qs-vehiclekeys',renewed='Renewed-Vehiclekeys',wasabi='wasabi_carlock'}
        return provider,cfg.Resource or defaults[provider]
    end
    local candidates={
        {provider='qbx_vehiclekeys',resource='qbx_vehiclekeys'},
        {provider='qb-vehiclekeys',resource='qb-vehiclekeys'},
        {provider='qs-vehiclekeys',resource='qs-vehiclekeys'},
        {provider='renewed',resource='Renewed-Vehiclekeys'},
        {provider='wasabi',resource='wasabi_carlock'}
    }
    for _,v in ipairs(candidates) do if GetResourceState(v.resource)=='started' then return v.provider,v.resource end end
    return 'disabled',nil
end

RegisterNetEvent('pam:server:vehicleSpawned',function(netId,plate,model)
    local src=source
    netId=tonumber(netId); plate=type(plate)=='string' and plate:sub(1,8) or nil
    model=type(model)=='string' and model:lower() or ''
    if not netId or not plate or not model:match('^[a-z0-9_%-]+$') then return end
    CreateThread(function()
        local entity=0
        for attempt=1,15 do
            entity=NetworkGetEntityFromNetworkId(netId)
            if entity~=0 and DoesEntityExist(entity) then break end
            Wait(100)
        end
        if entity==0 or not DoesEntityExist(entity) or GetEntityType(entity)~=2 then
            print(('[PAM] Key assignment skipped for %s: network vehicle entity was not found.'):format(model)); return
        end
        if GetEntityModel(entity)~=joaat(model) then
            print(('[PAM] Key assignment rejected for %s: spawned entity model did not match.'):format(model)); return
        end
        local ped=GetPlayerPed(src)
        if not ped or ped==0 or #(GetEntityCoords(ped)-GetEntityCoords(entity))>20.0 then
            print(('[PAM] Key assignment rejected for %s: vehicle is not near the requesting player.'):format(model)); return
        end
        local entityPlate=tostring(GetVehicleNumberPlateText(entity) or ''):gsub('^%s*(.-)%s*$','%1')
        local requestedPlate=tostring(plate or ''):gsub('^%s*(.-)%s*$','%1')
        if entityPlate~='' and requestedPlate~='' and entityPlate~=requestedPlate then
            print('[PAM] Key assignment rejected: plate mismatch.'); return
        end
        -- Network ownership can migrate between the client and server during creation; proximity,
        -- model and plate validation bind this request to the vehicle the admin just spawned.
        local provider,resource=keyProvider()
        if provider=='qbx_vehiclekeys' and resource and GetResourceState(resource)=='started' then
            local ok,err=pcall(function() exports[resource][(Config.VehicleKeys and Config.VehicleKeys.ServerExport) or 'GiveKeys'](src,entity,true) end)
            if not ok then print(('^1[PAM] qbx_vehiclekeys key assignment failed: %s^7'):format(err)) end
        elseif provider=='qb-vehiclekeys' and resource and GetResourceState(resource)=='started' then
            local ok,err=pcall(function() exports[resource][(Config.VehicleKeys and Config.VehicleKeys.ServerExport) or 'GiveKeys'](src,plate) end)
            if not ok then print(('^1[PAM] qb-vehiclekeys key assignment failed: %s^7'):format(err)) end
        else
            TriggerClientEvent('pam:client:assignVehicleKeys',src,plate,netId)
        end
    end)
end)
