"""Build a distributable without local credentials, player data or test artifacts."""
from pathlib import Path
import json
import zipfile
from bootstrap import ROOT, CACHE, download


def main():
    licenses=ROOT/"licenses"
    licenses.mkdir(exist_ok=True)
    for remote,local in [("LICENSE.txt","Luanti-LICENSE.txt"),("COPYING.LESSER","LGPL-2.1.txt")]:
        download("https://raw.githubusercontent.com/luanti-org/luanti/5.17.0/"+remote,licenses/local)
    engine_source=CACHE/"luanti-5.17.0-source.zip"
    download("https://codeload.github.com/luanti-org/luanti/zip/refs/tags/5.17.0",engine_source)
    destination=ROOT/"dist/Frontline-Windows-x64.zip"
    destination.parent.mkdir(exist_ok=True)
    included=[]
    root_files=[path for path in ROOT.iterdir() if path.is_file() and path.name not in {".gitignore"}]
    for path in root_files: included.append((path,path.name))
    for folder in ("mods","assets","licenses","scripts","tests/frontline_qa","docs","sources"):
        directory=ROOT/folder
        if directory.exists():
            for path in directory.rglob("*"):
                if path.is_file() and "__pycache__" not in path.parts:
                    included.append((path,path.relative_to(ROOT).as_posix()))
    for name in ("server.conf","client.conf"):
        included.append((ROOT/"config"/name,"config/"+name))
    for path in (ROOT/"runtime/luanti").rglob("*"):
        relative=path.relative_to(ROOT/"runtime/luanti")
        if not path.is_file() or relative.parts[0] in {"cache","mod_data","worlds"}: continue
        included.append((path,path.relative_to(ROOT).as_posix()))
    included.append((engine_source,"sources/luanti-5.17.0-source.zip"))
    with zipfile.ZipFile(destination,"w",zipfile.ZIP_DEFLATED,compresslevel=6) as archive:
        for path,name in sorted(included,key=lambda item:item[1]): archive.write(path,"Frontline/"+name)
    with zipfile.ZipFile(destination) as archive:
        if archive.testzip(): raise RuntimeError("Archive integrity failed")
        names=archive.namelist()
        if any(".password" in name or "/worlds/" in name or "/artifacts/" in name for name in names):
            raise RuntimeError("Private local state leaked into package")
    print(f"Portable package: {destination} ({destination.stat().st_size/1024/1024:.1f} MiB)")


if __name__=="__main__": main()
