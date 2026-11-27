class_name CampaignHouseholdWorldService
extends Node

const HALVARD_CHARACTER_ID := "steward_halvard_greer"
const HALVARD_MANOR_HEX := Vector2i(39, -502)

var simulation: WorldSimulation
var actor_parent: Node3D
var actor_by_id: Dictionary
var player_profile: Dictionary
var starting_loadouts: Dictionary
var world_position_for_hex: Callable
var find_valid_spawn_hex: Callable
var routine_accumulator: float = 0.0
var routine_busy: bool = false

func configure(
	world_simulation: WorldSimulation,
	parent: Node3D,
	actors: Dictionary,
	profile: Dictionary,
	loadouts: Dictionary,
	world_position_callback: Callable,
	spawn_hex_callback: Callable
) -> void:
	simulation = world_simulation
	actor_parent = parent
	actor_by_id = actors
	player_profile = profile
	starting_loadouts = loadouts
	world_position_for_hex = world_position_callback
	find_valid_spawn_hex = spawn_hex_callback

func process(delta: float) -> void:
	routine_accumulator += delta
	if routine_accumulator < 1.0:
		return
	routine_accumulator = 0.0
	update_routine()

func ensure_actor() -> void:
	if simulation == null or actor_by_id.has(HALVARD_CHARACTER_ID):
		return
	var resident: Dictionary = simulation.campaign_dwellings.residents.get(HALVARD_CHARACTER_ID, {})
	if String(resident.get("dwelling_id", "")) != "silverhart_manor":
		return
	simulation.ensure_exploration_region(HALVARD_MANOR_HEX)
	var spawn_hex: Vector2i = find_valid_spawn_hex.call(HALVARD_MANOR_HEX + Vector2i(0, 1))
	var profile := {
		"params": {
			"seed": "halvard-greer", "gender": 1, "age": 0.58,
			"muscle": 0.53, "weight": 0.59, "height": 0.72, "proportions": 0.67,
			"eyes": "blue", "hair": "braid01", "hairTint": "#C6A16B", "skinTint": "#E8C5A5",
			"underTop": "none", "underBottom": "none", "top": "none", "bottom": "none", "shoes": "none",
			"detail": "medium", "rig": "game", "restPose": "A", "animations": true
		}
	}
	var existing_state := simulation.get_character(HALVARD_CHARACTER_ID)
	if existing_state == null:
		CampaignCharacterSpawner.spawn_character(
			simulation, actor_parent, actor_by_id, player_profile, starting_loadouts,
			HALVARD_CHARACTER_ID, "Steward Halvard Greer", spawn_hex,
			world_position_for_hex.call(spawn_hex), false, "", profile, ""
		)
		return
	var actor := CampaignCharacterActorFactory.create_actor(
		existing_state, world_position_for_hex.call(existing_state.axial), false,
		player_profile, profile, "", ""
	)
	if actor == null:
		return
	actor_parent.add_child(actor)
	actor.set_meta("campaign2_npc_id", HALVARD_CHARACTER_ID)
	actor.set_meta("dialogue_id", "halvard_household_steward")
	actor.add_to_group("campaign2_npc")
	actor_by_id[HALVARD_CHARACTER_ID] = actor

func update_routine() -> void:
	if simulation == null or not simulation.campaign_dwellings.residents.has(HALVARD_CHARACTER_ID):
		return
	ensure_actor()
	var actor := actor_by_id.get(HALVARD_CHARACTER_ID) as Node3D
	if actor == null or routine_busy:
		return
	var hour := fposmod(simulation.clock.world_seconds, 86400.0) / 3600.0
	var schedule := simulation.campaign_dwellings.resident_schedule_for(HALVARD_CHARACTER_ID, hour, simulation.get_party_member_ids())
	var activity := String(schedule.get("activity", "socialise"))
	if activity.is_empty() or String(actor.get_meta("household_activity", "")) == activity:
		return
	actor.set_meta("household_activity", activity)
	var presentation_activity := activity
	match activity:
		"housekeeping":
			presentation_activity = "repair_gear"
		"manage_stores":
			presentation_activity = "study_map"
		"welcome_guests":
			presentation_activity = "socialise"
	var ara := actor.get_node_or_null("CharacterModel") as AraCharacterActor
	if ara != null:
		ara.play_camp_activity(presentation_activity)
	var offsets := {
		"hearth": Vector2i(1, 0), "common": Vector2i(0, 2),
		"threshold": Vector2i(0, -1), "bedroom": Vector2i(-1, -1)
	}
	var station_role := String(schedule.get("station_role", "common"))
	var target_hex: Vector2i = HALVARD_MANOR_HEX + offsets.get(station_role, Vector2i.ZERO)
	simulation.ensure_exploration_region(target_hex)
	if not simulation.map_data.is_walkable(target_hex) or (simulation.occupied_hexes.has(target_hex) and String(simulation.occupied_hexes[target_hex]) != HALVARD_CHARACTER_ID):
		target_hex = find_valid_spawn_hex.call(target_hex)
	var halvard_state := simulation.get_character(HALVARD_CHARACTER_ID)
	if halvard_state == null:
		return
	if target_hex != halvard_state.axial:
		routine_busy = true
		move_to_station(target_hex)

func move_to_station(target_hex: Vector2i) -> void:
	var path := simulation.find_path(HALVARD_CHARACTER_ID, target_hex)
	if path.size() > 1:
		for index in range(1, path.size()):
			if not simulation.try_move_character_step(HALVARD_CHARACTER_ID, path[index]):
				break
			await get_tree().create_timer(0.18).timeout
			if not is_instance_valid(self):
				return
	routine_busy = false

func dialogue_line() -> String:
	if simulation == null:
		return "The manor is in good order. I shall see to the household while you are away."
	var hour := fposmod(simulation.clock.world_seconds, 86400.0) / 3600.0
	var schedule := simulation.campaign_dwellings.resident_schedule_for(HALVARD_CHARACTER_ID, hour, simulation.get_party_member_ids())
	match String(schedule.get("activity", "socialise")):
		"cook":
			return "I have the hearth and provisions in hand. A proper meal is one of the comforts a house should never lack."
		"housekeeping":
			return "I am seeing to the rooms and common spaces. A well-kept home is ready for its people when they return."
		"manage_stores":
			return "I am taking stock of the household stores. I will make certain we know what is running low."
		"welcome_guests":
			return "I am keeping an eye on the entrance. Anyone who comes to the manor will be received properly."
		"sleep":
			return "Forgive me if I seem weary. Even a steward must keep a sensible hour."
	return "The manor is in good order. I shall see to the household while you are away."
