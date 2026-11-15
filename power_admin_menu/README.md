# Power Admin Menu — Configurable Integrations (1.3.0)

A modular FiveM administration resource with a Liquid Glass NUI. This release adds explicit framework/inventory providers, a native Qbox adapter, configurable resource names, and optional custom bridges so Tebex customers can map the resource to their server stack.

## Supported stacks

| Stack | Player/admin features | Catalog browsing | Give items | Create items | Create jobs |
|---|---|---|---|---|---|
| Qbox + ox_inventory (default Qbox) | Native qbx_core exports | Qbox vehicles/jobs + ox items | ox_inventory AddItem | Not through ox_inventory by default | qbx_core CreateJob; persisted by PAM and re-registered on start |
| QBCore + qb-inventory | QBCore adapter | QBCore shared catalog | qb-inventory export | QBCore shared item registry | QBCore shared job registry |
| QBCore + ox_inventory | QBCore adapter | QBCore vehicles/jobs + ox items | ox_inventory export | Requires a custom inventory registration bridge | QBCore shared job registry |
| ESX + ESX inventory | ESX adapter | SQL/framework catalogs | ESX addInventoryItem | Conventional ESX items SQL/cache path | Not included; use a custom ESX job bridge |
| ESX + external inventory | ESX player adapter + selected inventory provider | SQL/framework or custom catalog | Depends on selected provider | Custom registration bridge if supported | Custom framework bridge if supported |
| Custom framework/inventory | Template adapters in `integrations/` | Custom catalog getters | Custom inventory callback | Custom inventory callback | Custom framework callback |
| Standalone | ACE/staff access; limited player features | Custom catalogs only | Custom inventory callback | Custom inventory callback | Custom framework callback |

**Important:** Compatibility depends on the exact inventory fork and its exports. The built-in QS Inventory option exposes configurable export names, but you must confirm the signatures for your QS release. For any fork or inventory not matching the documented call shape, use the custom bridge rather than assuming compatibility.

## Requirements

- FiveM server artifact with Lua 5.4.
- `oxmysql` started before `power_admin_menu` (the SQL adapter in this release).
- MySQL/MariaDB configured in oxmysql.
- One of Qbox, QBCore, ESX, or a custom/standalone setup.
- The selected framework and inventory resources started before this resource.
- Default Qbox also requires its normal dependencies, including `ox_lib` and `ox_inventory`.

## Install — fresh server

1. Extract `power_admin_menu` into your resources folder.
2. Import `sql/install.sql`, then `sql/phase2_upgrade.sql`, then `sql/phase3_catalog_upgrade.sql` into your server database.
3. Edit `config.lua` and set framework/inventory providers to match your server.
4. Add startup lines after the relevant framework/inventory resources:

```cfg
ensure oxmysql
ensure ox_lib
ensure qbx_core       # Qbox example; use qb-core or es_extended for other stacks
ensure qbx_vehicles   # Qbox owned-vehicle registration API
ensure qbx_garages    # if using the default Qbox garage
ensure ox_inventory   # default Qbox inventory example
ensure power_admin_menu
```

5. Add staff identifiers or ACE permissions (examples below).
6. Restart and test on a staging server before production use.

## Upgrade

### From Phase 3 (1.2.x)

1. Back up resource and database.
2. Replace the full resource folder; preserve your staff identifiers and local config changes.
3. Keep the existing Phase 1/2/3 SQL tables. No migration is required for this integration-only update.
4. Review the new `Config.Integrations` and `Config.FrameworkResources` values, then restart.

### From Phase 2

Import `sql/phase3_catalog_upgrade.sql` once, then replace the resource folder and configure integrations.

### From Phase 1

Import `sql/phase2_upgrade.sql`, then `sql/phase3_catalog_upgrade.sql`, then replace the resource folder.

## Configuration

The main settings are in `config.lua`:

