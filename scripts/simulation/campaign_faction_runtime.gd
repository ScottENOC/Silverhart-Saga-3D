extends Node
## Runtime bridge for source-authored faction agendas.
## It observes WorldSimulation instances without coupling campaign state to UI scenes.

const FACTION_SYSTEM = preload("res://scripts/simulation/campaign_faction_system.gd")
const AGENDA_INTERVAL_SECONDS := 3600.0

var _simulations: Dictionary = {}


func _enter_tree() -> void:
	get_tree().node_added.connect(_on_node_added)


func _ready() -> void:
	_scan_tree(get_tree().root)


func _scan_tree(parent: Node) -> void:
	for child in parent.get_children():
		_on_node_added(child)
		_scan_tree(child)


func _on_node_added(node: Node) -> void:
	if node is WorldSimulation:
		_track_simulation(node as WorldSimulation)


func _track_simulation(simulation: WorldSimulation) -> void:
	if simulation == null:
		return
	var simulation_id := simulation.get_instance_id()
	if _simulations.has(simulation_id):
		return
	var callback := _on_world_tick.bind(simulation_id)
	if not simulation.clock.ticked.is_connected(callback):
		simulation.clock.ticked.connect(callback)
	_simulations[simulation_id] = {
		"reference":weakref(simulation),
		"seeded":false,
		"last_world_seconds":-1.0,
		"agenda_elapsed_seconds":0.0
	}


func _process(_delta: float) -> void:
	for simulation_id_value in _simulations.keys():
		var simulation_id := int(simulation_id_value)
		var entry: Dictionary = _simulations[simulation_id]
		var reference: WeakRef = entry.get("reference") as WeakRef
		var simulation: WorldSimulation = null
		if reference != null:
			simulation = reference.get_ref() as WorldSimulation
		if simulation == null or not is_instance_valid(simulation):
			_simulations.erase(simulation_id)
			continue
		if not bool(entry.get("seeded", false)):
			var player := simulation.get_character(simulation.player_character_id)
			if player != null:
				FACTION_SYSTEM.initialize_social_standings(simulation.campaign_journal, player.race)
				entry["seeded"] = true
				entry["last_world_seconds"] = simulation.clock.world_seconds
				_simulations[simulation_id] = entry


func _on_world_tick(_tick_index: int, world_seconds: float, simulation_id: int) -> void:
	if not _simulations.has(simulation_id):
		return
	var entry: Dictionary = _simulations[simulation_id]
	var reference: WeakRef = entry.get("reference") as WeakRef
	var simulation: WorldSimulation = null
	if reference != null:
		simulation = reference.get_ref() as WorldSimulation
	if simulation == null or not is_instance_valid(simulation):
		_simulations.erase(simulation_id)
		return
	if not bool(entry.get("seeded", false)):
		var player := simulation.get_character(simulation.player_character_id)
		if player != null:
			FACTION_SYSTEM.initialize_social_standings(simulation.campaign_journal, player.race)
			entry["seeded"] = true
		entry["last_world_seconds"] = world_seconds
		_simulations[simulation_id] = entry
		return
	var previous := float(entry.get("last_world_seconds", world_seconds))
	if world_seconds < previous:
		entry["last_world_seconds"] = world_seconds
		entry["agenda_elapsed_seconds"] = 0.0
		_simulations[simulation_id] = entry
		return
	entry["agenda_elapsed_seconds"] = float(entry.get("agenda_elapsed_seconds", 0.0)) + world_seconds - previous
	entry["last_world_seconds"] = world_seconds
	var elapsed := float(entry["agenda_elapsed_seconds"])
	if elapsed >= AGENDA_INTERVAL_SECONDS:
		var complete_intervals := floori(elapsed / AGENDA_INTERVAL_SECONDS)
		var consumed_seconds := float(complete_intervals) * AGENDA_INTERVAL_SECONDS
		FACTION_SYSTEM.advance_time(simulation.campaign_journal, consumed_seconds)
		entry["agenda_elapsed_seconds"] = elapsed - consumed_seconds
	_simulations[simulation_id] = entry
