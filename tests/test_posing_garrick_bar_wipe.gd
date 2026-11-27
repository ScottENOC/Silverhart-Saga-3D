extends SceneTree
## Real-rig regression test for Garrick's looping bar-wipe activity and interruption.

const ARA_ACTOR := preload("res://scripts/presentation/ara_character_actor.gd")
const WIPE_CONTROLLER := preload("res://scripts/presentation/garrick_bar_wipe_controller.gd")

var _interrupted: bool = false
var _return_to_station_count: int = 0
var _failures: int = 0


func _initialize() -> void:
	call_deferred("_start")


func _start() -> void:
	var actor := Node3D.new()
	actor.name = "GarrickTestActor"
	root.add_child(actor)
	var ara := ARA_ACTOR.new() as AraCharacterActor
	ara.name = "CharacterModel"
	actor.add_child(ara)
	if not ara.configure("res://art/characters/hollowmere/garrick_holt.glb"):
		_check(false, "Garrick's authored Hollowmere model loads")
		_finish()
		return

	await process_frame
	var controller := WIPE_CONTROLLER.new() as GarrickBarWipeController
	root.add_child(controller)
	controller.configure(actor, Callable(self, "_is_interrupted"), Callable(self, "_return_to_station"))
	for _frame in range(12):
		await process_frame

	var modifier := controller.modifier
	_check(modifier != null, "the controller attaches a late skeleton modifier")
	if modifier != null:
		_check(modifier.last_status == "bar wipe active", "Garrick can reach the bar surface with one arm (%s)" % modifier.last_status)
		_check(modifier.selected_side != &"", "the modifier selects a usable arm")
		_check(modifier.last_tip_error_m >= 0.0 and modifier.last_tip_error_m < 0.005, "the fingertip tracks the wipe target (%.4f m)" % modifier.last_tip_error_m)
		var first_target := modifier.last_target_world
		await create_timer(0.8).timeout
		_check(modifier.last_target_world.distance_to(first_target) > 0.08, "the hand travels along the bar rather than holding a static pose")

		_interrupted = true
		await process_frame
		await process_frame
		_check(not modifier.active, "the bar wipe is disabled during the Iron One confrontation")
		_interrupted = false
		await process_frame
		await process_frame
		_check(modifier.active, "the bar wipe resumes after the confrontation")
		_check(_return_to_station_count == 1, "the innkeeper is returned to his authored bar station")

	_finish()


func _is_interrupted() -> bool:
	return _interrupted


func _return_to_station() -> bool:
	_return_to_station_count += 1
	return true


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
	else:
		print("PASS ", message)


func _finish() -> void:
	if _failures > 0:
		push_error("GARRICK BAR WIPE: %d failure(s)" % _failures)
		quit(1)
		return
	print("GARRICK BAR WIPE: PASS")
	quit(0)
