"""Install an isolated Forge instance and a profile in the existing official launcher.

Only launcher profile metadata is read. Account/token stores are never accessed.
"""
from datetime import datetime,timezone
import json
import os
from pathlib import Path
import shutil
import subprocess
from resolve import ROOT,CACHE,get_json,download


def main():
    lock=json.loads((ROOT/'downloads.lock.json').read_text())
    minecraft=Path(os.environ['APPDATA'])/'.minecraft'
    profiles_path=minecraft/'launcher_profiles.json'
    if not profiles_path.exists(): raise RuntimeError('Open the official Minecraft Launcher once before installing Forge.')
    stamp=datetime.now(timezone.utc).strftime('%Y%m%d-%H%M%S')
    backup=minecraft/f'launcher_profiles.frontline-backup-{stamp}.json'
    shutil.copyfile(profiles_path,backup)
    manifest=get_json('https://piston-meta.mojang.com/mc/game/version_manifest_v2.json')
    version=next(version for version in manifest['versions'] if version['id']=='1.20.1')
    directory=minecraft/'versions/1.20.1'
    metadata=directory/'1.20.1.json'
    download(version['url'],metadata,'sha1',version['sha1'])
    data=json.loads(metadata.read_text())
    client=data['downloads']['client']
    download(client['url'],directory/'1.20.1.jar','sha1',client['sha1'])
    installer=CACHE/f"forge-1.20.1-{lock['forge']}-installer.jar"
    java=ROOT/'runtime/java17/bin/java.exe'
    with (CACHE/'forge-client-install.log').open('w',encoding='utf-8') as output:
        subprocess.run([str(java),'-jar',str(installer),'--installClient',str(minecraft)],stdout=output,stderr=subprocess.STDOUT,check=True)
    version_id='1.20.1-forge-'+lock['forge']
    if not (minecraft/'versions'/version_id/(version_id+'.json')).exists(): raise RuntimeError('Forge version metadata missing after installer.')
    profiles=json.loads(profiles_path.read_text(encoding='utf-8-sig'))
    current=datetime.now(timezone.utc).isoformat().replace('+00:00','Z')
    profiles.setdefault('profiles',{})['frontline-tacz-native']={
        'name':'Frontline - TaCZ NPC Co-op','type':'custom','created':current,'lastUsed':current,
        'gameDir':str(ROOT/'client'),'lastVersionId':version_id,
        'javaDir':str(ROOT/'runtime/java17/bin/javaw.exe'),
        'javaArgs':'-Xms1G -Xmx5G -XX:+UseG1GC','icon':'Furnace'}
    profiles['selectedProfile']='frontline-tacz-native'
    profiles_path.write_text(json.dumps(profiles,indent=2)+'\n',encoding='utf-8')
    print('Official launcher profile installed: Frontline - TaCZ NPC Co-op',flush=True)
    print('Existing saves and other launcher profiles retained.',flush=True)


if __name__=='__main__': main()
