# Compatibility and customer setup matrix

This file is intended to ship with the Tebex download. It is a configuration guide, not a promise that every fork/version has been tested.

## Standard Qbox

Expected resources: `qbx_core`, `qbx_vehicles`, `qbx_garages`, `qbx_vehiclekeys`, `ox_lib`, `oxmysql`, `ox_inventory` (the garage/key resources are required only if you use those features).

```lua
Config.Framework = 'qbox'
Config.FrameworkResources.Qbox = 'qbx_core'
Config.Integrations.Inventory = 'ox_inventory'
Config.Integrations.OxInventoryResource = 'ox_inventory'
```

Supported with native APIs:

- Player data and money: qbx_core exports.
- Jobs: `GetJobs()`; creation: `CreateJob()` (runtime-only in qbx_core; PAM persists and restores definitions).
- Vehicle catalog: `qbx_core:GetVehiclesByName()`. Owned-vehicle registration: `qbx_vehicles:CreatePlayerVehicle()` with complete ox_lib properties, including `engineHealth`, `bodyHealth` and `fuelLevel`.
- Items: `ox_inventory:Items()` and `AddItem()`; capacity checked with `CanCarryItem()`.
- Player inventory inspection: `GetInventoryItems()`.
- New ox_inventory item definitions: not available through a generic live API in this integration. Add items through ox_inventory's own item definition workflow.

## QBCore

```lua
Config.Framework = 'qbcore'
Config.FrameworkResources.QBCore = 'qb-core'
Config.Integrations.Inventory = 'qb-inventory' -- or ox_inventory / framework
```

QBCore's shared vehicle, item and job tables are read through the core object. `qb-inventory` and `ox_inventory` have separate inventory adapters. If ox_inventory is selected, item definitions must be registered in ox_inventory itself; the QBCore shared item table alone is not sufficient for that inventory.

## ESX

```lua
Config.Framework = 'esx'
Config.FrameworkResources.ESX = 'es_extended'
Config.Integrations.Inventory = 'framework'
```

The default ESX item/vehicle/job reads use conventional ESX caches or SQL tables. ESX item creation assumes the conventional `items(name,label,weight)` schema. Job creation is deliberately not included because job-grade schema and reload behavior differ across ESX versions.

## Other inventory or framework forks

Use `Inventory = 'custom'` and implement the bridge in `integrations/custom_inventory.lua`. Set `Framework = 'custom'` and implement `integrations/custom_framework.lua` for a nonstandard framework. For custom vehicle/job sources, set the catalog selector to `custom` and implement the matching getter. Do not use a guessed export name: map the template to the exact version installed by the customer.

## Pre-support checklist

For each stack advertised on Tebex, record:

- Framework name and exact version/commit.
- Inventory name and exact version/commit.
- Database resource/version.
- FiveM server artifact tested.
- Whether item list, inventory inspection, item grant, item registration, job list, job registration, money changes, player dossier and spectate were tested.
- Console output and any fork-specific adapter changes.

A provider can be compatible for listing but not for live item registration. Keep those capabilities separate in the product listing and support matrix.


## Vehicle ownership integrations

Vehicle keys and garage ownership are independently configurable. Qbox key handoff updates the `qb-vehiclekeys:client:AddKeys` compatibility cache and also calls the `qbx_vehiclekeys:GiveKeys(source, vehicle, skipNotification)` server export. qb-vehiclekeys uses its server export. QS Vehicle Keys, Renewed Vehicle Keys and Wasabi Carlock use configurable client event hooks; verify the event name for your installed release. Qbox owned vehicles are registered through `qbx_vehicles:CreatePlayerVehicle`; QBCore uses a configurable `player_vehicles` mapping and ESX uses `owned_vehicles`. JG Advanced Garages, CD Garage, QS Advanced Garages and custom garage forks use `integrations/custom_garage.lua` because their schemas/APIs vary between releases. Do not advertise a named garage as plug-and-play until its adapter has been tested against the exact release and schema.
