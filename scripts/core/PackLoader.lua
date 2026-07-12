--
-- PackLoader
--
-- Reads a sound-pack manifest and resolves (engineClass, sampleName) -> .ogg file
-- for the engine module, and (bedKey) -> .ogg for the ambience module. Packs are
-- pluggable: any pack that follows this manifest format drops into sounds/packs/.
--
-- The table-building and lookup are PURE (unit-tested). Only load() touches the
-- engine XML reader.
--

PackLoader = {}

-- Resolved lookup map, filled by load().
--   engine[engineClass][normalizedSampleName] = absoluteFilename
-- (Ambience beds are defined separately in sounds/ambient.xml and loaded via the
--  engine's own loadSampleFromXML — see AmbientSoundModule.)
PackLoader.engine = {}

---Reject a manifest file="" value that is not a safe, mod-relative path
-- (blocks "..", absolute paths and drive letters so a third-party pack cannot
-- point outside the mod directory). PURE.
-- @param string p
-- @return boolean
function PackLoader.isSafeRelativePath(p)
    if type(p) ~= "string" or p == "" then
        return false
    end
    if p:find("%.%.") ~= nil then return false end -- parent traversal
    if p:find("^[/\\]") ~= nil then return false end -- absolute (unix/unc)
    if p:find("^%a:") ~= nil then return false end   -- drive letter
    return true
end

---Normalise a sample name: strip the "(n)" index from plural sets so an entire
-- motor/gearbox RPM set maps to one pack key. PURE.
--   "motor(0)" -> "motor", "gearbox(3)" -> "gearbox", "motorStart" -> "motorStart"
-- @param string name
-- @return string
function PackLoader.normalizeSampleName(name)
    if type(name) ~= "string" then
        return ""
    end
    return (name:gsub("%b()", ""))
end

---Insert an engine entry into a map. PURE (map passed in so tests use a plain
-- table). Normalises the sample name; ignores incomplete rows.
-- @param table  map         the engine map to mutate
-- @param string engineClass e.g. "i6_td_large"
-- @param string sampleName  e.g. "motor(0)" / "motorStart"
-- @param string file        absolute filename
function PackLoader.addEngineEntry(map, engineClass, sampleName, file)
    if type(map) ~= "table" or engineClass == nil or engineClass == ""
        or file == nil or file == "" then
        return
    end
    local key = PackLoader.normalizeSampleName(sampleName)
    if key == "" then
        return
    end
    if map[engineClass] == nil then
        map[engineClass] = {}
    end
    map[engineClass][key] = file
end

---Resolve an engine sample. PURE. Returns nil (vanilla fallback) if the class or
-- the sample key is not in the pack.
-- @param table  map
-- @param string engineClass
-- @param string sampleName
-- @return string|nil
function PackLoader.resolve(map, engineClass, sampleName)
    if type(map) ~= "table" or engineClass == nil then
        return nil
    end
    local byClass = map[engineClass]
    if byClass == nil then
        return nil
    end
    return byClass[PackLoader.normalizeSampleName(sampleName)]
end

---Load a pack manifest from XML into PackLoader.engine.
-- IN-GAME ONLY (uses XMLFile). Manifest format:
--   <soundPack>
--     <engine>
--       <sample class="i6_td_large" name="motor"      file="engine/i6_large/motor.ogg"/>
--       <sample class="i6_td_large" name="motorStart" file="engine/i6_large/start.ogg"/>
--     </engine>
--   </soundPack>
-- @param string manifestPath absolute path to manifest.xml
-- @param string baseDir       directory the file="" paths are relative to
function PackLoader.load(manifestPath, baseDir)
    if XMLFile == nil or manifestPath == nil then
        return
    end
    local xml = XMLFile.loadIfExists("soundPackManifest", manifestPath)
    if xml == nil then
        Logging.warning("[SoundOverhaulRealism] pack manifest not found: %s", tostring(manifestPath))
        return
    end
    baseDir = baseDir or ""

    -- Only register a sample whose file="" is a SAFE mod-relative path AND whose
    -- .ogg actually exists on disk. The safety check stops a third-party pack from
    -- pointing outside the mod dir; the existence check lets a pack ship a manifest
    -- that lists intended files while nothing swaps until the real CC0 audio is
    -- present (a missing file never produces a bad/silent swap).
    local function present(abs)
        return fileExists == nil or fileExists(abs)
    end

    xml:iterate("soundPack.engine.sample", function(_, key)
        local class = xml:getString(key .. "#class")
        local name = xml:getString(key .. "#name")
        local file = xml:getString(key .. "#file")
        if file ~= nil and PackLoader.isSafeRelativePath(file) then
            local abs = baseDir .. file
            if present(abs) then
                PackLoader.addEngineEntry(PackLoader.engine, class, name, abs)
            end
        end
    end)

    xml:delete()
    Logging.info("[SoundOverhaulRealism] pack loaded: %s", tostring(manifestPath))
end