```lua
Config.Framework = 'auto' -- auto | qbox | qbcore | esx | standalone | custom
Config.FrameworkResources = {
    Qbox = 'qbx_core',
    QBCore = 'qb-core',
    ESX = 'es_extended'
}

Config.Integrations = {
    Inventory = 'auto', -- auto | ox_inventory | qb-inventory | qs-inventory | framework | custom | disabled
    OxInventoryResource = 'ox_inventory',
    QBInventoryResource = 'qb-inventory',
    QSInventoryResource = 'qs-inventory',
    QSInventoryGetExport = 'GetInventory',
    QSInventoryAddExport = 'AddItem',
    Catalogs = {
        Vehicles = 'framework', -- framework | custom
        Items = 'inventory',   -- inventory | custom
        Jobs = 'framework'     -- framework | custom
    }
}
```

### Default Qbox configuration

The default `auto` framework detection selects `qbx_core` before checking `qb-core`. With default Qbox and `ox_inventory`, `Inventory = 'auto'` selects ox_inventory automatically. You can make it explicit:

```lua
Config.Framework = 'qbox'
Config.Integrations.Inventory = 'ox_inventory'
Config.FrameworkResources.Qbox = 'qbx_core'
Config.Integrations.OxInventoryResource = 'ox_inventory'
```

Qbox integration uses native exports for `GetPlayer`, `GetJobs`, `GetVehiclesByName`, `AddMoney`, `RemoveMoney`, and `CreateJob`; it does not require `GetCoreObject()`.

- Vehicles are read from `qbx_core` and spawned after server-side catalog validation.
- Jobs are read from `qbx_core`. New jobs use `qbx_core:CreateJob`, which is runtime-only in Qbox. Power Admin Menu stores the definition in its own SQL table and calls `CreateJob` again after startup.
- Items are read from `ox_inventory:Items()` and given with `ox_inventory:AddItem()`.
- New ox_inventory item definitions are **not** dynamically registered by this resource. The item-creation UI stays unavailable unless a custom inventory registration bridge is configured. Add the definition using the inventory's supported item-registration workflow, usually its own item data configuration and restart, or implement the custom registration callback if your inventory version exposes a supported API.

## Inventory providers

- `auto`: chooses a started `ox_inventory`, `qb-inventory`, or `qs-inventory`; otherwise uses ESX framework inventory where applicable.
- `ox_inventory`: uses `Items`, `GetInventoryItems`, and `AddItem` exports.
- `qb-inventory`: uses `GetInventory` and `AddItem` exports. The AddItem call follows the documented six-argument qb-inventory signature.
- `qs-inventory`: calls the configured `QSInventoryGetExport` and `QSInventoryAddExport` names. Confirm your QS release's exact argument signatures; if different, use `custom`.
- `framework`: uses the native ESX/QBCore player inventory APIs; for Qbox it maps to ox_inventory.
- `custom`: delegates to functions in `integrations/custom_inventory.lua`.
- `disabled`: inventory viewing/giving is unavailable.

### Custom inventory bridge

Set `Config.Integrations.Inventory = 'custom'` and edit `integrations/custom_inventory.lua`. Implement only the functions your inventory supports:

- `PAMCustomInventory.GetItems()` — returns the item catalog map/table.
- `PAMCustomInventory.GetPlayerItems(source)` — returns a player's inventory.
- `PAMCustomInventory.AddItem(source, itemName, amount, metadata)` — return `true` only when the item was actually added.
- `PAMCustomInventory.RegisterItem(definition)` — optional; implement only if the inventory officially supports live registration.

Do not guess an export name or signature. Map the bridge to the exact installed inventory version and test add/carry/weight behavior on staging.

## Custom framework and custom catalogs

For a custom framework, set `Config.Framework = 'custom'` and implement the methods in `integrations/custom_framework.lua` as needed: `GetPlayer`, `GetIdentifier`, `GetCharacterId`, `GetCharacterName`, `GetJob`, `GetMoney`, `GetInventory`, `IsLoaded`, `AdjustMoney`, and optional `RegisterJob`. Return `true` only when a write succeeded.

To read custom vehicle/job registries, set the corresponding `Config.Integrations.Catalogs` value to `custom` and implement `PAMCustomCatalog.GetVehicles()` or `PAMCustomCatalog.GetJobs()` in `integrations/custom_inventory.lua`. To source the item catalog from a custom inventory, use `Inventory = 'custom'` and implement `PAMCustomInventory.GetItems()`.

Resource folder names can be changed in `Config.FrameworkResources` and the inventory resource-name fields. The database integration is currently oxmysql; it is not yet a pluggable database provider.

