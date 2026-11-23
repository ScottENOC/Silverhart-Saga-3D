extends SceneTree

const ARA_ACTOR_SCRIPT = preload("res://scripts/presentation/ara_character_actor.gd")
const HEX_ACTOR_SCRIPT = preload("res://scripts/presentation/hex_actor_presentation.gd")

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var presentation := HEX_ACTOR_SCRIPT.new() as Node3D
	var character_model := ARA_ACTOR_SCRIPT.new()
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
	await create_timer(0.5).timeout
	_check(presentation.global_position.is_equal_approx(Vector3(1.0, 0.0, 0.0)),
		"Character reaches the next hex centre through continuous interpolation")
	_check(absf(wrapf(presentation.global_rotation.y - PI / 3.0, -PI, PI)) < 0.02,
		"Character turns to face its direction of travel")
	_check(animation_player.current_animation == "Idle",
		"Character returns to idle after the movement tween completes")

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
