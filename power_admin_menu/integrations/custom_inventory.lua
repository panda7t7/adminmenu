-- OPTIONAL CUSTOM SERVER-SCRIPT BRIDGES
-- Configure the corresponding provider as 'custom' in config.lua.
-- This file is intentionally safe to ship as a template. Edit it to call your own resources.

PAMCustomInventory = PAMCustomInventory or {}
PAMCustomCatalog = PAMCustomCatalog or {}

-- INVENTORY FUNCTIONS (Config.Integrations.Inventory = 'custom')
-- function PAMCustomInventory.GetItems()
--     return exports['your_inventory']:GetItemList()
-- end
-- function PAMCustomInventory.GetPlayerItems(source)
--     return exports['your_inventory']:GetInventory(source)
-- end
-- function PAMCustomInventory.AddItem(source, itemName, amount, metadata)
--     local success = exports['your_inventory']:AddItem(source, itemName, amount, metadata)
--     return success == true, success and nil or 'Inventory rejected the item.'
-- end
-- function PAMCustomInventory.RegisterItem(definition)
--     -- Only implement if the inventory officially supports runtime registration.
--     local success = exports['your_inventory']:RegisterItem(definition)
--     return success == true, success and nil or 'Item registration failed.'
-- end

-- CATALOG FUNCTIONS (set Catalogs.Vehicles/Jobs = 'custom')
-- Each getter returns a map or array of definitions. Vehicle definitions need a model/name.
-- function PAMCustomCatalog.GetVehicles()
--     return exports['your_vehicle_resource']:GetVehicleCatalog()
-- end
-- function PAMCustomCatalog.GetJobs()
--     return exports['your_job_resource']:GetJobs()
-- end
