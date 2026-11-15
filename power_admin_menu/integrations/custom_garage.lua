-- Custom garage bridge. Edit AddVehicle to match your garage's documented API/schema.
PAMCustomGarage = PAMCustomGarage or {}

function PAMCustomGarage.AddVehicle(target, vehicleData)
    -- vehicleData: { model, hash, plate, props, citizenid, license, garage, fuel, engine, body }
    -- Return true on success, false, 'reason' on failure.
    return false, 'Custom garage adapter is not configured.'
end
