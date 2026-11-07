# ARENA / Hyderabad

**Moving to another laptop:** download the portable archive from [Releases](https://github.com/varshith-dev/ARENA-HYD/releases). See [new laptop setup](docs/NEW-LAPTOP.md), [development handoff](docs/HANDOFF.md) and [project context](docs/CONVERSATION-CONTEXT.md). `RUN-GAME.cmd` starts the included tested build; `OPEN-EDITOR.cmd` opens the current source. The current source contains additional collision work beyond the packaged builds.

A Godot 4.7.2 open-world prototype using an offline OpenStreetMap snapshot around HITEC City. Walk, drive, explore, complete delivery contracts, and encounter traffic and pedestrians. This is an original game, not a recreation of GTA assets.

The latest pass preserves Cyber Towers and the metro, replaces the old generic tower generator, and adds photo-informed Trident, TCS Deccan Park, Cyber Pearl, and roadside façades. The OSM importer preserves courtyards and removes duplicate relation members and the duplicate Raidurg station block. Five rigged citizen variants and five vehicle types replace the original capsule people and box cars. Most of the wider city still has estimated heights and generic local architectural styles. See [visual fidelity notes](docs/visual-fidelity.md).

## Run

After building, double-click `build/windows/ArenaHyderabad.exe`.

To run from source in PowerShell:

```powershell
./tools/godot/godot.exe --path game
```

To open the reference comparison camera:

```powershell
./tools/godot/godot.exe --path game -- --reference
```

The first launch prepares the city and shows progress. Later launches reuse a local geometry cache. Editing the city geometry invalidates that cache.

## Controls

| Input | Action |
| --- | --- |
| WASD / arrows | Walk or drive |
| Mouse | Look |
| Shift | Sprint |
| Space | Jump / brake |
| E | Enter or exit a car |
| C | Third-person / distant / first-person camera |
| M | Map |
| N | Contract |
| Left mouse | Fire |
| R | Reload / recover |
| T | Day / night |
| Escape | Pause, settings, controls, quit |
| F6 | Cycle reference cameras, then return to play |
| F11 | Fullscreen |

Touch controls are enabled only for mobile platforms or browsers with a coarse pointer. Resume from the Escape menu exits reference inspection.

## Build and validate

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/build.ps1
```

The build prepares and validates the OSM geometry, checks gameplay, citizen animations, vehicle variety and desktop menus, then exports Windows, Web, and a development-signed Android APK. Export outputs are in `build/windows`, `build/web`, and `build/android`. The APK is for device testing, not Play Store submission. Map preprocessing uses Python 3.11 with Shapely and pyproj in `tools/python-libs`.

Serve the web export with:

```powershell
node scripts/serve.mjs
```

For a native render check:

```powershell
./tools/godot/godot.exe --path game -- --capture --reference
```

The game writes `build/reference-0.png` and exits after capturing. Use `--reference=2` for Trident, `--reference=3` for Cyber Pearl / HDFC Bank, or `--reference=4` for TCS Deccan Park. F6 cycles all five views. These screenshots come from the game renderer; the camera poses are approximate panorama matches.

## Sources

- Map data © [OpenStreetMap contributors](https://www.openstreetmap.org/copyright), ODbL.
- Texture and sky assets: [Poly Haven](https://polyhaven.com/license), CC0. Powered by Poly Haven. Individual source URLs and hashes are in `docs/asset-provenance.json` and `docs/foliage-provenance.json`.
- User-provided street-view screenshots are modelling references only, outside the exported game assets.
- Rigged characters: Quaternius Ultimate Modular Men and Animated Women packs (CC0). Download URLs, original and adapted hashes, and licence pages are recorded in `docs/character-provenance.json`.

The project uses the Compatibility renderer to support Windows, Android and WebGL 2. Native rendering quality depends on the device. The user increased the new laptop's storage budget to **50 GB** (previously 15 GB); the build script checks the current limit.
