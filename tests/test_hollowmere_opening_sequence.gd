extends SceneTree

const CONTROLLER := preload("res://scripts/simulation/hollowmere_opening_sequence_controller.gd")

var _events: Array[String] = []
var _resolved := false
var _started_count := 0


func _initialize() -> void:
	var controller := CONTROLLER.new()
	root.add_child(controller)
	controller.shakedown_started.connect(_on_shakedown_started)
	controller.begin(
		"human",
		Callable(self, "_start_quest"),
		Callable(self, "_present_ambient"),
		Callable(self, "_move_soldiers"),
		Callable(self, "_present_interactive"),
		Callable(self, "_is_resolved"),
		0.01,
		0.01,
		0.01
	)
	await create_timer(0.2).timeout
	_check(_events.has("quest_started"), "The opening should start its quest through the injected service callback.")
	_check(_events.has("ambient:companion_wren_talbot"), "The opening should begin with Wren's ambient line.")
	_check(_events.has("ambient:dray_coltayne"), "The opening should present the first Ironbond speaker as ambient dialogue.")
	_check(_events.has("move_inside"), "The stage-direction beat should move the soldiers without presenting narrator text.")
	_check(not _events.has("ambient:narrator"), "Narrator stage direction must not become a floating speech bubble.")
	_check(_events.has("interactive"), "The opening should finish in the interactive dialogue mode.")
	_check(_started_count == 1, "The shakedown should be marked started exactly once.")
	controller.queue_free()

	var skipped := CONTROLLER.new()
	root.add_child(skipped)
	_events.clear()
	skipped.begin("orc", Callable(self, "_start_quest"), Callable(self, "_present_ambient"), Callable(self, "_move_soldiers"), Callable(self, "_present_interactive"), Callable(self, "_is_resolved"), 0.01, 0.01, 0.01)
	await create_timer(0.05).timeout
	_check(_events.is_empty(), "Goblin and orc player starts should skip the human opening sequence.")
	skipped.queue_free()

	if _failures > 0:
		push_error("%d Hollowmere opening sequence assertion(s) failed." % _failures)
		quit(1)
		return
	print("Hollowmere opening sequence tests passed.")
	quit(0)


var _failures := 0


func _start_quest() -> void:
	_events.append("quest_started")


func _present_ambient(speaker_id: String, _spoken_text: String) -> void:
	_events.append("ambient:" + speaker_id)


func _move_soldiers() -> void:
	_events.append("move_inside")


func _present_interactive() -> void:
	_events.append("interactive")


func _is_resolved() -> bool:
	return _resolved


func _on_shakedown_started() -> void:
	_started_count += 1


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
