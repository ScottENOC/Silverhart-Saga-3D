class_name Campaign2MultiStoryLocationRuntime
extends Node3D
## Renders and controls one source-authored multi-story Campaign 2 location.
## The host places this node at the location's world anchor; floor geometry is
## built relative to that anchor while simulation cells retain global axial IDs.

const FLOOR_MAP_BUILDER = preload("res://scripts/world/campaign2_multistory_floor_map_builder.gd")
const TUNNEL_NETWORK = preload("res://scripts/world/campaign2_tunnel_network.gd")
const CANOPY_PRESENTATION = preload("res://scripts/world/world_canopy_settlement_presentation.gd")
const CHARACTER_ACTOR_FACTORY = preload("res://scripts/presentation/campaign_character_actor_factory.gd")
const CHARACTER_REGISTRY_SCRIPT = preload("res://scripts/world/campaign2_character_definition_registry.gd")
const HEX_RADIUS: float = HexGrid.DEFAULT_RADIUS_M
const FLOOR_HEIGHT: float = 3.2

signal floor_changed(location_id: String, previous_floor: int, current_floor: int, stair_position: Vector2i)

var definition: Dictionary = {}
var character_registry: Campaign2CharacterDefinitionRegistry
var simulation: WorldSimulation
var location_state: Campaign2MultiStoryLocationState
var floor_groups: Dictionary = {}
var floor_hexes: Dictionary = {}
var floor_maps: Dictionary = {}
var character_actor_nodes: Dictionary = {}
var _active_floor_cells: Array[Vector2i] = []
var _previous_map_cells: Dictionary = {}
var _configured_location := false
var _configured_campaign := false

func configure_location(location_definition: Dictionary) -> void:
	definition = location_definition.duplicate(true)
	_configured_location = not definition.is_empty()

func configure_campaign(campaign_simulation: WorldSimulation, _profile: Dictionary, save_data: Dictionary) -> void:
	if campaign_simulation == null:
		push_error("Multi-story location runtime requires the shared campaign simulation.")
		return
	simulation = campaign_simulation
	var saved_locations: Variant = save_data.get("multistory_locations", {})
	if saved_locations is Dictionary and not saved_locations.is_empty():
		simulation.restore_multistory_location_states(saved_locations)
	location_state = simulation.register_multistory_location_state(definition)
	_configured_campaign = location_state != null

func _ready() -> void:
	if not _configured_location or not _configured_campaign:
		push_error("Multi-story location runtime must be configured before entering the scene tree.")
		return
	character_registry = CHARACTER_REGISTRY_SCRIPT.new() as Campaign2CharacterDefinitionRegistry
	_build_floor_presentations()
	location_state.floor_changed.connect(_on_state_floor_changed)
	simulation.multistory_transition_unlocked.connect(_on_transition_unlocked)
	_activate_floor(location_state.current_floor)

func _exit_tree() -> void:
	_restore_active_map_cells()
	if simulation != null and simulation.multistory_transition_unlocked.is_connected(_on_transition_unlocked):
		simulation.multistory_transition_unlocked.disconnect(_on_transition_unlocked)
	if location_state != null and location_state.floor_changed.is_connected(_on_state_floor_changed):
		location_state.floor_changed.disconnect(_on_state_floor_changed)

func get_current_floor() -> int:
	return location_state.current_floor if location_state != null else 0

func get_floor_tile_count(floor_number: int) -> int:
	var cells: Array = floor_hexes.get(floor_number, [])
	return cells.size()

func is_floor_visible(floor_number: int) -> bool:
	var group := floor_groups.get(floor_number) as Node3D
	return group != null and group.visible

func has_floor_actor(floor_number: int, character_id: String) -> bool:
	var group := floor_groups.get(floor_number) as Node3D
	if group == null:
		return false
	for child in group.get_children():
		if child is Node3D and String(child.get_meta("campaign2_npc_id", "")) == character_id:
			return true
	return false

## Register an externally-owned player/companion actor so vertical floor changes
## update its world height while its axial position remains on the shared stair.
func register_character_actor(character_id: String, actor: Node3D) -> bool:
	if character_id.strip_edges().is_empty() or actor == null or not is_instance_valid(actor):
		return false
	character_actor_nodes[character_id] = actor
	_set_actor_location(character_id, actor, get_current_floor())
	return true

