# Sound packs

A **pack** is a folder of `.ogg` samples plus a `manifest.xml` that maps them to
engine classes and ambience beds. Packs are pluggable — drop a new folder in here
and point `PackLoader` at its manifest.

## Layout
```
packs/<packname>/
  manifest.xml          # the mapping (see starter_cc0/manifest.xml)
  CREDITS.md            # one row per file: source + license (MUST be CC0/own)
  engine/<class>/*.ogg  # motor / start / stop per engine class
  ambient/*.ogg         # seasonal / weather beds
```

## Engine classes
`i4_td_small` · `i6_td_medium` · `i6_td_large` · `i6_td_artic` ·
`v8_diesel_truck` · `i4_na_vintage`
(see `scripts/core/SoundProfiles.lua` — the two-tier vehicle → class brain.)

## Ambience bed keys
`<season>_day` · `<season>_night` · `<season>_rain`, where season ∈
`spring|summer|autumn|winter`. Indoors plays nothing (the cabin muffles it).
(see `scripts/modules/AmbientSoundModule.lua`.)

## The one rule
Only **CC0 / public-domain / your own recordings**. Never ripped or "modified"
vanilla or copyrighted audio. Record every source in the pack's `CREDITS.md`.
Files that do not exist on disk are simply skipped — the sample stays on vanilla.
