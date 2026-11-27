extends SceneTree
## Shared harness for posing tests. Subclasses override _run() and use _check/_near.

var _failures := 0


func _initialize() -> void:
	call_deferred("_start")


func _start() -> void:
	await process_frame
	_run()
	if _failures > 0:
		push_error("%s: %d assertion(s) failed." % [_test_name(), _failures])
		quit(1)
		return
	print("%s: PASS" % _test_name())
	quit(0)


func _run() -> void:
	pass


func _test_name() -> String:
	return get_script().resource_path.get_file().get_basename().to_upper()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _near(actual: float, expected: float, tolerance: float, message: String) -> void:
	if absf(actual - expected) > tolerance:
		_failures += 1
		push_error("%s (expected %.6f +/- %.6f, got %.6f)" % [message, expected, tolerance, actual])


func _near_v(actual: Vector3, expected: Vector3, tolerance: float, message: String) -> void:
	if actual.distance_to(expected) > tolerance:
		_failures += 1
		push_error("%s (expected %s +/- %.6f, got %s)" % [message, expected, tolerance, actual])
