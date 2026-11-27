extends SceneTree

const PRESENTER := preload("res://scripts/presentation/ambient_dialogue_presenter.gd")

var _failures := 0


func _initialize() -> void:
	_check(PRESENTER.wrap_text("A short line") == "A short line", "Short text should remain on one line.")
	_check(PRESENTER.wrap_text("one two three four", 7) == "one two\nthree\nfour", "Ambient text should wrap at word boundaries.")
	var short_duration := PRESENTER.duration_for_text("Hello.")
	var long_duration := PRESENTER.duration_for_text("A considerably longer sentence that needs more than one line to display.")
	_check(short_duration >= 2.5 and short_duration <= 6.5, "Ambient text duration should respect its minimum and maximum.")
	_check(long_duration >= short_duration, "Longer ambient text should receive at least as much display time.")

	var world := Node3D.new()
	root.add_child(world)
	var actor := Node3D.new()
	actor.name = "Speaker"
	world.add_child(actor)
	var presenter := PRESENTER.new()
	world.add_child(presenter)
	var bubble: Label3D = presenter.present(actor, "A line spoken by this character.", 0.1)
	_check(bubble != null and bubble.get_parent() == actor, "Ambient text must be attached to its speaking actor.")
	_check(bubble != null and bubble.text == "A line spoken by this character.", "The actor-attached label should contain the spoken text.")
	await create_timer(0.2, true, false, true).timeout
	_check(not is_instance_valid(bubble), "Ambient text should expire after real elapsed time.")
	world.queue_free()

	if _failures > 0:
		push_error("%d ambient dialogue presenter assertion(s) failed." % _failures)
		quit(1)
		return
	print("Ambient dialogue presenter tests passed.")
	quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