## Staff permissions

Configure staff identifiers in `Config.Staff`:

```lua
Config.Staff = {
    ['license:YOUR_LICENSE_IDENTIFIER'] = 'owner',
    ['license:ANOTHER_LICENSE_IDENTIFIER'] = 'headadmin'
}
```

Or use ACE:

```cfg
add_ace group.admin poweradmin.owner allow
add_principal identifier.license:YOUR_LICENSE_IDENTIFIER group.admin
```

Sensitive operations are checked again server-side. NUI visibility is not treated as authorization.

## Modules

- Dashboard and online player list.
- Player dossiers, identifiers (opt-in), inventory inspection, money adjustment, notes, warnings, bans/unbans, activity history and spectating.
- Vehicle catalog with categories/search and server-validated spawning.
- Item catalog/search, permission-gated quantity grants and provider-aware item registration.
- Job catalog/search and QBCore/Qbox runtime job creation.
- Audit logging and persistent moderation data.

## Permissions

| Permission | Purpose |
|---|---|
| `players.view`, `players.dossier` | Online players and dossiers |
| `players.identifiers` | Identifier display (also requires privacy config) |
| `players.inventory` | Read-only inventory inspection |
| `players.money.view`, `players.money.modify` | View and adjust cash/bank with reason |
| `players.notes.view`, `players.notes.add` | Staff notes |
| `players.history` | Warnings, bans and recorded activity |
| `players.warn`, `players.ban`, `players.unban` | Moderation actions |
| `players.spectate`, `players.teleport`, `players.bring`, `players.freeze`, `players.heal`, `players.kick` | Player controls |
| `vehicles.view`, `vehicles.spawn` | Vehicle catalog and spawning |
| `items.view`, `items.give`, `items.create` | Item catalog, grants and supported registration |
| `jobs.view`, `jobs.create` | Job catalog and supported runtime registration |
| `audit.view`, `resources.view`, `staff.view` | Admin visibility tools |

## Known limitations

- The database provider is oxmysql only in this release.
- A generic live item registration API is not provided by ox_inventory. Its item definitions are managed by ox_inventory itself.
- Qbox `CreateJob` is runtime-only in qbx_core. Power Admin persists the definition separately and restores it at startup, but other scripts may cache jobs and may need to refresh their own data.
- QBCore dynamic item/job registration updates the running server shared table; it does not rewrite framework Lua source files or guarantee every third-party client cache refreshes.
- ESX job creation is not included because ESX job/grade schemas and cache-refresh APIs vary. Use a custom framework bridge for a specific ESX fork.
- QS Inventory and custom/forked resources must be mapped to their actual exports through the custom bridge if their signatures differ.
- Owned-vehicle lookup is disabled by default and requires the actual table/column mapping in `Config.PlayerIntelligence.OwnedVehicles`.
- Activity history only contains events observed/recorded by Power Admin after installation; it does not capture arbitrary events from other resources.
- Spectating and vehicle spawning must be tested against the server artifact/game build and any entity ownership/persistence scripts.

## Tebex release checklist

Before publishing, test every advertised framework/inventory combination on a clean staging server. Include the tested server artifact, framework and inventory versions in the Tebex listing. Ship the untouched `integrations/` templates, this README, SQL migrations and a support checklist. Do not advertise a fork as supported until its export signatures have been tested. This package does not include Tebex/Cfx escrow or a license-verification system; configure those separately if required by your distribution plan.

## Validation status

The JavaScript source is syntax-checked with Node, Lua files are syntax-checked with the available Lua parser, and the release ZIP is integrity-checked. No live FiveM framework, inventory or MySQL server is available in this build environment. Therefore this is a code-level compatibility update, not a claim that every listed combination has passed an in-game integration test.


## Vehicle spawn keys and player garage delivery (v1.4)

Vehicle Catalog now has two separate actions:

- **Spawn for me** creates a temporary admin vehicle and requests keys.
- **Give + Garage** inserts an owned-vehicle record for a selected connected player, then asks that player's client to spawn it with the generated plate and requests keys.

Configure these providers in `config.lua`:

