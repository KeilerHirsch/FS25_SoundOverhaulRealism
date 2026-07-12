--
-- SoundModule
--
-- Contract/base class for every Sound Overhaul feature module. A module is a
-- SINGLETON table. Two kinds of contribution (a module may do either or both):
--   * resolveSample(name, vehicle, audioGroup) -> filename|nil : swap a sample at
--     the createAudioSource choke point (nil = leave vanilla untouched).
--   * onUpdate(dt)                              : per-frame client tick (schedulers).
--
-- Every hook has a safe default (no-op / passthrough); a module overrides only
-- what it needs. Adding a feature = registering a new module, never touching core.
--

SoundModule = {}
local SoundModule_mt = { __index = SoundModule }

---Create a new module with the given unique name (also the config key).
-- @param string name unique module id
-- @return table module
function SoundModule.new(name)
    assert(type(name) == "string" and name ~= "", "SoundModule.new requires a non-empty name")
    return setmetatable({ name = name }, SoundModule_mt)
end

---Return a replacement filename for the given sample, or nil for vanilla.
-- @param string name        the sample name ("motorStart", "motor(0)", "brakes1", ...)
-- @param table  vehicle     owning vehicle/tool (sample.modifierTargetObject), may be nil
-- @param number audioGroup  AudioGroup.VEHICLE / ENVIRONMENT / ...
-- @return string|nil
function SoundModule:resolveSample(_name, _vehicle, _audioGroup)
    return nil
end

---Per-frame client tick. Only called when the module is enabled and not headless.
function SoundModule:onUpdate(_dt) end

---Called once after the mission has started (map + environment available).
function SoundModule:onMissionStarted() end
