extends Node

# Explicit test mode only. Commands drive the normal gameplay and ENet RPC paths.
var coordinator
var root
var report_path = ""
var command_path = ""
var elapsed = 0.0
var last_sequence = -1
var result_sequence = -1
var error = ""

func _ready():
    coordinator = get_parent()
    root = get_node("/root/Main")
    report_path = root.cli.get("--qa-output", "")
    command_path = root.cli.get("--qa-command", "")

func _process(delta):
    elapsed += delta
    if elapsed < 0.1:
        return
    elapsed = 0
    if not command_path.is_empty() and FileAccess.file_exists(command_path):
        var command = JSON.parse_string(FileAccess.get_file_as_string(command_path))
        if command is Dictionary and int(command.get("sequence", -1)) != last_sequence:
            last_sequence = int(command.sequence)
            _command(command)
            result_sequence = last_sequence
    if not report_path.is_empty():
        _report()

func _command(command: Dictionary):
    var character = coordinator._local()
    match command.action:
        "mode":
            coordinator.start_mode(command.value)
        "teleport":
            if character != null:
                character.position = Vector3(command.x, command.y, command.z)
                character.set("_velocity", Vector3.ZERO)
        "shoot":
            if character == null:
                return
            var id = int(command.get("actor", -1))
            var target = coordinator.actors.get(id)
            if target != null:
                var origin = character.position + Vector3(0, 0.7, 0)
                var direction = (target.position + Vector3(0, 0.4, 0) - origin).normalized()
                if multiplayer.is_server():
                    coordinator._fire(1, direction)
                else:
                    coordinator.request_fire.rpc_id(1, direction)
        "shoot_player":
            if character == null:
                return
            var target = coordinator._character(int(command.peer))
            if target != null:
                var direction = (target.position + Vector3(0, 0.4, 0) - character.position - Vector3(0, 0.7, 0)).normalized()
                if multiplayer.is_server():
                    coordinator._fire(1, direction)
                else:
                    coordinator.request_fire.rpc_id(1, direction)
        "reload":
            if multiplayer.is_server():
                coordinator._reload(1)
            else:
                coordinator.request_reload.rpc_id(1)
        "place":
            if character != null:
                character.get_node("Interaction")._place_single_block(Vector3(command.x, command.y, command.z), int(command.block))
        "save":
            coordinator.game._save_world()
        "quit":
            root._quit()

func _report():
    var character = coordinator._local()
    var actors = []
    for actor in coordinator.actors.values():
        actors.append({"id": actor.actor_id, "hp": actor.health,
            "position": [actor.position.x, actor.position.y, actor.position.z]})
    var peers = []
    for node in coordinator.game.get_node("Players").get_children():
        peers.append({"id": int(str(node.name)), "position": [node.position.x, node.position.y, node.position.z]})
    var tool = coordinator.terrain.get_voxel_tool()
    var report = {"peer": multiplayer.get_unique_id(), "server": multiplayer.is_server(),
        "connected_peers": Array(multiplayer.get_peers()), "mode": coordinator.mode,
        "wave": coordinator.wave, "players": coordinator.players if multiplayer.is_server() else coordinator.view_players,
        "actors": actors, "positions": peers, "counters": coordinator.counters,
        "command_sequence": result_sequence, "error": error,
        "grounded": character.get("_grounded") if character != null else false,
        "editable": tool.is_area_editable(AABB(Vector3(-4, 39, -15), Vector3(8, 8, 8))),
        "test_block": tool.get_voxel(Vector3i(-2, 41, -12)),
        "user_data_directory": OS.get_user_data_dir()}
    var file = FileAccess.open(report_path, FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify(report))
