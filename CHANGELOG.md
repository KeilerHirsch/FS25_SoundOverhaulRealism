# Changelog

All notable changes to this project are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.1.0.0] — 2026-07-12
### Added — Foundation release (the framework)
- **Global sound choke point:** overwrites `SoundManager:createAudioSource`, the one
  method every sample loader (single + plural motor/gearbox sets, base + modded
  vehicles) funnels through. One hook = total coverage; anything uncovered falls
  back to vanilla, untouched.
- **Two-tier vehicle → engine-class brain (`SoundProfiles`):** Tier 1 explicit
  flagship overrides (JD 8R = inline-6, Scania = V8, 9R/Steiger/T9 = articulated),
  Tier 2 heuristic classification `(power × rpm × category × brand)` so every
  vehicle gets a plausible class. Realism-calibrated: inline-6 turbo-diesel is the
  rule; V8 is the selective Scania-truck highlight — never faked everywhere.
- **Seasonal / weather ambience (`AmbientSoundModule`):** own client-side scheduler
  that reads season × daytime × weather × indoor and plays the matching
  ENVIRONMENT-group loop. Map-agnostic (works on any map).
- **Pluggable packs (`PackLoader`):** manifest-driven `.ogg` resolution; only files
  present on disk are registered, so a pack ships a manifest and swaps nothing until
  real CC0 audio is added.
- **Minimal config + persistence:** master toggle + per-module flags, saved to
  modSettings, server-authoritative MP sync (`SoundConfigSyncEvent`) — audio is
  client-side, only the config syncs.
- **Starter CC0 pack scaffold** (`sounds/packs/starter_cc0/`) with manifest + credits
  template. Audio content is added incrementally (in-game ears).
- **Tests:** busted unit suite over all pure logic (profiles, pack resolution,
  ambience gating, config); `.luacheckrc`.

### Notes
- This is the code framework. The rich audio library grows after, in-game.
- Distribution: GitHub-only. Ships only CC0 / own audio.
- Passed a two-agent review battery (code + security) before release; both HIGH
  findings fixed (ambient beds now load via the trusted `loadSampleFromXML` path;
  engine swaps gated to real `spec_motorized` vehicles) plus MP deny-by-default and
  pack path-traversal hardening.
- Roadmap: in-game toggle keybind/GUI, server→client config push, more modules.
