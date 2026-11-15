-- Repair existing Qbox vehicles created by older Power Admin Menu builds.
-- This fills only missing health/fuel properties in valid JSON `mods` records.
-- Existing non-null property values and vehicle customizations are preserved.
-- Run once in the server database if a vehicle added before v1.4.3 still
-- triggers qbx_garages' engineHealth/bodyHealth nil arithmetic error.

UPDATE `player_vehicles`
SET `mods` = JSON_SET(
    `mods`,
    '$.engineHealth', COALESCE(CAST(JSON_UNQUOTE(JSON_EXTRACT(`mods`, '$.engineHealth')) AS DECIMAL(10,2)), `engine`, 1000),
    '$.bodyHealth',   COALESCE(CAST(JSON_UNQUOTE(JSON_EXTRACT(`mods`, '$.bodyHealth')) AS DECIMAL(10,2)), `body`, 1000),
    '$.fuelLevel',    COALESCE(CAST(JSON_UNQUOTE(JSON_EXTRACT(`mods`, '$.fuelLevel')) AS DECIMAL(10,2)), `fuel`, 100)
)
WHERE JSON_VALID(`mods`) = 1
  AND (
      JSON_EXTRACT(`mods`, '$.engineHealth') IS NULL
      OR JSON_EXTRACT(`mods`, '$.bodyHealth') IS NULL
      OR JSON_EXTRACT(`mods`, '$.fuelLevel') IS NULL
  );
