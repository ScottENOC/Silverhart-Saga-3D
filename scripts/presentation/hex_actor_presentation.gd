class_name HexActorPresentation
extends Node3D

@export var movement_duration: float = 0.36

var movement_tween: Tween


func present_move_to(
	world_position: Vector3,
	facing_rotation: float = NAN,
	duration_override: float = -1.0
) -> void:
	if movement_tween != null and movement_tween.is_running():
		movement_tween.kill()

	var duration := movement_duration if duration_override <= 0.0 else maxf(0.01, duration_override)
	_set_locomotion(true)
	movement_tween = create_tween()
	movement_tween.set_trans(Tween.TRANS_SINE)
	movement_tween.set_ease(Tween.EASE_IN_OUT)
	movement_tween.tween_property(self, "global_position", world_position, duration)

	if not is_nan(facing_rotation):
		var shortest_turn := wrapf(facing_rotation - global_rotation.y, -PI, PI)
		movement_tween.parallel().tween_property(
			self,
			"global_rotation:y",
			global_rotation.y + shortest_turn,
			minf(0.16, duration * 0.6)
		)

	movement_tween.tween_callback(_finish_locomotion)


func stop_moving() -> void:
	if movement_tween != null and movement_tween.is_running():
		movement_tween.kill()
	_set_locomotion(false)


func _finish_locomotion() -> void:
	_set_locomotion(false)


func _set_locomotion(is_moving: bool) -> void:
	var character_model := get_node_or_null("CharacterModel")
	if character_model != null and character_model.has_method("set_moving"):
		character_model.call("set_moving", is_moving)