func unregister_character_actor(character_id: String) -> void:
	character_actor_nodes.erase(character_id)

func _set_actor_location(character_id: String, actor: Node3D, floor_number: int) -> void:
	if actor == null or not is_instance_valid(actor) or simulation == null:
		return
	var character := simulation.get_character(character_id)
	if character == null:
		return
	var anchor_data: Dictionary = definition.get("anchor", {})
	var anchor := Vector2i(int(anchor_data.get("q", 0)), int(anchor_data.get("r", 0)))
	var local_position := HexGrid.axial_to_world(character.axial - anchor, HEX_RADIUS, float(floor_number) * FLOOR_HEIGHT + 0.1)
	actor.global_position = to_global(local_position)

func _sync_registered_character_actor_floors(floor_number: int) -> void:
	for character_id_variant in character_actor_nodes.keys():
		var character_id := String(character_id_variant)
		var actor := character_actor_nodes[character_id] as Node3D
		if actor == null or not is_instance_valid(actor):
			character_actor_nodes.erase(character_id)
			continue
		_set_actor_location(character_id, actor, floor_number)

func has_floor_object(floor_number: int, object_id: String) -> bool:
	var group := floor_groups.get(floor_number) as Node3D
	if group == null:
		return false
	for child in group.get_children():
		if child.name == object_id:
			return true
	return false

## Interact with the nearest stair on the active floor. The character may stand
## on the stair or one hex away; movement to the stair uses normal occupancy rules.
func interact_with_stair(character_id: String) -> Dictionary:
	if simulation == null or location_state == null:
		return {"ok": false, "reason": "runtime_not_ready"}
	var character := simulation.get_character(character_id)
	if character == null:
		return {"ok": false, "reason": "unknown_character"}
	var candidate: Dictionary = {}
	var nearest_distance := 2147483647
	for transition in location_state._transitions:
		if int(transition.get("from_floor", 999999)) != location_state.current_floor:
			continue
		var position: Dictionary = transition.get("position", {})
		var stair := Vector2i(int(position.get("q", 0)), int(position.get("r", 0)))
		var distance := HexGrid.distance(character.axial, stair)
		if distance <= 1 and distance < nearest_distance:
			candidate = transition
			nearest_distance = distance
	if candidate.is_empty():
		return {"ok": false, "reason": "no_stair_nearby"}
	var stair_data: Dictionary = candidate.get("position", {})
	var stair_hex := Vector2i(int(stair_data.get("q", 0)), int(stair_data.get("r", 0)))
	if character.axial != stair_hex and not simulation.relocate_character(character_id, stair_hex):
		return {"ok": false, "reason": "stair_occupied_or_unwalkable"}
	return try_transition_at_stair(int(candidate.get("to_floor", 999999)), stair_hex)

## Reveal a source-authored concealed door after the caller has completed its search/check.
## The character must be beside the door; discovery is stored in the location state.
func reveal_secret_door(character_id: String, secret_id: String) -> Dictionary:
	if simulation == null or location_state == null:
		return {"ok": false, "reason": "runtime_not_ready"}
	var character := simulation.get_character(character_id)
	if character == null:
		return {"ok": false, "reason": "unknown_character"}
	var secret_object: Dictionary = {}
	var secret_floor := 999999
	for floor_variant in definition.get("floors", []):
		if not floor_variant is Dictionary:
			continue
		var floor_definition: Dictionary = floor_variant
		for object_variant in floor_definition.get("tile_objects", []):
			if not object_variant is Dictionary:
				continue
			var object_data: Dictionary = object_variant
			if String(object_data.get("id", "")) == secret_id and String(object_data.get("type", "")) in ["secret_door", "secret_passage"]:
				secret_object = object_data
				secret_floor = int(floor_definition.get("floor", 999999))
				break
		if not secret_object.is_empty():
			break
	if secret_object.is_empty() or secret_floor != location_state.current_floor:
		return {"ok": false, "reason": "secret_not_on_active_floor"}
	var position_data: Dictionary = secret_object.get("position", {})
	var secret_hex := Vector2i(int(position_data.get("q", 0)), int(position_data.get("r", 0)))
	if HexGrid.distance(character.axial, secret_hex) > 1:
		return {"ok": false, "reason": "secret_door_not_nearby"}
	var discovery: Dictionary = location_state.discover_secret(secret_id)
	if not bool(discovery.get("ok", false)):
		return discovery
	if not bool(discovery.get("already_discovered", false)):
		_rebuild_floor_presentation(secret_floor)
		_activate_floor(location_state.current_floor)
	return {"ok": true, "already_discovered": bool(discovery.get("already_discovered", false)), "secret_id": secret_id}


