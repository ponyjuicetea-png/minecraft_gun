extends Node3D

var actor_id = 0
var health = 100
var dead_time = 0.0
var shot_timer = 1.0
var motion = Vector3.ZERO
var mover = VoxelBoxMover.new()
var visual: Node3D
var terrain: VoxelTerrain
var coordinator: Node

func _ready():
    mover.set_collision_mask(1)
    mover.set_step_climbing_enabled(true)
    mover.set_max_step_height(0.6)
    visual = load("res://frontline/humanoid.gd").new()
    visual.enemy = true
    add_child(visual)

func simulate(delta: float, target: Node3D):
    if health <= 0:
        dead_time += delta
        visual.rotation.z = lerpf(visual.rotation.z, PI / 2, minf(1, delta * 8))
        return
    shot_timer -= delta
    var velocity = Vector3.ZERO
    if target != null:
        var difference = target.position - position
        var distance = difference.length()
        var direction = difference.normalized()
        rotation.y = atan2(-direction.x, -direction.z)
        var eye = position + Vector3(0, 0.6, 0)
        var target_eye = target.position + Vector3(0, 0.5, 0)
        var visible = coordinator.line_clear(eye, target_eye)
        if distance > 15 or not visible:
            velocity = Vector3(direction.x, 0, direction.z) * 2.4
            if not visible:
                velocity = velocity.rotated(Vector3.UP, sin(Time.get_ticks_msec() * 0.0005 + actor_id) * 1.1)
        if visible and distance < 48 and shot_timer <= 0:
            shot_timer = 1.15 + randf() * 0.4
            coordinator.npc_shoot(actor_id, target, eye, target_eye)
    motion.y -= delta * 24
    motion.x = velocity.x
    motion.z = velocity.z
    var box = AABB(Vector3(-0.35, -0.9, -0.35), Vector3(0.7, 1.8, 0.7))
    if terrain.get_voxel_tool().is_area_editable(AABB(position + box.position, box.size)):
        var move = mover.get_motion(position, motion * delta, box, terrain)
        position += move
        motion.y = move.y / maxf(delta, 0.001)
