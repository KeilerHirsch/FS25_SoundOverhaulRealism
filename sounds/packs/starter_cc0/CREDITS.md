# Starter CC0 pack — audio credits

**Every file here is CC0 / public-domain.** No ripped or "modified" vanilla or
copyrighted audio. All samples were sourced from OpenGameArt.org (CC0), then trimmed,
downmixed to mono where noted, level-normalised and loop-processed for this pack.

## Engine samples
Source: **"racing car engine sound loops"** by **domasx2** — CC0 —
<https://opengameart.org/content/racing-car-engine-sound-loops>
(the author remade these from a public-domain pdsounds sample; the six loops differ
only in pitch). Assigned to engine classes by fundamental frequency, low → high:

| File | Class | Source loop | Fundamental |
|------|-------|-------------|-------------|
| `engine/v8_truck/motor.ogg`  | v8_diesel_truck | loop_0 | ~43 Hz (deepest) |
| `engine/i6_large/motor.ogg`  | i6_td_large     | loop_1 | ~116 Hz |
| `engine/i6_medium/motor.ogg` | i6_td_medium    | loop_3 | ~261 Hz |
| `engine/i4_small/motor.ogg`  | i4_td_small     | loop_5 | ~292 Hz |

`motorStart` / `motorStop` are not yet included → those stay vanilla (graceful).

## Ambience beds
| File | Source | Author | License | URL |
|------|--------|--------|---------|-----|
| `ambient/summer_night.ogg` | Crickets Ambient Noise – loopable | Wolfgang_ (Ted Kerr) | CC0 | <https://opengameart.org/content/crickets-ambient-noise-loopable> |
| `ambient/rain.ogg` | Rain (loopable) | Ylmir | CC0 | <https://opengameart.org/content/rain-loopable> |
| `ambient/spring_day.ogg` | Forest bird sounds | pauliuw | CC0 | <https://opengameart.org/content/forest-bird-sounds> |
| `ambient/summer_day.ogg` | Forest bird sounds | pauliuw | CC0 | (same as above) |
| `ambient/autumn_day.ogg` | Forest bird sounds | pauliuw | CC0 | (same as above) |
| `ambient/winter_day.ogg` | Forest bird sounds (quieted variant) | pauliuw | CC0 | (same as above) |

The three day beds currently share one forest source; the winter bed is a quieter
mix of it. These are v0.1 real-CC0 starters — swap in richer per-season recordings
over time (see roadmap). The forest source is a low-samplerate field recording (8 kHz)
so it reads as distant/muffled ambience.

## Where to source more CC0 audio
- **OpenGameArt.org** — filter by CC0: <https://opengameart.org/>
- **Freesound.org** — CC0 tag: <https://freesound.org/browse/tags/cc0/>

**Not CC0, do not use here:** Pixabay (own licence, not CC0), any CC-BY sample
(requires attribution — this pack ships CC0 only).