## Return the two other fast-travel destinations when the character is standing
## on this location's authored -9 tunnel junction.
func get_tunnel_junction_node(character_id: String) -> String:
	return _tunnel_node_for_character(character_id)

func get_tunnel_junction_destinations(character_id: String) -> Array[Dictionary]:
	return TUNNEL_NETWORK.destinations_from(_tunnel_node_for_character(character_id))

## A discovered surface passage enters its matching tunnel node.
func get_tunnel_entry_node(character_id: String) -> String:
	return _secret_passage_node_for_character(character_id)

func _secret_passage_node_for_character(character_id: String) -> String:
	if simulation == null or location_state == null or location_state.current_floor != 0:
		return ""
	var character := simulation.get_character(character_id)
	if character == null:
		return ""
	for floor_variant in definition.get("floors", []):
		if not floor_variant is Dictionary or int(floor_variant.get("floor", 999999)) != 0:
			continue
		for object_variant in floor_variant.get("tile_objects", []):
			if not object_variant is Dictionary:
				continue
			var object_data: Dictionary = object_variant
			if String(object_data.get("type", "")) != "secret_passage" or not location_state.is_secret_discovered(String(object_data.get("id", ""))):
				continue
			var position: Dictionary = object_data.get("position", {})
			var entrance_hex := Vector2i(int(position.get("q", 0)), int(position.get("r", 0)))
			if HexGrid.distance(character.axial, entrance_hex) <= 1:
				return String(object_data.get("node_id", ""))
	return ""

func has_revealed_tunnel_passage(node_id: String) -> bool:
	return _tunnel_passage_position(node_id) != Vector2i(2147483647, 2147483647)

func get_tunnel_passage_position(node_id: String) -> Vector2i:
	return _tunnel_passage_position(node_id)

func _tunnel_passage_position(node_id: String) -> Vector2i:
	if location_state == null or location_state.current_floor != 0:
		return Vector2i(2147483647, 2147483647)
	for floor_variant in definition.get("floors", []):
		if not floor_variant is Dictionary or int(floor_variant.get("floor", 999999)) != 0:
			continue
		for object_variant in floor_variant.get("tile_objects", []):
			if not object_variant is Dictionary:
				continue
			var object_data: Dictionary = object_variant
			if String(object_data.get("type", "")) != "secret_passage" or String(object_data.get("node_id", "")) != node_id:
				continue
			if not location_state.is_secret_discovered(String(object_data.get("id", ""))):
				continue
			var position: Dictionary = object_data.get("position", {})
			return Vector2i(int(position.get("q", 0)), int(position.get("r", 0)))
	return Vector2i(2147483647, 2147483647)

func set_location_active(active: bool) -> void:
	if active:
		_activate_floor(get_current_floor())
		return
	for floor_key in floor_groups:
		var group := floor_groups[floor_key] as Node3D
		if group != null:
			group.visible = false
	_restore_active_map_cells()

## Enter from a discovered surface passage into the matching tunnel stub.
func enter_tunnel_node(character_id: String, target_runtime: Campaign2MultiStoryLocationRuntime, node_id: String) -> Dictionary:
	if simulation == null or target_runtime == null or target_runtime.simulation != simulation:
		return {"ok": false, "reason": "incompatible_tunnel_runtime"}
	if _secret_passage_node_for_character(character_id) != node_id:
		return {"ok": false, "reason": "not_at_revealed_tunnel_passage"}
	if not target_runtime.has_tunnel_node(node_id):
		return {"ok": false, "reason": "unknown_tunnel_destination"}
	return _transfer_to_location(character_id, target_runtime, TUNNEL_NETWORK.FLOOR_NUMBER, TUNNEL_NETWORK.get_node(node_id).get("position", Vector2i.ZERO), node_id)

