class_name Campaign2RegionalLocationManager
extends Node
## Streams source-authored multi-storey locations around the regional player.
## The active floor is still part of the shared WorldSimulation map; this class
## only manages when a location runtime is presented and which one owns the
## externally controlled player actor.

const LOCATION_REGISTRY_SCRIPT = preload("res://scripts/world/campaign2_multistory_location_registry.gd")
const LOCATION_LOADER_SCRIPT = preload("res://scripts/world/campaign2_location_loader.gd")
const HEX_RADIUS: float = HexGrid.DEFAULT_RADIUS_M
const LOAD_RADIUS_HEXES: int = 24
const UNLOAD_RADIUS_HEXES: int = 40

signal floor_changed(location_id: String, previous_floor: int, current_floor: int, stair_position: Vector2i)

var simulation: WorldSimulation
var player_actor: Node3D
var player_character_id: String = "player"
var elevation_for_hex: Callable
var location_registry: Campaign2MultiStoryLocationRegistry
var location_runtimes: Dictionary = {}
var active_runtime: Campaign2MultiStoryLocationRuntime

func configure(
	campaign_simulation: WorldSimulation,
	shared_player_actor: Node3D,
	character_id: String,
	elevation_query: Callable
) -> bool:
	if campaign_simulation == null or shared_player_actor == null or character_id.strip_edges().is_empty():
		return false
	simulation = campaign_simulation
	player_actor = shared_player_actor
	player_character_id = character_id
	elevation_for_hex = elevation_query
	location_registry = LOCATION_REGISTRY_SCRIPT.new() as Campaign2MultiStoryLocationRegistry
	return location_registry != null and location_registry.validation_errors.is_empty()

## Load nearby sites before the player reaches their entrance, and retire distant
## surface-level sites. A runtime containing the player on an upper/lower floor
## remains loaded until the player returns to its surface.
func update_for_player_hex(player_hex: Vector2i) -> void:
	if simulation == null or location_registry == null:
		return
	for location_id in location_registry.location_ids():
		var definition := location_registry.get_definition(location_id)
		var transitions: Variant = definition.get("transitions", [])
		# One-floor rooms without stairs use the ordinary building/door system;
		# they are not treated as multi-storey traversal sites here.
		if not transitions is Array or transitions.is_empty():
			continue
		var anchor_data: Dictionary = definition.get("anchor", {})
		var anchor := Vector2i(int(anchor_data.get("q", 0)), int(anchor_data.get("r", 0)))
		var distance := HexGrid.distance(player_hex, anchor)
		if distance <= LOAD_RADIUS_HEXES:
			_load_location(location_id)
		elif distance > UNLOAD_RADIUS_HEXES and location_runtimes.has(location_id):
			var runtime := location_runtimes[location_id] as Campaign2MultiStoryLocationRuntime
			if runtime != null and runtime.get_current_floor() == 0:
				_unload_location(location_id)

## Use the nearest authored stair within one hex. Once the player has entered a
## location, keep using that runtime until they return to its surface floor.
func interact_with_nearby_stair(character_id: String) -> Dictionary:
	if simulation == null or character_id != player_character_id:
		return {"ok": false, "reason": "runtime_not_ready"}
	var character := simulation.get_character(character_id)
	if character == null:
		return {"ok": false, "reason": "unknown_character"}
	update_for_player_hex(character.axial)

	var candidate: Campaign2MultiStoryLocationRuntime
	if active_runtime != null and active_runtime.get_current_floor() != 0:
		candidate = active_runtime
	else:
		candidate = _find_nearest_runtime(character.axial)
	if candidate == null:
		return {"ok": false, "reason": "no_stair_nearby"}

	var previous_runtime := active_runtime
	if previous_runtime != candidate and previous_runtime != null:
		previous_runtime.unregister_character_actor(character_id)
	active_runtime = candidate
	var result: Dictionary = candidate.interact_with_stair(character_id)
	if not bool(result.get("ok", false)):
		active_runtime = previous_runtime
		return result
	candidate.register_character_actor(character_id, player_actor)
	result["location_id"] = String(candidate.definition.get("id", ""))
	return result

func get_active_runtime() -> Campaign2MultiStoryLocationRuntime:
	return active_runtime

func get_current_floor() -> int:
	return active_runtime.get_current_floor() if active_runtime != null else 0

func get_loaded_location_ids() -> Array[String]:
	var result: Array[String] = []
	for location_id in location_runtimes:
		result.append(String(location_id))
	result.sort()
	return result

func _load_location(location_id: String) -> Campaign2MultiStoryLocationRuntime:
	if location_runtimes.has(location_id):
		return location_runtimes[location_id] as Campaign2MultiStoryLocationRuntime
	if get_parent() == null:
		return null
	var load_result: Dictionary = LOCATION_LOADER_SCRIPT.load_multistory_location(get_parent(), location_id, simulation)
	if not bool(load_result.get("ok", false)):
		push_warning("Could not load regional location %s: %s" % [location_id, load_result])
		return null
	var runtime := load_result.get("runtime") as Campaign2MultiStoryLocationRuntime
	if runtime == null:
		return null
	var anchor_data: Dictionary = runtime.definition.get("anchor", {})
	var anchor := Vector2i(int(anchor_data.get("q", 0)), int(anchor_data.get("r", 0)))
	var elevation := float(elevation_for_hex.call(anchor)) if elevation_for_hex.is_valid() else 0.0
	runtime.global_position = HexGrid.axial_to_world(anchor, HEX_RADIUS, elevation)
	runtime.floor_changed.connect(_on_runtime_floor_changed)
	location_runtimes[location_id] = runtime
	if runtime.get_current_floor() != 0:
		if active_runtime != null and active_runtime != runtime:
			push_error("More than one saved regional location is active above/below the surface.")
		else:
			active_runtime = runtime
			runtime.register_character_actor(player_character_id, player_actor)
	return runtime

func _unload_location(location_id: String) -> void:
	var runtime := location_runtimes.get(location_id) as Campaign2MultiStoryLocationRuntime
	if runtime == null:
		location_runtimes.erase(location_id)
		return
	if active_runtime == runtime:
		runtime.unregister_character_actor(player_character_id)
		active_runtime = null
	location_runtimes.erase(location_id)
	runtime.queue_free()

func _find_nearest_runtime(player_hex: Vector2i) -> Campaign2MultiStoryLocationRuntime:
	var nearest: Campaign2MultiStoryLocationRuntime
	var nearest_distance := 2147483647
	for runtime_variant in location_runtimes.values():
		var runtime := runtime_variant as Campaign2MultiStoryLocationRuntime
		if runtime == null:
			continue
		var current_floor := runtime.get_current_floor()
		for transition_variant in runtime.definition.get("transitions", []):
			if not transition_variant is Dictionary:
				continue
			var transition: Dictionary = transition_variant
			if int(transition.get("from_floor", 999999)) != current_floor:
				continue
			var position: Dictionary = transition.get("position", {})
			var stair := Vector2i(int(position.get("q", 0)), int(position.get("r", 0)))
			var distance := HexGrid.distance(player_hex, stair)
			if distance <= 1 and distance < nearest_distance:
				nearest = runtime
				nearest_distance = distance
	return nearest

func _on_runtime_floor_changed(
	location_id: String,
	previous_floor: int,
	current_floor: int,
	stair_position: Vector2i
) -> void:
	floor_changed.emit(location_id, previous_floor, current_floor, stair_position)
