import json
from pathlib import Path
import shutil
import zipfile
from resolve import ROOT, CACHE

lock=json.loads((ROOT/'downloads.lock.json').read_text())
if not (ROOT/'gradle/wrapper/gradle-wrapper.jar').exists():
    with zipfile.ZipFile(CACHE/f"forge-1.20.1-{lock['forge']}-mdk.zip") as archive:
        for name in archive.namelist():
            if name in ('gradlew','gradlew.bat') or name.startswith('gradle/'):
                if not name.endswith('/'):
                    destination=ROOT/name
                    destination.parent.mkdir(parents=True,exist_ok=True)
                    destination.write_bytes(archive.read(name))
aliases={'timeless-and-classics-zero':'tacz-1.1.8-hotfix2.jar',
    'tacz-npcs-craftorio':'tacznpcs-1.0.3-craftorio.jar','playeranimator':'playeranimator-1.0.2.jar',
    'smartbrainlib':'smartbrainlib-1.15.jar'}
for mod in lock['mods']:
    if mod['slug'] in aliases:
        target=CACHE/'devlibs'/aliases[mod['slug']]
        target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(CACHE/mod['filename'],target)
print('Forge development wrapper and remappable mod dependencies ready.')