## Return from a junction through its matching discovered surface entrance.
func return_to_surface_passage(character_id: String, target_runtime: Campaign2MultiStoryLocationRuntime, node_id: String) -> Dictionary:
	if simulation == null or target_runtime == null or target_runtime.simulation != simulation:
		return {"ok": false, "reason": "incompatible_tunnel_runtime"}
	if _tunnel_node_for_character(character_id) != node_id:
		return {"ok": false, "reason": "not_at_tunnel_junction"}
	if not target_runtime.has_revealed_tunnel_passage(node_id):
		return {"ok": false, "reason": "surface_passage_not_discovered"}
	return _transfer_to_location(character_id, target_runtime, 0, target_runtime.get_tunnel_passage_position(node_id), node_id)

func _transfer_to_location(character_id: String, target_runtime: Campaign2MultiStoryLocationRuntime, target_floor: int, destination_hex: Vector2i, node_id: String) -> Dictionary:
	var character := simulation.get_character(character_id)
	if character == null:
		return {"ok": false, "reason": "unknown_character"}
	var actor := character_actor_nodes.get(character_id) as Node3D
	set_location_active(false)
	target_runtime.set_location_active(false)
	var floor_result: Dictionary = target_runtime.location_state.set_current_floor_for_network_travel(target_floor)
	if not bool(floor_result.get("ok", false)):
		set_location_active(true)
		return floor_result
	target_runtime.set_location_active(true)
	if not simulation.relocate_character(character_id, destination_hex):
		target_runtime.set_location_active(false)
		set_location_active(true)
		return {"ok": false, "reason": "destination_unwalkable_or_occupied"}
	unregister_character_actor(character_id)
	if actor != null:
		target_runtime.register_character_actor(character_id, actor)
	return {"ok": true, "to_node": node_id, "position": destination_hex, "location_id": String(target_runtime.definition.get("id", ""))}

## Reveal a concealed Guild tunnel entrance after the caller's search/check.
func reveal_secret_passage(character_id: String, secret_id: String) -> Dictionary:
	return reveal_secret_door(character_id, secret_id)


func has_tunnel_node(node_id: String) -> bool:
	var location_node := TUNNEL_NETWORK.get_node(node_id)
	if location_node.is_empty() or String(location_node.get("location_id", "")) != String(definition.get("id", "")):
		return false
	var expected_object_id := String(location_node.get("object_id", ""))
	for floor_variant in definition.get("floors", []):
		if not floor_variant is Dictionary or int(floor_variant.get("floor", 999999)) != TUNNEL_NETWORK.FLOOR_NUMBER:
			continue
		for object_variant in floor_variant.get("tile_objects", []):
			if object_variant is Dictionary and String(object_variant.get("id", "")) == expected_object_id and String(object_variant.get("type", "")) == "tunnel_junction":
				return true
	return false

## Transfer a party character between two already-loaded tunnel stub runtimes.
## The target runtime must share this campaign simulation.
func travel_to_tunnel_node(character_id: String, target_runtime: Campaign2MultiStoryLocationRuntime, target_node_id: String) -> Dictionary:
	if simulation == null or target_runtime == null or target_runtime.simulation != simulation:
		return {"ok": false, "reason": "incompatible_tunnel_runtime"}
	var source_node_id := _tunnel_node_for_character(character_id)
	if source_node_id.is_empty():
		return {"ok": false, "reason": "not_at_tunnel_junction"}
	var destination := TUNNEL_NETWORK.get_node(target_node_id)
	if destination.is_empty() or not target_runtime.has_tunnel_node(target_node_id):
		return {"ok": false, "reason": "unknown_tunnel_destination"}
	if target_node_id == source_node_id:
		return {"ok": false, "reason": "already_at_destination"}
	var character := simulation.get_character(character_id)
	if character == null:
		return {"ok": false, "reason": "unknown_character"}
	var destination_hex: Vector2i = destination.get("position", Vector2i.ZERO)
	var result := _transfer_to_location(character_id, target_runtime, TUNNEL_NETWORK.FLOOR_NUMBER, destination_hex, target_node_id)
	if bool(result.get("ok", false)):
		result["from_node"] = source_node_id
	return result

