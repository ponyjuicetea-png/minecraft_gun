extends Node3D

var third_person = false
var kick = 0.0
var reload_progress = 0.0
var model: Node3D
var light: OmniLight3D
var flash_time = 0.0
var base_position = Vector3(0.28, -0.29, -0.43)

func _ready():
    if not third_person:
        position = base_position
    var mount = Node3D.new()
    add_child(mount)
    model = load("res://frontline/assets/m4a1/M4A1.fbx").instantiate()
    mount.add_child(model)
    var bounds = _bounds(model, Transform3D.IDENTITY)
    var length = maxf(maxf(bounds.size.x, bounds.size.y), bounds.size.z)
    var factor = (0.82 if third_person else 0.78) / maxf(length, 0.001)
    model.scale *= factor
    if bounds.size.x > bounds.size.z:
        mount.rotation.y = PI / 2
    model.position -= bounds.get_center() * factor
    model.position.z -= 0.16
    var mat = StandardMaterial3D.new()
    mat.albedo_texture = load("res://frontline/assets/m4a1/M4A1_Base_Color.png")
    mat.normal_enabled = true
    mat.normal_texture = load("res://frontline/assets/m4a1/M4A1_Normal.png")
    mat.metallic = 0.8
    mat.metallic_texture = load("res://frontline/assets/m4a1/M4A1_Metallic.png")
    mat.roughness = 0.7
    mat.roughness_texture = load("res://frontline/assets/m4a1/M4A1_Roughness.png")
    _material(model, mat)
    light = OmniLight3D.new()
    light.position = Vector3(0, 0, -0.55)
    light.light_color = Color(1.0, 0.67, 0.2)
    light.omni_range = 4.0
    light.visible = false
    add_child(light)
    if not third_person:
        var sleeve = StandardMaterial3D.new()
        sleeve.albedo_color = Color("#252d29")
        for side in [-1, 1]:
            var hand = MeshInstance3D.new()
            var mesh = BoxMesh.new()
            mesh.size = Vector3(0.075, 0.08, 0.19)
            hand.mesh = mesh
            hand.material_override = sleeve
            hand.position = Vector3(0.06 if side == 1 else 0.0, -0.1, 0.1 if side == 1 else -0.16)
            hand.rotation_degrees.x = -25
            add_child(hand)

static func _bounds(node: Node, trans: Transform3D) -> AABB:
    var result = AABB()
    if node is Node3D:
        trans = trans * node.transform
    if node is MeshInstance3D:
        result = trans * node.get_aabb()
    for child in node.get_children():
        var child_bounds = _bounds(child, trans)
        if child_bounds.size.length_squared() > 0:
            result = child_bounds if result.size.length_squared() == 0 else result.merge(child_bounds)
    return result

static func _material(node: Node, material: Material):
    if node is MeshInstance3D:
        node.material_override = material
    for child in node.get_children():
        _material(child, material)

func fire():
    kick = 1.0
    flash_time = 0.045

func _process(delta):
    kick = move_toward(kick, 0, delta * 8)
    flash_time = maxf(0, flash_time - delta)
    light.visible = flash_time > 0
    if third_person:
        return
    var aiming = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
    var goal = Vector3(0, -0.18, -0.34) if aiming else base_position
    if reload_progress > 0:
        goal.y -= sin(reload_progress * PI) * 0.28
    position = position.lerp(goal + Vector3(0, 0, kick * 0.075), 1 - exp(-delta * 16))
    rotation.x = kick * 0.05
    rotation.z = sin(reload_progress * PI) * 0.45
    var camera = get_parent() as Camera3D
    camera.fov = lerpf(camera.fov, 58.0 if aiming else 86.0, 1 - exp(-delta * 12))
