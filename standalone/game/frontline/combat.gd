extends Node

const NPC = preload("res://frontline/npc.gd")
var game
var terrain: VoxelTerrain
var players: Dictionary = {}
var view_players: Dictionary = {}
var actors: Dictionary = {}
var mode = "COOP"
var wave = 0
var next_wave = 0
var next_actor_id = 1
var sync_clock = 0.0
var shot_clock = 0.0
var save_clock = 0.0
var hud: Label
var ammo_label: Label
var notice: Label
var help: Label
var last_notice = ""
var audio: AudioStreamPlayer
var counters = {"shots": 0, "npc_hits": 0, "npc_shots": 0, "player_damage": 0, "kills": 0}

func _ready():
    game = get_parent()
    terrain = game.get_terrain()
    next_wave = Time.get_ticks_msec() + 5000
    mode = get_node("/root/Main").cli.get("--mode", "COOP")
    _make_hud()
    audio = AudioStreamPlayer.new()
    audio.stream = load("res://frontline/assets/rifle.wav")
    audio.volume_db = -12
    add_child(audio)
    multiplayer.peer_connected.connect(_peer_connected)
    multiplayer.peer_disconnected.connect(_peer_disconnected)
    multiplayer.server_disconnected.connect(_server_disconnected)
    if multiplayer.is_server():
        for node in game.get_node("Players").get_children():
            _ensure_player(int(str(node.name)))
    else:
        multiplayer.connected_to_server.connect(_introduce)
    call_deferred("_introduce")
    if "--qa" in OS.get_cmdline_user_args():
        var qa = load("res://frontline/qa.gd").new()
        qa.name = "QA"
        add_child(qa)

func _make_hud():
    var layer = CanvasLayer.new()
    layer.layer = 8
    add_child(layer)
    hud = Label.new()
    hud.position = Vector2(24, 22)
    hud.add_theme_font_size_override("font_size", 21)
    layer.add_child(hud)
    ammo_label = Label.new()
    ammo_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
    ammo_label.position = Vector2(-340, -105)
    ammo_label.size = Vector2(310, 80)
    ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    ammo_label.add_theme_font_size_override("font_size", 27)
    layer.add_child(ammo_label)
    notice = Label.new()
    notice.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
    notice.position = Vector2(-320, 22)
    notice.size = Vector2(640, 50)
    notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    notice.add_theme_font_size_override("font_size", 20)
    layer.add_child(notice)
    help = Label.new()
    help.text = "WASD 移動　空白 跳躍　左鍵 射擊　右鍵 瞄準　R 換彈\nG 槍械／建造　E 方塊背包　F2 合作波次　F3 玩家對戰　F5 存檔　Esc 選單"
    help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
    help.position = Vector2(24, -78)
    help.add_theme_font_size_override("font_size", 16)
    layer.add_child(help)

func _character(id: int) -> Node3D:
    return game.get_node("Players").get_node_or_null(str(id))

func _local() -> Node3D:
    return _character(multiplayer.get_unique_id())

func _ensure_player(id: int):
    if not players.has(id):
        players[id] = {"name": "Player " + str(id), "hp": 100, "ammo": 30, "reserve": 180,
            "kills": 0, "reload": 0, "last_shot": 0, "respawn": 0, "shield": Time.get_ticks_msec() + 3000}

func _peer_connected(id: int):
    if multiplayer.is_server():
        _ensure_player(id)
        _send_state()

func _peer_disconnected(id: int):
    players.erase(id)

func _server_disconnected():
    last_notice = "主機已離線。按 Esc 返回選單。"
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _introduce():
    var root = get_node("/root/Main")
    if multiplayer.is_server():
        if _character(1) != null:
            _ensure_player(1)
            players[1].name = root.nickname
    elif multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
        identify.rpc_id(1, root.nickname)

@rpc("any_peer", "call_remote", "reliable")
func identify(nickname: String):
    if not multiplayer.is_server():
        return
    var id = multiplayer.get_remote_sender_id()
    if _character(id) == null:
        return
    _ensure_player(id)
    players[id].name = nickname.strip_edges().left(20) if not nickname.strip_edges().is_empty() else "Guest"
    _send_state()

