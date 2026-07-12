# FS25 Realistic Sound Overhaul — Research & Plan (Source of Truth)

**Status:** RESEARCH + PLANNING (no code yet — maintainer-standard: erst Forschung/Planung)
**Started:** 2026-07-12
**Project name (LOCKED):** `FS25_SoundOverhaulRealism` — part of the "…Realism" series (sibling to `FS25_IronHorseRealism`)
**Predecessor context:** IronHorse Realism (v0.2.1.0, done) — same injection philosophy, applied to audio.

---

## 1. Vision & Scope

A FS25 mod that **automatically replaces the vanilla sounds** with a realistic set — a real
*Hörgenuss* — across **all vehicles, implements, environment, weather**. New and missing sounds
where vanilla is thin. Not a per-vehicle add-on: a **global overhaul** with graceful vanilla
fallback for anything not (yet) covered.

**Module priority chain (like IronHorse — one module at a time, not all at once):**
1. **Motor** (the star: start / stop / continuous RPM-pitched loop / load)
2. Transmission + brakes (gear*, brakes1-3, retarder, clutchCracking)
3. Turbo / aux (turboWhistle, blowOffValve, fan, airCompressor*)
4. Implements / tools (work sounds via same hook, `AudioGroup` filter)
5. Environment + weather (birds, wind, water, rain, thunder) — **last** (different managers)

---

## 2. DECISION LOG

| # | Decision | Choice (2026-07-12) | Why |
|---|----------|---------------------|-----|
| D1 | Sample-sourcing strategy (the license showstopper) | **Framework + CC0 starter (Hybrid)** | Code = the real, clean value (GPLv3). Audio ships **only CC0**; sound packs are **pluggable** → sidesteps the "good diesel loops are rare on CC0" problem. Runs out-of-the-box (Apple-KISS). Own recordings can become a premium pack later. |
| D2 | Replacement mechanism | **Script hook on `SoundManager` (global), NOT built-in `externalSoundsFile`** | `externalSoundsFile` is *gap-filler only* (internal has priority) → useless as an override. The hook is deterministic, global, covers modded vehicles too. |
| D3 | Injection point | **Overwrite `SoundManager:createAudioSource(sample, filename)`** | Single choke point: every loader (single + plural) funnels here; full context available (`sample.sampleName`, `sample.modifierTargetObject`=vehicle, `sample.audioGroup`). RPM/load pitch modifiers keep working on the swapped file. |
| D4 | UX | Auto-overhaul as default + a global on/off toggle; per-vehicle shop-config **optional, later** | Matches the maintainer's "automatically replace" vision; toggle for safety/MP. Shop-config is the market norm (More Motor Sounds) but heavier — defer. |
| D5 | License (code) | GPLv3 (repo gold-standard default) | Per `reference-keilerhirsch-repo-standard`. |

---

## 3. Engine Mechanics (verified against GIANTS source)

Source (local primary): `Steam/.../Farming Simulator 25/sdk/debugger/gameSource.zip` (951 Lua).

### 3.1 How every sample is loaded
`g_soundManager:loadSampleFromXML(xmlFile, baseKey, sampleName, baseDir, components, loops, audioGroup, i3dMappings, modifierTargetObject, requiresFile)`
- `SoundManager.lua:385` — resolves definition via `validateSampleDefinition`, applies a
  `#template` from `soundTemplates.xml`, sets `sample.filename = Utils.getFilename(...)`, then calls
  `createAudioSource(sample, sample.filename)` (`:428`).
- `sample.modifierTargetObject = modifierTargetObject` is set at `:420` **before** createAudioSource
  → the vehicle is known at the swap point.
- Plural variant `loadSamplesFromXML(... "motor" / "gearbox" ...)` loads a **set** for RPM
  crossfading — also funnels through `createAudioSource`.

### 3.2 The master injection point — `createAudioSource` (`SoundManager.lua:470`)
```lua
function SoundManager:createAudioSource(sample, filename)
    ...
    sample.filename = filename
    sample.soundNode = createAudioSource(name, filename, outerRadius, innerRadius, volume, loops)
    ...
end
```
**Plan:** `Utils.overwrittenFunction(SoundManager, "createAudioSource", ...)`. In the wrapper, look up
`(sample.sampleName, sample.audioGroup, sample.modifierTargetObject)` against our profile map; if a
replacement exists, pass our filename to `superFunc`; else call `superFunc` unchanged (= vanilla).
One hook = total coverage. Not matched = untouched.

