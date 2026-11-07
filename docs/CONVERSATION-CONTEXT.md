# Project context for the next machine

This document preserves the user's game direction and the current development state. Read it with `HANDOFF.md`, `NEW-LAPTOP.md`, and the validation/provenance reports. It is a project handoff, not a claim that every requested feature is finished.

## User's requirements, in order

1. Build a realistic real-world game covering almost all of HITEC City, Hyderabad, using OpenStreetMap. Support Android APK, Android web and desktop web, with Windows native play. Original storage allocation: **15 GB**, later increased to **50 GB for the new laptop** (see latest update below).
2. The intended genre is **Vice City / GTA-style open-world action**, with the player as a person who can walk and drive, rather than only a driving camera.
3. Follow real entities and alignments. The user can provide imagery and supplied **36 street-view screenshots** from HITEC City station towards Raidurg metro station in `hyd-images/`. Aim for precise landmark/sculpture geometry, roads, facades and street objects; do not claim block approximations are accurate reconstruction.
4. NPCs should have individual activities. Add more pedestrians and vehicles and improve their models and behavior.
5. The user repeatedly asked to run the app to inspect it. Early results were rejected as dummy blocks with imprecise graphics, noise/blur, pixelation and Android-style controls on Windows. They want sharp, clear, thin visual details, proper native desktop input, and Escape/pause/settings/quit controls.
6. Improve OSM alignment, add missing real buildings, remove unwanted or duplicate ones, and preserve open courtyards. Replace generic buildings with recognizable Hyderabad architecture.
7. **Cyber Towers and the metro line were explicitly approved.** Preserve them while improving the rest of the city.
8. Solid obstacles must stop the player and vehicles. Add a functioning metro, and replace unrealistic empty grass areas with actual buildings where the evidence supports them. Do not invent development inside real parks or courtyards.
9. Create a **local Python capture tool** that opens Google Maps Street View at coordinates, visits several headings, saves images in coordinate-labelled folders, and associates them with map candidates for more accurate reconstruction.
10. Move the entire project to another laptop with a stronger GPU and processor. Preserve source, reference images, assets, datasets, builds, toolchain and development context.
11. Latest explicit instruction: **push all contents and context to GitHub, provide the URL quickly, and make the repository PUBLIC**.
12. Latest transfer update: the new Codex agent read all four guides and selected collision regression testing while preserving Cyber Towers and the metro viaduct. It could not clone/run because Git was unavailable, shell access to GitHub failed and browser automation could not establish Chrome's URL. No code was changed. Finish publishing the portable release so it can retry setup and verify hashes. The user explicitly states the **new system's maximum capacity is 50 GB**; this supersedes the previous 15 GB instruction for the new workspace.

## Current project and evidence

- Repository: https://github.com/varshith-dev/ARENA-HYD
- Engine: Godot 4.7.2, Compatibility renderer for Windows / Android / WebGL 2. The executable editor and release templates are in the portable release, not normal Git source history.
- Local coordinates: origin 17.4485 N, 78.3825 E, metres, local east/north projection, Godot Z south. Map import preserves relation holes and removes duplicate member footprints. The prepared dataset currently contains **13,635 building features and 68 courtyards**.
- Added modeled profiles include Trident, TCS Deccan Park, Cyber Pearl and HDFC/Whiteboard frontage. The wider district still contains estimated facades/heights. References are modeling evidence, not shipped textures.
- Fleet: sedan, hatchback, SUV, auto-rickshaw and bus. People: five rigged adult variants based on CC0 Quaternius assets. Traffic and pedestrians have basic activity/route behavior; richer simulation and higher density remain requested work.
- Existing Windows, web and Android builds are the last validated corridor revision. They predate the newest collision code. Read `validation-2026-11-07.md` for actual checks and limitations. The old machine's Intel UHD rendered reference views around 22–31 FPS; better hardware has not yet been measured.
- Current source adds full-body clearance, safe exit/recovery checks, vehicle entry visibility rules and continuous building collision surfaces. Its headless gameplay checks now pass, including exit/re-entry, missions, pursuit, graphics settings and desktop menus. Focused obstacle/corner and real-device checks remain necessary.
- An exclusion-array bug found during transfer preparation was fixed: Godot query exclusions are constructed before assigning the array so the player's own collision body is excluded. The smoke test now exits with failure if a test assertion interrupts completion.
- A supplementary Microsoft footprint dataset has **8,024 candidates**, not 8,024 confirmed new buildings. It is not merged into the city. Provenance, source URLs and CDLA Permissive 2.0 license are included. Reserve roads, parks, water, courtyards and existing OSM buildings before considering infill.
- The Street View tool creates coordinate folders, multiple heading captures, a manifest and HTML review gallery. It records requested/resolved panorama coordinates and nearby OSM candidates. Initial captures on the old GPU were blank, correctly marked `unverified_view` / `CHECK_`. Retry on the new laptop; a nearby footprint is not automatically an identified facade.
- A moving metro train, safe boarding, increased crowd/traffic density, and filtered infill are **not complete**. The transfer request took priority. `HANDOFF.md` lists the next implementation work.

## How to resume

Download the portable Windows archive from the repository's Releases page, extract it, and run `RUN-GAME.cmd` for the existing build or `OPEN-EDITOR.cmd` for current source. Open the extracted project as the coding workspace and read `HANDOFF.md`. For continuing Git history, clone the repository and overlay the archive as explained in `NEW-LAPTOP.md`.

Use `scripts/build.ps1` to prepare/validate the map, run gameplay checks and export. Android rebuilding requires SDK/JDK paths on the new machine. The portable release includes Python and dependencies; `CAPTURE-STREETVIEW.cmd` launches the reference capture tool with installed Chrome (Edge is also supported). No credentials, browser profile, signing keys, old editor settings or regenerable caches are transferred.

The original workspace is `C:\Users\ADMIN\Desktop\ARENA-HYD`. It now has its own Git repository. An unrelated accidental repository exists above it at `C:\Users\ADMIN`; do not stage or push that parent directory. All further work should stay in the project repository.
