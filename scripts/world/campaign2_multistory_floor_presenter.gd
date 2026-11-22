class_name Campaign2MultiStoryFloorPresenter
extends Node3D
## Renders the active floor of a source-authored multi-story location and
## exposes stair/quest interactions to the campaign location controller.

signal floor_changed(previous_floor: int, current_floor: int, stair_position: Vector2i)
signal quest_gate_revealed(quest_id: String, from_floor: int, to_floor: int)

const REGISTRY = preload("res://scripts/world/campaign2_multistory_location_registry.gd")
const LOCATION_STATE = preload("res://scripts/simulation/campaign2_multistory_location_state.gd")
const FLOOR_BUILDER = preload("res://scripts/world/campaign2_multistory_floor_map_builder.gd")
const TERRAIN_RENDERER = preload("res://scripts/presentation/hex_terrain_renderer.gd")

const DEFAULT_WALL_HEIGHT := 2.4

var location_definition: Dictionary = {}
var location_state: Campaign2MultiStoryLocationState
var simulation: WorldSimulation
var terrain_renderer: HexTerrainRenderer
var wall_geometry: Node3D
var tile_object_visuals: Node3D
var current_map_data: HexMapData
var current_tile_objects: Array[Dictionary] = []
var current_actors: Array[Dictionary] = []
var current_creatures: Array[Dictionary] = []
var hex_radius: float = HexGrid.DEFAULT_RADIUS_M
var wall_height: float = DEFAULT_WALL_HEIGHT
var _configured: bool = false

func configure_campaign(
	campaign_simulation: WorldSimulation,
	_profile: Dictionary,
	save_data: Dictionary
) -> void:
	simulation = campaign_simulation
	var registry := REGISTRY.new()
	var definition := registry.get_definition("kragmoor")
	var locations: Dictionary = save_data.get("multi_story_locations", {})
	var saved_state: Dictionary = locations.get("kragmoor", {})
	var result := configure_location(definition, saved_state)
	if not bool(result.get("ok", false)):
		push_error("Kragmoor floor presenter configuration failed: %s" % result)
		return
	if simulation != null and not simulation.campaign_journal.journal_event.is_connected(_on_campaign_journal_event):
		simulation.campaign_journal.journal_event.connect(_on_campaign_journal_event)
	# If the quest was completed before entering the location, replay its
	# completed state into the location gate rather than requiring a new event.
	if simulation != null:
		var quest: Dictionary = simulation.campaign_journal.quests.get("deepholds_infestation", {})
		if String(quest.get("status", "")) == "completed":
			complete_quest("deepholds_infestation")

func configure_location(definition: Dictionary, saved_state: Dictionary = {}) -> Dictionary:
	if definition.is_empty() or String(definition.get("id", "")) != "kragmoor":
		return {"ok": false, "reason": "unsupported_or_missing_multi_story_location"}
	location_definition = definition.duplicate(true)
	hex_radius = float(location_definition.get("hex_radius", HexGrid.DEFAULT_RADIUS_M))
	if hex_radius <= 0.0:
		return {"ok": false, "reason": "invalid_hex_radius"}
	location_state = LOCATION_STATE.new()
	var state_result: Dictionary = location_state.configure(location_definition, saved_state)
	if not bool(state_result.get("ok", false)):
		return state_result
	_configured = true
	return {"ok": true, "location_id": location_state.location_id, "current_floor": location_state.current_floor}

func _ready() -> void:
	if not _configured:
		push_error("Campaign2MultiStoryFloorPresenter requires configure_location or configure_campaign.")
		return
	_render_current_floor()

func try_use_stair(stair_position: Vector2i) -> Dictionary:
	if not _configured:
		return {"ok": false, "reason": "location_not_configured"}
	var destination_floor := 999999
	for tile_object in current_tile_objects:
		if String(tile_object.get("type", "")) not in ["stair_up", "stair_down"]:
			continue
		var position: Dictionary = tile_object.get("position", {})
		if Vector2i(int(position.get("q", 0)), int(position.get("r", 0))) == stair_position:
			destination_floor = int(tile_object.get("to_floor", 999999))
			break
	if destination_floor == 999999:
		return {"ok": false, "reason": "no_stair_at_position"}
	var saved_before := location_state.to_dict()
	var transition_result: Dictionary = location_state.try_transition(destination_floor, stair_position)
	if not bool(transition_result.get("ok", false)):
		return transition_result
	var render_result := _render_current_floor()
	if not bool(render_result.get("ok", false)):
		location_state.restore(saved_before)
		_render_current_floor()
		return {"ok": false, "reason": "floor_render_failed", "details": render_result}
	floor_changed.emit(
		int(transition_result.get("from_floor", 0)),
		int(transition_result.get("to_floor", 0)),
		stair_position
	)
	return transition_result

func complete_quest(quest_id: String) -> Dictionary:
	if not _configured:
		return {"ok": false, "reason": "location_not_configured"}
	var result: Dictionary = location_state.complete_quest(quest_id)
	if not bool(result.get("ok", false)):
		return result
	for transition in result.get("revealed", []):
		var from_floor := int(transition.get("from_floor", 999999))
		var to_floor := int(transition.get("to_floor", 999999))
		quest_gate_revealed.emit(quest_id, from_floor, to_floor)
		if from_floor == location_state.current_floor:
			_render_current_floor()
	return result

func to_dict() -> Dictionary:
	return location_state.to_dict() if location_state != null else {}

func get_current_floor() -> int:
	return location_state.current_floor if location_state != null else 0

func get_map_data() -> HexMapData:
	return current_map_data

func get_tile_objects() -> Array[Dictionary]:
	return current_tile_objects.duplicate(true)

