"""Stage downloaded original mods and user-side visual packs into isolated folders."""
import json
from pathlib import Path
import shutil
from resolve import ROOT,CACHE


def stage():
    lock=json.loads((ROOT/'downloads.lock.json').read_text(encoding='utf-8'))
    server=ROOT/'server'; client=ROOT/'client'
    for directory in (server/'mods',client/'mods',client/'shaderpacks',client/'resourcepacks',client/'config'):
        directory.mkdir(parents=True,exist_ok=True)
    for mod in lock['mods']:
        source=CACHE/mod['filename']
        if mod['side']=='both': shutil.copyfile(source,server/'mods'/source.name)
        target=client/({'shader':'shaderpacks','resourcepack':'resourcepacks'}.get(mod['side'],'mods'))/source.name
        shutil.copyfile(source,target)
    addon=ROOT/'build/libs/frontline-operations-1.20.1-1.0.0.jar'
    if addon.exists():
        for destination in (server/'mods',client/'mods'): shutil.copyfile(addon,destination/addon.name)
    properties=server/'server.properties'
    if not properties.exists():
        properties.write_text('''motd=Frontline | Minecraft Java + TaCZ | NPC Co-op and PvP
server-port=25565
server-ip=
online-mode=true
enforce-secure-profile=true
max-players=8
gamemode=survival
difficulty=normal
hardcore=false
pvp=true
spawn-protection=0
view-distance=8
simulation-distance=6
max-tick-time=120000
enable-command-block=false
enable-rcon=false
white-list=false
level-name=world
level-seed=762026
level-type=minecraft:normal
allow-flight=false
''',encoding='utf-8')
    eula=server/'eula.txt'
    if not eula.exists(): eula.write_text('# Review https://www.minecraft.net/eula before accepting.\neula=false\n',encoding='utf-8')
    for destination in (server/'config',client/'config'):
        destination.mkdir(exist_ok=True)
        npc_config=destination/'tacz_npc-common.toml'
        if not npc_config.exists(): npc_config.write_text('"base multiplier" = 1.0\n"base player multiplier" = 0.35\ndropitems = true\ndespawntime = 1200\nmin = 3\nmax = 6\nfrom = 200\nto = 800\n',encoding='utf-8')
    shader=next(mod for mod in lock['mods'] if mod['side']=='shader')
    resource=next(mod for mod in lock['mods'] if mod['side']=='resourcepack')
    options=client/'options.txt'
    if not options.exists(): options.write_text('lang:zh_tw\nrenderDistance:8\nsimulationDistance:6\nmaxFps:90\nfullscreen:false\noverrideWidth:1280\noverrideHeight:720\nfov:0.25\n'
        +'resourcePacks:'+json.dumps(['vanilla','mod_resources','file/'+resource['filename']])+'\n'
        +'incompatibleResourcePacks:'+json.dumps(['file/'+resource['filename']])+'\n',encoding='utf-8')
    oculus=client/'config/oculus.properties'
    if not oculus.exists(): oculus.write_text('enableShaders=true\nshaderPack='+shader['filename']+'\n',encoding='utf-8')
    settings=client/'shaderpacks'/(shader['filename']+'.txt')
    if not settings.exists(): settings.write_text('RP_MODE=3\nSHADOW_QUALITY=2\nshadowDistance=128.0\nWATER_REFLECT_QUALITY=2\nBLOCK_REFLECT_QUALITY=1\nLIGHTSHAFT_QUALI_DEFINE=1\nSSAO_QUALI_DEFINE=2\nFXAA_DEFINE=1\nDETAIL_QUALITY=2\nCLOUD_QUALITY=2\nANISOTROPIC_FILTER=0\nCOLORED_LIGHTING=0\nWORLD_SPACE_REFLECTIONS=-1\nENTITY_SHADOW=-1\nRAIN_PUDDLES=0\n',encoding='utf-8')
    print('Native Minecraft client and authenticated 8-player Forge server staged. EULA acceptance is unchanged.')


if __name__=='__main__': stage()