func _input(event):
    var character = _local()
    if character == null:
        return
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_G:
            var gun = not character.get_meta("gun_mode", true)
            character.set_meta("gun_mode", gun)
            character.get_node("HotBar").visible = not gun
            character.get_node("Camera/Weapon").visible = gun
            get_viewport().set_input_as_handled()
        elif event.keycode == KEY_R:
            if multiplayer.is_server():
                _reload(1)
            else:
                request_reload.rpc_id(1)
        elif event.keycode == KEY_F2:
            if multiplayer.is_server():
                start_mode("COOP")
        elif event.keycode == KEY_F3:
            if multiplayer.is_server():
                start_mode("PVP")
        elif event.keycode == KEY_F5 and multiplayer.is_server():
            game._save_world()
            last_notice = "世界已送出存檔。"

func _physics_process(delta):
    var character = _local()
    if character != null and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and character.get_meta("gun_mode", true):
        shot_clock -= delta
        if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and shot_clock <= 0:
            shot_clock = 0.105
            var direction = -character.get_node("Camera").global_transform.basis.z
            if multiplayer.is_server():
                _fire(1, direction)
            else:
                request_fire.rpc_id(1, direction)
    if multiplayer.is_server():
        _simulate(delta)
        sync_clock += delta
        if sync_clock >= 0.05:
            sync_clock = 0
            _send_state()
        save_clock += delta
        if save_clock > 30:
            save_clock = 0
            game._save_world()
    _update_hud()

func _simulate(delta):
    var now = Time.get_ticks_msec()
    for id in players.keys():
        var state = players[id]
        if state.reload > 0 and now >= state.reload:
            var amount = mini(30 - state.ammo, state.reserve)
            state.ammo += amount
            state.reserve -= amount
            state.reload = 0
        if state.hp <= 0 and state.respawn > 0 and now >= state.respawn:
            _reset_player(id)
        var character = _character(id)
        if character != null and character.position.y < -100:
            _reset_player(id)
    for id in actors.keys():
        var actor = actors[id]
        if actor.health <= 0 and actor.dead_time > 5:
            actor.queue_free()
            actors.erase(id)
            continue
        var target: Node3D = null
        var distance = INF
        for peer in players:
            var candidate = _character(peer)
            if candidate == null or players[peer].hp <= 0:
                continue
            var d = actor.position.distance_squared_to(candidate.position)
            if d < distance:
                distance = d
                target = candidate
        actor.simulate(delta, target)
    if mode == "COOP" and not players.is_empty():
        if living_enemies() == 0:
            if next_wave == 0:
                next_wave = now + 5000
            elif now >= next_wave:
                _spawn_wave()

func living_enemies() -> int:
    var count = 0
    for actor in actors.values():
        if actor.health > 0:
            count += 1
    return count

func start_mode(value: String):
    if not multiplayer.is_server():
        return
    if value == "PVP" and players.size() < 2:
        last_notice = "玩家對戰需要至少兩人。單人可先玩合作作戰。"
        return
    for actor in actors.values():
        actor.queue_free()
    actors.clear()
    mode = value
    wave = 0
    next_wave = Time.get_ticks_msec() + 3000
    var index = 0
    for id in players:
        players[id].kills = 0
        _reset_player(id, index)
        index += 1
    last_notice = "合作作戰：抵擋武裝敵人。" if mode == "COOP" else "玩家對戰：先到 10 擊殺獲勝。"

func _reset_player(id: int, index = 0):
    var state = players[id]
    state.hp = 100
    state.ammo = 30
    state.reserve = 180
    state.reload = 0
    state.respawn = 0
    state.shield = Time.get_ticks_msec() + 3000
    var position = Vector3(24 if mode == "PVP" and index % 2 else -24, 42, index * 2)
    _teleport(id, position)
    if multiplayer.get_peers().size() > 0:
        teleport_player.rpc(id, position)

func _teleport(id: int, position: Vector3):
    var character = _character(id)
    if character != null:
        character.position = position
        if character.get_script().has_method("_physics_process"):
            character.set("_velocity", Vector3.ZERO)

@rpc("authority", "call_remote", "reliable")
func teleport_player(id: int, position: Vector3):
    _teleport(id, position)

