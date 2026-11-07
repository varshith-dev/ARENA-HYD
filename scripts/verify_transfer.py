"""Verify every extracted handoff file against TRANSFER-MANIFEST.json."""
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
manifest = json.loads((root / "TRANSFER-MANIFEST.json").read_text(encoding="utf-8"))
failures = []
for item in manifest["files"]:
    path = root / item["path"]
    if not path.resolve().is_relative_to(root):
        raise SystemExit("Unsafe path in manifest")
    if not path.is_file() or path.stat().st_size != item["bytes"]:
        failures.append(item["path"])
        continue
    with path.open("rb") as source:
        if hashlib.file_digest(source, "sha256").hexdigest() != item["sha256"]:
            failures.append(item["path"])
if failures:
    print("Missing or changed files:\n" + "\n".join(failures))
    raise SystemExit(1)
print(f"All {len(manifest['files'])} files verified. Source commit: {manifest['source_commit']}")
