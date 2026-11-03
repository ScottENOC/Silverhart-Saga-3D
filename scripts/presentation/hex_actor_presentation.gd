class_name HexActorPresentation
extends Node3D

@export var movement_duration: float = 0.18

func present_move_to(world_position: Vector3) -> void:
    var tween := create_tween()
    tween.set_trans(Tween.TRANS_QUAD)
    tween.set_ease(Tween.EASE_IN_OUT)
    tween.tween_property(self, "global_position", world_position, movement_duration)