### 3.3 `externalSoundsFile` (why it is NOT enough)
`Vehicle.lua:598` sets `externalSoundsFilename` from `vehicle.base.sounds#filename`.
`SoundManager.lua:276-282`: external file is consulted **only if the sample key is absent internally**
→ it *fills gaps*, does not override. Confirmed unsuitable for a forced overhaul.

### 3.4 Two-layer sound model
- **`data/sounds/soundTemplates.xml`** (5531 lines): mix/physics templates
  (`engineSmall/Medium/Large`, `engineVintage`, radii, lowpass, volume indoor/outdoor) +
  **modifiers**: `MOTOR_RPM`, `MOTOR_RPM_REAL`, `MOTOR_LOAD`, `SPEED`, `ACCELERATE`, `DECELERATE`,
  `BLOW_OFF_VALVE_STATE`, `BRAKE_TIME`, `CRUISECONTROL`, `SUSPENSION`, etc. These drive
  pitch/volume/lowpass at runtime — **they keep working on a swapped sample file**.
- **`data/sounds/vehicles/*`** actual sample library, by category: `engine, turbo, brake, transmission,
  gearShift, fan, retarder, hydraulic, compressor, horn, cabin, reverse_beep, steering_wheel,
  windscreen, load, surfaces, shared, npc`.

### 3.5 Vehicle sample taxonomy (Motorized.lua:1819-1845 `loadSounds`)
Single: `motorStart, motorStop, clutchCracking, gearEngaged, gearDisengaged, gearGroupChange,
gearLeverStart/End, gearGroupLeverStart/End, gearRangeChange, blowOffValve, retarder,
airCompressorStart/Stop/Run`.
Plural sets: `motor` (`spec.motorSamples`), `gearbox` (`spec.gearboxSamples`).
Also (elsewhere in spec): `brakes1-3, turboWhistle, fanNoice, wheelHubBearingNoise, warning,
transmissionShiftFailed1-3`.

---

## 4. Vehicle → Sound-Profile Mapping (the "realistic" brain)

One global sample would make every vehicle sound identical = unrealistic. So the hook must pick a
**profile** per vehicle. Inputs available on `modifierTargetObject` (the vehicle): power (kW/hp),
cylinder count / motor type, brand/category, `soundTemplate` class (small/medium/large/vintage).

**Design:** an `IronHorse-style` data table `SoundProfiles.lua`:
`profile = f(powerBand, motorType, category)` → `{ motor=<pack>, turbo=<pack>, brakes=<pack>, ... }`.
Start coarse (3-4 engine classes: small/medium/large/vintage) mirroring `soundTemplates.xml` classes;
refine later. Fallback profile = "do nothing" (vanilla) when unmatched.

---

## 5. Multiplayer

Sound is **client-side** (`Motorized:loadSounds` is guarded by `if self.isClient`). Playback needs no
server authority. BUT the **config/toggle state** (global on/off, later per-vehicle chosen pack) is
shared → use the throttled server-authoritative sync pattern
(learned skill `fs25-mp-throttled-authoritative-sync`) for any *setting*, not for the audio itself.
No money/authoritative writes here (unlike IronHorse repair), so MP surface is small. Design MP-clean
from day 1 anyway.

---

## 6. Sample-Sourcing (D1 = Hybrid) — legal hygiene rules

**HARD RULE:** ship **only CC0 / public-domain** audio, or the maintainer's own recordings. **Never** rip or
"modify" GIANTS/vanilla samples (that is a derivative of copyrighted audio — this is exactly what the
"⭐⭐⭐ modified GIANTS sounds" mods do, and it is *not* clean).

**CC0 sources (verified live 2026-07-12):**
- **Freesound.org** — filter by CC0 tag (`freesound.org/browse/tags/cc0/`), 11k+ PD sounds. Primary.
- **Pixabay** sound effects — CC0, no attribution.
- **ZapSplat** — CC0 1.0 license type (free account).
- **SoundBible** — some CC0 / PD.
- ⚠ Reality: good **diesel engine loops** (that pitch-shift cleanly across RPM) are **rare** on CC0
  sites (mostly one-shots/horns). → This is *why* Hybrid wins: pluggable packs + a small curated
  starter, not a full CC0 set we can't source well.

**Pack format (design):** a mod-local folder of `.ogg` samples + a manifest mapping
`sampleName → file` per profile. Community/own packs drop into the same structure.

**Own-recording option (later, premium):** the maintainer records real vehicles (48kHz, clean loopable
engine loops per RPM band). Best quality + 100% clean + unique. Not blocking for MVP.

---

## 7. Reuse-First (existing work studied)

