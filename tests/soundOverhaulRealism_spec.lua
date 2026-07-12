--
-- Unit tests for FS25_SoundOverhaulRealism core (busted).
-- Run from the mod root with a Lua 5.1 / LuaJIT environment: busted
--
-- Engine globals are stubbed; only pure/core logic is exercised (the in-game
-- integration — the createAudioSource hook, the ambience tick, sample playback —
-- is verified in-game, since FS25 cannot run headless).
--

local function loadCore()
    _G.Logging = { info = function() end, warning = function() end }
    -- engine enums the pure code branches on
    _G.AudioGroup = { VEHICLE = 1, ENVIRONMENT = 2 }
    _G.WeatherType = { SUN = 1, PARTIALLY_CLOUDY = 2, CLOUDY = 3, RAIN = 4, HAIL = 5, SNOW = 6, THUNDER = 7, TWISTER = 8 }

    _G.SoundModule = nil
    _G.SoundModuleRegistry = nil
    _G.SoundConfig = nil
    _G.SoundProfiles = nil
    _G.PackLoader = nil
    _G.EngineSoundModule = nil
    _G.AmbientSoundModule = nil

    dofile("scripts/core/SoundModule.lua")
    dofile("scripts/core/SoundModuleRegistry.lua")
    dofile("scripts/core/SoundConfig.lua")
    dofile("scripts/core/SoundProfiles.lua")
    dofile("scripts/core/PackLoader.lua")
    dofile("scripts/modules/EngineSoundModule.lua")
    dofile("scripts/modules/AmbientSoundModule.lua")
end

