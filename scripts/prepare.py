"""Copy the authored server mod and configure a new world without wiping saves."""
import argparse
from pathlib import Path
import shutil
from bootstrap import ROOT, ENGINE


def prepare(world):
    if not (ENGINE/"bin/luanti.exe").exists():
        raise RuntimeError("Run Setup.cmd first")
    if not (ROOT/"mods/frontline/textures/frontline_rifle_icon.png").exists():
        raise RuntimeError("Bundled assets are missing; regenerate them with scripts/generate_assets.py")
    world.mkdir(parents=True,exist_ok=True)
    metadata=world/"world.mt"
    if not metadata.exists():
        metadata.write_text("gameid = voxelibre\nbackend = sqlite3\nplayer_backend = sqlite3\n"
            "auth_backend = sqlite3\nmod_storage_backend = sqlite3\nload_mod_frontline = true\n",encoding="utf-8")
    shutil.copytree(ROOT/"mods/frontline",world/"worldmods/frontline",dirs_exist_ok=True)
    pack=ROOT/"assets/frontline_realism"
    if pack.exists(): shutil.copytree(pack,ENGINE/"textures/frontline_realism",dirs_exist_ok=True)
    (ROOT/"logs").mkdir(exist_ok=True)
    print(f"World ready: {world}")


if __name__=="__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("--world",type=Path,default=ROOT/"worlds/frontline")
    args=parser.parse_args()
    prepare(args.world.resolve())