- **More Motor Sounds** (ModHub) — global script, alternative engine sound as **shop config** per
  vehicle; large DB; star-graded (⭐ original recordings, ⭐⭐ prefab, ⭐⭐⭐ modified GIANTS). Confirms the
  global-script approach is standard; confirms the shop-config UX and the legal spectrum.
- **Improved Harvester Sounds** — same pattern for combines/foragers.
- **Takeaway:** our differentiator = *forced auto-overhaul default* + *CC0-clean* + *pluggable packs*.
  Not yet another shop-config pack.

---

## 8. Open Questions for Build Phase

1. Confirm `createAudioSource` overwrite fires for **already-loaded** shared samples / caching
   (SoundManager may pool `self.samples`) — test that our swap isn't bypassed by a cache hit.
2. Environment/weather sounds: which manager? (`AmbientSoundManager`? map-level `<sounds>`?) —
   research before Module 5. Not in `Motorized`.
3. How to expose the global toggle (settings menu vs. modSettings XML vs. keybind).
4. Verify RPM pitch modifiers behave on our loop lengths (loop points, sample rate).
5. Starter-pack scope: how many engine classes for MVP (recommend 3: small/medium/large diesel).

---

## 9. Build-Phase Skeleton (once research locked)

- `FS25_SoundOverhaul/`
  - `modDesc.xml`, `icon`, l10n
  - `scripts/SoundOverhaul.lua` — the `createAudioSource` overwrite + toggle
  - `scripts/core/SoundProfiles.lua` — vehicle→profile map (IronHorse-style data table)
  - `scripts/core/PackLoader.lua` — read pack manifest, resolve `sampleName→file`
  - `sounds/packs/starter_cc0/` — curated CC0 `.ogg` + `manifest.xml` + `CREDITS.md` (licenses)
  - `tests/` — lupa headless (learned skill `lupa-headless-luajit-mod-testing`) for profile-mapping logic
  - `docs/` (this file), `CHANGELOG.md`, `README.md`

---

## Sources
- GIANTS engine Lua source (local): `gameSource.zip` — `SoundManager.lua`, `Motorized.lua`, `Vehicle.lua`; `data/sounds/soundTemplates.xml`.
- https://www.farming-simulator.com/mod.php?mod_id=357192 (More Motor Sounds)
- https://www.farming-simulator.com/mod.php?mod_id=281440 (Improved Harvester Sounds)
- https://freesound.org/browse/tags/cc0/ · https://pixabay.com/sound-effects/search/cc0/ · https://www.zapsplat.com/license-type/cc0-1-0-universal/

---

## 10. Brainstorm Round 2 (2026-07-12) — scope expansion

**Maintainer steer:** MP = must-have · truly realistic sound for EVERYTHING · **seasonal/monthly
ambience** ("wie in echt") elevated to a **first-class pillar**, not the last afterthought.

### 10.1 Name — shortlist (decision open)
Candidates: **IronEar** (sibling to IronHorse family), **TrueDiesel**, **Diesel & Dawn** (captures both
pillars: engine + seasonal nature), **TerraSound**, **Auralis**, **SoundScape Realism**, **HiFi Harvest**.
Leaning: a name that carries BOTH engine + ambience (not iron-only), since scope now = vehicles + nature.

### 10.2 Seasonal/monthly ambience (NEW first-class module)
- **System exists:** `g_currentMission.ambientSoundSystem` (indoor/outdoor aware, moving sounds,
  placeable sounds e.g. rollercoaster). Hookable. Exact selection API = build-phase task.
- **Signals available:** period/month (12 periods via `growthMode`/environment), `WeatherType`
  (incl. THUNDER), dayTime/nightFactor, indoor/outdoor, biome/region.
- **Design = layered ambience selected by (period × daytime × weather × region):**
  - Spring: dawn chorus, songbirds ramp, insects waking, wet ground.
  - Summer: crickets/cicadas, dry heat shimmer, dense insect bed, distant machinery.
  - Autumn: wind, rustling leaves, migrating geese, more rain, sparser birds.
  - Winter: muffled/quiet, wind, sparse crows, snow-hush; night owls.
  - Day/night overlay: dawn chorus vs. owls/crickets/frogs at night.
  - Weather overlay: rain intensity, rain-on-cabin-roof (indoor) vs open, distant→near thunder, wind gusts.
- Ambience is **cosmetic/client-side** → per-client is fine; keyed to server-synced weather/period so it
  stays consistent across MP naturally.

