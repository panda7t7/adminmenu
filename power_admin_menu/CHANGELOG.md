# Changelog

## 1.6.1 - Object placer and transform gizmo fix
- Removed the unsupported `IsModelAnObject` call that caused object placement to fail with a nil-global error.
- Validates model availability, creates a preview, and confirms the preview entity type is an object before allowing placement.
- Added a touch-friendly in-world transform panel with independent world-axis X/Y/Z movement and Euler X/Y/Z rotation controls.
- Added independent movement and rotation increments, live coordinate and rotation readouts, reset controls, visible world-space XYZ axis guides, and explicit Place/Cancel buttons.
- Added keyboard fallbacks, retained camera-aim surface placement and mouse-wheel distance adjustment, and reliably releases NUI focus on place/cancel/resource stop.

## 1.4.3 - Qbox vehicle keys and garage properties
- Fixed Qbox key assignment so the client vehicle-key cache is updated through the Qbox-compatible `qb-vehiclekeys:client:AddKeys` event; the server export remains an additional grant path.
- Qbox garage delivery now uses the supported `qbx_vehicles:CreatePlayerVehicle` export instead of a hand-built `player_vehicles` SQL insert.
- Saved vehicle properties now include numeric `engineHealth`, `bodyHealth`, `fuelLevel`, `tankHealth`, and `dirtLevel`, preventing qbx_garages vehicle-info arithmetic errors.
- Added explicit errors when qbx_vehicles is not started or rejects a vehicle registration.
- Added a one-time SQL repair script for vehicles created by older builds with incomplete properties.

## 1.4.2 - Vehicle target list and key handoff
- Included the current admin in the vehicle delivery target dropdown and labeled the admin entry as YOU.
- Refreshed connected-player data while the Vehicles page is open and updated the target dropdown when the server sends a new player snapshot.
- Changed player refresh to update only the player list instead of reopening/resetting the menu.
- Waited for a valid network ID before requesting server-side vehicle key assignment.
- Removed a fragile network-owner equality check that could reject a valid spawned vehicle after ownership migration; retained entity existence, type and model validation.
- Kept Qbox and qb-vehiclekeys key grants on their server-side exports.

## 1.4.1 - Responsive UI and scrolling
- Fixed flex/grid min-height constraints that could prevent long catalog pages from scrolling to the Create New Job section.
- Made the main content area independently vertically scrollable with touch-friendly overscroll and visible scrollbars.
- Added compact-height desktop layout rules and responsive tablet/mobile navigation, forms, tables and dialogs.
- Made job creation form fields adapt to narrow screens and prevented textarea/form overflow.

## 1.4.0 - Vehicle ownership and keys
- Added separate spawn-for-admin and give-to-player/garage-delivery actions.
- Added configurable vehicle-key provider detection and server-side Qbox/QB key exports.
- Added Qbox/QBCore and ESX garage database mappings plus custom garage bridge.
- Added vehicle give permission and delivery target selection.

## 1.3.0-configurable-integrations
- Replaced Qbox's legacy core-object dependency with native qbx_core player, money, shared-catalog and runtime job exports.
- Added independent inventory provider selection for ox_inventory, qb-inventory, qs-inventory, framework, custom and disabled modes.
- Added configurable inventory resource names and configurable Qbox/QBCore/ESX resource names.
- Added custom inventory, custom framework and custom catalog bridge templates for Tebex customers running forks or bespoke resources.
- Routed item grants and player inventory inspection through the selected inventory provider.
- Exposed integration capability information to the UI so unsupported live item registration is not presented as available.
- Updated setup, upgrade, compatibility matrix and Tebex release documentation.

## 1.2.0-catalog
- Added Vehicles, Items and Jobs catalog modules.
- Added persistent dynamic definition registry and Phase 3 SQL migration.

## 1.1.0-liquid-glass
- Added Liquid Glass visual theme.

## 1.0.0
- Initial Power Admin Menu release.


## 1.5.0 - Live vector tool
- Added the staff-only `/vector` command with a compact right-side Liquid Glass panel.
- Displays live X, Y, Z and heading values while the player keeps moving.
- Supports copying `vector3`, `vec3`, `vector4` and `vec4` formats with arrow keys and Enter.
- Copying coordinates leaves the panel open; Escape closes it.
- The vector panel does not take NUI focus and does not block normal movement controls.


