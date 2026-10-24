extends Node3D

@rpc("any_peer", "call_remote", "unreliable", 0)
func receive_position(pos: Vector3, yaw: float):
    if multiplayer.get_remote_sender_id() != int(str(name)) or not pos.is_finite():
        return
    position = pos
    rotation.y = yaw
