# Build Notes — decisions made during the one-shot build (2026-07-12)

Companion to `SOUND_RESEARCH.md` (the research source of truth). This records the
build-time findings + choices that differ from or refine the research doc.

## 1. Ambient system is engine-side — design refined
The research doc assumed we could "inject a global `sounds.xml` into
`g_currentMission.ambientSoundSystem` at runtime". Verified against
`gameSource.zip`: **that system is C++-side**. The only Lua-visible methods are
`setIsIndoor`, `addMovingSound`, `removeMovingSound` (used by `Enterable.lua`,
`PlaceableRollercoaster.lua`). There is **no Lua API to append gated ambient
samples** or load a runtime `sounds.xml`.

**Decision:** `AmbientSoundModule` runs its **own client-side scheduler** — read the
environment (`environment.currentSeason`, `.isSunOn`, `.weather`, indoor state) each
throttled tick, and play an ENVIRONMENT-group loop. This is **better**: map-agnostic
(works on every map, not just maps whose author added a `sounds.xml`), and the gating
LOGIC stays pure Lua = unit-tested.

**Bed samples go through `g_soundManager:loadSampleFromXML`** (from the bundled
`sounds/ambient.xml`), NOT a hand-rolled sample table. The review battery caught this:
`SoundManager:playSample`/`stopSample` no-op unless `sample.soundSample` and the full
`sample.current` attribute set exist, and only the loader populates them — a hand-built
`{ soundNode = … }` table plays nothing (or crashes once `soundSample` is added
without `current`). `loadSampleFromXML` builds the whole valid sample the engine
trusts. `ambient.xml` file paths are `requiresFile`, so a bed with no `.ogg` yet simply
never plays.

## 2. Hook points (verified)
- **Sound swap:** `SoundManager.createAudioSource` (class method) via
  `Utils.overwrittenFunction`. Single choke point for all vehicle/tool samples.
- **Client tick:** `FSBaseMission.update` (appended) — NOT `Mission00.update`.
  Mission00 inherits `update` from the base; assigning `Mission00.update` would
  shadow the inherited chain and break the mission update. Wrapping the base keeps
  it intact.
- **Session start:** `Mission00.load` (appended) — the same verified point IronHorse
  uses; loads settings + starter pack + coexistence detection.

## 3. Sample format & normalisation
- Samples are `.ogg` (`.gls` is a GIANTS special format, skipped).
- Plural sets (`motor(0)`, `gearbox(3)`) are normalised to one pack key (`motor`,
  `gearbox`) — the whole RPM set maps to one file; the engine's MOTOR_RPM modifiers
  crossfade/pitch it at runtime.

## 4. Honest scope of "in einem Rutsch"
Shipped: the **code framework** — swap engine, profile brain, pack loader, ambience
scheduler, config/MP/persistence, tests, repo. **Not** shipped: the rich audio
library (CC0 curation + own recordings). Audio quality can't be unit-tested; it needs
in-game ears and grows incrementally. `PackLoader` skips missing files, so the mod is
safe to ship audio-less — it simply swaps nothing until packs are filled.

## 5. What still needs in-game verification (tuning pass, not code)
- `createAudioSource` swap is not bypassed by a pooled/shared sample.
- `environment.currentSeason` index order (assumed 0=spring..3=winter) + the
  `weather:getCurrentWeatherType()` accessor name.
- Ambient 2D-bed radii / volume feel; RPM loop points on real diesel loops.
- Coexistence behaviour with More Motor Sounds when both are loaded.
