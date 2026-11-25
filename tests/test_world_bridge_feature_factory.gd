extends SceneTree

const FACTORY = preload("res://scripts/world/world_bridge_feature_factory.gd")
const HOLLOWMERE_BRIDGES = preload("res://data/settlements/hollowmere/bridges.gd")
const HOLLOWMERE_SETTLEMENT = preload("res://data/settlements/hollowmere/settlement_definition.gd")
const HOLLOWMERE_TERRAIN = preload("res://data/settlements/hollowmere/terrain.gd")
const TERRAIN_PROVIDER = preload("res://scripts/world/authored_settlement_terrain_provider.gd")
const SETTLEMENT_PRESENTER = preload("res://scripts/world/world_settlement_presenter.gd")
const HOLLOWMERE_PRESENTATION = preload("res://data/settlements/hollowmere/presentation.gd")

func _initialize() -> void:
	_test_bridge_assembly_from_authored_definition()
	_test_invalid_bridge_is_rejected_atomically()
	_test_hollowmere_bridge_integration()
	print("World bridge feature factory tests passed.")
	quit(0)

func _test_bridge_assembly_from_authored_definition() -> void:
	var parent := Node3D.new()
	var timber := StandardMaterial3D.new()
	var dark_wood := StandardMaterial3D.new()
	var bridge := FACTORY.create_bridge(
		parent,
		HOLLOWMERE_BRIDGES.BRIDGE_PRESENTATION,
		{"timber": timber, "dark_wood": dark_wood},
		HexGrid.DEFAULT_RADIUS_M
	)
	assert(bridge != null, "Authored bridge should be constructible")
	assert(bridge.name == "NarrowRiverBridge", "Bridge root should retain its authored identity")
	assert(bridge.position.distance_to(HexGrid.axial_to_world(HOLLOWMERE_SETTLEMENT.BRIDGE, HexGrid.DEFAULT_RADIUS_M, 0.0)) < 0.001, "Bridge should be placed at its authored axial centre")
	assert(is_equal_approx(rad_to_deg(bridge.rotation.y), -5.0), "Bridge should preserve its authored crossing angle")
	assert(bridge.get_child_count() == 9, "Bridge should contain one deck, two rails and six posts")
	var deck := bridge.get_node("StreamBridgeDeck") as MeshInstance3D
	assert(deck != null and (deck.mesh as BoxMesh).size == Vector3(2.8, 0.24, 4.8), "Bridge deck dimensions should match the authored geometry")
	assert(deck.material_override == timber, "Deck should resolve the timber material")
	assert((bridge.get_node("BridgeRail_Left") as MeshInstance3D).material_override == dark_wood, "Rails should resolve dark wood")
	assert(bridge.get_node_or_null("BridgePost_Right_South") != null, "All authored posts should be named deterministically")
	parent.free()

func _test_invalid_bridge_is_rejected_atomically() -> void:
	var parent := Node3D.new()
	var timber := StandardMaterial3D.new()
	var missing_parts := {"id": "NoParts", "centre": Vector2i.ZERO, "parts": []}
	assert(FACTORY.create_bridge(parent, missing_parts, {"timber": timber}, HexGrid.DEFAULT_RADIUS_M) == null, "Bridge without parts should be rejected")
	var invalid_material := {
		"id": "BadMaterial",
		"centre": Vector2i.ZERO,
		"parts": [{"name": "Deck", "position": Vector3.ZERO, "size": Vector3.ONE, "material": "missing"}]
	}
	assert(FACTORY.create_bridge(parent, invalid_material, {"timber": timber}, HexGrid.DEFAULT_RADIUS_M) == null, "Unknown material should be rejected")
	var invalid_size := {
		"id": "BadSize",
		"centre": Vector2i.ZERO,
		"parts": [{"name": "Deck", "position": Vector3.ZERO, "size": Vector3(1.0, 0.0, 1.0), "material": "timber"}]
	}
	assert(FACTORY.create_bridge(parent, invalid_size, {"timber": timber}, HexGrid.DEFAULT_RADIUS_M) == null, "Zero-sized geometry should be rejected")
	var invalid_centre := {"id": "BadCentre", "centre": Vector3.ZERO, "parts": [{"name": "Deck", "position": Vector3.ZERO, "size": Vector3.ONE, "material": "timber"}]}
	assert(FACTORY.create_bridge(parent, invalid_centre, {"timber": timber}, HexGrid.DEFAULT_RADIUS_M) == null, "Bridge centre must be an axial coordinate")
	assert(parent.get_child_count() == 0, "Invalid definitions must not leave partial bridge roots")
	parent.free()

func _test_hollowmere_bridge_integration() -> void:
	var village := SETTLEMENT_PRESENTER.new() as Node3D
	village.call("configure_location", HOLLOWMERE_PRESENTATION.DEFINITION)
	village.call("_create_materials", HOLLOWMERE_PRESENTATION.DEFINITION.palette)
	village.call("_present_authored_features", HOLLOWMERE_PRESENTATION.DEFINITION.features, HexGrid.DEFAULT_RADIUS_M)
	var bridge := village.get_node_or_null("NarrowRiverBridge") as Node3D
	assert(bridge != null, "Hollowmere should delegate its authored bridge to the shared factory")
	assert(bridge.get_child_count() == HOLLOWMERE_BRIDGES.BRIDGE_PRESENTATION.parts.size(), "Hollowmere bridge should render every authored part")
	assert(not TERRAIN_PROVIDER.is_blocked(HOLLOWMERE_SETTLEMENT.BRIDGE, HOLLOWMERE_TERRAIN.DEFINITION), "Presentation extraction must not alter bridge movement traversability")
	village.free()