## 1.5.1 - Developer Tools section
- Added a Developer Tools navigation section to the main admin menu.
- Added the Coords utility; selecting it closes the main admin menu and opens the existing live vector panel.
- Reuses the same server-side staff permission check as the `/vector` command.

## 1.5.2 - Coords clipboard fix
- Moved coordinate copying onto direct NUI keyboard/button interactions so Chromium clipboard permissions can recognize the user action.
- Added a visible Copy Selected Format button and verified legacy clipboard fallback result.
- Kept movement available while the Coords panel is open; Escape closes the panel.


## 1.5.3 - Hide Coords panel cursor
- The Coords mini panel now keeps NUI keyboard focus without displaying the mouse cursor.
- Arrow keys, Enter to copy, and Escape to close remain available.


## v1.5.4-laser-object-mode
- Added Laser Object Mode to the Coords mini menu.
- Added camera ray targeting for peds, vehicles, and objects, with live entity details.
- Added entity-coordinate copying and permission-checked deletion with audit logging.
- Kept the mini menu mouse-cursor-free and added keyboard controls.


## v1.5.5-laser-beam-fix
- Fixed Laser Object Mode beam rendering so the line is drawn continuously every frame instead of waiting for an asynchronous raycast result.
- Separated beam rendering from entity detection and made the raycast lifecycle recover cleanly when a test is invalidated.
- Kept target details, coordinate copy, and permission-checked entity deletion connected to the same target scan.

## v1.5.6 – Laser stability and overview recovery
- Restored the missing `renderOverview()` function that caused the NUI `ReferenceError` during menu bootstrap and navigation.
- Avoided ped-only health native calls for object entities during laser inspection.
- Changed network entity deletion to request network control on the authorized client before using the entity-type-specific delete native.
- Kept laser beam rendering independent from shape-test completion.

## 1.5.7 - Laser ray recovery
- Keep the laser endpoint cached between asynchronous raycast results to prevent visual flicker.
- Handle boolean/integer ray hit values consistently.
- Remove the per-result marker native call and recover from stale/invalid ray handles.
- Clear cached ray state when laser mode closes or the resource stops.


## v1.5.8 - Laser Object Mode rebuild
- Rebuilt laser targeting around a fresh camera ray and immediate shape-test result, removing retained asynchronous ray handles.
- Beam now renders every frame and changes to green when a valid ped, vehicle, or object is targeted.
- Added a green 12-edge 3D bounding box using model dimensions and the entity transform matrix; removed ground-Z lookups.
- Added target distance, heading, and type-specific details to the Developer Tools panel.
- Added strict entity validation before inspection and target consistency checks before deletion.
- Kept deletion permission-gated and preserved the existing vector menu and cursor-free interaction.

## 1.5.9 — Developer Object Spawner
- Added a permission-gated Spawn Object utility to Developer Tools.
- Added curated prop quick picks and custom GTA object model input.
- Added transparent placement preview, camera-surface targeting, rotation, distance adjustment, confirm/cancel controls, and networked frozen placement.
- Added server-side `entities.spawn` permission validation and request throttling.


## 1.6.0 — Full GTA V object catalogue
- Added searchable catalogue browser for 21,631 GTA V object models, grouped by props, interiors, mission, world/DLC and LOD/helper models.
- Added thumbnail previews where available, model hash display, selected-prop preview and lazy 72-item rendering.
- Kept manual model entry for streamed/add-on props and offline fallback.
- Corrected the server-to-client object placement event name so successful requests start the placement preview.


## 1.6.2-object-placer-focus-fix
- Fixed placement UI focus: NUI now captures mouse/keyboard input without forwarding it to gameplay.
- Disabled gameplay camera look axes while object placement is active.
- Restored a visible pointer and clickable controls inside the placement panel.


## 1.6.3 - Object placer cursor toggle
- Added Left Ctrl hotkey to show/hide the NUI mouse cursor while object placement is active.
- Keeps NUI keyboard focus when the cursor is hidden, so keyboard placement controls remain usable.
- Added an on-panel cursor status indicator showing the current state and toggle hint.
