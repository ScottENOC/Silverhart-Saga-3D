extends SceneTree

const ARA_ACTOR_SCRIPT = preload("res://scripts/presentation/ara_character_actor.gd")
const HEX_ACTOR_SCRIPT = preload("res://scripts/presentation/hex_actor_presentation.gd")

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var presentation := HEX_ACTOR_SCRIPT.new() as Node3D
	var character_model := ARA_ACTOR_SCRIPT.new()
	character_model.name = "CharacterModel"
	var animation_player := AnimationPlayer.new()
	var library := AnimationLibrary.new()
	library.add_animation("Idle", Animation.new())
	library.add_animation("Walk", Animation.new())
	animation_player.add_animation_library("", library)
	character_model.animation_player = animation_player
	presentation.add_child(character_model)
	root.add_child(presentation)

	_check(character_model.play_idle(), "Ara actor can select its idle clip")
	_check(animation_player.current_animation == "Idle", "Idle clip is playing before movement")

	presentation.present_move_to(Vector3(1.0, 0.0, 0.0), PI / 3.0)
	_check(animation_player.current_animation == "Walk", "Movement switches the Ara actor to its walk clip")
	await create_timer(0.18).timeout
	_check(presentation.global_position.x > 0.05 and presentation.global_position.x < 0.95,
		"Character is visibly between hex centres during the movement transition")
	await create_timer(0.35).timeout
	_check(presentation.global_position.is_equal_approx(Vector3(1.0, 0.0, 0.0)),
		"Character reaches the next hex centre through continuous interpolation")
	_check(absf(wrapf(presentation.global_rotation.y - PI / 3.0, -PI, PI)) < 0.02,
		"Character turns to face its direction of travel")
	_check(animation_player.current_animation == "Idle",
		"Character returns to idle after the movement tween completes")

	# A second move should continue from the current position rather than snapping
	# back to the previous hex centre or allowing the old tween to win.
	presentation.present_move_to(Vector3(2.0, 0.0, 0.0), 0.0)
	await create_timer(0.10).timeout
	var interrupted_position := presentation.global_position
	presentation.present_move_to(Vector3(3.0, 0.0, 0.0), -PI / 3.0)
	_check(presentation.global_position.is_equal_approx(interrupted_position),
		"An interrupted move continues from its current visual position")
	await create_timer(0.45).timeout
	_check(presentation.global_position.is_equal_approx(Vector3(3.0, 0.0, 0.0)),
		"Latest movement target wins after an interrupted transition")

	# A vertical floor change uses the same locomotion path, with a longer
	# duration so the actor visibly walks the authored staircase.
	var stair_start := Vector3(5.625, 0.12, 3.2476)
	var stair_end := Vector3(5.625, 3.5, 1.0825)
	presentation.global_position = stair_start
	presentation.present_move_to(stair_end, NAN, 1.2)
	await create_timer(0.30).timeout
	var stair_midpoint := presentation.global_position
	_check(stair_midpoint.y > stair_start.y and stair_midpoint.y < stair_end.y,
		"Stair traversal moves continuously through intermediate elevations")
	_check(stair_midpoint.z < stair_start.z and stair_midpoint.z > stair_end.z,
		"Stair traversal follows the authored ascending direction instead of snapping floors")
	await create_timer(1.0).timeout
	_check(presentation.global_position.is_equal_approx(stair_end),
		"Actor reaches the upper landing after the stair traversal duration")
	_check(presentation.movement_duration == 0.36,
		"An authored stair duration override does not alter ordinary movement speed")
	_check(animation_player.current_animation == "Idle",
		"Character returns to idle after the stair traversal completes")

	presentation.queue_free()
	if failures > 0:
		push_error("%d character presentation assertion(s) failed." % failures)
		quit(1)
		return
	print("Hex actor presentation movement and animation tests passed.")
	quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
