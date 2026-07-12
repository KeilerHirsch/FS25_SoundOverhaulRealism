-- luacheck configuration for FS25_SoundOverhaulRealism
-- FS25 runs LuaJIT (Lua 5.1 semantics).
std = "lua51"

-- Globals this mod defines (module system + core singletons).
globals = {
    "SoundOverhaulRealism",
    "SoundModule",
    "SoundModuleRegistry",
    "SoundConfig",
    "SoundProfiles",
    "PackLoader",
    "SoundSettings",
    "SoundConfigSyncEvent",
    "EngineSoundModule",
    "AmbientSoundModule",
}

-- Engine-provided globals the mod reads (never assigns).
read_globals = {
    "Utils", "Logging", "Class", "InitEventClass", "Event",
    "SoundManager", "g_soundManager", "AudioGroup", "WeatherType",
    "createAudioSource", "getAudioSourceSample",
    "g_currentMission", "g_currentModDirectory", "g_currentModName",
    "g_modIsLoaded", "g_dedicatedServer", "g_server", "g_client",
    "g_storeManager", "g_brandManager",
    "FSBaseMission", "Mission00", "TypeManager", "SpecializationUtil",
    "NetworkUtil", "InputAction", "source",
    "streamWriteBool", "streamReadBool", "streamWriteString", "streamReadString",
    "streamWriteFloat32", "streamReadFloat32", "streamWriteUIntN", "streamReadUIntN",
    "XMLFile", "fileExists", "getUserProfileAppPath",
}

-- Tests load the mod with stubbed engine globals.
files["tests/"] = {
    std = "+busted",
    globals = { "_G" },
    read_globals = {},
}
