class_name CampPartyActivityDirector
extends Node

signal companion_exchange(exchange: Dictionary)

const CAMP_DIALOGUE_SERVICE := preload("res://scripts/simulation/camp_companion_dialogue_service.gd")
const CAMPAIGN_RUNTIME_STORE := preload("res://scripts/simulation/companion_campaign_runtime_store.gd")
## Drives visible companion movement for the in-world camp.
## Character movement remains authoritative in WorldSimulation; HollowTankard's
## existing character_moved signal supplies the normal locomotion animation.

const STEP_INTERVAL := 0.42
const MAX_STATION_RADIUS := 5
const INVALID_HEX := Vector2i(2147483647, 2147483647)

var simulation: WorldSimulation
var _actor_lookup: Callable
var _camp_hex: Vector2i = Vector2i.ZERO
var _active_character_ids: Array[String] = []
var _destination_by_character: Dictionary = {}
var _activity_by_character: Dictionary = {}
var _social_pause_remaining: Dictionary = {}
var _step_accumulator: float = 0.0
var _social_accumulator: float = 0.0
var _exchange_index: int = 0
var _running: bool = false


func configure(world_simulation: WorldSimulation, actor_lookup: Callable = Callable()) -> void:
	simulation = world_simulation
	_actor_lookup = actor_lookup
	var assignment_callback := Callable(self, "_on_activity_assigned")
	if not simulation.camp_simulation.activity_assigned.is_connected(assignment_callback):
		simulation.camp_simulation.activity_assigned.connect(assignment_callback)


func begin_camp(site: Dictionary) -> void:
	stop()
	if simulation == null:
		return
	var hex_value: Variant = site.get("hex", Vector2i.ZERO)
	if not hex_value is Vector2i:
		return
	_camp_hex = hex_value
	_build_companion_destinations()
	# Social exchanges remain active even if a tight or obstructed camp site has
	# no free station for one of the companions.
	_running = simulation.camp_simulation.phase == "evening"


func stop() -> void:
	_running = false
	_active_character_ids.clear()
	_destination_by_character.clear()
	_activity_by_character.clear()
	_social_pause_remaining.clear()
	_step_accumulator = 0.0
	_social_accumulator = 0.0
	_exchange_index = 0


func is_running() -> bool:
	return _running


func process_activity_movement(delta: float) -> void:
	if not _running or simulation == null or delta <= 0.0:
		return
	if simulation.is_in_combat or simulation.has_pending_reaction() or simulation.clock.paused:
		return
	_advance_social_pauses(delta)
	_step_accumulator += delta
	if _step_accumulator >= STEP_INTERVAL:
		_step_accumulator = 0.0
		# All companions advance on the same cadence. Round-robin stepping would
		# make a six-person party wait several seconds between each actor's steps.
		for character_id in _active_character_ids.duplicate():
			_process_companion_step(character_id)
	_process_social_exchanges(delta)


func _process_companion_step(character_id: String) -> void:
	if float(_social_pause_remaining.get(character_id, 0.0)) > 0.0:
		return
	var state := simulation.get_character(character_id)
	if state == null or not state.alive or not state.can_act():
		_active_character_ids.erase(character_id)
		_destination_by_character.erase(character_id)
		_activity_by_character.erase(character_id)
		return
	var destination: Vector2i = _destination_by_character.get(character_id, state.axial)
	if state.axial == destination:
		_play_assigned_activity(character_id)
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
		var target := _choose_station(activity, reserved, character_id)
		if target == INVALID_HEX:
			continue
		reserved[target] = true
		_active_character_ids.append(character_id)
		_destination_by_character[character_id] = target
		_activity_by_character[character_id] = activity


func _choose_station(activity: String, reserved: Dictionary, character_id: String) -> Vector2i:
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
		var occupant_id := String(simulation.occupied_hexes.get(candidate, ""))
		if not occupant_id.is_empty() and occupant_id != character_id:
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
		return INVALID_HEX
	if activity == "gather_wood":
		for candidate in candidates:
			if simulation.map_data.terrain_id_at(candidate).to_lower() == "forest":
				return candidate
	elif activity == "fetch_water":
		for candidate in candidates:
			if _adjacent_to_terrain(candidate, "water"):
				return candidate
	return candidates[0]


func _adjacent_to_terrain(hex: Vector2i, terrain_id: String) -> bool:
	for direction in HexGrid.DIRECTIONS:
		var neighbour := hex + direction
		if simulation.map_data.has_cell(neighbour) and simulation.map_data.terrain_id_at(neighbour).to_lower() == terrain_id:
			return true
	return false


func _play_assigned_activity(character_id: String) -> void:
	if not _actor_lookup.is_valid():
		return
	var actor: Variant = _actor_lookup.call(character_id)
	if actor == null or not is_instance_valid(actor) or not actor.has_method("play_camp_activity"):
		return
	actor.call("play_camp_activity", String(_activity_by_character.get(character_id, "socialise")))


