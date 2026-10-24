"""Resolve official pinned Minecraft/Forge/mod downloads without account access."""
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import shutil
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT / ".cache"
HEADERS = {"User-Agent": "Frontline-Operations-local-development/1.0"}


def get_json(url):
    with urllib.request.urlopen(urllib.request.Request(url, headers=HEADERS), timeout=90) as response:
        return json.load(response)


def download(url, target, algorithm="sha256", expected=None):
    target.parent.mkdir(parents=True, exist_ok=True)
    if not target.exists():
        print("Downloading", target.name, flush=True)
        temporary = target.with_suffix(target.suffix + ".part")
        with urllib.request.urlopen(urllib.request.Request(url, headers=HEADERS), timeout=180) as response, temporary.open("wb") as output:
            shutil.copyfileobj(response, output, 1024 * 1024)
        temporary.replace(target)
    digest = hashlib.file_digest(target.open("rb"), algorithm).hexdigest()
    if expected and digest != expected:
        raise RuntimeError("Download integrity check failed: " + str(target))
    return digest


def main():
    CACHE.mkdir(parents=True, exist_ok=True)
    promotions = get_json("https://files.minecraftforge.net/net/minecraftforge/forge/promotions_slim.json")["promos"]
    forge = promotions["1.20.1-recommended"]
    mods = []
    projects = [("timeless-and-classics-zero", "both"), ("smartbrainlib", "both"),
        ("playeranimator", "both"), ("embeddium", "client"), ("oculus", "client"),
        ("complementary-unbound", "shader"), ("rotrblocks", "resourcepack")]
    for slug, side in projects:
        project = get_json("https://api.modrinth.com/v2/project/" + slug)
        versions = get_json("https://api.modrinth.com/v2/project/" + project["id"] + "/version")
        compatible = [version for version in versions if "1.20.1" in version["game_versions"]
            and any(loader in version["loaders"] for loader in ("forge", "iris", "minecraft"))]
        if side == "resourcepack":
            # The lighter 2D foliage variant suits the available GTX 1660 Ti.
            compatible = [version for version in compatible if "2D" in version["version_number"]]
        version = compatible[0]
        artifact = next((file for file in version["files"] if file.get("primary")), version["files"][0])
        mods.append({"slug":slug, "project":project["id"], "version":version["version_number"],
            "version_id":version["id"], "side":side, "filename":artifact["filename"],
            "url":artifact["url"], "size":artifact["size"], "hashes":artifact["hashes"],
            "license":project["license"], "source":project.get("source_url"),
            "dependencies":version["dependencies"]})
    # Pin the maintained Bandit/Duty fork with null-safe shooting target checks.
    npc_url="https://github.com/craftorio/tacz-npcs/releases/download/1.0.3/tacz_npc-1.0.3-craftorio.jar"
    npc_file=CACHE/"tacz_npc-1.0.3-craftorio.jar"
    download(npc_url,npc_file)
    mods.append({"slug":"tacz-npcs-craftorio","project":None,"version":"1.0.3-craftorio", "version_id":None,
        "side":"both","filename":npc_file.name,"url":npc_url,"size":npc_file.stat().st_size,
        "hashes":{"sha512":hashlib.file_digest(npc_file.open('rb'),'sha512').hexdigest()},
        "license":{"id":"LicenseRef-Upstream-Notices"},"source":"https://github.com/craftorio/tacz-npcs/tree/1.0.3",
        "dependencies":[{"project_id":"PuyPazRT","dependency_type":"required"}]})
    jdk = get_json("https://api.adoptium.net/v3/assets/latest/17/hotspot?architecture=x64&heap_size=normal&image_type=jdk&jvm_impl=hotspot&os=windows&vendor=eclipse")[0]
    package = jdk["binary"]["package"]
    lock = {"minecraft":"1.20.1", "forge":forge, "java":{"version":jdk["version"]["semver"],
        "url":package["link"], "sha256":package["checksum"], "filename":package["name"]}, "mods":mods}
    (ROOT/"downloads.lock.json").write_text(json.dumps(lock, indent=2)+"\n", encoding="utf-8")
    def fetch_mod(mod):
        download(mod["url"], CACHE/mod["filename"], "sha512", mod["hashes"]["sha512"])
        print(mod["slug"], mod["version"], flush=True)
    with ThreadPoolExecutor(max_workers=4) as pool:
        futures = [pool.submit(fetch_mod, mod) for mod in mods]
        futures += [pool.submit(download, package["link"], CACHE/package["name"], "sha256", package["checksum"])]
        for suffix in ("installer.jar", "mdk.zip"):
            name=f"forge-1.20.1-{forge}-{suffix}"
            futures.append(pool.submit(download,"https://maven.minecraftforge.net/net/minecraftforge/forge/1.20.1-"+forge+"/"+name,CACHE/name))
        for future in futures: future.result()
    java_home = ROOT/"runtime/java17"
    if not (java_home/"bin/java.exe").exists():
        print("Extracting Java 17",flush=True)
        java_home.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(CACHE/package["name"]) as archive:
            for member in archive.infolist():
                parts=Path(member.filename).parts[1:]
                if not parts: continue
                target=java_home.joinpath(*parts)
                if not target.resolve().is_relative_to(java_home.resolve()): raise RuntimeError("Unsafe archive path")
                if member.is_dir(): target.mkdir(parents=True,exist_ok=True)
                else:
                    target.parent.mkdir(parents=True,exist_ok=True)
                    with archive.open(member) as source,target.open("wb") as output: shutil.copyfileobj(source,output)
    installer=CACHE/f"forge-1.20.1-{forge}-installer.jar"
    lock['forge_installer']={'filename':installer.name,'sha256':hashlib.file_digest(installer.open('rb'),'sha256').hexdigest()}
    for mod in mods:
        if 'sha1' not in mod['hashes']: mod['hashes']['sha1']=hashlib.file_digest((CACHE/mod['filename']).open('rb'),'sha1').hexdigest()
    (ROOT/'downloads.lock.json').write_text(json.dumps(lock,indent=2)+'\n',encoding='utf-8')
    print("Resolved Minecraft",lock["minecraft"],"Forge",forge,"Java",lock["java"]["version"],flush=True)


if __name__ == "__main__": main()
