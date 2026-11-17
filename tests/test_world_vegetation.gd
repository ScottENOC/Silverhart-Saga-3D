extends SceneTree

var failures: int = 0

func _initialize() -> void:
	_test_catalogue()
	_test_authored_placements()
	_test_deterministic_grid_generation()
	if failures > 0:
		push_error("%d world vegetation test(s) failed." % failures)
		quit(1)
		return
	print("World vegetation tests passed.")
	quit(0)

func _test_catalogue() -> void:
	_check(WorldVegetationGenerator.catalogue_asset_count() == 48, "All 48 committed Cosmo vegetation models should be available")

func _test_authored_placements() -> void:
	var grove := Node3D.new()
	root.add_child(grove)
	var placements: Array[Dictionary] = [
		{"name": "TestAsh", "position": Vector3(-2.0, 0.0, 0.0), "family": "ash", "seed": 21, "scale": 0.92},
		{"name": "TestPine", "position": Vector3(2.0, 0.0, 0.0), "family": "pine", "seed": 23, "scale": 0.94}
	]
	var count := WorldVegetationGenerator.generate_authored_placements(grove, placements)
	_check(count == 2, "The shared generator should create all authored grove placements")
	_check(grove.has_node("TestAsh") and grove.has_node("TestPine"), "Authored placements should preserve their stable names")
	for child in grove.get_children():
		_check(child.has_meta("vegetation_family"), "Every generated model should expose its catalogue family")
	grove.free()

func _test_deterministic_grid_generation() -> void:
	var first := Node3D.new()
	var second := Node3D.new()
	root.add_child(first)
	root.add_child(second)
	var filter := Callable(self, "_accept_all_hexes")
	var selector := Callable(self, "_select_ash")
	var first_count := WorldVegetationGenerator.generate_hex_grid(
		first, -2, 2, -2, 2, 2, HexGrid.DEFAULT_RADIUS,
		filter, Vector2i.ZERO, 0.0, selector, 0.9, 0.0, "GridTree"
	)
	var second_count := WorldVegetationGenerator.generate_hex_grid(
		second, -2, 2, -2, 2, 2, HexGrid.DEFAULT_RADIUS,
		filter, Vector2i.ZERO, 0.0, selector, 0.9, 0.0, "GridTree"
	)
	_check(first_count == 9 and second_count == 9, "Grid generation should place every eligible candidate")
	for index in range(first.get_child_count()):
		var a := first.get_child(index) as Node3D
		var b := second.get_child(index) as Node3D
		_check(a.name == b.name, "Deterministic generation should preserve stable node names")
		_check(a.position.is_equal_approx(b.position), "Deterministic generation should preserve positions")
		_check(a.rotation.is_equal_approx(b.rotation), "Deterministic generation should preserve rotations")
	first.free()
	second.free()

func _accept_all_hexes(_hex: Vector2i) -> bool:
	return true

func _select_ash(_hex: Vector2i, _density_roll: float) -> String:
	return "ash"

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
