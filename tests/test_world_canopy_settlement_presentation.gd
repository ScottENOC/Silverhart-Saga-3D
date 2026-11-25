extends SceneTree

const REGISTRY = preload("res://scripts/world/campaign2_multistory_location_registry.gd")
const PRESENTATION = preload("res://scripts/world/world_canopy_settlement_presentation.gd")

var failures := 0

func _initialize() -> void:
	var registry = REGISTRY.new()
	var definition: Dictionary = registry.get_definition("silthandriel")
	_check(not definition.is_empty(), "Sil'thandriel must load from the canonical multi-story registry")

	var western_chunk := Node3D.new()
	root.add_child(western_chunk)
	var west_result: Dictionary = PRESENTATION.present_chunk(western_chunk, definition, Vector2i(-264, 936), 24, HexGrid.DEFAULT_RADIUS_M)
	_check(bool(west_result.get("ok", false)), "Western canopy chunk must present")
	_check(west_result.get("platforms", 0) == 1, "Western chunk must present the Archive platform only")
	_check(west_result.get("bridge_segments", 0) > 0, "Western chunk must present its share of the rope bridge")
	_check(western_chunk.get_node_or_null("SilthandrielPlatform_archive_platform") != null, "Archive platform must have a stable root")

	var eastern_chunk := Node3D.new()
	root.add_child(eastern_chunk)
	var east_result: Dictionary = PRESENTATION.present_chunk(eastern_chunk, definition, Vector2i(-240, 936), 24, HexGrid.DEFAULT_RADIUS_M)
	_check(bool(east_result.get("ok", false)), "Eastern canopy chunk must present")
	_check(east_result.get("platforms", 0) == 1, "Eastern chunk must present the healer lodge platform only")
	_check(eastern_chunk.get_node_or_null("SilthandrielPlatform_healer_lodge_platform") != null, "Healer lodge platform must have a stable root")

	var central_chunk := Node3D.new()
	root.add_child(central_chunk)
	var centre_result: Dictionary = PRESENTATION.present_chunk(central_chunk, definition, Vector2i(-264, 912), 24, HexGrid.DEFAULT_RADIUS_M)
	_check(bool(centre_result.get("ok", false)), "Central canopy chunk must present")
	_check(centre_result.get("trunks", 0) == 1, "Central chunk must present the great tree trunk")
	_check(centre_result.get("platforms", 0) == 1, "Central chunk must present the upper court platform")
	_check(central_chunk.get_node_or_null("silthandriel_great_tree_trunk") != null, "Great tree must use its stable source ID")

	var unrelated_chunk := Node3D.new()
	root.add_child(unrelated_chunk)
	var unrelated_result: Dictionary = PRESENTATION.present_chunk(unrelated_chunk, definition, Vector2i(600, 600), 24, HexGrid.DEFAULT_RADIUS_M)
	_check(bool(unrelated_result.get("ok", false)), "Unrelated chunks must remain valid")
	_check(unrelated_chunk.get_child_count() == 0, "Canopy geometry must not leak into unrelated chunks")

	var runtime_root := Node3D.new()
	root.add_child(runtime_root)
	_check(PRESENTATION.present_trunk(runtime_root, definition, Vector2i(-252, 934), HexGrid.DEFAULT_RADIUS_M), "Tree trunk must be available to the multi-story runtime")
	_check(runtime_root.get_node_or_null("silthandriel_great_tree_trunk") != null, "Runtime tree trunk must be rendered")
	var lower_floor := Node3D.new()
	runtime_root.add_child(lower_floor)
	var lower_result: Dictionary = PRESENTATION.present_floor(lower_floor, definition, 1, Vector2i(-252, 934), HexGrid.DEFAULT_RADIUS_M)
	_check(bool(lower_result.get("ok", false)) and lower_result.get("platforms", 0) == 2, "Lower Canopy must present both platforms")
	_check(lower_result.get("bridge_segments", 0) == 18, "Lower Canopy must present all source rope-bridge deck segments")
	var upper_floor := Node3D.new()
	runtime_root.add_child(upper_floor)
	var upper_result: Dictionary = PRESENTATION.present_floor(upper_floor, definition, 2, Vector2i(-252, 934), HexGrid.DEFAULT_RADIUS_M)
	_check(bool(upper_result.get("ok", false)) and upper_result.get("platforms", 0) == 1, "Upper Canopy must present the open Court platform")

	if failures > 0:
		push_error("%d canopy settlement presentation test(s) failed." % failures)
		quit(1)
		return
	print("Sil'thandriel canopy settlement presentation tests passed.")
	quit(0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