describe("SoundModuleRegistry", function()
    it("registers, dedupes by name, and lists in order", function()
        loadCore()
        local reg = _G.SoundModuleRegistry
        reg.modules = {}
        reg.byName = {}
        local a = _G.SoundModule.new("a")
        local b = _G.SoundModule.new("b")
        reg.register(a)
        reg.register(b)
        reg.register(a) -- duplicate ignored
        assert.are.equal(2, #reg.getModules())
        assert.are.equal("a", reg.getModules()[1].name)
        assert.are.equal(b, reg.get("b"))
        assert.is_nil(reg.get("missing"))
    end)

    it("ignores a module without a name", function()
        loadCore()
        local reg = _G.SoundModuleRegistry
        reg.modules = {}
        reg.byName = {}
        reg.register({})
        reg.register(nil)
        assert.are.equal(0, #reg.getModules())
    end)
end)

describe("SoundConfig (master + per-module gating)", function()
    it("gates modules behind the master switch", function()
        loadCore()
        local CFG = _G.SoundConfig
        CFG.enabled = true
        CFG.moduleEnabled.engine = true
        CFG.moduleEnabled.ambient = false
        assert.is_true(CFG.isEnabled())
        assert.is_true(CFG.isModuleEnabled("engine"))
        assert.is_false(CFG.isModuleEnabled("ambient"))
        CFG.enabled = false
        assert.is_false(CFG.isModuleEnabled("engine")) -- master off disables all
    end)

    it("toggle flips the master and returns the new state", function()
        loadCore()
        local CFG = _G.SoundConfig
        CFG.enabled = true
        assert.is_false(CFG.toggle())
        assert.is_true(CFG.toggle())
    end)

    it("toValues / applyValues round-trip (missing keys preserved)", function()
        loadCore()
        local CFG = _G.SoundConfig
        CFG.enabled = true; CFG.moduleEnabled.engine = true; CFG.moduleEnabled.ambient = true
        CFG.applyValues({ enabled = false, ambient = false }) -- engine omitted
        local v = CFG.toValues()
        assert.is_false(v.enabled)
        assert.is_true(v.engine)   -- preserved
        assert.is_false(v.ambient)
        CFG.applyValues("not a table") -- no crash, no change
        assert.is_false(CFG.toValues().enabled)
    end)
end)

describe("SoundProfiles.classify (heuristic Tier 2)", function()
    loadCore()
    local SP = _G.SoundProfiles
    local C = SP.CLASS

    it("small tractor -> inline-4 turbo diesel", function()
        assert.are.equal(C.I4_TD_SMALL, SP.classify(70, 2200, "tractor", "deutz"))
    end)
    it("medium tractor -> inline-6 turbo diesel", function()
        assert.are.equal(C.I6_TD_MEDIUM, SP.classify(120, 2100, "tractor", "fendt"))
    end)
    it("large tractor -> inline-6 large", function()
        assert.are.equal(C.I6_TD_LARGE, SP.classify(230, 2100, "tractor", "johndeere"))
    end)
    it("above the large band + tractor -> articulated inline-6", function()
        assert.are.equal(C.I6_TD_ARTIC, SP.classify(340, 2100, "tractor", "caseih"))
    end)
    it("Scania truck is the one selective V8", function()
        assert.are.equal(C.V8_DIESEL_TRUCK, SP.classify(370, 1900, "truck", "scania"))
    end)
    it("a non-Scania truck is NOT a V8 (stays inline-6)", function()
        assert.are.equal(C.I6_TD_LARGE, SP.classify(340, 2000, "truck", "man"))
    end)
    it("low power + low rpm -> vintage naturally aspirated", function()
        assert.are.equal(C.I4_NA_VINTAGE, SP.classify(45, 1800, "tractor", "oldtimer"))
    end)
    it("low power but modern rpm is NOT vintage", function()
        assert.are.equal(C.I4_TD_SMALL, SP.classify(45, 2400, "tractor", "kubota"))
    end)
    it("unknown inputs default to the small class, never crash", function()
        assert.are.equal(C.I4_TD_SMALL, SP.classify(nil, nil, nil, nil))
    end)
end)

describe("SoundProfiles.tier1Match (flagship overrides)", function()
    loadCore()
    local SP = _G.SoundProfiles
    local C = SP.CLASS

    it("John Deere 8R -> large inline-6", function()
        assert.are.equal(C.I6_TD_LARGE, SP.tier1Match("data/vehicles/johnDeere/8R/8R.xml"))
    end)
    it("Scania -> V8 truck, case-insensitive + backslashes", function()
        assert.are.equal(C.V8_DIESEL_TRUCK, SP.tier1Match("DATA\\VEHICLES\\SCANIA\\R500\\r500.xml"))
    end)
    it("9R articulated -> artic (more specific than 8R substring)", function()
        assert.are.equal(C.I6_TD_ARTIC, SP.tier1Match("data/vehicles/johnDeere/9R/9R.xml"))
    end)
    it("an unmapped model returns nil (falls through to heuristic)", function()
        assert.is_nil(SP.tier1Match("data/vehicles/someBrand/x/x.xml"))
        assert.is_nil(SP.tier1Match(nil))
    end)
end)

describe("PackLoader.normalizeSampleName", function()
    loadCore()
    local PL = _G.PackLoader
    it("strips the (n) index from plural sets", function()
        assert.are.equal("motor", PL.normalizeSampleName("motor(0)"))
        assert.are.equal("motor", PL.normalizeSampleName("motor(11)"))
        assert.are.equal("gearbox", PL.normalizeSampleName("gearbox(3)"))
    end)
    it("leaves single sample names untouched", function()
        assert.are.equal("motorStart", PL.normalizeSampleName("motorStart"))
        assert.are.equal("brakes1", PL.normalizeSampleName("brakes1"))
    end)
    it("non-string is safe", function()
        assert.are.equal("", PL.normalizeSampleName(nil))
    end)
end)

describe("PackLoader.addEngineEntry / resolve", function()
    loadCore()
    local PL = _G.PackLoader

    it("builds a nested map, normalising the key on insert and lookup", function()
        local map = {}
        PL.addEngineEntry(map, "i6_td_large", "motor(0)", "/abs/motor.ogg")
        PL.addEngineEntry(map, "i6_td_large", "motorStart", "/abs/start.ogg")
        assert.are.equal("/abs/motor.ogg", PL.resolve(map, "i6_td_large", "motor(4)")) -- any index hits the set
        assert.are.equal("/abs/start.ogg", PL.resolve(map, "i6_td_large", "motorStart"))
    end)
    it("returns nil (vanilla) for an unknown class or sample", function()
        local map = {}
        PL.addEngineEntry(map, "i6_td_large", "motor", "/abs/motor.ogg")
        assert.is_nil(PL.resolve(map, "v8_diesel_truck", "motor")) -- class absent
        assert.is_nil(PL.resolve(map, "i6_td_large", "turboWhistle")) -- sample absent
        assert.is_nil(PL.resolve(nil, "i6_td_large", "motor"))
    end)
    it("ignores incomplete rows", function()
        local map = {}
        PL.addEngineEntry(map, nil, "motor", "/abs/x.ogg")
        PL.addEngineEntry(map, "c", "motor", nil)
        PL.addEngineEntry(map, "c", "", "/abs/x.ogg")
        assert.is_nil(next(map))
    end)
    it("isSafeRelativePath rejects traversal / absolute / drive-letter paths", function()
        assert.is_true(PL.isSafeRelativePath("engine/i6_large/motor.ogg"))
        assert.is_false(PL.isSafeRelativePath("../secret.ogg"))
        assert.is_false(PL.isSafeRelativePath("a/../../b.ogg"))
        assert.is_false(PL.isSafeRelativePath("/etc/passwd"))
        assert.is_false(PL.isSafeRelativePath("\\server\\share"))
        assert.is_false(PL.isSafeRelativePath("C:\\Windows\\x.ogg"))
        assert.is_false(PL.isSafeRelativePath(nil))
        assert.is_false(PL.isSafeRelativePath(""))
    end)
end)

describe("EngineSoundModule.pick (pure swap decision)", function()
    loadCore()
    local ESM = _G.EngineSoundModule
    local PL = _G.PackLoader
    local map = {}
    PL.addEngineEntry(map, "i6_td_large", "motor", "/abs/motor.ogg")

    it("returns the pack file for a covered class+sample", function()
        assert.are.equal("/abs/motor.ogg", ESM.pick("i6_td_large", "motor(2)", map))
    end)
    it("returns nil (vanilla) for nil class or uncovered sample", function()
        assert.is_nil(ESM.pick(nil, "motor", map))
        assert.is_nil(ESM.pick("i6_td_large", "brakes1", map))
    end)
end)

describe("AmbientSoundModule.selectBed (season x weather x daytime x indoor)", function()
    loadCore()
    local ASM = _G.AmbientSoundModule

    it("indoors plays nothing (cabin muffles ambience)", function()
        assert.is_nil(ASM.selectBed("summer", false, true, true))
        assert.is_nil(ASM.selectBed("winter", true, false, true))
    end)
    it("rainy weather overrides day/night with the rain bed", function()
        assert.are.equal("summer_rain", ASM.selectBed("summer", true, true, false))
        assert.are.equal("winter_rain", ASM.selectBed("winter", true, false, false))
    end)
    it("dry weather picks day vs night per season", function()
        assert.are.equal("spring_day", ASM.selectBed("spring", false, true, false))
        assert.are.equal("autumn_night", ASM.selectBed("autumn", false, false, false))
    end)
    it("nil season defaults to summer, never crashes", function()
        assert.are.equal("summer_day", ASM.selectBed(nil, false, true, false))
    end)
end)

describe("AmbientSoundModule helpers", function()
    loadCore()
    local ASM = _G.AmbientSoundModule

    it("seasonName maps the engine index (0=spring..3=winter)", function()
        assert.are.equal("spring", ASM.seasonName(0))
        assert.are.equal("summer", ASM.seasonName(1))
        assert.are.equal("autumn", ASM.seasonName(2))
        assert.are.equal("winter", ASM.seasonName(3))
        assert.are.equal("summer", ASM.seasonName(99)) -- out of range -> safe default
    end)
    it("isRainy is true for RAIN / THUNDER / HAIL only", function()
        assert.is_true(ASM.isRainy(_G.WeatherType.RAIN))
        assert.is_true(ASM.isRainy(_G.WeatherType.THUNDER))
        assert.is_true(ASM.isRainy(_G.WeatherType.HAIL))
        assert.is_false(ASM.isRainy(_G.WeatherType.SUN))
        assert.is_false(ASM.isRainy(_G.WeatherType.SNOW))
        assert.is_false(ASM.isRainy(nil))
    end)
end)