func _spawn_wave():
    wave += 1
    next_wave = 0
    var size = mini(16, 2 + wave * 2 + maxi(0, players.size() - 1) * 2)
    for i in size:
        var actor = NPC.new()
        actor.actor_id = next_actor_id
        next_actor_id += 1
        actor.position = Vector3(13 + i % 5 * 4, 42, [0, -10, -20, 8][int(i / 5)])
        actor.terrain = terrain
        actor.coordinator = self
        game.add_child(actor)
        actors[actor.actor_id] = actor
    last_notice = "第 %d 波：%d 名武裝敵人" % [wave, size]
    print("FRONTLINE_WAVE ", wave, " ", size)

func line_clear(from: Vector3, to: Vector3) -> bool:
    var distance = from.distance_to(to)
    if distance < 0.01:
        return true
    var hit = terrain.get_voxel_tool().raycast(from, (to - from) / distance, distance, 1)
    return hit == null or hit.distance > distance - 0.3

@rpc("any_peer", "call_remote", "reliable")
func request_reload():
    if multiplayer.is_server():
        _reload(multiplayer.get_remote_sender_id())

func _reload(id: int):
    if not players.has(id):
        return
    var state = players[id]
    if state.hp > 0 and state.ammo < 30 and state.reserve > 0 and state.reload == 0:
        state.reload = Time.get_ticks_msec() + 2100

@rpc("any_peer", "call_remote", "reliable")
func request_fire(direction: Vector3):
    if multiplayer.is_server():
        _fire(multiplayer.get_remote_sender_id(), direction)

func _fire(id: int, direction: Vector3):
    if not players.has(id) or not direction.is_finite() or direction.length_squared() < 0.5:
        return
    var state = players[id]
    var character = _character(id)
    var now = Time.get_ticks_msec()
    if character == null or state.hp <= 0 or state.reload > 0 or now - state.last_shot < 90 or state.ammo <= 0:
        return
    state.last_shot = now
    state.shield = 0
    state.ammo -= 1
    counters.shots += 1
    direction = direction.normalized()
    var origin = character.position + Vector3(0, 0.7, 0)
    var distance = 100.0
    var block_hit = terrain.get_voxel_tool().raycast(origin, direction, distance, 1)
    if block_hit != null:
        distance = block_hit.distance
    var target_id = -1
    var target_player = false
    for actor_id in actors:
        var actor = actors[actor_id]
        if actor.health <= 0:
            continue
        var hit = AABB(actor.position + Vector3(-0.35, -0.9, -0.35), Vector3(0.7, 1.8, 0.7)).intersects_ray(origin, direction)
        if hit is Vector3 and origin.distance_to(hit) < distance:
            distance = origin.distance_to(hit)
            target_id = actor_id
            target_player = false
    if mode == "PVP":
        for peer in players:
            var target = _character(peer)
            if peer == id or target == null or players[peer].hp <= 0:
                continue
            var hit = AABB(target.position + Vector3(-0.35, -0.9, -0.35), Vector3(0.7, 1.8, 0.7)).intersects_ray(origin, direction)
            if hit is Vector3 and origin.distance_to(hit) < distance:
                distance = origin.distance_to(hit)
                target_id = peer
                target_player = true
    if target_id >= 0:
        if target_player:
            _damage_player(target_id, 26, id)
        else:
            var actor = actors[target_id]
            actor.health = maxi(0, actor.health - 26)
            counters.npc_hits += 1
            if actor.health == 0:
                state.kills += 1
                counters.kills += 1
    _show_shot(id, origin, origin + direction * distance, target_id >= 0)
    if multiplayer.get_peers().size() > 0:
        show_shot.rpc(id, origin, origin + direction * distance, target_id >= 0)

func npc_shoot(id: int, target: Node3D, from: Vector3, to: Vector3):
    if not multiplayer.is_server() or not line_clear(from, to):
        return
    var peer = int(str(target.name))
    _damage_player(peer, 6, -1)
    counters.npc_shots += 1
    _show_shot(-id, from, to, true)
    if multiplayer.get_peers().size() > 0:
        show_shot.rpc(-id, from, to, true)

