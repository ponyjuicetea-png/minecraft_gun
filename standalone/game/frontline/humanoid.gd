extends Node3D

var enemy = false
var limbs: Array[Node3D] = []
var last_position = Vector3.ZERO
var walk_phase = 0.0

static func box(parent: Node3D, size: Vector3, offset: Vector3, color: Color) -> MeshInstance3D:
    var node = MeshInstance3D.new()
    var mesh = BoxMesh.new()
    mesh.size = size
    node.mesh = mesh
    var mat = StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.8
    node.material_override = mat
    node.position = offset
    parent.add_child(node)
    return node

func _ready():
    var cloth = Color("#80664c") if enemy else Color("#3d6678")
    box(self, Vector3(0.55, 0.63, 0.28), Vector3(0, 0.05, 0), cloth)
    box(self, Vector3(0.59, 0.39, 0.35), Vector3(0, 0.09, -0.02), Color("#28302b"))
    box(self, Vector3(0.35, 0.32, 0.34), Vector3(0, 0.56, 0), Color("#bc9272"))
    box(self, Vector3(0.4, 0.15, 0.4), Vector3(0, 0.75, 0.01), Color("#394036"))
    box(self, Vector3(0.29, 0.08, 0.035), Vector3(0, 0.59, -0.18), Color("#182b31"))
    for side in [-1, 1]:
        var leg = Node3D.new()
        leg.position = Vector3(side * 0.16, -0.27, 0)
        add_child(leg)
        box(leg, Vector3(0.23, 0.5, 0.24), Vector3(0, -0.25, 0), cloth)
        box(leg, Vector3(0.24, 0.17, 0.36), Vector3(0, -0.52, -0.04), Color("#25292a"))
        limbs.append(leg)
    box(self, Vector3(0.16, 0.43, 0.17), Vector3(-0.36, 0.01, -0.17), cloth)
    box(self, Vector3(0.16, 0.28, 0.17), Vector3(0.32, 0.1, -0.13), cloth)
    var gun = load("res://frontline/weapon_view.gd").new()
    gun.third_person = true
    gun.position = Vector3(0.16, 0.22, -0.3)
    add_child(gun)
    last_position = global_position

func _process(delta):
    var speed = global_position.distance_to(last_position) / maxf(delta, 0.001)
    last_position = global_position
    walk_phase += delta * clampf(speed * 3, 0, 12)
    for i in limbs.size():
        limbs[i].rotation.x = sin(walk_phase + i * PI) * (0.42 if speed > 0.1 else 0.0)
