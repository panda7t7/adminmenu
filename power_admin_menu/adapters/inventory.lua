-- Configurable inventory bridge. Custom inventories implement PAMCustomInventory below.
PAMInventory = {}

local function cfg()
    Config.Integrations = Config.Integrations or {}
    return Config.Integrations
end

function PAMInventory.Provider()
    local c = cfg()
    local provider = string.lower(c.Inventory or 'auto')
    if provider ~= 'auto' then return provider end
    if GetResourceState(c.OxInventoryResource or 'ox_inventory') == 'started' then return 'ox_inventory' end
    if GetResourceState(c.QBInventoryResource or 'qb-inventory') == 'started' then return 'qb-inventory' end
    if GetResourceState(c.QSInventoryResource or 'qs-inventory') == 'started' then return 'qs-inventory' end
    if Framework and Framework.Type == 'esx' then return 'framework' end
    return 'disabled'
end

local function resourceFor(provider)
    local c = cfg()
    if provider == 'ox_inventory' then return c.OxInventoryResource or 'ox_inventory' end
    if provider == 'qb-inventory' then return c.QBInventoryResource or 'qb-inventory' end
    if provider == 'qs-inventory' then return c.QSInventoryResource or 'qs-inventory' end
end

local function addOxItem(resource, source, name, amount, metadata)
    if GetResourceState(resource) ~= 'started' then return false, 'Configured ox_inventory resource is not started.' end
    local canCall, canCarry = pcall(function() return exports[resource]:CanCarryItem(source, name, amount) end)
    if not canCall then return false, 'ox_inventory CanCarryItem check failed: ' .. tostring(canCarry) end
    if canCarry ~= true then return false, 'Target inventory cannot carry that quantity.' end
    local ok, result = pcall(function() return exports[resource]:AddItem(source, name, amount, metadata or {}) end)
    return ok and result == true, ok and nil or tostring(result)
end

function PAMInventory.GetItems()
    local provider = PAMInventory.Provider()
    if provider == 'ox_inventory' then
        local resource = resourceFor(provider)
        if GetResourceState(resource) ~= 'started' then return {} end
        local ok, items = pcall(function() return exports[resource]:Items() end)
        return ok and type(items) == 'table' and items or {}
    elseif provider == 'framework' then
        if Framework.Type == 'esx' then
            local core = Framework.GetCore()
            return core and core.Items or {}
        elseif Framework.Type == 'qbcore' then
            local core = Framework.GetCore(); return core and core.Shared and core.Shared.Items or {}
        elseif Framework.Type == 'qbox' then
            local resource = cfg().OxInventoryResource or 'ox_inventory'
            if GetResourceState(resource) == 'started' then
                local ok, items = pcall(function() return exports[resource]:Items() end)
                return ok and type(items) == 'table' and items or {}
            end
        end
        return {}
    elseif provider == 'custom' and PAMCustomInventory and PAMCustomInventory.GetItems then
        local ok, items = pcall(PAMCustomInventory.GetItems)
        return ok and type(items) == 'table' and items or {}
    end
    return {}
end

function PAMInventory.GetPlayerItems(source)
    local provider = PAMInventory.Provider()
    if provider == 'ox_inventory' then
        local resource = resourceFor(provider)
        if GetResourceState(resource) ~= 'started' then return nil, 'integration_unavailable' end
        local ok, items = pcall(function() return exports[resource]:GetInventoryItems(source) end)
        return ok and items or nil, ok and 'available' or 'integration_error'
    elseif provider == 'qb-inventory' then
        local resource = resourceFor(provider)
        if GetResourceState(resource) ~= 'started' then return nil, 'integration_unavailable' end
        local ok, items = pcall(function() return exports[resource]:GetInventory(source) end)
        return ok and items or nil, ok and 'available' or 'integration_error'
    elseif provider == 'qs-inventory' then
        local resource = resourceFor(provider)
        if GetResourceState(resource) ~= 'started' then return nil, 'integration_unavailable' end
        local c = cfg()
        local exportName = c.QSInventoryGetExport or 'GetInventory'
        local ok, items = pcall(function() return exports[resource][exportName](source) end)
        return ok and items or nil, ok and 'available' or 'integration_error'
    elseif provider == 'custom' and PAMCustomInventory and PAMCustomInventory.GetPlayerItems then
        local ok, items = pcall(PAMCustomInventory.GetPlayerItems, source)
        return ok and items or nil, ok and 'available' or 'integration_error'
    elseif provider == 'framework' then
        if Framework.Type == 'qbox' then
            local resource = cfg().OxInventoryResource or 'ox_inventory'
            if GetResourceState(resource) == 'started' then
                local ok, items = pcall(function() return exports[resource]:GetInventoryItems(source) end)
                return ok and items or nil, ok and 'available' or 'integration_error'
            end
        end
        local items = Framework.GetInventory(source)
        return items, items and 'available' or 'integration_unavailable'
    end
    return nil, provider == 'disabled' and 'disabled' or 'unsupported_integration'