### 10.3 MP architecture (must-have) — good news
- Audio playback is **client-side** (`Motorized:loadSounds` guarded by `if self.isClient`;
  ambientSoundSystem is client). **No server authority needed for sound itself.**
- Only **settings/config** (master toggle, per-category toggles, chosen pack, volumes) need sync →
  throttled server-authoritative pattern ([[fs25-mp-throttled-authoritative-sync]]). Small surface,
  no money/authoritative writes. Design MP-clean from day 1.

### 10.4 Extended feature backlog (what else matters)
- **Interior vs exterior:** cabin muffling (templates already lowpass indoor); windows open/closed;
  extend indoor/outdoor to ambience + weather (rain on roof).
- **Surface-dependent:** tire/rolling sound by ground (`data/sounds/vehicles/surfaces` exists) —
  asphalt/field/gravel/mud.
- **Load-dependent:** engine load, `MOWER_LOAD`/`COMBINE_LOAD`/`SPEED` modifiers → working sounds scale
  with real load (threshing, baler, sprayer, PTO, hydraulics).
- **Engine detail:** cold-start vs warm, turbo spool, blow-off, exhaust/retarder brake (trucks).
- **Nature/world:** wind in trees, water/rivers, animal husbandry ambience, distant village/traffic.
- **Config/UX:** master + per-category toggles, volume sliders, transparent vanilla fallback,
  profile/pack selection.
- **Respect AudioGroups** (VEHICLE vs ENVIRONMENT) so the player's in-game volume sliders still work.

### 10.5 RISK REGISTER (sleepers to decide early)
1. **Distribution channel:** ModHub may **reject a pluggable-external-pack design** (loading user files) →
   our **GitHub-first** repo (gold-standard) sidesteps this. Decide ModHub vs GitHub-only per module.
2. **Performance/VRAM/RAM:** "sound for EVERYTHING" = many samples loaded → memory + load-time cost.
   Need pooling / streaming discipline (ties to AutoVRAM sensitivity + Katana thermal). Budget sample
   count per profile.
3. **Mod compatibility:** coexistence with "More Motor Sounds" & co (both hook sound). Define policy:
   detect + defer, or last-writer-wins, or a compat toggle.
4. **Cache/pool bypass** (already logged): confirm our `createAudioSource` swap isn't skipped by a
   pooled/shared sample.

### 10.6 Modularity note
Engine-sound module and seasonal-ambience module are **independent** — can ship/version separately
(even as two mods sharing the pack format). Keeps each shippable on its own.

---

## 11. Engine-accurate vehicle sound mapping (2026-07-12) — CORE USP

**Maintainer steer:** juicy V6/V8 + realistic per-vehicle engine sound; **web-research the real engine
behind each FS25 vehicle** to assign the correct sound. **Name locked = `SoundOverhaulRealism` (…Realism series, sibling to IronHorseRealism).
Distribution = GitHub-only** (freed from ModHub → full pluggable packs allowed).

### 11.1 Feasibility (verified)
FS25 `data/vehicles/` is organized by **real brands + models** (johnDeere, fendt, caseIH, newHolland,
scania/mack/volvo trucks, … 150+ brands). Each maps to a **known real engine** → the mapping is sound.
Fine data (hp/maxRpm/config) sits in nested per-model XMLs (`<motorConfigurations>`); harvesting it is a
build-phase data task, not a blocker.

### 11.2 Realism calibration (verified — DO NOT fake V8-everything)
- **John Deere 8R = 9.0 L PowerTech PSS = inline-6 turbo-diesel** (not a V). This is the RULE.
- Tractors are overwhelmingly **inline-4 / inline-6 turbo-diesels** (JD PowerTech I6, FPT Cursor I6,
  AGCO Power I4/I6, Deutz TCD). Fendt 1000 = MAN D26 **I6** 12.4 L. Big artics (Steiger/Quadtrac/9R) =
  mostly **I6** (Cummins QSX / FPT Cursor 13).
- **Genuine V8** is SELECTIVE: **Scania V8 (16 L)** trucks = the showcase growl; a few Mack/vintage/
  special cases. → real V8 becomes a celebrated *highlight* precisely because it's rare.
- The "juicy" tractor sound = a meaty **I6 turbo-diesel growl + turbo whistle** — correct AND satisfying.

### 11.3 Data structure (IronHorse-style, two-tier)
`SoundProfiles.lua`:
- **Tier 1 — explicit per-model overrides** for flagships (accurate): key = store xmlFilename / brand+model
  → `{ engineClass, displacement, cylinders, aspiration, packRefs{motor,turbo,brakes,...} }`.
