PAMClient = { Open = false, Data = nil }

local function setOpen(state)
    PAMClient.Open = state
    SetNuiFocus(state, state)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ type = 'PAM_VISIBILITY', visible = state })
end

RegisterCommand(Config.OpenCommand, function()
    if not Config.AllowCommand and not Config.AllowKeybind then return end
    TriggerServerEvent(PAM.Events.OpenRequest)
end, false)

if Config.AllowKeybind then
    RegisterKeyMapping(Config.OpenCommand, 'Open Power Admin Menu', 'keyboard', Config.OpenKey)
end

RegisterNetEvent(PAM.Events.Bootstrap, function(data)
    if type(data) ~= 'table' then return end
    PAMClient.Data = data
    setOpen(true)
    SendNUIMessage({ type = 'PAM_BOOTSTRAP', payload = data })
end)

RegisterNetEvent(PAM.Events.ActionResult, function(result)
    SendNUIMessage({ type = 'PAM_ACTION_RESULT', payload = result or {} })
end)

RegisterNetEvent('pam:client:beginObjectPlacement', function(modelName)
    setOpen(false)
    TriggerEvent('pam:client:startObjectPlacement', modelName)
end)

RegisterNUICallback('close', function(_, cb)
    setOpen(false)
    cb({ success = true })
end)

CreateThread(function()
    while true do
        if PAMClient.Open then
            DisableControlAction(0, 1, true)
            DisableControlAction(0, 2, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 200, true)
            Wait(0)
        else
            Wait(500)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        SetNuiFocus(false, false)
    end
end)

RegisterNetEvent('pam:client:dossier', function(data) SendNUIMessage({ type = 'PAM_PLAYER_DOSSIER', payload = data or {} }) end)
RegisterNetEvent('pam:client:playerList', function(data) SendNUIMessage({ type = 'PAM_PLAYER_LIST', payload = data or {} }) end)

RegisterNetEvent('pam:client:banList', function(data) SendNUIMessage({ type = 'PAM_BAN_LIST', payload = data or {} }) end)

RegisterNetEvent('pam:client:catalog', function(kind, rows)
    SendNUIMessage({ type='PAM_CATALOG', kind=kind, payload=rows or {} })
end)

local function assignVehicleKeys(vehicle, plate)
    local cfg=Config.VehicleKeys or {}
    local provider=cfg.Provider or 'auto'
    local resource=cfg.Resource
    local event=cfg.ClientEvent
    if provider=='auto' then
        local choices={
            {name='qbx_vehiclekeys',resource='qbx_vehiclekeys',event='qb-vehiclekeys:client:AddKeys'},
            {name='qb-vehiclekeys',resource='qb-vehiclekeys',event='qb-vehiclekeys:client:AddKeys'},
            {name='qs-vehiclekeys',resource='qs-vehiclekeys',event='qs-vehiclekeys:client:AddKeys'},
            {name='renewed',resource='Renewed-Vehiclekeys',event='Renewed-Vehiclekeys:client:AddKeys'},
            {name='wasabi',resource='wasabi_carlock',event='wasabi_carlock:giveKey'}
        }
        for _,v in ipairs(choices) do if GetResourceState(v.resource)=='started' then provider=v.name;resource=v.resource;event=v.event;break end end
    end
    if provider=='disabled' then return false end
    resource=resource or ({qbx_vehiclekeys='qbx_vehiclekeys',['qb-vehiclekeys']='qb-vehiclekeys',['qs-vehiclekeys']='qs-vehiclekeys',renewed='Renewed-Vehiclekeys',wasabi='wasabi_carlock'})[provider]
    -- Qbox's own admin menu grants keys through this compatibility client event.
    -- Keep the server export as a second path, but do not skip the client-side key cache update.
    if provider=='qbx_vehiclekeys' then event=event or 'qb-vehiclekeys:client:AddKeys' end
    if provider=='qb-vehiclekeys' then event=event or 'qb-vehiclekeys:client:AddKeys' end
    if provider=='custom' then
        if cfg.CustomExport and resource and GetResourceState(resource)=='started' then
            local ok=pcall(function() exports[resource][cfg.CustomExport](vehicle,plate) end)
            if ok then return true end
        elseif event then TriggerEvent(event,vehicle,plate); return true end
    end
    if provider=='qb-vehiclekeys' then event=event or 'qb-vehiclekeys:client:AddKeys' end
    if provider=='qs-vehiclekeys' then event=event or 'qs-vehiclekeys:client:AddKeys' end
    if provider=='renewed' then event=event or 'Renewed-Vehiclekeys:client:AddKeys' end
    if provider=='wasabi' then event=event or 'wasabi_carlock:giveKey' end
    if event then TriggerEvent(event,plate); return true end
    return false
