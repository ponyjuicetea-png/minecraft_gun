"""Assemble the already-exported, tested Windows game without build caches or saves."""
from pathlib import Path
import hashlib
import json
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]

def main():
    licenses = ROOT / "licenses"
    request = urllib.request.Request(
        "https://raw.githubusercontent.com/Zylann/godot_voxel/v1.7/LICENSE.md",
        headers={"User-Agent": "Frontline-Standalone-Packager"},
    )
    destination = licenses / "VoxelTools-MIT.txt"
    if not destination.exists():
        with urllib.request.urlopen(request, timeout=30) as response:
            content = response.read()
        assert b"Permission is hereby granted" in content
        destination.write_bytes(content)

    target = ROOT / "dist" / "Frontline-Standalone-Windows-x64.zip"
    with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for name in ("Frontline.exe", "Frontline.pck", "Start-Game.cmd"):
            path = ROOT / "dist" / name
            assert path.is_file(), path
            archive.write(path, name)
        archive.write(ROOT / "README.md", "README.md")
        archive.write(ROOT / "dependencies.lock.json", "dependencies.lock.json")
        for folder in ("licenses", "assets"):
            for path in sorted((ROOT / folder).rglob("*")):
                if path.is_file():
                    archive.write(path, path.relative_to(ROOT).as_posix())
        for name in ("network-integration.json", "export-preview.png", "export-smoke.log"):
            path = ROOT / "reports" / name
            assert path.is_file(), path
            archive.write(path, "reports/" + name)
    with zipfile.ZipFile(target) as archive:
        assert archive.testzip() is None
    digest = hashlib.sha256(target.read_bytes()).hexdigest()
    target.with_suffix(".zip.sha256").write_text(digest + "  " + target.name + "\n", encoding="ascii")
    print(json.dumps({"file": str(target), "bytes": target.stat().st_size, "sha256": digest}))

if __name__ == "__main__":
    main()
