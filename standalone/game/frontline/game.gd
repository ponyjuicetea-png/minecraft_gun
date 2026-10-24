extends "res://blocky_game/blocky_game.gd"

var combat: Node
var _spawn_number = 0

func _ready():
    var terrain: VoxelTerrain = get_node("VoxelTerrain")
    var generator = load("res://frontline/world_generator.gd").new()
    terrain.generator = generator
    if get_network_mode() != NETWORK_MODE_CLIENT:
        DirAccess.make_dir_recursive_absolute("user://worlds")
        var stream = VoxelStreamSQLite.new()
        stream.database_path = get_node("/root/Main").cli.get("--world", "user://worlds/frontline.sqlite")
        terrain.stream = stream
    _prepare_materials()
    var blocks = get_node("Blocks")
    blocks._create_block({"name": "concrete", "directory": "planks", "gui_model": "planks.obj", "voxels": ["concrete"]})
    var environment: Environment = get_node("WorldEnvironment").environment
    environment.sdfgi_enabled = false
    environment.ssao_enabled = true
    environment.ssao_radius = 1.6
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    environment.ambient_light_energy = 0.55
    environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    environment.fog_density = 0.0012
    get_node("DirectionalLight3D").light_energy = 1.5
    super._ready()
    get_node("DebugInfo").queue_free()
    combat = load("res://frontline/combat.gd").new()
    combat.name = "Combat"
    add_child(combat)

func _prepare_materials():
    var library = get_node("Blocks").get_model_library()
    var photo_materials = {}
    for asset in ["brown_mud_02", "aerial_grass_rock", "brown_planks_03", "concrete_floor_02"]:
        var mat = StandardMaterial3D.new()
        mat.albedo_texture = load("res://frontline/assets/surfaces/" + asset + "_diff.jpg")
        mat.vertex_color_use_as_albedo = true
        mat.uv1_triplanar = true
        mat.uv1_world_triplanar = true
        mat.uv1_scale = Vector3(0.65, 0.65, 0.65)
        mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
        mat.roughness = 0.88
        mat.metallic_specular = 0.25
        var normal_path = "res://frontline/assets/surfaces/" + asset + "_normal.jpg"
        if ResourceLoader.exists(normal_path):
            mat.normal_enabled = true
            mat.normal_texture = load(normal_path)
        photo_materials[asset] = mat
    var materials = {1: "brown_mud_02", 2: "aerial_grass_rock", 3: "brown_planks_03",
        4: "brown_planks_03", 5: "brown_planks_03", 6: "brown_planks_03", 7: "brown_planks_03", 27: "concrete_floor_02"}
    for index in materials:
        library.get_model(index).set_material_override(0, photo_materials[materials[index]])
    library.bake()

func _spawn_character(peer_id: int, pos: Vector3) -> Node3D:
    if get_node("/root/Main").cli.has("--server"):
        return null
    if get_network_mode() != NETWORK_MODE_CLIENT:
        pos = Vector3(-24, 42, _spawn_number * 2)
        _spawn_number += 1
    var character = super._spawn_character(peer_id, pos)
    character.set_meta("gun_mode", true)
    character.set_meta("peer_id", peer_id)
    character.get_node("Camera").rotation.y = -PI / 2
    character.get_node("Camera").set("_yaw", -90.0)
    character.get_node("HotBar").hide()
    character.get_node("CharacterVisual").hide()
    var weapon = load("res://frontline/weapon_view.gd").new()
    weapon.name = "Weapon"
    character.get_node("Camera").add_child(weapon)
    return character

func _spawn_remote_character(peer_id: int, pos: Vector3) -> Node3D:
    if get_network_mode() == NETWORK_MODE_HOST:
        pos = Vector3(-22, 42, _spawn_number * 2)
        _spawn_number += 1
    var character = super._spawn_remote_character(peer_id, pos)
    character.set_meta("peer_id", peer_id)
    character.get_node("CharacterVisual").hide()
    var visual = load("res://frontline/humanoid.gd").new()
    visual.name = "Soldier"
    character.add_child(visual)
    return character