end

local function spawnAdminVehicle(modelName, plate)
    if type(modelName)~='string' then return false,'Invalid vehicle model.' end
    local hash=joaat(modelName)
    if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then return false,'Vehicle model is not valid on this client.' end
    RequestModel(hash)
    local deadline=GetGameTimer()+10000
    while not HasModelLoaded(hash) and GetGameTimer()<deadline do Wait(50) end
    if not HasModelLoaded(hash) then return false,'Vehicle model failed to load.' end
    local ped=PlayerPedId(); local coords=GetEntityCoords(ped); local heading=GetEntityHeading(ped)
    local vehicle=CreateVehicle(hash,coords.x,coords.y,coords.z+1.0,heading,true,false)
    if vehicle and vehicle~=0 then
        SetVehicleOnGroundProperly(vehicle); SetPedIntoVehicle(ped,vehicle,-1); SetEntityAsMissionEntity(vehicle,true,true)
        if plate and plate~='' then SetVehicleNumberPlateText(vehicle,plate) end
        local actualPlate=tostring(GetVehicleNumberPlateText(vehicle) or ''):gsub('^%s*(.-)%s*$','%1')
        NetworkRegisterEntityAsNetworked(vehicle)
        local netId=NetworkGetNetworkIdFromEntity(vehicle)
        local netDeadline=GetGameTimer()+3000
        while (not netId or netId==0) and GetGameTimer()<netDeadline do Wait(50); netId=NetworkGetNetworkIdFromEntity(vehicle) end
        if netId and netId~=0 then
            TriggerServerEvent('pam:server:vehicleSpawned',netId,actualPlate,modelName)
        else
            print('[PAM] Vehicle spawned but did not receive a network ID; server key assignment was not requested.')
        end
        -- Update the local key cache immediately; the server also attempts the
        -- provider's trusted server export after validating the network entity.
        assignVehicleKeys(vehicle,actualPlate)
        SetVehicleNeedsToBeHotwired(vehicle,false)
        SetVehicleHasBeenOwnedByPlayer(vehicle,true)
        SetVehicleIsStolen(vehicle,false)
        SetVehicleIsWanted(vehicle,false)
        SetVehicleEngineOn(vehicle,true,true,true)
        SetModelAsNoLongerNeeded(hash)
        return true,'Vehicle spawned: '..modelName
    end
    SetModelAsNoLongerNeeded(hash)
    return false,'Vehicle spawn failed.'
end

RegisterNetEvent('pam:client:spawnVehicle', function(modelName)
    local ok,message=spawnAdminVehicle(modelName)
    SendNUIMessage({type='PAM_ACTION_RESULT',payload={success=ok,message=message}})
end)
RegisterNetEvent('pam:client:receiveVehicle', function(modelName,plate)
    local ok,message=spawnAdminVehicle(modelName,plate)
    TriggerEvent('chat:addMessage',{args={'POWER ADMIN',ok and (message..' | Plate: '..tostring(plate)) or message}})
end)

RegisterNetEvent('pam:client:assignVehicleKeys',function(plate,netId)
    local vehicle=NetToVeh(tonumber(netId) or 0)
    if vehicle~=0 and DoesEntityExist(vehicle) then assignVehicleKeys(vehicle,plate) end
end)
