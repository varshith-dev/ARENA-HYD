# ARENA-HYD development handoff

## User's current direction

Build a GTA-style open-world HITEC City, Hyderabad game for Windows, Android APK and desktop/mobile web, under 15 GB. Preserve the approved Cyber Towers and metro viaduct appearance. Improve fidelity using the provided street-view references, add solid obstacle rules, a working metro train, more vehicles and pedestrians, and real building footprints in currently empty areas. Latest priority: transfer everything to the user's stronger laptop via PUBLIC GitHub, as explicitly requested. See `CONVERSATION-CONTEXT.md` for the user's full direction.

## Validated build included in the release

`build/windows/ArenaHyderabad.exe`, `build/android/ArenaHyderabad.apk`, and `build/web/` are the last validated corridor revision. They include Trident, TCS Deccan Park, Cyber Pearl, HDFC/Whiteboard frontage, five rigged adult citizen variants, five vehicle types, native-resolution graphics, desktop controls and Escape menus. The map contains 13,635 prepared OSM building features with 68 courtyard holes. `docs/validation-2026-11-07.md` records tests and limitations. Native views run around 22–31 FPS on the old laptop's Intel UHD; this is not a promised frame rate on other devices.

## Source changes started after that build

- `game/scripts/world_rules.gd`: full-body clearance checks, safe vehicle exits, line-of-sight entry rules and recovery placement.
- `city.gd`: continuous building collision envelopes, two-sided solid surfaces and one collision mesh per geographic cell; glass, roofs, poles, tree trunks and metro parts participate. Neutral base ground replaces blanket grass; mapped park/grass areas remain green. These changes need focused collision regression tests before a new release.
- `actor.gd` and `main.gd`: collision-aware vehicle rotation, stopping against walls, blocked-exit checks and guarded recovery. Source parses successfully. See the handoff test result note below for gameplay checks.
- `scripts/streetview_capture.py`: visible Chrome/Edge capture with coordinate folders, headings, public panorama pose, OSM candidate matches, resumable manifest and HTML gallery. Initial captures on this GPU were blank and correctly flagged unverified. Blank-frame checks and support for Google's `600a` URL form are implemented; successful photographic captures still need verification on the stronger laptop.
- `game/data/hitec-city.infill.geojson`: **8,024 candidate** Microsoft imagery-derived footprints clipped to the district from a 628,630-record tile. These are NOT yet integrated, not 8,024 confirmed new buildings. The downloaded tile is indexed in `docs/infill-provenance.json` under CDLA Permissive 2.0. Filter overlaps with OSM buildings, all courtyard envelopes, roads, parks and water before rendering. Imagery may predate the current city.

## Required next work

### Handoff test result — 2026-11-07

Current source passes headless world generation, courtyard/fleet/character checks, desktop menu/reference/native-resolution checks, vehicle exit and re-entry, pickup/delivery rewards, pursuit/escape and graphics preset checks. Map validation passes using the relocated portable Python 3.11.15 runtime. A self-collision query exclusion bug was fixed during this check. Tests now return a nonzero exit if an assertion prevents full completion. The binary builds were not re-exported after these changes; focused collision regression and visual checks remain.

### Implementation queue

1. Test pedestrian/car sweeps against building walls, glass, trees, metro pillars, and corners; test both exits blocked, moving-car entry rejected, recovery clearance, and holes under elevated canopies. Fix any collision regressions before export.
2. Build a visible metro train on the existing OSM paired-track alignment, with station stops and safe boarding rules. Train implementation has **not** been completed. Existing station structures are visual reconstructions; platforms/access need physical alignment and testing.
3. Increase traffic/pedestrian density around main roads/stations while profiling the active simulation radius. Population increase has **not** been completed. Current fleet: sedan, hatchback, SUV, auto-rickshaw, bus; five civilian appearances.
4. Filter and merge the supplementary footprints with source labels, conservative heights and no duplicates. Correct remaining urban surfaces; do not fill actual parks, water or courtyards with invented buildings.
5. Run the capture tool on the stronger laptop, inspect valid frames, match facades to OSM IDs, and extend `game/data/building-profiles.json`. A nearby footprint candidate alone is not an exact building identification.
6. Run `scripts/build.ps1`, inspect native captures, export all targets and update the validation report. Android hardware and real browser gameplay still need device checks.

## Important project details

- Godot 4.7.2 Compatibility, `game/project.godot`; metres; origin 17.4485 N / 78.3825 E. WGS84 ECEF to local east/north, Godot Z points south.
- Python dependencies in `scripts/requirements.txt`. Portable bundle includes `tools/python/python.exe` and `tools/python-libs`.
- OSM preparation: `scripts/prepare_map.py`; validation: `scripts/validate_map.py`; profiles: `game/data/building-profiles.json`; source attribution in `docs/*provenance.json`.
- Reference images: original 36 PNGs in `hyd-images/`. Use them as modelling references, not exported textures. Many district heights/facades remain estimates.
- Cached geometry is under the current OS user's Godot app-data directory. It is disposable and versioned by data/source hashes. Do not transfer old geometry caches.
- F6 cycles reference cameras; Escape returns to the menu. The user wants thin, sharp details and dislikes blurry rendering, crude block buildings and desktop touch buttons.
- No task subagents were authorized. Keep source changes in the project repository, not the accidental parent repository on the original machine.
