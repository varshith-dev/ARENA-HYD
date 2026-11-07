# Continue on another Windows laptop

## Easiest transfer

1. Open https://github.com/varshith-dev/ARENA-HYD/releases (public; no sign-in needed to download).
2. Download [ARENA-HYD-portable-windows.zip](https://github.com/varshith-dev/ARENA-HYD/releases/download/v0.1-handoff-20261107/ARENA-HYD-portable-windows.zip) from the handoff release. Extract it to a local folder, for example `D:\Projects\ARENA-HYD`.
3. Double-click `RUN-GAME.cmd` to play the last validated Windows build, or `OPEN-EDITOR.cmd` to edit the current source in the included Godot 4.7.2 editor.
4. Open the extracted `ARENA-HYD` folder as the workspace in Codex/your editor. Start with `docs/HANDOFF.md` to continue the unfinished work.

The archive includes source, original street-view reference images, game assets, map datasets, Windows/APK/web builds, a portable Windows Godot editor, matching export templates, Python 3.11, and Python dependencies. It excludes machine-specific editor settings, browser profiles, signing keys and regenerable Godot caches. The first source launch/import rebuilds caches.

**Current new-laptop budget: 50 GB**, increased from the original 15 GB by the user. The initial portable project occupies about 1.45 GB before caches. Git is **not required** to download, extract, verify, run or edit this archive. If shell networking or browser automation fails, download the ZIP manually in a normal browser, extract it, then open that local folder in Codex. Git can be installed/configured later for pushing changes.

To verify the extracted files before editing, run `.\tools\python\python.exe scripts/verify_transfer.py`. Full requirements and outstanding work are preserved in `docs/CONVERSATION-CONTEXT.md` and `docs/HANDOFF.md`.

## Git workflow

```powershell
gh auth login
gh repo clone varshith-dev/ARENA-HYD
```

Extract the portable archive beside the clone so its `ARENA-HYD` folder merges with the cloned folder. The large toolchain and build outputs are ignored by Git; all source/assets/reference data are tracked. After editing, commit and push from this project directory.

```powershell
git status
git add game scripts docs README.md
git commit -m "Improve Hyderabad district"
git push
```

## Build from current source

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/setup-laptop.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/build.ps1 -SkipAndroid
```

Android rebuilding additionally needs a local Android SDK and JDK 17. Configure those paths on the new machine with `scripts/setup-laptop.ps1 -AndroidSdk '<sdk path>' -JavaHome '<jdk path>'`. The existing APK can be installed without rebuilding. No signing credentials from the old laptop are transferred.

Godot Compatibility remains the cross-platform baseline. On the stronger GPU select High in the game menu. A different renderer is a future separate desktop profile, not something silently enabled by moving machines.

## Street View capture

```powershell
.\tools\python\python.exe scripts/streetview_capture.py --plan-only
.\tools\python\python.exe scripts/streetview_capture.py --limit 28
```

Or double-click `CAPTURE-STREETVIEW.cmd`. Chrome must be installed; `--browser msedge` uses Edge. Default route: seven supplied HITEC City–Raidurg locations, four headings each. `--coords route.csv` accepts `lat,lon,label`; `--spacing 100 --limit 0` samples the segments more densely. `--output` changes the destination. `--max-gb 1.5` limits capture storage.

Images, `manifest.json`, `capture-plan.json` and `index.html` are saved under `hyd-images/auto-streetview`. Each record keeps requested and resolved panorama coordinates, heading/pitch, URL, panorama ID when exposed, offset distance, and nearby OSM candidates. Candidate identity still requires visual review. The current machine returned blank WebGL views in the initial check; those are marked `CHECK_` / `unverified_view`, not usable city reconstruction evidence. Retry on the new laptop. The tool does not bypass sign-in, consent or access challenges, and does not export Street View screenshots as game textures.

Maps URL reference: https://developers.google.com/maps/documentation/urls/get-started . Capture API: https://playwright.dev/python/docs/library .
