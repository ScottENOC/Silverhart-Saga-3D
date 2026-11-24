class_name CampPartyActivityDirector
extends Node
## Drives visible companion movement for the in-world camp.
## Character movement remains authoritative in WorldSimulation; HollowTankard's
## existing character_moved signal supplies the normal locomotion animation.

const STEP_INTERVAL := 0.62
const MAX_STATION_RADIUS := 5

var simulation: WorldSimulation
var _camp_hex: Vector2i = Vector2i.ZERO
var _active_character_ids: Array[String] = []
var _destination_by_character: Dictionary = {}
var _step_accumulator: float = 0.0
var _next_character_index: int = 0
var _running: bool = false


func configure(world_simulation: WorldSimulation) -> void:
	simulation = world_simulation


func begin_camp(site: Dictionary) -> void:
	stop()
	if simulation == null:
		return
	var hex_value: Variant = site.get("hex", Vector2i.ZERO)
	if not hex_value is Vector2i:
		return
	_camp_hex = hex_value
	_build_companion_destinations()
	_running = not _active_character_ids.is_empty()


func stop() -> void:
	_running = false
	_active_character_ids.clear()
	_destination_by_character.clear()
	_step_accumulator = 0.0
	_next_character_index = 0


func is_running() -> bool:
	return _running


func process_activity_movement(delta: float) -> void:
	if not _running or simulation == null or delta <= 0.0:
		return
	if simulation.is_in_combat or simulation.has_pending_reaction() or simulation.clock.paused:
		return
	_step_accumulator += delta
	if _step_accumulator < STEP_INTERVAL:
		return
	_step_accumulator = 0.0
	if _active_character_ids.is_empty():
		stop()
		return
	if _next_character_index >= _active_character_ids.size():
		_next_character_index = 0
	var character_id := _active_character_ids[_next_character_index]
	_next_character_index += 1
	var state := simulation.get_character(character_id)
	if state == null or not state.alive or not state.can_act():
		_active_character_ids.erase(character_id)
		_destination_by_character.erase(character_id)
		return
	var destination: Vector2i = _destination_by_character.get(character_id, state.axial)
	if state.axial == destination:
		_active_character_ids.erase(character_id)
		_destination_by_character.erase(character_id)
		return
	var path := simulation.find_path(character_id, destination)
	if path.size() < 2:
		# A temporary obstruction may clear as another companion moves.
		return
	simulation.try_move_character(character_id, path[1])


func _build_companion_destinations() -> void:
	var reserved: Dictionary = {}
	var camp := simulation.camp_simulation
	for character_id_value in camp.party_ids:
		var character_id := String(character_id_value)
		# The player remains under direct control. Companions gather at camp.
		if character_id == simulation.player_character_id:
			continue
		var state := simulation.get_character(character_id)
		if state == null or not state.alive:
			continue
		var assignment: Dictionary = camp.assignments.get(character_id, {})
		var activity := String(assignment.get("activity", "socialise"))
		var target := _choose_station(activity, reserved)
		if target == state.axial:
			continue
		reserved[target] = true
		_active_character_ids.append(character_id)
		_destination_by_character[character_id] = target


func _choose_station(activity: String, reserved: Dictionary) -> Vector2i:
	var candidates: Array[Vector2i] = []
	for cell_value in simulation.map_data.cells:
		if not cell_value is Vector2i:
			continue
		var candidate: Vector2i = cell_value
		var distance := HexGrid.distance(_camp_hex, candidate)
		if distance < 1 or distance > MAX_STATION_RADIUS:
			continue
		if not simulation.map_data.is_walkable(candidate) or reserved.has(candidate):
			continue
		if simulation.is_hex_occupied(candidate):
			continue
		var terrain := simulation.map_data.terrain_id_at(candidate).to_lower()
		if terrain == "water" and activity != "fetch_water":
			continue
		candidates.append(candidate)
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da := HexGrid.distance(_camp_hex, a)
		var db := HexGrid.distance(_camp_hex, b)
		if da != db:
			return da < db
		if a.x != b.x:
			return a.x < b.x
		return a.y < b.y
	)
	if candidates.is_empty():
		return _camp_hex
	if activity == "gather_wood":
		for candidate in candidates:
			if simulation.map_data.terrain_id_at(candidate).to_lower() == "forest":
				return candidate
	elif activity == "fetch_water":
		for candidate in candidates:
			if simulation.map_data.terrain_id_at(candidate).to_lower() == "water":
				return candidate
	return candidates[0]
