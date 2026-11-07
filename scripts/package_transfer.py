"""Create the Windows handoff bundle from tracked source and allowlisted tools.

Run after committing source. No browser profile, editor settings or signing key is
included. Python's standard library is sufficient.
"""
from __future__ import annotations

import hashlib
import json
import subprocess
import time
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PREFIX = "ARENA-HYD/"
OUTPUT = ROOT / "build/transfer/ARENA-HYD-portable-windows.zip"
BLOCKED_PARTS = {".git", ".godot", "editor_data", "__pycache__", ".secrets", ".venv"}
BLOCKED_SUFFIXES = {".pyc", ".pyo", ".keystore", ".jks", ".p12", ".pfx", ".pem", ".key"}


def git(*args: str) -> str:
    return subprocess.check_output(["git", "-C", str(ROOT), *args], text=True).strip()


def allowed(path: Path) -> bool:
    rel = path.relative_to(ROOT)
    # Certifi's public CA roots are needed for HTTPS in the portable Python tools.
    public_ca_bundle = path.name == "cacert.pem" and "certifi" in rel.parts
    return (not any(part in BLOCKED_PARTS for part in rel.parts)
            and (path.suffix.lower() not in BLOCKED_SUFFIXES or public_ca_bundle)
            and not path.name.startswith(".env")
            and path.name != "export_credentials.cfg")


def files_for_bundle() -> list[Path]:
    tracked = subprocess.check_output(["git", "-C", str(ROOT), "ls-files", "-z"])
    files = {ROOT / name.decode("utf-8") for name in tracked.split(b"\0") if name}
    for directory in ("tools/python", "tools/python-libs", "tools/export_templates",
                      "build/windows", "build/android", "build/web"):
        base = ROOT / directory
        if not base.is_dir():
            raise FileNotFoundError(f"Missing portable component: {directory}")
        files.update(p for p in base.rglob("*") if p.is_file())
    for name in ("tools/godot/godot.exe", "tools/godot/godot_console.exe", "tools/godot/_sc_"):
        path = ROOT / name
        if not path.is_file():
            raise FileNotFoundError(name)
        files.add(path)
    # Preserve the source snapshot corresponding to the previously validated builds.
    for pattern in ("before-metro-collision.zip", "reference-*.png", "people-preview.png", "vehicle-preview.png"):
        files.update((ROOT / "build").glob(pattern))
    result = sorted((p for p in files if allowed(p)), key=lambda p: p.relative_to(ROOT).as_posix())
    for path in result:
        if path.is_symlink() or not path.resolve().is_relative_to(ROOT):
            raise ValueError(f"Refusing external file: {path}")
    return result


def main() -> None:
    if git("status", "--porcelain"):
        raise SystemExit("Commit source before packaging so the handoff matches its Git revision.")
    paths = files_for_bundle()
    total = sum(p.stat().st_size for p in paths)
    if total > 15_000_000_000:
        raise SystemExit("Bundle exceeds the 15 GB project limit.")
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    manifest = {"format": 1, "source_commit": git("rev-parse", "HEAD"),
                "repository": "https://github.com/varshith-dev/ARENA-HYD",
                "created_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                "uncompressed_bytes": total,
                "build_note": "Included binaries predate the current collision/source changes. Read docs/HANDOFF.md.",
                "files": []}
    print(f"Packing {len(paths)} files, {total / 1e9:.3f} GB before compression", flush=True)
    with zipfile.ZipFile(OUTPUT, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=2, allowZip64=True) as archive:
        for i, path in enumerate(paths):
            rel = path.relative_to(ROOT).as_posix()
            info = zipfile.ZipInfo.from_file(path, PREFIX + rel)
            info.compress_type = zipfile.ZIP_STORED if path.suffix.lower() in {".png", ".jpg", ".jpeg", ".zip", ".gz", ".apk", ".webp"} else zipfile.ZIP_DEFLATED
            info._compresslevel = 2
            digest = hashlib.sha256()
            with path.open("rb") as source, archive.open(info, "w", force_zip64=True) as target:
                while chunk := source.read(1024 * 1024):
                    digest.update(chunk)
                    target.write(chunk)
            manifest["files"].append({"path": rel, "bytes": path.stat().st_size, "sha256": digest.hexdigest()})
            if i % 1000 == 0:
                print(f"Packed {i + 1}/{len(paths)}", flush=True)
        archive.writestr(PREFIX + "TRANSFER-MANIFEST.json", json.dumps(manifest, indent=2))
    print("Checking every ZIP member for corruption...", flush=True)
    with zipfile.ZipFile(OUTPUT) as archive:
        bad = archive.testzip()
        if bad:
            raise RuntimeError(f"ZIP verification failed: {bad}")
        assert len(archive.namelist()) == len(paths) + 1
    digest = hashlib.file_digest(OUTPUT.open("rb"), "sha256").hexdigest()
    (OUTPUT.parent / "SHA256SUMS.txt").write_text(f"{digest}  {OUTPUT.name}\n", encoding="ascii")
    (OUTPUT.parent / "transfer-summary.json").write_text(json.dumps({
        "source_commit": manifest["source_commit"], "files": len(paths), "bytes": OUTPUT.stat().st_size,
        "uncompressed_bytes": total, "sha256": digest}, indent=2), encoding="utf-8")
    print(f"Verified {OUTPUT.name}: {OUTPUT.stat().st_size / 1e9:.3f} GB; SHA256 {digest}", flush=True)


if __name__ == "__main__":
    main()