func _on_activity_assigned(character_id: String, activity: String) -> void:
	if not _running or character_id == simulation.player_character_id:
		return
	if not _destination_by_character.has(character_id):
		return
	var state := simulation.get_character(character_id)
	if state == null or not state.alive:
		return
	var reserved: Dictionary = {}
	for other_id_value in _destination_by_character:
		var other_id := String(other_id_value)
		if other_id != character_id:
			reserved[_destination_by_character[other_id_value]] = true
	var target := _choose_station(activity, reserved, character_id)
	if target == INVALID_HEX:
		return
	_destination_by_character[character_id] = target
	_activity_by_character[character_id] = activity


## Companions keep talking to one another while camp duties continue. This is
## independent of player interaction and does not require a dedicated social
## assignment: a worker can pause, exchange a few words, then resume their task.
func _process_social_exchanges(delta: float) -> void:
	if simulation == null or simulation.camp_simulation.phase != "evening":
		return
	_social_accumulator += delta
	if _social_accumulator < 22.0:
		return
	_social_accumulator = 0.0
	var companions: Array[String] = []
	for value in simulation.camp_simulation.party_ids:
		var character_id := String(value)
		if character_id == simulation.player_character_id:
			continue
		if not CAMP_DIALOGUE_SERVICE.supported_companion_ids().has(CAMP_DIALOGUE_SERVICE.canonical_id(character_id)):
			continue
		var state := simulation.get_character(character_id)
		if state != null and state.alive and state.can_act():
			companions.append(character_id)
	if companions.size() < 2:
		return
	var pairs: Array[Array] = []
	for first_index in range(companions.size()):
		for second_index in range(first_index + 1, companions.size()):
			pairs.append([companions[first_index], companions[second_index]])
	if pairs.is_empty():
		return
	var pair: Array = pairs[posmod(_exchange_index, pairs.size())]
	var first_id := String(pair[0])
	var second_id := String(pair[1])
	var first_state := simulation.get_character(first_id)
	var second_state := simulation.get_character(second_id)
	if first_state == null or second_state == null:
		return
	var quest_chain := CAMPAIGN_RUNTIME_STORE.quest_chain_state_for(simulation)
	var exchange := CAMP_DIALOGUE_SERVICE.build_campaign_memory_exchange(
		first_id,
		second_id,
		_exchange_index,
		simulation.companion_bonds,
		quest_chain,
		simulation.campaign_journal,
		first_state.display_name,
		second_state.display_name
	)
	var event_key := CAMP_DIALOGUE_SERVICE.campaign_memory_event_key(exchange)
	if not exchange.is_empty():
		var first_bond := simulation.companion_bonds.snapshot(first_id, second_id)
		var second_bond := simulation.companion_bonds.snapshot(second_id, first_id)
		var first_events: Array = first_bond.get("applied_event_keys", [])
		var second_events: Array = second_bond.get("applied_event_keys", [])
		if first_events.has(event_key) or second_events.has(event_key):
			exchange = {}
	if exchange.is_empty():
		exchange = CAMP_DIALOGUE_SERVICE.build_exchange(
			first_id,
			second_id,
			_exchange_index,
			simulation.companion_bonds,
			first_state.display_name,
			second_state.display_name
		)
		event_key = "camp_banter:%s:%d:%d" % [
			String(simulation.camp_simulation.site.get("hex", Vector2i.ZERO)),
			int(simulation.clock.world_seconds),
			_exchange_index
		]
	if exchange.is_empty() or event_key.is_empty():
		return
	CAMP_DIALOGUE_SERVICE.record_exchange(
		simulation.companion_bonds,
		simulation.camp_simulation,
		exchange,
		event_key
	)
	_social_pause_remaining[first_id] = 4.5
	_social_pause_remaining[second_id] = 4.5
	_play_social_animation(first_id)
	_play_social_animation(second_id)
	_exchange_index += 1
	companion_exchange.emit(exchange)


func _play_social_animation(character_id: String) -> void:
	if not _actor_lookup.is_valid():
		return
	var actor: Variant = _actor_lookup.call(character_id)
	if actor == null or not is_instance_valid(actor) or not actor.has_method("play_camp_activity"):
		return
	actor.call("play_camp_activity", "socialise")


## Keep the talk gesture alive for the full two-turn exchange. The ordinary
## station animation is restored when both speech bubbles have had time to show.
func _advance_social_pauses(delta: float) -> void:
	for character_id_value in _social_pause_remaining.keys():
		var character_id := String(character_id_value)
		var remaining := maxf(0.0, float(_social_pause_remaining[character_id]) - delta)
		if remaining > 0.0:
			_social_pause_remaining[character_id] = remaining
			continue
		_social_pause_remaining.erase(character_id)
		if _destination_by_character.has(character_id):
			var state := simulation.get_character(character_id)
			if state != null and state.axial == _destination_by_character[character_id]:
				_play_assigned_activity(character_id)