- **Tier 2 — heuristic fallback** for the long tail (150+ brands): classify by
  `(powerBand × maxRpm × category × brand-region)` → nearest engineClass. Guarantees every vehicle gets a
  *plausible* sound even before hand-mapping.
- `engineClass` examples: `i4_td_small`, `i6_td_medium`, `i6_td_large`, `i6_td_artic`, `v8_diesel_truck`
  (Scania), `i4_na_vintage`, …
- Populating Tier 1 = the incremental web-research effort (per flagship). Framework ships first; accuracy
  grows over time. Community can contribute profiles (GitHub).

### 11.4 Sources (this round)
- https://www.deere.com/en/tractors/row-crop-tractors/row-crop-8-family/power-efficiency/ (8R = 9.0L PowerTech, I6)
- https://www.deere.com/en/industrial-engines/final-tier-4-stage-v/6068hi550/ (PowerTech = inline family)

---

## 12. FINAL gap-closure (2026-07-12) — RESEARCH COMPLETE

Last curiosity sweep: "what would break a one-shot build?" Five gaps hunted, all closed.

| Gap | Result |
|-----|--------|
| G1 motor sample SET | `loadSamplesFromXML` just loops `motor(0..n)` via `loadSampleFromXML` → **all funnel through our one `createAudioSource` hook**. RPM crossfade = modifier system (MOTOR_RPM) over the layers. |
| G2 audio format | Vanilla = **`.ogg`**. `.gls` = GIANTS special format, not needed. We ship `.ogg`. |
| G3 ambient system | **See §12.1 — the big win.** |
| G4 hook viability | `SoundManager` = global class (`SoundManager.new`), `g_soundManager` = instance → wrap `SoundManager.createAudioSource` (class method) = global, covers modded vehicles. Install at script load (before vehicle spawn). |
| G5 settings/toggle | Known pattern: modSettings XML in savegame (+ optional GUI menu injection). Not a blocker. |

### 12.1 Ambient system — NATIVE seasonal/weather support (major de-risk)
Ambient sounds are **map-defined** in `data/maps/<map>/sounds/sounds.xml` (schema
`shared/xml/schema/ambientSounds.xsd`), with a `<ambient3d filename="…sounds.i3d"/>` for 3D placement,
real loops in `data/sounds/maps/*.ogg`. **The engine already gates each ambient sample by attributes:**
`spring, summer, autumn, winter, sun, rain, cloudy, snow, inForest, nearWater, inVehicle, outVehicle,
isIndoor` — combined via `<required/>` (all must match) / `<prevent/>` (any kills it). Per-sample:
`audioGroup, min/maxVolume, indoorVolume, min/maxLoops, min/maxRetriggerDelaySeconds, min/maxPitch,
min/maxDelay, fadeIn/OutTime, min/maxLength`.
`environment.xml` confirms 4 seasons + weather types (SUN/CLOUDY/RAIN/HAIL/SNOW/TWISTER) with per-season
weather weights + daytime windows.

**→ Our seasonal ambience = author a global `sounds.xml` (+ CC0 `.ogg` loops) using these native
attributes, injected into `g_currentMission.ambientSoundSystem` at runtime (global, map-agnostic).** No
fighting the engine. Exact injection call = the class behind `ambientSoundSystem` (build-time 5-min
lookup: find the loader of `ambientSounds.xsd` / `sounds.xml`).

### 12.2 One-shot build — honest scope & order
"In einem Rutsch fertig" = the full **code framework + logic + minimal proof audio + tests + repo**, in
one focused session. The **rich audio content library grows after** (manual CC0 curation + the maintainer's
in-game ears — audio quality can't be unit-tested; lupa only tests logic).

Build order (one session):
1. `modDesc.xml` + global bootstrap (install `createAudioSource` hook + ambient injection).
2. `SoundProfiles.lua` (Tier-2 heuristic map first → every vehicle covered) + a few Tier-1 flagships.
3. `PackLoader.lua` (manifest → sampleName/attributes → file) for both engine + ambient packs.
4. Engine module (swap via hook) + Ambient module (global `sounds.xml` injection).
5. `starter_cc0/` minimal proof set (3 engine classes + 1 V8 + 4 seasonal ambient beds) + `CREDITS.md`.
6. Settings toggle (modSettings XML).
7. lupa headless tests (profile mapping, attribute logic) → repo-gold-standard release (GitHub).
In-game audio tuning = the maintainer, after.

**RESEARCH STATUS: COMPLETE. Ready for `/ecc:plan` → build.**
