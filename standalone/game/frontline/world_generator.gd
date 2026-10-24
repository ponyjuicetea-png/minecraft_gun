extends "res://blocky_game/generator/generator.gd"

const CONCRETE = 27

func _get_height_at(x: int, z: int) -> int:
    var radius = max(abs(x), abs(z))
    if radius < 52:
        return 40
    return int(lerpf(40.0, float(super._get_height_at(x, z)), clampf((radius - 52.0) / 36.0, 0.0, 1.0)))

func _get_tree_instances_in_chunk(cpos: Vector3i, offset: Vector3i, size: int, instances: Array):
    var trees: Array = []
    super._get_tree_instances_in_chunk(cpos, offset, size, trees)
    for tree in trees:
        var p: Vector3i = tree[0] + offset
        if abs(p.x) > 48 or abs(p.z) > 40:
            instances.append(tree)

func _generate_block(buffer: VoxelBuffer, origin: Vector3i, lod: int):
    super._generate_block(buffer, origin, lod)
    if origin.y > 46 or origin.y + buffer.get_size().y < 39:
        return
    var size = buffer.get_size()
    for z in size.z:
        for x in size.x:
            var gx = origin.x + x
            var gz = origin.z + z
            if abs(gx) > 36 or abs(gz) > 28:
                continue
            for y in size.y:
                var gy = origin.y + y
                var value = -1
                if gy == 39:
                    value = CONCRETE
                elif gy >= 40 and gy <= 46:
                    value = AIR
                    # Two windowed buildings, crates and low timber cover.
                    for rect in [Rect2i(-18, -22, 12, 11), Rect2i(9, 12, 12, 11)]:
                        if rect.has_point(Vector2i(gx, gz)):
                            var wall = gx == rect.position.x or gx == rect.end.x - 1 or gz == rect.position.y or gz == rect.end.y - 1
                            if gy == 44 or (wall and gy < 44):
                                value = CONCRETE
                            if wall and gy in [41, 42] and gx % 4 in [0, 1]:
                                value = 12 # Glass.
                            if gx in [rect.position.x + 4, rect.position.x + 5] and gz == (rect.end.y - 1 if gz < 0 else rect.position.y) and gy < 43:
                                value = AIR
                    if gy < 42 and ((gx >= -9 and gx <= -2 and gz >= 3 and gz <= 5) or (gx >= 4 and gx <= 11 and gz >= -6 and gz <= -4)):
                        value = 7 # Planks.
                    if gy < 42 and ((gx >= -20 and gx <= -18 and gz >= -4 and gz <= -2) or (gx >= 19 and gx <= 21 and gz >= 4 and gz <= 6)):
                        value = 4 # Log crates.
                if value >= 0:
                    buffer.set_voxel(value, x, y, z, VoxelBuffer.CHANNEL_TYPE)
    buffer.compress_uniform_channels()