func _tunnel_node_for_character(character_id: String) -> String:
	if simulation == null or location_state == null:
		return ""
	var character := simulation.get_character(character_id)
	if character == null:
		return ""
	var active_floor := location_state.current_floor
	if active_floor != TUNNEL_NETWORK.FLOOR_NUMBER:
		return ""
	for floor_variant in definition.get("floors", []):
		if not floor_variant is Dictionary or int(floor_variant.get("floor", 999999)) != active_floor:
			continue
		for object_variant in floor_variant.get("tile_objects", []):
			if not object_variant is Dictionary:
				continue
			var object_data: Dictionary = object_variant
			var object_type := String(object_data.get("type", ""))
			if object_type != "tunnel_junction":
				continue
			var position: Dictionary = object_data.get("position", {})
			var object_hex := Vector2i(int(position.get("q", 0)), int(position.get("r", 0)))
			if character.axial == object_hex:
				return String(object_data.get("node_id", ""))
	return ""


func try_transition_at_stair(to_floor: int, stair_position: Vector2i) -> Dictionary:
	if location_state == null:
		return {"ok": false, "reason": "runtime_not_ready"}
	return location_state.try_transition(to_floor, stair_position)

func _on_state_floor_changed(previous_floor: int, current_floor: int, stair_position: Vector2i) -> void:
	_activate_floor(current_floor)
	_sync_registered_character_actor_floors(current_floor)
	floor_changed.emit(String(definition.get("id", "")), previous_floor, current_floor, stair_position)

func _on_transition_unlocked(location_id: String, _quest_id: String, transitions: Array[Dictionary]) -> void:
	if location_id != String(definition.get("id", "")):
		return
	var rebuild_floors: Dictionary = {}
	for transition in transitions:
		rebuild_floors[int(transition.get("from_floor", 999999))] = true
	for floor_number in rebuild_floors:
		_rebuild_floor_presentation(int(floor_number))
	_activate_floor(location_state.current_floor)

func _rebuild_floor_presentation(floor_number: int) -> void:
	_restore_active_map_cells()
	var old_group := floor_groups.get(floor_number) as Node3D
	if old_group != null:
		old_group.free()
	floor_groups.erase(floor_number)
	floor_hexes.erase(floor_number)
	floor_maps.erase(floor_number)
	var floor_definition: Dictionary = {}
	for floor_variant in definition.get("floors", []):
		if floor_variant is Dictionary and int(floor_variant.get("floor", 999999)) == floor_number:
			floor_definition = floor_variant
			break
	if floor_definition.is_empty():
		return
	var anchor_data: Dictionary = definition.get("anchor", {})
	var anchor := Vector2i(int(anchor_data.get("q", 0)), int(anchor_data.get("r", 0)))
	_build_floor_presentation(floor_definition, anchor)

func _build_floor_presentations() -> void:
	var anchor_data: Dictionary = definition.get("anchor", {})
	var anchor := Vector2i(int(anchor_data.get("q", 0)), int(anchor_data.get("r", 0)))
	CANOPY_PRESENTATION.present_trunk(self, definition, anchor, HEX_RADIUS)
	for floor_variant in definition.get("floors", []):
		if floor_variant is Dictionary:
			_build_floor_presentation(floor_variant, anchor)