func _damage_player(id: int, damage: int, shooter: int):
    if not players.has(id):
        return
    var state = players[id]
    if state.hp <= 0 or state.shield > Time.get_ticks_msec():
        return
    state.hp = maxi(0, state.hp - damage)
    counters.player_damage += damage
    if state.hp == 0:
        state.respawn = Time.get_ticks_msec() + 2000
        if players.has(shooter):
            players[shooter].kills += 1
            if players[shooter].kills >= 10:
                last_notice = players[shooter].name + " 獲勝！按 F3 開始下一局。"
                mode = "READY"

@rpc("authority", "call_remote", "unreliable", 1)
func show_shot(id: int, from: Vector3, to: Vector3, hit: bool):
    _show_shot(id, from, to, hit)

func _show_shot(id: int, from: Vector3, to: Vector3, hit: bool):
    var mesh = ImmediateMesh.new()
    mesh.surface_begin(Mesh.PRIMITIVE_LINES)
    mesh.surface_add_vertex(from)
    mesh.surface_add_vertex(to)
    mesh.surface_end()
    var tracer = MeshInstance3D.new()
    tracer.mesh = mesh
    var mat = StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.albedo_color = Color(1, 0.65, 0.15)
    tracer.material_override = mat
    game.add_child(tracer)
    get_tree().create_timer(0.08).timeout.connect(tracer.queue_free)
    if id == multiplayer.get_unique_id():
        var character = _local()
        if character != null:
            character.get_node("Camera/Weapon").fire()
            audio.play()
            if hit:
                last_notice = "命中"

func _send_state():
    var public = {}
    var now = Time.get_ticks_msec()
    for id in players:
        var state = players[id]
        public[id] = {"name": state.name, "hp": state.hp, "ammo": state.ammo, "reserve": state.reserve,
            "kills": state.kills, "reload": maxf(0, (state.reload - now) / 1000.0) if state.reload > 0 else 0.0}
    var actor_states = []
    for id in actors:
        var actor = actors[id]
        actor_states.append({"id": id, "position": actor.position, "rotation": actor.rotation.y, "hp": actor.health})
    var round_state = {"mode": mode, "wave": wave, "enemies": living_enemies(), "notice": last_notice}
    view_players = public
    if multiplayer.get_peers().size() > 0:
        sync_state.rpc(public, actor_states, round_state)

@rpc("authority", "call_remote", "unreliable_ordered", 1)
func sync_state(public: Dictionary, actor_states: Array, round_state: Dictionary):
    view_players = public
    mode = round_state.mode
    wave = round_state.wave
    last_notice = round_state.notice
    var keep = {}
    for state in actor_states:
        var id = state.id
        keep[id] = true
        if not actors.has(id):
            var actor = NPC.new()
            actor.actor_id = id
            actor.position = state.position
            actor.terrain = terrain
            actor.coordinator = self
            game.add_child(actor)
            actors[id] = actor
        actors[id].position = state.position
        actors[id].rotation.y = state.rotation
        actors[id].health = state.hp
        if state.hp <= 0:
            actors[id].visual.rotation.z = PI / 2
    for id in actors.keys():
        if not keep.has(id):
            actors[id].queue_free()
            actors.erase(id)

func _update_hud():
    var id = multiplayer.get_unique_id()
    var character = _local()
    if character == null or not view_players.has(id):
        hud.text = "正在連線與載入世界…"
        return
    var state = view_players[id]
    character.set_meta("dead", state.hp <= 0)
    var title = "合作作戰" if mode == "COOP" else ("玩家對戰" if mode == "PVP" else "自由探索")
    hud.text = "%s　·　第 %d 波\n生命 %d　擊殺 %d　玩家 %d / 8　敵人 %d" % [title, wave, state.hp, state.kills, view_players.size(), living_enemies()]
    var weapon = character.get_node("Camera/Weapon")
    weapon.reload_progress = clampf(1.0 - state.reload / 2.1, 0.0, 1.0) if state.reload > 0 else 0.0
    ammo_label.text = ("換彈中…" if state.reload > 0 else "M4A1  %02d / %d" % [state.ammo, state.reserve]) if character.get_meta("gun_mode", true) else "建造模式"
    notice.text = last_notice