```lua
Config.VehicleKeys = {
    Provider = 'auto', -- auto | qbx_vehiclekeys | qb-vehiclekeys | qs-vehiclekeys | renewed | wasabi | custom | disabled
    Resource = nil,
    ClientEvent = nil,
    CustomExport = nil,
    ServerExport = 'GiveKeys'
}

Config.VehicleGarage = {
    Provider = 'qbox', -- qbox | qbcore | esx | jg_advancedgarages | cd_garage | qs_advancedgarages | custom | disabled
    Table = 'player_vehicles',
    Columns = { License='license', CitizenId='citizenid', Vehicle='vehicle', Hash='hash', Mods='mods', Plate='plate', Garage='garage', Fuel='fuel', Engine='engine', Body='body', State='state' },
    DefaultGarage = 'pillboxgarage'
}
```

### Built-in garage storage

- `qbox` and `qbcore`: inserts the conventional `player_vehicles` record. The configured table/columns and default garage must match the installed garage resource's schema/configuration.
- `esx`: inserts the conventional `owned_vehicles` record; configure the `VehicleGarage.ESX` mapping for your ESX schema.
- `disabled`: turns off garage delivery.

### Other garage resources / custom garages

JG Advanced Garages, CD Garage, QS Advanced Garages and other forks differ by version and database schema. Select the matching provider name (or `custom`) and implement `PAMCustomGarage.AddVehicle(target, vehicleData)` in `integrations/custom_garage.lua`. The bridge receives model, hash, plate, properties, player identifiers, garage, fuel, engine and body values. It must return `true` only after the garage confirms the vehicle was saved. This is intentionally an adapter hook, not a claim that every third-party schema is identical.

### Vehicle keys

`auto` checks for `qbx_vehiclekeys`, `qb-vehiclekeys`, `qs-vehiclekeys`, `Renewed-Vehiclekeys`, then `wasabi_carlock`. Qbox uses the Qbox-compatible `qb-vehiclekeys:client:AddKeys` event to update the player's client key cache, with the `qbx_vehiclekeys:GiveKeys(source, vehicle, skipNotification)` server export as an additional grant path. qb-vehiclekeys uses its server-side `GiveKeys` export; other providers use their configured client event or custom export. Forks often rename events/exports, so configure `Provider`, `Resource`, `ClientEvent`, `CustomExport` or `ServerExport` to match the installed version. Set `Provider='disabled'` if the server has no key resource.

### Security and important notes

- Only staff with `vehicles.give` can add owned vehicles. The target must be a connected player.
- Vehicle model names are validated against the server vehicle catalog before delivery.
- Key handoff validates that the reported network entity belongs to the requesting player and matches the requested model.
- The garage record is saved before client delivery. If the target disconnects or the client cannot load the model, the vehicle remains in their garage for later retrieval.
- For custom garage support, confirm the custom adapter's insert/export semantics and plate uniqueness against that garage's documentation before production use.
- Set `DefaultGarage` to an actual garage identifier from your server. `pillboxgarage` is only a common default, not guaranteed to exist on every server.


### Live vector tool
Staff with dashboard access can use `/vector` to open a non-focus right-side coordinate panel. Move normally while it displays live coordinates. Use Up/Down (or Left/Right) to select `vector3`, `vec3`, `vector4` or `vec4`, Enter to copy, and Escape to close. Vector4 formats include the player's heading as the fourth component.


### Developer Tools: Coords
The Developer Tools section includes **Coords**. Selecting it closes the main admin menu and opens the same non-blocking live coordinate panel as `/vector`. Use Up/Down or Left/Right to select `vector3`, `vec3`, `vector4`, or `vec4`; press Enter to copy without closing; press Escape to close. The action uses the same server-side staff permission validation as `/vector`.


## Developer Tools: Coords and Laser Object Mode

Open **Developer Tools → Coords** or run `/vector`. The mini panel stays mouse-cursor-free. Use the arrow keys to select `vector3`, `vec3`, `vector4`, `vec4`, or **Laser Object Mode**. Press Enter to copy the selected player-coordinate format, or Enter on Laser Object Mode to toggle it.