func _build_floor_presentation(floor_definition: Dictionary, anchor: Vector2i) -> void:
	var floor_number := int(floor_definition.get("floor", 0))
	var build_result: Dictionary = FLOOR_MAP_BUILDER.build_floor_map(definition, floor_number, location_state)
	if not bool(build_result.get("ok", false)):
		push_error("Could not build %s floor %d: %s" % [String(definition.get("id", "")), floor_number, build_result])
		return
	var group := Node3D.new()
	group.name = "Floor_%d" % floor_number
	group.position.y = float(floor_number) * FLOOR_HEIGHT
	group.visible = false
	add_child(group)
	floor_groups[floor_number] = group
	var logical_map := build_result.get("map_data") as HexMapData
	floor_maps[floor_number] = logical_map
	var walkable_hexes: Array[Vector2i] = build_result.get("walkable_hexes", [])
	var wall_hexes: Array[Vector2i] = build_result.get("wall_hexes", [])
	floor_hexes[floor_number] = walkable_hexes
	for hex in walkable_hexes:
		var tile := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = HEX_RADIUS * 0.96
		mesh.bottom_radius = HEX_RADIUS * 0.96
		mesh.height = 0.18
		mesh.radial_segments = 6
		tile.mesh = mesh
		tile.material_override = _floor_material(floor_number)
		tile.position = HexGrid.axial_to_world(hex - anchor, HEX_RADIUS)
		tile.rotation.y = PI / 6.0
		group.add_child(tile)
	for hex in wall_hexes:
		var wall := MeshInstance3D.new()
		var wall_mesh := CylinderMesh.new()
		wall_mesh.top_radius = HEX_RADIUS * 0.96
		wall_mesh.bottom_radius = HEX_RADIUS * 0.96
		wall_mesh.height = 2.4
		wall_mesh.radial_segments = 6
		wall.mesh = wall_mesh
		wall.material_override = _wall_material()
		wall.position = HexGrid.axial_to_world(hex - anchor, HEX_RADIUS, 1.15)
		wall.rotation.y = PI / 6.0
		group.add_child(wall)
	_present_floor_objects(group, build_result.get("tile_objects", []), anchor)
	CANOPY_PRESENTATION.present_floor(group, definition, floor_number, anchor, HEX_RADIUS)
	_present_floor_actors(group, build_result.get("actors", []), anchor, floor_number)

func _present_floor_actors(group: Node3D, actors: Array, anchor: Vector2i, floor_number: int) -> void:
	if character_registry == null:
		return
	for actor_variant in actors:
		if not actor_variant is Dictionary:
			continue
		var actor_data: Dictionary = actor_variant
		var character_id := String(actor_data.get("character_id", actor_data.get("id", ""))).strip_edges()
		if character_id.is_empty():
			continue
		var character_definition := character_registry.get_character(character_id)
		if character_definition.is_empty():
			push_warning("Multi-story location %s references missing character %s." % [String(definition.get("id", "")), character_id])
			continue
		var position_data: Dictionary = actor_data.get("position", {})
		var hex := Vector2i(int(position_data.get("q", 0)), int(position_data.get("r", 0)))
		var local_position := HexGrid.axial_to_world(hex - anchor, HEX_RADIUS, 0.1)
		var actor := CHARACTER_ACTOR_FACTORY.create_settlement_actor(character_definition, local_position)
		if actor == null:
			continue
		actor.set_meta("multistory_location_id", String(definition.get("id", "")))
		actor.set_meta("multistory_floor", floor_number)
		group.add_child(actor)

