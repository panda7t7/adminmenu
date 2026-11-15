-- Live catalog and runtime definitions for vehicles, items and jobs.
Catalog = { Vehicles = {}, Items = {}, Jobs = {} }
local function qboxResource() return Config.FrameworkResources and Config.FrameworkResources.Qbox or 'qbx_core' end
local function safeName(v) return type(v)=='string' and v:lower():match('^[a-z0-9_%-]+$') and #v<=64 end
local function copyRows(t, categoryField)
    local out = {}
    for name, value in pairs(t or {}) do
        if type(value)=='table' then
            local row = {}
            for k,v in pairs(value) do if type(v)=='string' or type(v)=='number' or type(v)=='boolean' then row[k]=v end end
            row.name = row.name or name
            row.category = row.category or row[categoryField] or 'Other'
            out[#out+1]=row
        end
    end
    table.sort(out,function(a,b) return tostring(a.name):lower()<tostring(b.name):lower() end)
    return out
end

local function frameworkShared(kind)
    local catalogConfig = Config.Integrations and Config.Integrations.Catalogs or {}
    if catalogConfig[kind] == 'custom' and PAMCustomCatalog then
        local getter = PAMCustomCatalog['Get' .. kind]
        if type(getter) == 'function' then
            local ok, result = pcall(getter)
            if ok and type(result) == 'table' then return result end
        end
        return {}
    end
    if Framework.Type=='qbcore' then
        local core = Framework.GetCore and Framework.GetCore()
        local shared = core and core.Shared
        return shared and shared[kind] or {}
    elseif Framework.Type=='qbox' then
        local ok, result = false, nil
        if kind=='Jobs' then ok,result=pcall(function() return exports[qboxResource()]:GetJobs() end)
        elseif kind=='Vehicles' then ok,result=pcall(function() return exports[qboxResource()]:GetVehiclesByName() end)
        elseif kind=='Items' and PAMInventory then result=PAMInventory.GetItems(); ok=true end
        return ok and type(result)=='table' and result or {}
    end
    return {}
end

function Catalog.Refresh(kind)
    if kind=='vehicles' then
        local src = frameworkShared('Vehicles')
        Catalog.Vehicles = copyRows(src, 'category')
        if #Catalog.Vehicles==0 and Framework.Type=='esx' and Database.Ready then
            local ok, rows=pcall(function() return MySQL.query.await('SELECT name, model, category FROM vehicles') end)
            if not ok then ok,rows=pcall(function() return MySQL.query.await('SELECT name, model FROM vehicles') end) end
            if ok and rows then Catalog.Vehicles=rows end
        end
        for _, row in ipairs(Catalog.Vehicles) do row.spawnName=row.spawnName or row.model or row.name end
        return Catalog.Vehicles
    elseif kind=='items' then
        local src=frameworkShared('Items')
        Catalog.Items=copyRows(src,'type')
        if #Catalog.Items==0 and Framework.Type=='esx' and Database.Ready then
            local ok, rows=pcall(function() return MySQL.query.await('SELECT name, label, weight FROM items') end)
            if not ok then ok,rows=pcall(function() return MySQL.query.await('SELECT name, label FROM items') end) end
            if ok and rows then Catalog.Items=rows end
        end
        for _,row in ipairs(Catalog.Items) do row.label=row.label or row.name end
        return Catalog.Items
    elseif kind=='jobs' then
        local src=frameworkShared('Jobs')
        Catalog.Jobs=copyRows(src,'type')
        if #Catalog.Jobs==0 and Framework.Type=='esx' and Database.Ready then
            local ok, rows=pcall(function() return MySQL.query.await('SELECT name, label FROM jobs') end)
            if ok and rows then Catalog.Jobs=rows end
        end
        return Catalog.Jobs
    end
    return {}
end


function Catalog.LoadDynamic()
    if not Database.Ready then return end
    local ok, rows=pcall(function() return MySQL.query.await('SELECT definition_type, definition_name, definition_json FROM pam_dynamic_definitions') end)
    if not ok or not rows then return end
    local core=Framework.GetCore and Framework.GetCore()
    for _,r in ipairs(rows) do
        local good,def=pcall(json.decode,r.definition_json or '{}')
        if good and type(def)=='table' then
            if r.definition_type=='item' then
                Catalog.Items[#Catalog.Items+1]=def
                if Framework.Type=='qbcore' and core and core.Shared and core.Shared.Items then core.Shared.Items[r.definition_name]=def end
                if PAMInventory and (Framework.Type=='qbox' or PAMInventory.Provider()=='custom') then
                    local registered, registerMessage=PAMInventory.RegisterItem(def)
                    if not registered then print(('^3[PAM] Saved item %s is not registered in the active inventory: %s^7'):format(r.definition_name,tostring(registerMessage))) end
                end
                if Framework.Type=='esx' and Framework.GetCore() and Framework.GetCore().Items then Framework.GetCore().Items[r.definition_name]=def end
            elseif r.definition_type=='job' then
                Catalog.Jobs[#Catalog.Jobs+1]=def
                if Framework.Type=='qbcore' and core and core.Shared and core.Shared.Jobs then core.Shared.Jobs[r.definition_name]=def end
                if Framework.Type=='qbox' then
                    local qboxDef={name=r.definition_name,label=def.label,type=def.type or 'none',defaultDuty=def.defaultDuty~=false,offDutyPay=def.offDutyPay==true,grades={}}
                    for level,grade in pairs(def.grades or {}) do qboxDef.grades[tonumber(level) or level]=grade end
                    local registered, result=pcall(function() return exports[qboxResource()]:CreateJob(r.definition_name,qboxDef) end)
                    if not registered or result ~= true then print(('^1[PAM] Could not restore Qbox job %s: %s^7'):format(r.definition_name,tostring(result))) end
                end
                if Framework.Type=='esx' and Framework.GetCore() and Framework.GetCore().Jobs then Framework.GetCore().Jobs[r.definition_name]=def end
            end
        end
    end
end

local function sendCatalog(src,kind)
    if kind=='vehicles' and not Permissions.Has(src,'vehicles.view') then return end
    if kind=='items' and not Permissions.Has(src,'items.view') then return end
    if kind=='jobs' and not Permissions.Has(src,'jobs.view') then return end
    TriggerClientEvent('pam:client:catalog',src,kind,Catalog.Refresh(kind))
end
RegisterNetEvent('pam:server:catalog',function(kind)
    local src=source
    if not Security.AllowRequest(src) then return end
    if kind~='vehicles' and kind~='items' and kind~='jobs' then return end
    sendCatalog(src,kind)
end)

local function persist(kind,name,definition,src)
    if not Database.Ready then return false,'Database unavailable.' end
    local ok,err=pcall(function()
        MySQL.insert.await('INSERT INTO pam_dynamic_definitions (definition_type, definition_name, definition_json, created_by) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE definition_json=VALUES(definition_json), created_by=VALUES(created_by)',{kind,name,json.encode(definition),Framework.GetIdentifier(src) or 'unknown'})
    end)
    if not ok then print(('^1[PAM] Dynamic definition save failed: %s^7'):format(err)); return false,'Could not save definition.' end
    return true
end

function Catalog.Handle(src,p)
    local a=p.action
    if a=='vehicle.spawn' then
        if not Permissions.Has(src,'vehicles.spawn') then return true,false,'Permission denied.' end
        local model=type(p.model)=='string' and p.model:lower() or ''
        if not safeName(model) then return true,false,'Invalid vehicle spawn name.' end
        local found=false
        for _,v in ipairs(Catalog.Refresh('vehicles')) do if tostring(v.spawnName or v.model or v.name):lower()==model then found=true break end end
        if not found then return true,false,'Vehicle is not in the server vehicle catalog.' end
        TriggerClientEvent('pam:client:spawnVehicle',src,model)
        Audit.Record(src,'vehicle.spawn',nil,{model=model},true)
        return true,true,'Vehicle spawn requested.'
    elseif a=='vehicle.give' then
        if not Permissions.Has(src,'vehicles.give') then return true,false,'Permission denied.' end
        local target=tonumber(p.target)
        local model=type(p.model)=='string' and p.model:lower() or ''
        if not target or not GetPlayerName(target) or not safeName(model) then return true,false,'Invalid target or vehicle model.' end
        if not Framework.IsLoaded(target) then return true,false,'Target framework player is not loaded.' end
        local found=false
        for _,v in ipairs(Catalog.Refresh('vehicles')) do if tostring(v.spawnName or v.model or v.name):lower()==model then found=true break end end
        if not found then return true,false,'Vehicle is not in the server vehicle catalog.' end
        local ok,plate=VehicleOwnership.Give(src,target,model)
        if not ok then return true,false,plate end
        return true,true,('Vehicle %s registered in the player garage (plate %s); delivery and key assignment started.'):format(model,plate)
    elseif a=='item.give' then
        if not Permissions.Has(src,'items.give') then return true,false,'Permission denied.' end
        local target=tonumber(p.target); local name=type(p.name)=='string' and p.name:lower() or ''; local amount=tonumber(p.amount)
        if not target or not GetPlayerName(target) or (target~=src and not Security.ValidTarget(src,target)) or not safeName(name) or not amount or amount%1~=0 or amount<1 or amount>10000 then return true,false,'Invalid target, item or quantity.' end
        local exists=false; for _,v in ipairs(Catalog.Refresh('items')) do if v.name==name then exists=true break end end
        if not exists then return true,false,'Item not found in the live item catalog.' end
        if not Framework.IsLoaded(target) then return true,false,'Target framework player unavailable.' end
        local ok, inventoryError = PAMInventory.AddItem(target, name, amount, { reason = 'power-admin-menu' })
        if not ok then return true,false,inventoryError or 'Configured inventory adapter could not add this item.' end
        Audit.Record(src,'item.give',target,{item=name,amount=amount},true)
        return true,true,('Gave %sx %s.'):format(amount,name)
    elseif a=='item.create' then
        if not Permissions.Has(src,'items.create') then return true,false,'Permission denied.' end
        local name=type(p.name)=='string' and p.name:lower() or ''
        local label=type(p.label)=='string' and PAM.SafeString(p.label,80) or nil
        local weight=tonumber(p.weight) or 0
        if not safeName(name) or not label or not weight or weight%1~=0 or weight<0 or weight>100000 then return true,false,'Invalid item name, label or weight.' end
        for _,v in ipairs(Catalog.Refresh('items')) do if v.name==name then return true,false,'An item with this name already exists.' end end
        local def={name=name,label=label,weight=weight,type='item',image=type(p.image)=='string' and PAM.SafeString(p.image,120) or nil,unique=p.unique==true,useable=p.useable==true,shouldClose=p.shouldClose~=false,description=type(p.description)=='string' and PAM.SafeString(p.description,250) or ''}
        local saved,msg=persist('item',name,def,src); if not saved then return true,false,msg end
        if Framework.Type=='qbox' then
            local registered, registerMessage = PAMInventory.RegisterItem(def)
            if not registered then
                MySQL.update.await('DELETE FROM pam_dynamic_definitions WHERE definition_type = ? AND definition_name = ?', {'item', name})
                return true,false,registerMessage
            end
        elseif Framework.Type=='qbcore' then
            local registered, registerMessage=PAMInventory.RegisterItem(def)
            if not registered then
                MySQL.update.await('DELETE FROM pam_dynamic_definitions WHERE definition_type = ? AND definition_name = ?', {'item', name})
                return true,false,registerMessage
            end
        elseif Framework.Type=='custom' then
            local registered, registerMessage=PAMInventory.RegisterItem(def)
            if not registered then
                MySQL.update.await('DELETE FROM pam_dynamic_definitions WHERE definition_type = ? AND definition_name = ?', {'item', name})
                return true,false,registerMessage
            end
        elseif Framework.Type=='esx' then
            local ok=pcall(function() MySQL.insert.await('INSERT INTO items (name, label, weight) VALUES (?, ?, ?)',{name,label,weight}) end)
            if not ok then
                MySQL.update.await('DELETE FROM pam_dynamic_definitions WHERE definition_type = ? AND definition_name = ?', {'item', name})
                return true,false,'ESX items table insert failed.'
            end
            local esx=Framework.GetCore(); if esx and esx.Items then esx.Items[name]=def end
        else return true,false,'Creating framework items requires ESX, QBCore or a custom inventory registration bridge.' end
        Catalog.Refresh('items')
        Audit.Record(src,'item.create',nil,{name=name,label=label},true)
        TriggerClientEvent('pam:client:catalog',src,'items',Catalog.Items)
        return true,true,'Item registered in the live server registry and persisted. Some inventory resources cache item definitions and may require their own refresh.'
    elseif a=='job.create' then
        if not Permissions.Has(src,'jobs.create') then return true,false,'Permission denied.' end
        local name=type(p.name)=='string' and p.name:lower() or ''; local label=type(p.label)=='string' and PAM.SafeString(p.label,80) or nil
        if not safeName(name) or not label then return true,false,'Invalid job name or label.' end
        for _,v in ipairs(Catalog.Refresh('jobs')) do if v.name==name then return true,false,'A job with this name already exists.' end end
        local grades={}
        if type(p.grades)=='table' then
            for k,g in pairs(p.grades) do local level=tonumber(k); if level and level%1==0 and level>=0 and level<=20 and type(g)=='table' then grades[tostring(level)]={name=PAM.SafeString(g.name or ('Grade '..level),40) or ('Grade '..level),payment=math.max(0,math.min(1000000,tonumber(g.payment) or 0)),isboss=g.isboss==true} end end
        end
        if not grades['0'] then grades['0']={name='Recruit',payment=0,isboss=false} end
        local jobType=type(p.type)=='string' and PAM.SafeString(p.type,32) or 'none'
        local def={name=name,label=label,type=jobType,defaultDuty=p.defaultDuty~=false,offDutyPay=p.offDutyPay==true,grades=grades}
        local saved,msg=persist('job',name,def,src); if not saved then return true,false,msg end
        if Framework.Type=='qbox' then
            local qboxDef={name=name,label=label,type=jobType,defaultDuty=def.defaultDuty,offDutyPay=def.offDutyPay,grades={}}
            for level,grade in pairs(grades) do qboxDef.grades[tonumber(level)]=grade end
            local ok, success, response=pcall(function() return exports[qboxResource()]:CreateJob(name,qboxDef) end)
            if not ok or success ~= true then
                MySQL.update.await('DELETE FROM pam_dynamic_definitions WHERE definition_type = ? AND definition_name = ?', {'job', name})
                return true,false,(ok and (type(response)=='table' and response.message or tostring(response)) or 'Qbox CreateJob export failed.')
            end
        elseif Framework.Type=='qbcore' then
            local core=Framework.GetCore()
            if not core or not core.Shared or not core.Shared.Jobs then
                MySQL.update.await('DELETE FROM pam_dynamic_definitions WHERE definition_type = ? AND definition_name = ?', {'job', name})
                return true,false,'QBCore shared job registry unavailable.'
            end
            core.Shared.Jobs[name]=def
        elseif Framework.Type=='esx' then
            MySQL.update.await('DELETE FROM pam_dynamic_definitions WHERE definition_type = ? AND definition_name = ?', {'job', name})
            return true,false,'ESX job creation requires a framework-specific jobs/job_grades migration and cache refresh.'
        elseif Framework.Type=='custom' and PAMCustomFramework and PAMCustomFramework.RegisterJob then
            local customOk, customSuccess, customMessage=pcall(PAMCustomFramework.RegisterJob,name,def)
            if not customOk or customSuccess ~= true then
                MySQL.update.await('DELETE FROM pam_dynamic_definitions WHERE definition_type = ? AND definition_name = ?', {'job', name})
                return true,false,customOk and (customMessage or 'Custom framework rejected the job.') or tostring(customSuccess)
            end
        else
            MySQL.update.await('DELETE FROM pam_dynamic_definitions WHERE definition_type = ? AND definition_name = ?', {'job', name})
            return true,false,'Creating jobs requires a supported framework job-registration adapter.'
        end
        Catalog.Refresh('jobs')
        Audit.Record(src,'job.create',nil,{name=name,label=label},true)
        TriggerClientEvent('pam:client:catalog',src,'jobs',Catalog.Jobs)
        return true,true,Framework.Type=='qbox' and 'Job registered with qbx_core at runtime and saved by Power Admin Menu for re-registration after restart.' or 'Job added to the live QBCore server registry and persisted. Existing client shared.lua caches are not rewritten.'
    end
    return nil
end

CreateThread(function()
    Wait(1500)
    if Database.Ready then Catalog.LoadDynamic() end
end)
