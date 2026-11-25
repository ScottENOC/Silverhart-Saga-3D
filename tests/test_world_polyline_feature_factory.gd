extends SceneTree

const FACTORY = preload("res://scripts/world/world_polyline_feature_factory.gd")
const HOLLOWMERE_ROUTES = preload("res://data/settlements/hollowmere/routes.gd")

func _initialize() -> void:
	_test_authored_route_rendering()
	_test_invalid_definitions_are_skipped_without_partial_nodes()
	_test_hollowmere_authored_route_manifest()
	print("World polyline feature factory tests passed.")
	quit(0)

func _test_authored_route_rendering() -> void:
	var parent := Node3D.new()
	var path_material := StandardMaterial3D.new()
	var water_material := StandardMaterial3D.new()
	var definitions := [
		{"id": "RoadA", "material": "path", "points": [Vector2i(0, 0), Vector2i(2, 0), Vector2i(4, 1)], "widths": [2.0, 2.5, 2.0]},
		{"id": "StreamA", "material": "water", "points": [Vector2i(-2, 3), Vector2i(0, 4)], "widths": [3.0, 3.0], "elevation": -0.05, "samples_per_segment": 10}
	]
	var created := FACTORY.render_features(parent, definitions, {"path": path_material, "water": water_material}, HexGrid.DEFAULT_RADIUS_M)
	assert(created.size() == 2, "Each valid authored route should create one presentation node")
	assert(parent.get_child_count() == 2, "Renderer should not create hidden helper nodes")
	assert(parent.get_node("RoadA") != null and parent.get_node("StreamA") != null, "Stable authored IDs should become deterministic node names")
	assert((parent.get_node("RoadA") as MeshInstance3D).material_override == path_material, "Route material should resolve from the caller's material map")
	assert((parent.get_node("StreamA") as MeshInstance3D).material_override == water_material, "Water material should resolve from the caller's material map")
	assert((parent.get_node("RoadA") as MeshInstance3D).mesh != null, "Valid route geometry should produce a mesh")
	parent.free()

func _test_invalid_definitions_are_skipped_without_partial_nodes() -> void:
	var parent := Node3D.new()
	var material := StandardMaterial3D.new()
	var definitions := [
		{"id": "TooShort", "material": "path", "points": [Vector2i.ZERO], "widths": [1.0]},
		{"id": "MismatchedWidths", "material": "path", "points": [Vector2i.ZERO, Vector2i.RIGHT], "widths": [1.0]},
		{"id": "MissingMaterial", "material": "unknown", "points": [Vector2i.ZERO, Vector2i.RIGHT], "widths": [1.0, 1.0]},
		{"id": "BadWidth", "material": "path", "points": [Vector2i.ZERO, Vector2i.RIGHT], "widths": [1.0, 0.0]}
	]
	var created := FACTORY.render_features(parent, definitions, {"path": material}, HexGrid.DEFAULT_RADIUS_M)
	assert(created.is_empty(), "Malformed routes should be rejected")
	assert(parent.get_child_count() == 0, "Invalid routes must not leave partial scene nodes")
	var duplicate_ids := [
		{"id": "Duplicate", "material": "path", "points": [Vector2i.ZERO, Vector2i.RIGHT], "widths": [1.0, 1.0]},
		{"id": "Duplicate", "material": "path", "points": [Vector2i.ZERO, Vector2i.LEFT], "widths": [1.0, 1.0]}
	]
	created = FACTORY.render_features(parent, duplicate_ids, {"path": material}, HexGrid.DEFAULT_RADIUS_M)
	assert(created.size() == 1 and parent.get_child_count() == 1, "Only the first route with a stable ID should be created")
	parent.free()

func _test_hollowmere_authored_route_manifest() -> void:
	var parent := Node3D.new()
	var path_material := StandardMaterial3D.new()
	var water_material := StandardMaterial3D.new()
	var bank_material := StandardMaterial3D.new()
	var created := FACTORY.render_features(
		parent,
		HOLLOWMERE_ROUTES.PRESENTATION_ROUTES,
		{"path": path_material, "water": water_material, "bank": bank_material},
		HexGrid.DEFAULT_RADIUS_M
	)
	assert(HOLLOWMERE_ROUTES.PRESENTATION_ROUTES.size() == 13, "Hollowmere should author the stream, banks, main roads, village lane, ring, five house spurs, farmyard lane and cottage-plot access spur")
	assert(created.size() == HOLLOWMERE_ROUTES.PRESENTATION_ROUTES.size(), "Every authored Hollowmere route should render")
	assert(parent.get_node_or_null("VillageStream") != null and parent.get_node_or_null("NorthSouthRoad") != null, "Key routes should retain stable scene names")
	parent.free()