func _present_floor_objects(group: Node3D, tile_objects: Array, anchor: Vector2i) -> void:
	for object_variant in tile_objects:
		if not object_variant is Dictionary:
			continue
		var object_data: Dictionary = object_variant
		var position_data: Dictionary = object_data.get("position", {})
		var hex := Vector2i(int(position_data.get("q", 0)), int(position_data.get("r", 0)))
		var object_type := String(object_data.get("type", ""))
		var marker := MeshInstance3D.new()
		marker.name = String(object_data.get("id", object_type))
		var material := StandardMaterial3D.new()
		material.roughness = 0.82
		match object_type:
			"stair_up", "stair_down":
				var stair_mesh := CylinderMesh.new()
				stair_mesh.top_radius = HEX_RADIUS * 0.42
				stair_mesh.bottom_radius = HEX_RADIUS * 0.42
				stair_mesh.height = 0.28
				stair_mesh.radial_segments = 6
				marker.mesh = stair_mesh
				material.albedo_color = Color(0.55, 0.48, 0.32)
				material.metallic = 0.45
			"tunnel_entrance":
				var entrance_mesh := CylinderMesh.new()
				entrance_mesh.top_radius = HEX_RADIUS * 0.40
				entrance_mesh.bottom_radius = HEX_RADIUS * 0.40
				entrance_mesh.height = 0.24
				entrance_mesh.radial_segments = 6
				marker.mesh = entrance_mesh
				material.albedo_color = Color(0.18, 0.34, 0.29)
				material.emission_enabled = true
				material.emission = Color(0.08, 0.22, 0.15)
			"fireplace", "rune_forge":
				var forge_mesh := CylinderMesh.new()
				forge_mesh.top_radius = HEX_RADIUS * 0.38
				forge_mesh.bottom_radius = HEX_RADIUS * 0.48
				forge_mesh.height = 0.72
				forge_mesh.radial_segments = 8
				marker.mesh = forge_mesh
				material.albedo_color = Color(0.42, 0.19, 0.10) if object_type == "fireplace" else Color(0.42, 0.25, 0.16)
				material.emission_enabled = true
				material.emission = Color(0.65, 0.19, 0.04) if object_type == "fireplace" else Color(0.30, 0.12, 0.04)
			"throne", "journal":
				var object_mesh := BoxMesh.new()
				object_mesh.size = Vector3(HEX_RADIUS * 0.7, 0.9, HEX_RADIUS * 0.7)
				marker.mesh = object_mesh
				material.albedo_color = Color(0.35, 0.26, 0.17) if object_type == "throne" else Color(0.36, 0.27, 0.16)
			"ore_node":
				var ore_mesh := CylinderMesh.new()
				ore_mesh.top_radius = HEX_RADIUS * 0.12
				ore_mesh.bottom_radius = HEX_RADIUS * 0.34
				ore_mesh.height = 0.9
				ore_mesh.radial_segments = 6
				marker.mesh = ore_mesh
				var ore_type := String(object_data.get("ore_type", ""))
				if ore_type == "ore_gold":
					material.albedo_color = Color(0.78, 0.55, 0.16)
					material.metallic = 0.55
					material.roughness = 0.34
				else:
					material.albedo_color = Color(0.16, 0.48, 0.86)
					material.emission_enabled = true
					material.emission = Color(0.06, 0.19, 0.42)
					material.roughness = 0.28
			_:
				var generic_mesh := BoxMesh.new()
				generic_mesh.size = Vector3(HEX_RADIUS * 0.5, 0.4, HEX_RADIUS * 0.5)
				marker.mesh = generic_mesh
				material.albedo_color = Color(0.38, 0.36, 0.31)
		marker.material_override = material
		marker.position = HexGrid.axial_to_world(hex - anchor, HEX_RADIUS, 0.5)
		group.add_child(marker)
		if object_type in ["stair_up", "stair_down"]:
			var label := Label3D.new()
			label.text = "UP" if object_type == "stair_up" else "DOWN"
			label.position = marker.position + Vector3(0.0, 0.65, 0.0)
			label.font_size = 18
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			group.add_child(label)

func _floor_material(floor_number: int) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.roughness = 0.94
	match floor_number:
		0: material.albedo_color = Color(0.38, 0.39, 0.36)
		-1: material.albedo_color = Color(0.34, 0.35, 0.34)
		-2: material.albedo_color = Color(0.32, 0.31, 0.29)
		-3: material.albedo_color = Color(0.29, 0.29, 0.27)
		-4: material.albedo_color = Color(0.25, 0.25, 0.24)
		-5: material.albedo_color = Color(0.22, 0.23, 0.23)
		_: material.albedo_color = Color(0.31, 0.31, 0.30)
	return material

func _wall_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.19, 0.20, 0.20)
	material.roughness = 0.98
	return material

func _activate_floor(floor_number: int) -> void:
	for floor_key in floor_groups:
		var group := floor_groups[floor_key] as Node3D
		group.visible = int(floor_key) == floor_number
	_restore_active_map_cells()
	if simulation == null:
		return
	var active_map := floor_maps.get(floor_number) as HexMapData
	if active_map == null:
		return
	for hex in active_map.cells:
		if not _previous_map_cells.has(hex):
			_previous_map_cells[hex] = simulation.map_data.cells.get(hex, null)
		simulation.map_data.cells[hex] = (active_map.cells[hex] as Dictionary).duplicate(true)
		_active_floor_cells.append(hex)

func _restore_active_map_cells() -> void:
	if simulation == null:
		_active_floor_cells.clear()
		_previous_map_cells.clear()
		return
	for hex in _active_floor_cells:
		var previous: Variant = _previous_map_cells.get(hex, null)
		if previous == null:
			simulation.map_data.cells.erase(hex)
		else:
			simulation.map_data.cells[hex] = previous
	_active_floor_cells.clear()
	_previous_map_cells.clear()
