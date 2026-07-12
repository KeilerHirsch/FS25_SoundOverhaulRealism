--
-- SoundSettings
--
-- Persists the (tiny) SoundConfig to the user's modSettings folder so choices
-- survive between sessions. Pure serialisation lives on SoundConfig
-- (toValues/applyValues); this file only does the file I/O (in-game only).
--

SoundSettings = {}

SoundSettings.FILE_NAME = "FS25_SoundOverhaulRealism.xml"
SoundSettings.ROOT = "soundOverhaulRealism"

---Absolute path to the settings file, or nil if the profile path is unavailable.
-- @return string|nil
function SoundSettings.path()
    if getUserProfileAppPath == nil then
        return nil
    end
    return getUserProfileAppPath() .. "modSettings/" .. SoundSettings.FILE_NAME
end

---Load persisted settings into the given config. IN-GAME ONLY. No-op if missing.
-- @param table config the SoundConfig table
function SoundSettings.load(config)
    local path = SoundSettings.path()
    if path == nil or XMLFile == nil then
        return
    end
    local xml = XMLFile.loadIfExists("sorSettings", path)
    if xml == nil then
        return
    end
    local root = SoundSettings.ROOT
    config.applyValues({
        enabled = xml:getBool(root .. "#enabled"),
        engine = xml:getBool(root .. ".modules#engine"),
        ambient = xml:getBool(root .. ".modules#ambient"),
    })
    xml:delete()
end

---Write the given config to disk. IN-GAME ONLY.
-- @param table config the SoundConfig table
function SoundSettings.save(config)
    local path = SoundSettings.path()
    if path == nil or XMLFile == nil then
        return
    end
    local values = config.toValues()
    local root = SoundSettings.ROOT
    local xml = XMLFile.create("sorSettings", path, root)
    if xml == nil then
        return
    end
    xml:setBool(root .. "#enabled", values.enabled)
    xml:setBool(root .. ".modules#engine", values.engine)
    xml:setBool(root .. ".modules#ambient", values.ambient)
    xml:save()
    xml:delete()
end
