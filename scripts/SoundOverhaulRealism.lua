--
-- SoundOverhaulRealism — mod loader
--
-- The Man, The Mythos, The Legend : KeilerHirsch
-- Copyright (c) 2026 KeilerHirsch. Licensed under the GNU GPL v3 or later.
--
-- Sources the core + modules, installs the SINGLE global sound choke point
-- (SoundManager.createAudioSource), wires a global tick for the ambience
-- scheduler, and runs the coexistence detector against rival sound mods.
--
-- Design (verified against GIANTS gameSource, 2026-07-12, see docs/BUILD_NOTES.md):
--   * Vehicle sounds  -> every loader funnels through SoundManager:createAudioSource;
--     we overwrite that ONE class method and swap the file per vehicle profile.
--   * Ambience         -> g_currentMission.ambientSoundSystem is engine-side and NOT
--     scriptable; instead we run our own client-side scheduler that reads the
--     environment (season/weather/daytime/indoor) and plays ENVIRONMENT-group loops.
--

SoundOverhaulRealism = {}
SoundOverhaulRealism.VERSION = "0.1.0.0"
SoundOverhaulRealism.MOD_NAME = g_currentModName

local modDirectory = g_currentModDirectory

-- Core (order: base -> registry -> config -> data/loader), then modules, then events.
source(modDirectory .. "scripts/core/SoundModule.lua")
source(modDirectory .. "scripts/core/SoundModuleRegistry.lua")
source(modDirectory .. "scripts/core/SoundConfig.lua")
source(modDirectory .. "scripts/core/SoundProfiles.lua")
source(modDirectory .. "scripts/core/PackLoader.lua")
source(modDirectory .. "scripts/core/SoundSettings.lua")
source(modDirectory .. "scripts/events/SoundConfigSyncEvent.lua")
source(modDirectory .. "scripts/modules/EngineSoundModule.lua")
source(modDirectory .. "scripts/modules/AmbientSoundModule.lua")

---Register all feature modules with the registry. Add new modules here.
-- Order: the sample resolvers first (engine), then the tick-driven ambience.
function SoundOverhaulRealism.registerModules()
    SoundModuleRegistry.register(EngineSoundModule)
    SoundModuleRegistry.register(AmbientSoundModule)
end

---The master sample resolver. Called by the createAudioSource wrapper for every
-- sample the game (or another mod) creates. Walks the registered modules and
-- returns the FIRST replacement filename; nil = leave the vanilla file untouched.
-- @param table sample the sound sample (sampleName, audioGroup, modifierTargetObject)
-- @return string|nil replacement absolute filename, or nil for vanilla fallback
function SoundOverhaulRealism.resolveSample(sample)
    if not SoundConfig.isEnabled() or sample == nil then
        return nil
    end
    local name = sample.sampleName
    local vehicle = sample.modifierTargetObject
    local group = sample.audioGroup
    for _, m in ipairs(SoundModuleRegistry.getModules()) do
        if SoundConfig.isModuleEnabled(m.name) and m.resolveSample ~= nil then
            -- pcall: this is the single choke point for ALL vehicle audio, so a bug
            -- in one (future) module must not take down every sample in the session.
            local ok, swapped = pcall(m.resolveSample, m, name, vehicle, group)
            if ok and swapped ~= nil then
                return swapped
            end
        end
    end
    return nil
end

---Install the global choke point. Every single sample AND every plural set
-- (motor/gearbox) funnels through SoundManager:createAudioSource, so wrapping the
-- CLASS method covers base + modded vehicles + tools with one hook.
function SoundOverhaulRealism.installSoundHook()
    if SoundManager == nil or SoundManager.createAudioSource == nil then
        Logging.warning("[SoundOverhaulRealism] SoundManager.createAudioSource missing - hook not installed.")
        return
    end
    SoundManager.createAudioSource = Utils.overwrittenFunction(SoundManager.createAudioSource,
        function(self, superFunc, sample, filename)
            local swapped = SoundOverhaulRealism.resolveSample(sample)
            return superFunc(self, sample, swapped or filename)
        end)
    Logging.info("[SoundOverhaulRealism] sound choke point installed on SoundManager.createAudioSource.")
end

---Per-frame tick (client-side): drive the tick-based modules (ambience scheduler).
-- Guarded so a headless/server instance without audio does nothing costly.
function SoundOverhaulRealism.update(_mission, dt)
    if g_dedicatedServer ~= nil or not SoundConfig.isEnabled() then
        return
    end
    for _, m in ipairs(SoundModuleRegistry.getModules()) do
        if SoundConfig.isModuleEnabled(m.name) and m.onUpdate ~= nil then
            m:onUpdate(dt)
        end
    end
end

---Load the bundled starter pack (and later, any user packs). Files that are not
-- present on disk are skipped, so an audio-less pack simply swaps nothing.
function SoundOverhaulRealism.loadPacks()
    local base = modDirectory .. "sounds/packs/starter_cc0/"
    PackLoader.load(base .. "manifest.xml", base)
end

---Mission start: load persisted settings, packs, and let modules bootstrap.
function SoundOverhaulRealism.onMissionStarted()
    SoundSettings.load(SoundConfig)
    SoundOverhaulRealism.loadPacks()
    AmbientSoundModule.setDefs(modDirectory .. "sounds/ambient.xml", modDirectory)
    SoundOverhaulRealism.detectCoexistence()
    for _, m in ipairs(SoundModuleRegistry.getModules()) do
        if m.onMissionStarted ~= nil then
            m:onMissionStarted()
        end
    end
end

---Detect rival sound-overhaul mods and flag the overlap loudly (both hook sound;
-- last writer wins on our chain, but double-loaded samples waste memory).
function SoundOverhaulRealism.detectCoexistence()
    local rivals = { "FS25_moreMotorSounds", "FS25_ImprovedHarvesterSounds", "FS25_MotorSoundExtension" }
    local found = {}
    for _, name in ipairs(rivals) do
        if g_modIsLoaded ~= nil and g_modIsLoaded[name] == true then
            found[#found + 1] = name
        end
    end
    SoundOverhaulRealism.rivalsPresent = found
    if #found > 0 then
        Logging.warning("[SoundOverhaulRealism] other sound mods active: %s. Disable them to avoid double-loaded samples / conflicting swaps.", table.concat(found, ", "))
    end
end

SoundOverhaulRealism.registerModules()
SoundOverhaulRealism.installSoundHook()
-- FSBaseMission.update (not Mission00.update): Mission00 inherits update from the
-- base, so assigning Mission00.update would SHADOW the inherited chain. Wrapping
-- the base function keeps the real update running and appends our client tick.
FSBaseMission.update = Utils.appendedFunction(FSBaseMission.update, SoundOverhaulRealism.update)
-- Mission00.load is the verified once-per-session start hook (same point IronHorse
-- uses). Appended so the real load runs first, then our settings/pack bootstrap.
Mission00.load = Utils.appendedFunction(Mission00.load, SoundOverhaulRealism.onMissionStarted)

Logging.info("[SoundOverhaulRealism %s] core loaded.", SoundOverhaulRealism.VERSION)
