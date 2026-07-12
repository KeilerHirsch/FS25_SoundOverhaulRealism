--
-- EngineSoundModule
--
-- The star module. At the createAudioSource choke point it looks up the owning
-- vehicle's engineClass (SoundProfiles) and returns the matching pack sample, so
-- the engine's own RPM/load pitch modifiers keep working on OUR file. Anything not
-- in the pack returns nil = untouched vanilla.
--
-- Only VEHICLE-group samples are touched; ambience (ENVIRONMENT group) is handled
-- by AmbientSoundModule, never here.
--

EngineSoundModule = SoundModule.new("engine")

---Pure decision: given a resolved engineClass, a sample name and the engine pack
-- map, return the replacement file or nil. Unit-tested.
-- @param string engineClass
-- @param string sampleName
-- @param table  packMap  PackLoader-style engine map
-- @return string|nil
function EngineSoundModule.pick(engineClass, sampleName, packMap)
    if engineClass == nil then
        return nil
    end
    return PackLoader.resolve(packMap, engineClass, sampleName)
end

---Swap a vehicle sample. Returns nil for anything we do not cover (vanilla).
function EngineSoundModule:resolveSample(name, vehicle, audioGroup)
    -- Only vehicle sounds. When AudioGroup is available and this is not a vehicle
    -- group, skip. (In headless tests AudioGroup is nil -> the guard is inert.)
    if AudioGroup ~= nil and audioGroup ~= nil and audioGroup ~= AudioGroup.VEHICLE then
        return nil
    end
    if vehicle == nil then
        return nil
    end
    -- Only real powertrain vehicles. Some non-motorized components (yarder tower,
    -- standalone motor) load a sample literally named "motor" in the VEHICLE group;
    -- without this gate SoundProfiles' small-class fallback would swap their sound
    -- with a tractor engine loop.
    if vehicle.spec_motorized == nil then
        return nil
    end
    local engineClass = SoundProfiles.forVehicle(vehicle)
    return EngineSoundModule.pick(engineClass, name, PackLoader.engine)
end
