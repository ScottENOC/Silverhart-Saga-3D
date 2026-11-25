extends SceneTree

const SERVICE = preload("res://scripts/world/campaign_dwelling_interior_service.gd")
const DWELLING_STATE = preload("res://scripts/simulation/campaign_dwelling_state.gd")
const SIMULATION = preload("res://scripts/simulation/world_simulation.gd")

var failures := 0

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_ownership_gate()
	_test_crossroads_cottage()
	_test_country_house_upgrade()
	_test_restored_roadside_house()
	_test_silverhart_manor_states()
	if failures > 0:
		push_error("%d dwelling interior test(s) failed." % failures)
		quit(1)
		return
	print("Campaign dwelling interior floor-map tests passed.")
	quit(0)


func _test_ownership_gate() -> void:
	var state = DWELLING_STATE.new()
	var simulation = _simulation()
	var parent := Node3D.new()
	root.add_child(parent)
	var result: Dictionary = SERVICE.load_owned_dwelling(parent, state, simulation, "crossroads_cottage")
	_check(not bool(result.get("ok", false)) and String(result.get("reason", "")) == "dwelling_not_owned", "An unowned property must not expose its private interior")
	_check(parent.get_child_count() == 0, "An unowned property must not create an interior runtime")
	parent.free()
	simulation.free()


func _test_crossroads_cottage() -> void:
	var state = DWELLING_STATE.new()
	state.owned["crossroads_cottage"] = true
	var simulation = _simulation()
	var parent := Node3D.new()
	root.add_child(parent)
	var result: Dictionary = SERVICE.load_owned_dwelling(parent, state, simulation, "crossroads_cottage")
	_check(bool(result.get("ok", false)), "An owned crossroads cottage must load its source-authored interior")
	var runtime = result.get("runtime") as Campaign2MultiStoryLocationRuntime
	if runtime != null:
		_check(runtime.get_floor_tile_count(0) > 0, "The cottage must create walkable ground-floor geometry")
		_check(runtime.has_floor_object(0, "crossroads_cottage_south_door"), "The cottage must retain its south doorway")
		_check(runtime.has_floor_object(0, "crossroads_cottage_player_bed"), "The cottage must present its source player bed")
		_check(runtime.has_floor_object(0, "crossroads_cottage_fireplace"), "The cottage must present its source fireplace")
		_check(runtime.has_floor_object(0, "crossroads_cottage_storage_chest"), "The cottage must present its source storage chest")
		var floor_group := runtime.floor_groups.get(0) as Node3D
		var bed_prop := floor_group.get_node_or_null("crossroads_cottage_player_bed") as Node3D
		_check(bed_prop != null and bed_prop.get_node_or_null("BedFrame") is MeshInstance3D and bed_prop.get_node_or_null("Mattress") is MeshInstance3D and bed_prop.get_node_or_null("Pillow") is MeshInstance3D, "The bed must render as a frame, mattress and pillow rather than a generic cube")
		var chest_prop := floor_group.get_node_or_null("crossroads_cottage_storage_chest") as Node3D
		_check(chest_prop != null and chest_prop.get_node_or_null("ChestBody") is MeshInstance3D and chest_prop.get_node_or_null("ChestLid") is MeshInstance3D, "The storage chest must have a distinct body and lid")
		var door_prop := floor_group.get_node_or_null("crossroads_cottage_south_door") as Node3D
		_check(door_prop != null and door_prop.get_node_or_null("DoorFrameLeft") is MeshInstance3D and door_prop.get_node_or_null("DoorPanel") is MeshInstance3D, "The doorway must render as a frame and open door panel")
		_check(runtime.definition.get("anchor", {}) == {"q": 13, "r": 27}, "The cottage must use the surveyed plot's exact source anchor")
		_check(runtime.definition.get("id", "") == "dwelling_crossroads_cottage", "The dwelling interior needs a stable save identity separate from the world plot")
	_check(simulation.map_data.is_walkable(Vector2i(13, 27)), "The cottage bed hex must be walkable")
	var repeated: Dictionary = SERVICE.load_owned_dwelling(parent, state, simulation, "crossroads_cottage")
	_check(not bool(repeated.get("ok", false)) and String(repeated.get("reason", "")) == "dwelling_interior_already_loaded", "The same property interior must not be loaded twice")
	parent.free()
	simulation.free()