func get_actor_placements() -> Array[Dictionary]:
	return current_actors.duplicate(true)

func get_creature_placements() -> Array[Dictionary]:
	return current_creatures.duplicate(true)

func _copy_dictionary_array(values: Variant) -> Array[Dictionary]:
	var copied: Array[Dictionary] = []
	if values is Array:
		for value in values:
			if value is Dictionary:
				copied.append(value.duplicate(true))
	return copied

func _on_campaign_journal_event(event: Dictionary) -> void:
	if String(event.get("event_type", "")) == "quest_completed":
		var quest_id := String(event.get("quest_id", ""))
		if quest_id == "deepholds_infestation":
			complete_quest(quest_id)

func _render_current_floor() -> Dictionary:
	var result: Dictionary = FLOOR_BUILDER.build_floor_map(
		location_definition,
		location_state.current_floor,
		location_state
	)
	if not bool(result.get("ok", false)):
		return result
	current_map_data = result.get("map_data") as HexMapData
	current_tile_objects = _copy_dictionary_array(result.get("tile_objects", []))
	current_actors = _copy_dictionary_array(result.get("actors", []))
	current_creatures = _copy_dictionary_array(result.get("creatures", []))
	if current_map_data == null:
		return {"ok": false, "reason": "floor_builder_returned_no_map"}
	if terrain_renderer == null:
		terrain_renderer = TERRAIN_RENDERER.new() as HexTerrainRenderer
		terrain_renderer.name = "HexTerrainRenderer"
		add_child(terrain_renderer)
	terrain_renderer.rebuild(current_map_data, hex_radius)
	_rebuild_wall_geometry(result.get("wall_hexes", []))
	_rebuild_tile_object_visuals()
	return {"ok": true, "floor": location_state.current_floor, "cell_count": current_map_data.cells.size()}

func _rebuild_wall_geometry(wall_hexes: Array) -> void:
	if is_instance_valid(wall_geometry):
		wall_geometry.queue_free()
	wall_geometry = Node3D.new()
	wall_geometry.name = "StoneWallGeometry"
	add_child(wall_geometry)
	var wall_material := StandardMaterial3D.new()
	wall_material.albedo_color = Color(0.24, 0.25, 0.27)
	wall_material.roughness = 0.98
	wall_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var wall_mesh := CylinderMesh.new()
	wall_mesh.top_radius = hex_radius * 0.98
	wall_mesh.bottom_radius = hex_radius * 0.98
	wall_mesh.height = wall_height
	wall_mesh.radial_segments = 6
	for hex_variant in wall_hexes:
		var hex: Vector2i = hex_variant
		var wall := MeshInstance3D.new()
		wall.name = "StoneWall_%d_%d" % [hex.x, hex.y]
		wall.mesh = wall_mesh
		wall.material_override = wall_material
		wall.position = HexGrid.axial_to_world(hex, hex_radius, wall_height * 0.5)
		wall_geometry.add_child(wall)

func _rebuild_tile_object_visuals() -> void:
	if is_instance_valid(tile_object_visuals):
		tile_object_visuals.queue_free()
	tile_object_visuals = Node3D.new()
	tile_object_visuals.name = "TileObjectVisuals"
	add_child(tile_object_visuals)
	var stone_material := StandardMaterial3D.new()
	stone_material.albedo_color = Color(0.32, 0.33, 0.35)
	stone_material.roughness = 0.95
	var wood_material := StandardMaterial3D.new()
	wood_material.albedo_color = Color(0.25, 0.16, 0.10)
	wood_material.roughness = 0.92
	for tile_object in current_tile_objects:
		var position_data: Dictionary = tile_object.get("position", {})
		var axial := Vector2i(int(position_data.get("q", 0)), int(position_data.get("r", 0)))
		var marker := Node3D.new()
		marker.name = String(tile_object.get("id", "TileObject"))
		marker.position = HexGrid.axial_to_world(axial, hex_radius, 0.04)
		tile_object_visuals.add_child(marker)
		match String(tile_object.get("type", "")):
			"stair_up", "stair_down":
				_add_stair_marker(marker, wood_material, String(tile_object.get("type", "")) == "stair_up")
			"door_open":
				_add_door_frame(marker, stone_material)

func _add_stair_marker(parent: Node3D, material: Material, ascending: bool) -> void:
	for index in range(3):
		var step_mesh := BoxMesh.new()
		step_mesh.size = Vector3(hex_radius * 1.25, 0.16, hex_radius * 0.46)
		var step := MeshInstance3D.new()
		step.name = "StairStep_%d" % index
		step.mesh = step_mesh
		step.material_override = material
		var direction := 1.0 if ascending else -1.0
		step.position = Vector3(0.0, 0.08 + float(index) * 0.16, direction * (float(index) - 1.0) * hex_radius * 0.32)
		parent.add_child(step)

func _add_door_frame(parent: Node3D, material: Material) -> void:
	for side in [-1.0, 1.0]:
		var pillar_mesh := BoxMesh.new()
		pillar_mesh.size = Vector3(0.22, 1.8, 0.22)
		var pillar := MeshInstance3D.new()
		pillar.mesh = pillar_mesh
		pillar.material_override = material
		pillar.position = Vector3(side * hex_radius * 0.48, 0.9, 0.0)
		parent.add_child(pillar)
	var lintel_mesh := BoxMesh.new()
	lintel_mesh.size = Vector3(hex_radius * 1.1, 0.22, 0.24)
	var lintel := MeshInstance3D.new()
	lintel.mesh = lintel_mesh
	lintel.material_override = material
	lintel.position = Vector3(0.0, 1.8, 0.0)
	parent.add_child(lintel)
