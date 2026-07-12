--
-- SoundConfig
--
-- Deliberately MINIMAL (Apple-KISS): a global on/off plus one enable flag per
-- module. No live numeric tuning. Server-owned in multiplayer; the config is the
-- ONLY thing that needs to sync (the audio itself is client-side).
--

SoundConfig = {}

SoundConfig.enabled = true
SoundConfig.moduleEnabled = {
    engine = true,
    ambient = true,
}

---@return boolean whether the mod is active at all
function SoundConfig.isEnabled()
    return SoundConfig.enabled == true
end

---@param string name module id
-- @return boolean whether that module is enabled (and the mod is on)
function SoundConfig.isModuleEnabled(name)
    return SoundConfig.enabled == true and SoundConfig.moduleEnabled[name] == true
end

---Flip the global master switch. Returns the new state.
-- @return boolean
function SoundConfig.toggle()
    SoundConfig.enabled = not SoundConfig.enabled
    return SoundConfig.enabled
end

---Serialise the config to a flat table of booleans (for savegame / sync).
-- @return table { enabled = bool, engine = bool, ambient = bool }
function SoundConfig.toValues()
    return {
        enabled = SoundConfig.enabled == true,
        engine = SoundConfig.moduleEnabled.engine == true,
        ambient = SoundConfig.moduleEnabled.ambient == true,
    }
end

---Apply a flat table of booleans back onto the config (pure; missing keys keep
-- their current value). Used by savegame load and the MP sync event.
-- @param table values
function SoundConfig.applyValues(values)
    if type(values) ~= "table" then
        return
    end
    if values.enabled ~= nil then
        SoundConfig.enabled = values.enabled == true
    end
    if values.engine ~= nil then
        SoundConfig.moduleEnabled.engine = values.engine == true
    end
    if values.ambient ~= nil then
        SoundConfig.moduleEnabled.ambient = values.ambient == true
    end
end
