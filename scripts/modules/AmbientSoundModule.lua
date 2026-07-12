--
-- AmbientSoundModule
--
-- Seasonal / weather ambience. The engine's own ambientSoundSystem is C++-side
-- and NOT scriptable at runtime (verified, docs/BUILD_NOTES.md), so we run our
-- OWN client-side scheduler: read the environment (season x daytime x weather x
-- indoor) each tick, and play the matching ENVIRONMENT-group loop. Map-agnostic
-- by design (works on any map, unlike a map-authored sounds.xml).
--
-- Bed samples are built through g_soundManager:loadSampleFromXML from the bundled
-- sounds/ambient.xml — the SAME trusted path every vehicle/placeable sound uses,
-- so playSample/stopSample and the runtime modifiers all work (a hand-rolled
-- sample table would be a silent no-op: playSample requires sample.soundSample +
-- sample.current, which only the loader populates).
--
-- The bed-selection logic is PURE (unit-tested); the tick/playback wiring is
-- in-game verified.
--

AmbientSoundModule = SoundModule.new("ambient")

AmbientSoundModule.CFG = {
    RESELECT_INTERVAL_MS = 2000, -- re-evaluate conditions at most this often
    FADE_MS = 1500,              -- cross-fade when the bed changes
}

-- Runtime state (client-side only).
AmbientSoundModule.timer = 0
AmbientSoundModule.currentBed = nil     -- bedKey currently playing
AmbientSoundModule.currentSample = nil
AmbientSoundModule.samples = {}         -- bedKey -> loaded sample (false = tried, absent)
AmbientSoundModule.defsPath = nil       -- absolute path to sounds/ambient.xml
AmbientSoundModule.baseDir = ""         -- mod dir the ambient.xml file="" paths resolve against

---Season index -> canonical name. Order per FS25 environment (0=spring..3=winter).
-- PURE. In-game index is verified during tuning; the mapping lives here so it is
-- the single place to correct.
function AmbientSoundModule.seasonName(index)
    local names = { [0] = "spring", [1] = "summer", [2] = "autumn", [3] = "winter" }
    return names[index] or "summer"
end

---Whether a weather type counts as "rainy" for the ambience overlay. PURE.
-- Accepts the WeatherType enum value; unknown -> not rainy.
function AmbientSoundModule.isRainy(weatherType)
    if weatherType == nil or WeatherType == nil then
        return false
    end
    return weatherType == WeatherType.RAIN
        or weatherType == WeatherType.THUNDER
        or weatherType == WeatherType.HAIL
end

---Select the ambience bed key for the given conditions. PURE — the core the
-- tests exercise. nil = play nothing (e.g. indoors: the cabin muffles ambience
-- and the engine templates already apply an indoor lowpass).
--   indoors                 -> nil
--   rainy weather           -> "<season>_rain"
--   otherwise               -> "<season>_day" | "<season>_night"
-- @param string  season   "spring".."winter"
-- @param boolean rainy
-- @param boolean isDay
-- @param boolean isIndoor
-- @return string|nil bedKey
function AmbientSoundModule.selectBed(season, rainy, isDay, isIndoor)
    if isIndoor then
        return nil
    end
    season = season or "summer"
    if rainy then
        return season .. "_rain"
    end
    return season .. (isDay and "_day" or "_night")
end

---Point the scheduler at the bundled ambient sound definitions. Called by the
-- loader at mission start (baseDir = mod directory).
function AmbientSoundModule.setDefs(defsPath, baseDir)
    AmbientSoundModule.defsPath = defsPath
    AmbientSoundModule.baseDir = baseDir or ""
end

---Read the current conditions off the environment and compute the target bed.
-- IN-GAME ONLY (defensive). Returns a bedKey or nil.
function AmbientSoundModule.currentTargetBed()
    local mission = g_currentMission
    if mission == nil or mission.environment == nil then
        return nil
    end
    local env = mission.environment
    local season = AmbientSoundModule.seasonName(env.currentSeason or 1)
    local isDay = env.isSunOn == true

    local weatherType = nil
    if env.weather ~= nil and env.weather.getCurrentWeatherType ~= nil then
        weatherType = env.weather:getCurrentWeatherType()
    end
    local rainy = AmbientSoundModule.isRainy(weatherType)

    local isIndoor = g_soundManager ~= nil and g_soundManager.currentModifierTargetIsIndoor == true

    return AmbientSoundModule.selectBed(season, rainy, isDay, isIndoor)
end

---Lazily load (and cache) the sample for a bed via the trusted loader path.
-- IN-GAME ONLY. Returns a sample table, or nil if the bed has no (present) audio.
function AmbientSoundModule:getBedSample(bedKey)
    local cached = self.samples[bedKey]
    if cached ~= nil then
        return cached or nil -- false = tried before and absent
    end
    local sample = nil
    if self.defsPath ~= nil and XMLFile ~= nil and g_soundManager ~= nil then
        local xml = XMLFile.loadIfExists("sorAmbientDefs", self.defsPath)
        if xml ~= nil then
            local group = AudioGroup ~= nil and AudioGroup.ENVIRONMENT or nil
            -- (xmlFile, baseKey, sampleName, baseDir, components, loops, audioGroup,
            --  i3dMappings, modifierTargetObject, requiresFile)
            sample = g_soundManager:loadSampleFromXML(xml, "sounds", bedKey, self.baseDir,
                nil, 0, group, nil, nil, true)
            xml:delete()
        end
    end
    self.samples[bedKey] = sample or false -- cache the miss so we do not reload every change
    return sample
end

---Throttled tick: when the target bed changes, cross-fade to the new loop.
-- IN-GAME ONLY.
function AmbientSoundModule:onUpdate(dt)
    self.timer = self.timer + (dt or 0)
    if self.timer < self.CFG.RESELECT_INTERVAL_MS then
        return
    end
    self.timer = 0

    local target = AmbientSoundModule.currentTargetBed()
    if target == self.currentBed then
        return
    end

    if self.currentSample ~= nil and g_soundManager ~= nil then
        g_soundManager:stopSample(self.currentSample, 0, self.CFG.FADE_MS)
    end
    self.currentSample = nil
    self.currentBed = target

    if target == nil then
        return
    end

    local sample = self:getBedSample(target)
    if sample ~= nil and g_soundManager ~= nil then
        self.currentSample = sample
        g_soundManager:playSample(sample)
    end
end

---Reset scheduler state on a fresh mission.
function AmbientSoundModule:onMissionStarted()
    self.timer = self.CFG.RESELECT_INTERVAL_MS -- evaluate on the first tick
    self.currentBed = nil
    self.currentSample = nil
    self.samples = {}
end
