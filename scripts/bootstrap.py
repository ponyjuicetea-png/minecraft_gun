"""Install pinned upstream portable distributions; never modify existing saves."""
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import shutil
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT / ".cache"
ENGINE = ROOT / "runtime" / "luanti"


def download(url, destination, expected=None):
    destination.parent.mkdir(parents=True, exist_ok=True)
    if not destination.exists():
        print(f"Downloading {destination.name}", flush=True)
        request = urllib.request.Request(url, headers={"User-Agent": "Frontline-Voxels-local-setup/1.0"})
        temporary = destination.with_suffix(destination.suffix + ".part")
        with urllib.request.urlopen(request, timeout=120) as response, temporary.open("wb") as output:
            shutil.copyfileobj(response, output)
        temporary.replace(destination)
    digest = hashlib.sha256(destination.read_bytes()).hexdigest()
    if expected and digest != expected:
        raise RuntimeError(f"SHA-256 mismatch: {destination}; remove this archive and retry")
    return digest


def extract_stripped(archive, destination):
    destination.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(archive) as package:
        for entry in package.infolist():
            parts = Path(entry.filename).parts[1:]
            if not parts:
                continue
            target = destination.joinpath(*parts)
            if not target.resolve().is_relative_to(destination.resolve()):
                raise RuntimeError("Unsafe archive member")
            if entry.is_dir():
                target.mkdir(parents=True, exist_ok=True)
            else:
                target.parent.mkdir(parents=True, exist_ok=True)
                with package.open(entry) as source, target.open("wb") as output:
                    shutil.copyfileobj(source, output)


def main():
    lock_path = ROOT / "dependencies.lock.json"
    lock = json.loads(lock_path.read_text(encoding="utf-8"))
    tasks = []
    with ThreadPoolExecutor(max_workers=2) as pool:
        for name, dependency in lock.items():
            archive = CACHE / f"{name}-{dependency['version']}.zip"
            tasks.append((name, archive, pool.submit(download, dependency["url"], archive, dependency.get("sha256"))))
        for name, archive, task in tasks:
            digest = task.result()
            lock[name]["sha256"] = digest
            destination = ENGINE if name == "luanti" else ENGINE / "games" / "voxelibre"
            marker = destination / ".frontline-version"
            if not marker.exists() or marker.read_text() != lock[name]["version"]:
                print(f"Installing {name} {lock[name]['version']}", flush=True)
                extract_stripped(archive, destination)
                marker.write_text(lock[name]["version"])
    lock_path.write_text(json.dumps(lock, indent=2) + "\n", encoding="utf-8")
    api_file = CACHE / "lua_api-5.17.0.md"
    download("https://raw.githubusercontent.com/luanti-org/luanti/5.17.0/doc/lua_api.md", api_file)
    license_path = ROOT / "LICENSE"
    if not license_path.exists():
        shutil.copyfile(ENGINE / "games" / "voxelibre" / "LICENSE.txt", license_path)
    print("Pinned Luanti + VoxeLibre installed. Saves are untouched.", flush=True)


if __name__ == "__main__":
    main()
