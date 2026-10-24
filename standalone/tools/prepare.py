"""Configure the isolated upstream demo; the finished game has no Python dependency."""
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import shutil
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT/'game'
PROJ = ROOT.parent


def surfaces():
    output=GAME/'frontline/assets/surfaces'
    output.mkdir(parents=True,exist_ok=True)
    items=[]
    def fetch(asset):
        results=[]
        for kind,local in [('diff','diff'),('nor_gl','normal')]:
            target=output/(asset+'_'+local+'.jpg')
            entry={'url':f'https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/{asset}/{asset}_{kind}_1k.jpg'}
            if not target.exists():
                cached=PROJ/'.cache'/(asset+'.jpg')
                if kind=='diff' and cached.exists():
                    shutil.copyfile(cached,target)
                else:
                    request=urllib.request.Request(entry['url'],headers={'User-Agent':'FrontlineStandalone/1.0'})
                    with urllib.request.urlopen(request,timeout=90) as response,target.open('wb') as file:
                        shutil.copyfileobj(response,file)
            results.append({'asset':asset,'kind':kind,'source':'https://polyhaven.com/a/'+asset,
                'license':'CC0-1.0','url':entry['url'],'sha256':hashlib.sha256(target.read_bytes()).hexdigest()})
        return results
    with ThreadPoolExecutor(max_workers=4) as pool:
        for result in pool.map(fetch,['concrete_floor_02','aerial_grass_rock','brown_planks_03','brown_mud_02']):
            items.extend(result)
    (ROOT/'assets/surface-sources.json').write_text(json.dumps(items,indent=2)+'\n')


def configure():
    project=GAME/'project.godot'
    text=project.read_text(encoding='utf-8')
    text=text.replace('config/name="New Game Project"', 'config/name="FrontlineStandalone"\nrun/main_scene="res://frontline/main.tscn"')
    if 'window/size/viewport_width' not in text:
        text=text.replace('[display]', '[display]\n\nwindow/size/viewport_width=1280\nwindow/size/viewport_height=720\nwindow/size/window_width_override=1280\nwindow/size/window_height_override=720')
    text=text.replace('window/stretch/mode="2d"','window/stretch/mode="canvas_items"')
    project.write_text(text,encoding='utf-8')
    library=GAME/'blocky_game/blocks/voxel_library.tres'
    text=library.read_text()
    if 'resource_name = "concrete"' not in text:
        text=text.replace('load_steps=57','load_steps=58')
        entry='[sub_resource type="VoxelBlockyModelMesh" id="FrontlineConcrete"]\nresource_name = "concrete"\ncollision_aabbs = Array[AABB]([AABB(0, 0, 0, 1, 1, 1)])\nmaterial_override_0 = ExtResource("2_r7axq")\ncollision_enabled_0 = true\nmesh = ExtResource("2")\n\n'
        text=text.replace('[resource]\nmodels =',entry+'[resource]\nmodels =')
        text=text.replace('SubResource("VoxelBlockyModelMesh_kcviq")])','SubResource("VoxelBlockyModelMesh_kcviq"), SubResource("FrontlineConcrete")])')
        library.write_text(text)
    shutil.copyfile(GAME/'blocky_game/blocks/planks/planks_sprite.png',GAME/'blocky_game/blocks/planks/concrete_sprite.png')
    interaction=GAME/'blocky_game/player/avatar_interaction.gd'
    text=interaction.read_text()
    if 'get_meta("gun_mode"' not in text:
        text=text.replace('func _physics_process(_delta):','func _physics_process(_delta):\n\tif get_parent().get_meta("gun_mode", false):\n\t\t_cursor.hide()\n\t\treturn')
        text=text.replace('func _unhandled_input(event: InputEvent):','func _unhandled_input(event: InputEvent):\n\tif get_parent().get_meta("gun_mode", false) or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:\n\t\treturn')
        interaction.write_text(text)
    controller=GAME/'blocky_game/player/character_controller.gd'
    text=controller.read_text()
    if 'can_move' not in text:
        text=text.replace('var motor = Vector3()','var motor = Vector3()\n\tvar can_move = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not get_meta("dead", false)')
        for original in ['if Input.is_key_pressed(KEY_UP)', 'if Input.is_key_pressed(KEY_DOWN)', 'if Input.is_key_pressed(KEY_LEFT)', 'if Input.is_key_pressed(KEY_RIGHT)']:
            # Parenthesize both alternatives so neither can bypass the menu gate.
            lines=text.splitlines()
            text='\n'.join('\tif can_move and ('+line.strip()[3:-1]+'):' if line.startswith('\t'+original) else line for line in lines)+'\n'
        text=text.replace('if _grounded and Input.is_key_pressed(KEY_SPACE):','if can_move and _grounded and Input.is_key_pressed(KEY_SPACE):')
        text=text.replace('rpc(&"receive_position", position)','rpc(&"receive_position", position, _head.rotation.y)')
        text=text.replace('func receive_position(_unused_pos: Vector3):','func receive_position(_unused_pos: Vector3, _unused_yaw: float):')
        controller.write_text(text)
    remote=GAME/'blocky_game/player/remote_character.gd'
    remote.write_text('''extends Node3D\n\n@rpc("any_peer", "call_remote", "unreliable", 0)\nfunc receive_position(pos: Vector3, yaw: float):\n    if multiplayer.get_remote_sender_id() != int(str(name)) or not pos.is_finite():\n        return\n    position = pos\n    rotation.y = yaw\n''')
    inventory=GAME/'blocky_game/gui/inventory/inventory.gd'
    text=inventory.read_text().replace('_slots[hotbar_begin_index + 7] = _make_item(InventoryItem.TYPE_ITEM, 0)',
        '_slots[hotbar_begin_index + 7] = _make_item(InventoryItem.TYPE_BLOCK, 12)')
    inventory.write_text(text)
    base=GAME/'blocky_game/blocky_game.gd'
    text=base.read_text().replace('peer.create_server(_port, 32,','peer.create_server(_port, 8,')
    base.write_text(text)
    shutil.copyfile(PROJ/'.cache/frontline_rifle.wav',GAME/'frontline/assets/rifle.wav')


if __name__=='__main__':
    configure()
    surfaces()
    print('Standalone project and CC0 surface materials prepared.')