When Laser Object Mode is enabled, aim at a ped, vehicle, or object to see its type, model hash, entity/network ID, health (where applicable), coordinates, heading, distance, and type-specific details. A continuous beam is drawn from the active camera; it turns green and a green 3D bounding box appears when a valid entity is targeted. The box follows the entity's model dimensions and transform, including rotated props. Hotkeys: **L** toggles the laser, **C** copies the targeted entity coordinates using the selected vector format, **Delete** requests deletion, and **Esc** closes the panel. Deletion is checked server-side with the `entities.delete` permission and recorded in the audit log. Networked entities require client network control before deletion; non-networked local map entities are removed on the requesting client only and may be recreated by world streaming.


### Previous laser implementation (v1.5.5–v1.5.7)
These earlier releases used a retained asynchronous shape-test handle. That implementation is superseded by the v1.5.8 rebuild below.


### Laser Object Mode rebuild (v1.5.8)
The laser scanner has been rebuilt to use a fresh camera ray per frame, without retaining asynchronous ray handles. The beam remains visible even when the ray hits the road or another non-entity surface. Entity properties are only queried after the hit handle has been validated. The green outline uses transformed model-space corners and does not depend on ground-height queries.

### Developer Tools — Spawn Object
The Developer Tools page includes a Spawn Object utility for staff with the `entities.spawn` permission. Enter a GTA object model name or choose a quick pick. The client validates the model using supported model natives, creates a transparent preview, and verifies that the preview entity is an object (entity type 3). A touch-friendly in-world transform panel provides independent X/Y/Z movement and X/Y/Z rotation controls, separate movement and rotation increments, live position/rotation readouts, reset controls, visible world-space XYZ axis guides, and Place/Cancel actions. Keyboard fallback: WASD moves on X/Y, Page Up/Down moves on Z, arrow keys rotate Z, Q/R rotate X, mouse wheel changes the camera placement distance, Enter places, and Backspace/Escape cancels. The final prop is created as a networked entity and frozen in place. Add `entities.spawn` to the desired role in `config.lua` or grant the matching ACE permission (`poweradmin.entities.spawn`).


### Developer Tools: GTA V object catalogue

The Spawn Object browser can load the public FiveM object-name catalogue from FAM Tools (`https://fam-tools.com/data/props.json`) and displays reference thumbnails where available (`https://fam-tools.com/props-3d/thumb/`). The catalogue includes 21,631 createable object model names across props, interiors, mission, world/DLC and helper groups. The catalogue is loaded lazily in the NUI and filtered locally; only the first 72 matching entries are rendered at a time.

**Network note:** the in-menu catalogue and remote thumbnails require the player's NUI browser to have internet access. If the catalogue cannot be reached, staff can still enter a GTA or streamed add-on model name manually. The image references are community reference thumbnails, not bundled Rockstar game assets. Data credit: [FAM Tools GTA 5 createable object models](https://fam-tools.com/props).


## Developer Tools: Persistent and Temporary Props

Open Developer Tools → Spawn Object, choose a model, then select its lifetime before placing it with the existing transform gizmo:

- **Persistent** — saved in the pam_managed_props table and recreated at the saved coordinates and rotation after the resource/server restarts.
- **Temporary** — tracked in server memory for the current session only and removed when the resource/server stops or restarts.

The **Placed Props** area is split into **Persistent Props** and **Temporary Props**. It shows each managed model, ID, position and rotation. Staff with entities.manage can refresh the list, edit a prop with the same gizmo, or delete it. Deleting a persistent prop removes its database row as well as its managed world entity, so it will not return at the next restart. Temporary props remain until deleted or the server/resource session ends.

### SQL migration for existing installations

Back up your database, then import sql/managed_props.sql once. Fresh installations also receive the table automatically from the updated sql/install.sql. Do not drop the existing Power Admin tables.

Grant both entities.spawn and entities.manage to staff who should place props. The default owner, headadmin and admin roles include these permissions. Custom roles must be granted both permissions (or the equivalent ACE permissions poweradmin.entities.spawn and poweradmin.entities.manage).

**Scope and safety:** the manager only lists and deletes props registered by this feature. It does not enumerate or delete unrelated map props or entities spawned by other resources. Persistent restoration requires the configured oxmysql database to be available when Power Admin starts. Test on a staging server with OneSync enabled before production use.