end

function PAMInventory.AddItem(source, name, amount, metadata)
    local provider = PAMInventory.Provider()
    if provider == 'ox_inventory' then
        return addOxItem(resourceFor(provider), source, name, amount, metadata)
    elseif provider == 'qb-inventory' then
        local resource = resourceFor(provider)
        if GetResourceState(resource) ~= 'started' then return false, 'Configured qb-inventory resource is not started.' end
        local ok, result = pcall(function() return exports[resource]:AddItem(source, name, amount, false, metadata or false, 'power-admin-menu') end)
        return ok and result == true, ok and nil or tostring(result)
    elseif provider == 'qs-inventory' then
        local resource = resourceFor(provider)
        if GetResourceState(resource) ~= 'started' then return false, 'Configured qs-inventory resource is not started.' end
        local c = cfg()
        local exportName = c.QSInventoryAddExport or 'AddItem'
        local ok, result = pcall(function() return exports[resource][exportName](source, name, amount, nil, metadata or {}) end)
        return ok and result ~= false, ok and nil or tostring(result)
    elseif provider == 'custom' and PAMCustomInventory and PAMCustomInventory.AddItem then
        local ok, result, message = pcall(PAMCustomInventory.AddItem, source, name, amount, metadata or {})
        return ok and result == true, ok and message or tostring(result)
    elseif provider == 'framework' and Framework.Type == 'esx' then
        local player = Framework.GetPlayer(source)
        if not player or not player.addInventoryItem then return false, 'ESX inventory API unavailable.' end
        local ok, result = pcall(player.addInventoryItem, name, amount)
        return ok and result ~= false, ok and nil or tostring(result)
    elseif provider == 'framework' and Framework.Type == 'qbcore' then
        local player = Framework.GetPlayer(source)
        local ok, result = pcall(function() return player and player.Functions and player.Functions.AddItem(name, amount, false, metadata or {}) end)
        return ok and result == true, ok and nil or tostring(result)
    elseif provider == 'framework' and Framework.Type == 'qbox' then
        return addOxItem(cfg().OxInventoryResource or 'ox_inventory', source, name, amount, metadata)
    end
    return false, ('No item-give adapter configured (provider: %s).'):format(provider)
end

function PAMInventory.CanRegisterItem()
    local provider = PAMInventory.Provider()
    if provider == 'custom' then return PAMCustomInventory and type(PAMCustomInventory.RegisterItem) == 'function' end
    if Framework.Type == 'qbcore' and (provider == 'framework' or provider == 'qb-inventory') then
        local core = Framework.GetCore()
        return core and core.Shared and core.Shared.Items ~= nil
    end
    if Framework.Type == 'esx' and provider == 'framework' then
        local core = Framework.GetCore()
        return core and core.Items ~= nil
    end
    return false
end

function PAMInventory.RegisterItem(definition)
    local provider = PAMInventory.Provider()
    if provider == 'custom' and PAMCustomInventory and PAMCustomInventory.RegisterItem then
        local ok, result, message = pcall(PAMCustomInventory.RegisterItem, definition)
        return ok and result == true, ok and message or tostring(result)
    end
    if Framework.Type == 'qbcore' and (provider == 'framework' or provider == 'qb-inventory') then
        local core = Framework.GetCore()
        if core and core.Shared and core.Shared.Items then core.Shared.Items[definition.name] = definition; return true end
    end
    if Framework.Type == 'esx' and provider == 'framework' then
        local core = Framework.GetCore()
        if core and core.Items then core.Items[definition.name] = definition; return true end
    end
    return false, 'This inventory does not expose a safe runtime item-registration API. Use the custom inventory bridge or register the item in its own configuration.'
end