func _test_country_house_upgrade() -> void:
	var state = DWELLING_STATE.new()
	state.owned["crossroads_cottage"] = true
	state.upgrades["crossroads_cottage"] = "upgrade_country_house"
	var simulation = _simulation()
	var parent := Node3D.new()
	root.add_child(parent)
	var result: Dictionary = SERVICE.load_owned_dwelling(parent, state, simulation, "crossroads_cottage")
	_check(bool(result.get("ok", false)), "The upgraded country house must load its larger source footprint")
	var runtime = result.get("runtime") as Campaign2MultiStoryLocationRuntime
	if runtime != null:
		_check(runtime.has_floor_object(0, "crossroads_country_house_south_door"), "The upgraded house must move its doorway one source hex south")
		_check(runtime.has_floor_object(0, "crossroads_country_house_table"), "The upgraded house must present its source table")
		_check(runtime.has_floor_object(0, "crossroads_country_house_bench"), "The upgraded house must present its source bench")
		var floor_group := runtime.floor_groups.get(0) as Node3D
		var table_prop := floor_group.get_node_or_null("crossroads_country_house_table") as Node3D
		_check(table_prop != null and table_prop.get_node_or_null("TableTop") is MeshInstance3D and table_prop.get_child_count() == 5, "The country-house table must render a top and four legs")
		var bench_prop := floor_group.get_node_or_null("crossroads_country_house_bench") as Node3D
		_check(bench_prop != null and bench_prop.get_node_or_null("BenchSeat") is MeshInstance3D and bench_prop.get_child_count() == 5, "The country-house bench must render a seat and four legs")
		_check(not runtime.has_floor_object(0, "crossroads_cottage_storage_chest"), "The source upgrade replaces the cottage chest hex with its table")
		_check(runtime.get_floor_tile_count(0) > 20, "The upgraded house must use the larger 3-by-3 source-building footprint")
	parent.free()
	simulation.free()


func _test_restored_roadside_house() -> void:
	var state = DWELLING_STATE.new()
	state.owned["abandoned_house"] = true
	var simulation = _simulation()
	var parent := Node3D.new()
	root.add_child(parent)
	var result: Dictionary = SERVICE.load_owned_dwelling(parent, state, simulation, "abandoned_house")
	_check(bool(result.get("ok", false)), "A restored roadside house must load its source floor map")
	var runtime = result.get("runtime") as Campaign2MultiStoryLocationRuntime
	if runtime != null:
		_check(runtime.has_floor_object(0, "abandoned_house_journal"), "Restoration must preserve the source journal")
		_check(runtime.has_floor_object(0, "phylactery_altar"), "Restoration must preserve the source altar")
		_check(runtime.has_floor_object(0, "abandoned_house_player_bed"), "Restoration must add the bed at centre.q - 1")
	parent.free()
	simulation.free()


func _test_silverhart_manor_states() -> void:
	var state = DWELLING_STATE.new()
	state.owned["silverhart_manor"] = true
	var simulation = _simulation()
	var parent := Node3D.new()
	root.add_child(parent)
	var ruined_result: Dictionary = SERVICE.load_owned_dwelling(parent, state, simulation, "silverhart_manor")
	_check(bool(ruined_result.get("ok", false)), "A granted but unfortified manor must load its ruined floor map")
	var ruined_runtime = ruined_result.get("runtime") as Campaign2MultiStoryLocationRuntime
	if ruined_runtime != null:
		_check(ruined_runtime.get_floor_tile_count(0) == 31, "The ruined manor must preserve its source irregular floor mask")
		_check(not ruined_runtime.has_floor_object(0, "silverhart_manor_player_bed"), "A royal grant must not invent a bed before fortification")
	parent.free()
	simulation.free()

	state.upgrades["silverhart_manor"] = "fortify_silverhart_manor"
	simulation = _simulation()
	parent = Node3D.new()
	root.add_child(parent)
	var livable_result: Dictionary = SERVICE.load_owned_dwelling(parent, state, simulation, "silverhart_manor")
	_check(bool(livable_result.get("ok", false)), "A fortified manor must load its livable floor map")
	var livable_runtime = livable_result.get("runtime") as Campaign2MultiStoryLocationRuntime
	if livable_runtime != null:
		_check(livable_runtime.has_floor_object(0, "silverhart_manor_player_bed"), "Fortification must add the source player bed")
		_check(livable_runtime.has_floor_object(0, "silverhart_manor_fireplace"), "Fortification must add the source fireplace")
	parent.free()
	simulation.free()


func _simulation() -> WorldSimulation:
	var simulation = SIMULATION.new()
	root.add_child(simulation)
	return simulation


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
