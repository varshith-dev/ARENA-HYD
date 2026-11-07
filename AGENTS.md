# ARENA Hyderabad — instructions for the next Codex agent

## Read first

1. `docs/CONVERSATION-CONTEXT.md`: the user's aims, corrections and requests.
2. `docs/HANDOFF.md`: what is implemented, what passed validation, and what is unfinished.
3. `docs/NEW-LAPTOP.md`: portable tools, launch commands and build setup.
4. `docs/visual-fidelity.md`, `docs/validation-2026-11-07.md`, and the source/asset provenance files before changing geometry or assets.

## Aim and non-negotiable user requirements

- Build an original GTA / Vice City-style open-world **HITEC City, Hyderabad** game: the player is a person, can walk and drive, and encounters traffic, pedestrians, missions and a metro.
- Cover almost all of the district, rather than a single landmark. Use real OSM alignments and supplied street-view evidence. Never describe generic geometry, guessed heights or nearby footprint matches as exact real-world reconstruction.
- Preserve the user-approved **Cyber Towers and metro viaduct** appearance. Improve the other buildings and the city around them.
- The user prioritizes **sharp, clear, fine details** and rejects blur, noise, pixelation, crude dummy blocks and desktop touch controls. Native desktop input, Escape/pause/settings/quit and platform-appropriate mobile controls are required.
- Obstacles must be solid: no walking/driving through buildings, pillars, trees or other solid geometry. Test vehicle exit/re-entry, collisions, corners and recovery after changes.
- Add more varied vehicles and NPCs with individual activities. Build a functioning metro with station stops and safe boarding. These enhancements are not yet finished.
- Fill inappropriate empty terrain only where real footprint evidence supports development. Preserve parks, water, roads and courtyards. Supplementary footprints are candidates, not confirmed new buildings.
- Support Windows, Android APK, Android web and desktop web. **Current maximum project storage on the new laptop: 50 GB**, updated by the user after the original 15 GB limit. Keep compatibility and performance measurable on each target.
- The user explicitly requested **PUBLIC GitHub** and preservation of all source, references, tools, builds and project context for another laptop. Repository: https://github.com/varshith-dev/ARENA-HYD . Large tools/builds are in the release archive; they are intentionally Git-ignored.

## Work from the existing implementation

- Godot **4.7.2**, Compatibility renderer; project `game/project.godot`. Do not replace the engine or start over without a concrete need and user direction. A stronger GPU alone does not make the current estimated facades more accurate.
- Use `hyd-images/` as modeling evidence. Original 36 screenshots cover HITEC City station towards Raidurg. Images remain references outside exported game textures. Preserve attribution and provenance for external assets/data.
- Current source has collision changes newer than the included Windows/APK/web binaries. The source's headless gameplay and map checks pass; detailed obstacle testing and real-device testing still remain. Do not report the packaged binaries as containing unexported changes.
- `game/data/hitec-city.infill.geojson` has 8,024 unmerged Microsoft footprint candidates. Filter overlaps and preserve protected open spaces before integration.
- `scripts/streetview_capture.py` exists. Initial screenshots were blank on the old GPU and are flagged unverified. Retry and visually validate on the new laptop before using images to reconstruct facades. Do not bypass sign-in, consent or access challenges.
- `docs/HANDOFF.md` is the implementation queue. Update it and the validation notes when work actually finishes. State precise checks, measured results and unresolved limitations; do not claim a complete or photorealistic city without evidence.

## Tools and checks

- `RUN-GAME.cmd`: last validated Windows binary.
- `OPEN-EDITOR.cmd`: current source in the bundled Godot editor.
- `CAPTURE-STREETVIEW.cmd`: coordinate/heading reference capture in Chrome; Edge supported with `--browser msedge`.
- Portable Python: `tools/python/python.exe`; dependencies: `tools/python-libs`; declarations: `scripts/requirements.txt`.
- `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/setup-laptop.ps1`: import/setup on the new machine.
- `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/build.ps1 -SkipAndroid`: map preparation, validation, headless gameplay checks and Windows/web export. Android export additionally needs local SDK/JDK paths; see setup guide.
- `tools/python/python.exe scripts/verify_transfer.py`: verify the extracted release against its SHA256 manifest before editing.
- `scripts/package_transfer.py`: recreate the portable handoff from a clean committed tree and the allowlisted local tools/builds.
- Keep credentials, signing keys, browser profiles, personal editor settings and regenerable caches out of Git and release archives.
- Work inside this project repository. The old laptop had an accidental parent repository at `C:\Users\ADMIN`; do not use or upload that parent repository.
- Do not spawn subagents unless the user explicitly authorizes them. Proceed with the user's requested fixes and ordinary reversible implementation work; avoid repeated permission requests for work already authorized.

<!-- postman-cli:installation:start -->
Postman CLI is installed on the original device, and can be used for API Engineering work. Check availability on the new laptop before relying on it.
<!-- postman-cli:installation:end -->
