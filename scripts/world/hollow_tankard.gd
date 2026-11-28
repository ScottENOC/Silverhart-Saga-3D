class_name HollowTankard
extends Node3D

const REACTION_PROMPT_SCRIPT = preload("res://scripts/ui/reaction_prompt.gd")
const INITIATIVE_TIMELINE_SCRIPT = preload("res://scripts/ui/combat_initiative_timeline.gd")
const CHARACTER_PANEL_SCRIPT = preload("res://scripts/ui/character_panel.gd")
const WORLD_MAP_PANEL_SCRIPT = preload("res://scripts/ui/main_campaign_world_map.gd")
const AMBIENT_CHATTER_SCRIPT = preload("res://scripts/simulation/ambient_chatter.gd")
const HOLLOWMERE_OPENING_SEQUENCE_SCRIPT = preload("res://scripts/simulation/hollowmere_opening_sequence_controller.gd")
const WORLD_VEGETATION_SCRIPT = preload("res://scripts/world/world_vegetation_generator.gd")
const RESOURCE_VISUAL_SCRIPT = preload("res://scripts/presentation/wilderness_resource_visual.gd")
const CREATURE_ACTOR_SCRIPT = preload("res://scripts/presentation/creature_actor.gd")
const HOLLOWMERE_ENCOUNTER_SCRIPT = preload("res://scripts/simulation/hollowmere_encounter.gd")
const HOLLOWMERE_OPENING_CONTEXT = preload("res://scripts/simulation/hollowmere_opening_context.gd")
const COMPANION_CAMPAIGN_SCRIPT = preload("res://scripts/simulation/companion_campaign_content.gd")
const COMPANION_RUNTIME_STORE = preload("res://scripts/simulation/companion_campaign_runtime_store.gd")
const CAMPAIGN_QUEST_SERVICE_SCRIPT = preload("res://scripts/quests/campaign_quest_service.gd")
const CAMPAIGN_AMBASSADOR_DIALOGUE_SERVICE = preload("res://scripts/quests/campaign_ambassador_dialogue_service.gd")
const CAMPAIGN_LOCAL_QUEST_DIALOGUE_SERVICE = preload("res://scripts/quests/campaign_local_quest_dialogue_service.gd")
const COMPANION_DIALOGUE_SERVICE = preload("res://scripts/simulation/companion_campaign_dialogue_service.gd")
const FARM_WOLVES_QUEST_SCRIPT = preload("res://scripts/simulation/farm_wolves_quest.gd")
const TOLL_TAKER_CONTENT_SCRIPT = preload("res://scripts/simulation/toll_taker_quest_content.gd")
const TOLL_TAKER_ENCOUNTER_SCRIPT = preload("res://scripts/simulation/toll_taker_quest_encounter.gd")
const ELDER_MARTA_CONTENT_SCRIPT = preload("res://scripts/simulation/elder_marta_content.gd")
const ELDER_LOCKET_PICKUP_SCRIPT = preload("res://scripts/simulation/elder_locket_pickup_content.gd")
const NELLA_CONTENT_SCRIPT = preload("res://scripts/simulation/reddale_innkeeper_content.gd")
const IRONBOND_MISSING_COURIER_CONTENT_SCRIPT = preload("res://scripts/simulation/ironbond_missing_courier_content.gd")
const BARON_TRIBUTE_CONTENT_SCRIPT = preload("res://scripts/simulation/baron_tribute_content.gd")
const DWARVEN_AMBASSADOR_CONTENT_SCRIPT = preload("res://scripts/simulation/dwarven_ambassador_content.gd")
const CORVANE_AMBASSADOR_CONTENT_SCRIPT = preload("res://scripts/simulation/corvane_ambassador_content.gd")
const ALDENREACH_MESSAGE_CONTENT_SCRIPT = preload("res://scripts/simulation/aldenreach_message_content.gd")
const FARMSTEAD_DIRE_WOLF_SCRIPT = preload("res://scripts/simulation/farmstead_dire_wolf_encounter.gd")
const DWELLING_WORLD_SERVICE = preload("res://scripts/world/campaign_dwelling_world_service.gd")
const DWELLING_DIALOGUE_SERVICE = preload("res://scripts/simulation/campaign_dwelling_dialogue_service.gd")
const ABANDONED_HOUSE_QUEST_SCRIPT = preload("res://scripts/simulation/abandoned_house_clearing_quest.gd")
const ABANDONED_HOUSE_DIALOGUE_SERVICE = preload("res://scripts/simulation/abandoned_house_dialogue_service.gd")
const REYNA_RESCUE_SERVICE = preload("res://scripts/quests/reyna_rescue_service.gd")
const HOLLOWMERE_SHAKEDOWN_DIALOGUE_SERVICE = preload("res://scripts/quests/hollowmere_shakedown_dialogue_service.gd")
const DWELLING_WORLD_PRESENTATION = preload("res://scripts/presentation/campaign_dwelling_world_presentation.gd")
const SKELETAL_GUARDIAN_ACTOR_SCRIPT = preload("res://scripts/presentation/skeletal_guardian_actor.gd")
const HOLLOWMERE_PLACEMENTS = preload("res://data/settlements/hollowmere/placements.gd")
const HOLLOWMERE_TERRAIN_PROVIDER = preload("res://scripts/world/authored_settlement_terrain_provider.gd")
const HOLLOWMERE_TERRAIN_DEFINITION = preload("res://data/settlements/hollowmere/terrain.gd")
const WORLD_CELL_LOADER_SCRIPT = preload("res://scripts/world/campaign2_world_cell_loader.gd")
const WORLD_PLAYER_MOVEMENT_CONTROLLER = preload("res://scripts/world/world_player_movement_controller.gd")
const MULTISTORY_LOCATION_LOADER = preload("res://scripts/world/campaign2_location_loader.gd")
const TUNNEL_NETWORK = preload("res://scripts/world/campaign2_tunnel_network.gd")
const TUNNEL_INTERACTION_CONTENT = preload("res://scripts/simulation/campaign2_tunnel_interaction_content.gd")
const NPC_INTERACTION_SERVICE = preload("res://scripts/world/campaign_npc_interaction_service.gd")
const INTERIOR_LAYOUT_REGISTRAR = preload("res://scripts/world/world_interior_layout_registrar.gd")
const INTERIOR_LAYOUT_PRESENTER = preload("res://scripts/world/world_interior_layout_presenter.gd")
const HOLLOW_TANKARD_LAYOUT = preload("res://data/settlements/hollowmere/interiors/hollow_tankard_layout.gd")
const SPELL_VFX_SCRIPT = preload("res://scripts/presentation/spell_vfx_controller.gd")
const COMBAT_ENCOUNTER_CONTROLLER_SCRIPT = preload("res://scripts/presentation/combat_encounter_controller.gd")
const CAMP_NIGHT_AMBUSH_ENCOUNTER_SCRIPT = preload("res://scripts/simulation/camp_night_ambush_encounter.gd")
const SAVE_LOAD_MENU_SCRIPT = preload("res://scripts/ui/save_load_menu.gd")
const SAVE_MANAGER_SCRIPT = preload("res://scripts/save/save_manager.gd")
const CAMPAIGN_SIMULATION_SNAPSHOT_RESTORER = preload("res://scripts/campaign/campaign_simulation_snapshot_restorer.gd")
const CAMPAIGN_CHARACTER_SAVE_DIFFS = preload("res://scripts/campaign/campaign_character_save_diffs.gd")
const PERSISTENT_RELATIONSHIP_STORE = preload("res://scripts/simulation/persistent_character_relationship_store.gd")
const PERSISTENT_DIALOGUE_CONTENT = preload("res://scripts/simulation/persistent_character_dialogue_content.gd")
const ILSA_WATCH_CAPTAIN_CONTENT_SCRIPT = preload("res://scripts/simulation/ilsa_watch_captain_content.gd")
const CAMPAIGN_FACTION_SIMULATION_SCRIPT = preload("res://scripts/simulation/campaign_faction_simulation.gd")
const CAMP_WORLD_PRESENTATION_SCRIPT = preload("res://scripts/presentation/camp_world_presentation.gd")
const CAMP_PARTY_ACTIVITY_DIRECTOR_SCRIPT = preload("res://scripts/presentation/camp_party_activity_director.gd")
const HOUSEHOLD_WORLD_SERVICE_SCRIPT = preload("res://scripts/world/campaign_household_world_service.gd")
const ROWAN_WORLD_SERVICE_SCRIPT = preload("res://scripts/world/rowan_fletcher_world_service.gd")
const CAMP_LIFECYCLE_CONTROLLER_SCRIPT = preload("res://scripts/world/camp_lifecycle_controller.gd")
const WILDERNESS_CREATURE_SPAWN_SERVICE = preload("res://scripts/world/wilderness_creature_spawn_service.gd")
const TAVERN_BUILDING_ID: String = HOLLOW_TANKARD_LAYOUT.BUILDING_ID
const TAVERN_FRONT_DOOR_ID: String = HOLLOW_TANKARD_LAYOUT.FRONT_DOOR_ID
const TAVERN_DOOR_HEX: Vector2i = HOLLOW_TANKARD_LAYOUT.DOOR_HEX
const UPPER_FLOOR_ORIGIN: Vector2i = HOLLOW_TANKARD_LAYOUT.UPPER_FLOOR_ORIGIN
const UPPER_FLOOR_Y: float = HOLLOW_TANKARD_LAYOUT.UPPER_FLOOR_Y
const TAVERN_STAIR_GROUND_HEX: Vector2i = HOLLOW_TANKARD_LAYOUT.STAIR_GROUND_HEX
const TAVERN_STAIR_UPPER_HEX: Vector2i = HOLLOW_TANKARD_LAYOUT.STAIR_UPPER_HEX
const TAVERN_STAIR_TRAVERSAL_DURATION := 1.4
const UPPER_BED_HEXES: Array[Vector2i] = HOLLOW_TANKARD_LAYOUT.UPPER_BED_HEXES

var location_label: Label
var upper_shell_group: Node3D
var upper_floor_group: Node3D
var upper_interior_group: Node3D
var upper_floor_tiles: Node3D
var tavern_door_pivot: Node3D
var tavern_door_leaf: MeshInstance3D

# First authored location: the Hollow Tankard and its immediate approach.
# Logical movement remains hex-based; this scene only presents that state.
const HEX_RADIUS: float = HexGrid.DEFAULT_RADIUS_M
const ROOM_HALF_WIDTH: float = HOLLOW_TANKARD_LAYOUT.ROOM_HALF_WIDTH
const ROOM_HALF_DEPTH: float = HOLLOW_TANKARD_LAYOUT.ROOM_HALF_DEPTH

var simulation: WorldSimulation
var world_cell_loader: Campaign2WorldCellLoader
var multistory_runtime_by_location: Dictionary = {}
var active_multistory_runtime: Campaign2MultiStoryLocationRuntime
var spell_vfx: Node3D
var save_load_menu: CanvasLayer
var pending_save_data: Dictionary = {}
var campaign_faction_simulation: CampaignFactionSimulation
var campaign_quest_service: CampaignQuestService
var initial_character_baselines: Dictionary = {}

var autosave_accumulator: float = 0.0
var reaction_prompt: CanvasLayer
var initiative_timeline: CombatInitiativeTimeline
var character_panel: CharacterPanel
var world_map_panel: CanvasLayer
var camera_rig: OrbitCameraRig
var roof_group: Node3D
var actor_by_id: Dictionary = {}
var starting_loadouts: Dictionary = {}
var player_profile: Dictionary = {}
var active_party_index: int = 0
var active_character_id: String = "player"
var party_switch_button: Button
var zoom_slider: HSlider
var rotate_left_button: Button
var rotate_right_button: Button
var tile_mesh: ArrayMesh
var path_material: StandardMaterial3D
var movement_controller: Variant
var stair_traversal_running: bool = false
var stair_traversal_character_id: String = ""
const INVALID_HEX := Vector2i(2147483647, 2147483647)

var grass_material: StandardMaterial3D
var floor_material: StandardMaterial3D
var blocked_material: StandardMaterial3D
var stone_material: StandardMaterial3D
var timber_material: StandardMaterial3D
var dark_wood_material: StandardMaterial3D
var plaster_material: StandardMaterial3D
var roof_material: StandardMaterial3D
var glass_material: StandardMaterial3D
var bottle_green_material: StandardMaterial3D
var ambient_chatter: AmbientChatter
var ambient_dialogue_presenter: CampaignAmbientDialoguePresenter
var hollowmere_opening_sequence: HollowmereOpeningSequenceController
var ambient_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var household_world_service: CampaignHouseholdWorldService
var ambient_accumulator: float = 0.0
var ambient_exchange_running: bool = false
var ambient_security: int = 50
var shakedown_started: bool = false
var shakedown_resolved: bool = false
var abandoned_house_journal_read: bool = false
var elder_locket_collected: bool = false
var elder_locket_visual: Node3D
var dialogue_open: bool = false
var dialogue_panel: CampaignDialoguePanel
var conversation_controller: CampaignConversationController
var combat_hud: CampaignCombatHud
var combat_controller: CombatEncounterController
var resource_status_label: Label
var resource_visuals_by_hex: Dictionary = {}
var encounter_active: bool = false
var active_combat_session: Dictionary = {}
var active_encounter_resolver: Callable
var nearby_interaction_panel: PanelContainer
var nearby_interaction_box: VBoxContainer
var nearby_interaction_refresh: float = 0.0
var farm_wolves_spawned: bool = false
var farm_wolves_retry_armed: bool = false
var reyna_clue_visual: Node3D
var wilderness_creature_spawner: WildernessCreatureSpawnService
var camp_presentation: CampWorldPresentation
var camp_activity_director: CampPartyActivityDirector
var camp_selection_mode: bool = false
var camp_button: Button
var camp_sleep_button: Button
var camp_status_label: Label
var rowan_world_service: RowanFletcherWorldService
var camp_lifecycle_controller: CampLifecycleController

func _save_manager_service() -> Node:
	return get_node_or_null("/root/SaveManager")

func _ready() -> void:
	_create_materials()
	_create_lighting()
	ambient_dialogue_presenter = CampaignAmbientDialoguePresenter.new()
	ambient_dialogue_presenter.name = "CampaignAmbientDialoguePresenter"
	add_child(ambient_dialogue_presenter)
	spell_vfx = SPELL_VFX_SCRIPT.new() as Node3D
	spell_vfx.name = "SpellVisualEffects"
	add_child(spell_vfx)
	_configure_location_simulation()
	_register_campaign_quest_content()
	campaign_faction_simulation = CAMPAIGN_FACTION_SIMULATION_SCRIPT.new() as CampaignFactionSimulation
	_present_interior_layout()
	movement_controller = WORLD_PLAYER_MOVEMENT_CONTROLLER.new()
	movement_controller.name = "WorldPlayerMovementController"
	add_child(movement_controller)
	movement_controller.configure(simulation, self, tile_mesh, path_material, Callable(self, "_hex_world_position"), active_character_id)
	_create_wilderness_gatherable_grove()
	_create_characters()
	_create_household_world_service()
	_create_reyna_shelter()
	_capture_initial_character_baselines()
	_create_camera()
	_create_camp_presentation()
	_create_hud()
	_create_camp_lifecycle_controller()
	if not simulation.camp_night_encounter_resolved.is_connected(_on_camp_night_encounter_resolved):
		simulation.camp_night_encounter_resolved.connect(_on_camp_night_encounter_resolved)
	ambient_chatter = AMBIENT_CHATTER_SCRIPT.new() as AmbientChatter
	ambient_rng.randomize()
	_create_wilderness_creature_spawn_service()
	var restored_from_save := not pending_save_data.is_empty()

	if restored_from_save:
		_apply_save_data(pending_save_data)
		var saved_multistory_location := String(pending_save_data.get("active_multistory_location_id", ""))
		if not saved_multistory_location.is_empty():
			var restored_location := enter_multistory_location(saved_multistory_location)
			if not bool(restored_location.get("ok", false)):
				push_warning("Saved multi-story location could not be restored: %s" % restored_location)
		pending_save_data.clear()
	_refresh_dwelling_world_presentation()
	_restore_abandoned_house_guardian_actors()
	_restore_toll_ogre_actor()
	_initialise_companion_relationship_context()
	var initial_player_state := simulation.get_character("player")
	var player_race := initial_player_state.race if initial_player_state != null else "human"
	CAMPAIGN_FACTION_SIMULATION_SCRIPT.seed_faction_standings(simulation.campaign_journal, String(player_race))
	campaign_faction_simulation.reset_world_time(simulation.clock.world_seconds)
	if not simulation.clock.time_advanced.is_connected(_on_campaign_world_time_advanced):
		simulation.clock.time_advanced.connect(_on_campaign_world_time_advanced)
	if restored_from_save:
		if not shakedown_started:
			_run_opening_sequence()
	else:
		var save_manager := _save_manager_service()
		if save_manager != null:
			save_manager.call("save_autosave", _build_save_snapshot())
		_run_opening_sequence()

func _register_campaign_quest_content() -> void:
	campaign_quest_service = CAMPAIGN_QUEST_SERVICE_SCRIPT.new() as CampaignQuestService
	var configured: Dictionary = campaign_quest_service.configure(simulation)
	if not bool(configured.get("ok", false)):
		push_error("Campaign quest service could not configure: %s" % configured)
		return
	var registered: Dictionary = campaign_quest_service.register_definitions()
	if not bool(registered.get("ok", false)):
		push_error("Campaign quest definitions could not be registered: %s" % registered)

func _initialise_companion_relationship_context() -> void:
	var relationships := COMPANION_RUNTIME_STORE.relationship_state_for(simulation)
	if relationships == null:
		return
	var presentation := String(player_profile.get("gender_presentation", "Masculine")).strip_edges().to_lower()
	if not ["masculine", "feminine", "androgynous", "unknown"].has(presentation):
		presentation = "unknown"
	for companion_id in ["wren_talbot", "ser_aldric_thorne", "fenn_oakheart", "reyna_fletcher", "mirabel_quill", "brother_alden"]:
		relationships.set_presentation(companion_id, presentation)

func _create_materials() -> void:
	grass_material = _material(Color(0.28, 0.38, 0.27))
	floor_material = _material(Color(0.35, 0.25, 0.16))
	blocked_material = _material(Color(0.30, 0.29, 0.25))
	stone_material = _material(Color(0.34, 0.34, 0.31))
	timber_material = _material(Color(0.25, 0.13, 0.075))
	dark_wood_material = _material(Color(0.13, 0.075, 0.045))
	plaster_material = _material(Color(0.55, 0.48, 0.36))
	roof_material = _material(Color(0.19, 0.22, 0.23))
	glass_material = _material(Color(0.28, 0.42, 0.48, 0.68))
	glass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bottle_green_material = _material(Color(0.22, 0.34, 0.20))
	path_material = _material(Color(0.95, 0.72, 0.20, 0.48))
	path_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

func _material(colour: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = colour
	result.roughness = 0.88
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	return result

func _create_lighting() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	sun.light_energy = 1.2
	add_child(sun)

	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.48, 0.62, 0.69)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.62, 0.59, 0.51)
	environment.ambient_light_energy = 0.7
	environment_node.environment = environment
	add_child(environment_node)

func configure_campaign(campaign_simulation: WorldSimulation, profile: Dictionary, save_data: Dictionary) -> void:
	if campaign_simulation == null:
		push_error("HollowTankard requires a campaign simulation supplied by WorldRoot.")
		return
	simulation = campaign_simulation
	player_profile = profile.duplicate(true)
	pending_save_data = save_data.duplicate(true)

func _configure_location_simulation() -> void:
	# Register this location's map, building, floor and presentation hooks.
	if simulation == null:
		push_error("Campaign simulation was not configured before HollowTankard entered the scene tree.")
		return
	simulation.clock.ticked.connect(_on_world_clock_ticked)
	if not simulation.weather_changed.is_connected(_on_world_weather_changed):
		simulation.weather_changed.connect(_on_world_weather_changed)
	simulation.action_committed.connect(_on_simulation_action_committed)
	# Materialise the opening area through the same world provider used by the
	# regional preview. Hollowmere is no longer a bypassed special-case radius.
	world_cell_loader = WORLD_CELL_LOADER_SCRIPT.new() as Campaign2WorldCellLoader
	world_cell_loader.load_around(simulation.map_data, Vector2i.ZERO, 4)
	# Authored collision regions, upper-floor cells, building metadata and door
	# state are registered by the shared logical interior-layout registrar.
	if not INTERIOR_LAYOUT_REGISTRAR.register_layout(
		simulation, HOLLOW_TANKARD_LAYOUT.LOGICAL_DEFINITION, HEX_RADIUS
	):
		push_error("Failed to register the Hollow Tankard logical interior layout.")
		return
	simulation.building_registry.door_state_changed.connect(_on_building_door_state_changed)
	simulation.character_moved.connect(_on_character_moved)
	simulation.reaction_requested.connect(_on_reaction_requested)
	simulation.reaction_resolved.connect(_on_reaction_resolved)
	simulation.movement_reaction_resolved.connect(_on_movement_reaction_resolved)
	simulation.turn_scheduler.turn_started.connect(_on_combat_turn_started)


func _camp_weather_summary(conditions: Dictionary) -> String:
	return "%s · %.1f°C · wind %.0f km/h" % [
		String(conditions.get("weather_label", "Clear")),
		float(conditions.get("temperature_c", 0.0)),
		float(conditions.get("wind_speed", 0.0))
	]


func _on_world_weather_changed(_conditions: Dictionary) -> void:
	if simulation == null or camp_status_label == null:
		return
	if simulation.camp_simulation.phase != "evening":
		return
	var terrain_id := String(simulation.camp_simulation.site.get("terrain_id", ""))
	var local_conditions := simulation.weather_state.conditions_at(simulation.clock.world_seconds, terrain_id)
	camp_status_label.text = "Camp · %s. Companion routines have adjusted to the changing weather." % _camp_weather_summary(local_conditions)


func _on_campaign_world_time_advanced(world_seconds: float) -> void:
	if campaign_faction_simulation == null or simulation == null:
		return
	var player := simulation.get_character(simulation.player_character_id)
	var cooked := household_world_service.prepare_scheduled_meal(world_seconds, player) if household_world_service != null else {}
	if bool(cooked.get("ok", false)) and resource_status_label != null:
		var meal_name := "breakfast" if String(cooked.get("meal_slot", "")) == "breakfast" else "supper"
		resource_status_label.text = "Halvard has prepared %s at Silverhart Manor." % meal_name.capitalize()
	campaign_faction_simulation.advance_to(simulation.campaign_journal, world_seconds)

func _on_simulation_action_committed(event: SimulationEvent) -> void:
	if event == null or spell_vfx == null:
		return
	# A selected Counterspell reaction is emitted as spell_countered rather
	# than spell_cast, but it still needs the same visible counter-pulse.
	if event.event_type not in ["spell_cast", "spell_countered"]:
		return
	var payload := event.payload
	var spell_id := "counterspell" if event.event_type == "spell_countered" else String(payload.get("spell_id", ""))
	if spell_id.is_empty():
		return
	var caster := actor_by_id.get(event.actor_id) as Node3D
	var target := actor_by_id.get(event.target_id) as Node3D
	var target_hex_value: Variant = payload.get("target_hex", Vector2i.ZERO)
	var target_hex := Vector2i.ZERO
	if target_hex_value is Vector2i:
		target_hex = target_hex_value
	elif target_hex_value is Dictionary:
		target_hex = Vector2i(int(target_hex_value.get("q", 0)), int(target_hex_value.get("r", 0)))
	var target_position := HexGrid.axial_to_world(target_hex, HEX_RADIUS)
	if target != null:
		target_position = target.global_position
	elif caster != null and spell_id in ["disguise_self", "feather_fall", "wild_fury"]:
		target_position = caster.global_position

	var affected_actors: Array[Node3D] = []
	var affected_ids: Variant = payload.get("affected_ids", [])
	if affected_ids is Array:
		for affected_id_value in affected_ids:
			var affected_actor := actor_by_id.get(String(affected_id_value)) as Node3D
			if affected_actor != null:
				affected_actors.append(affected_actor)
	spell_vfx.call("play_spell",
		spell_id,
		caster,
		target,
		target_position,
		payload,
		affected_actors
	)

func _create_wilderness_gatherable_grove() -> void:
	# These authored trees use the same shared generator and committed Cosmo
	# catalogue as Hollowmere's surrounding forest.
	var decorative_trees: Array[Dictionary] = [
		{"name": "TavernGrove_Ash", "position": Vector3(-7.5, 0.0, -17.3), "family": "ash", "seed": 21, "scale": 0.92},
		{"name": "TavernGrove_Cherry", "position": Vector3(7.5, 0.0, 17.3), "family": "cherry", "seed": 22, "scale": 0.98},
		{"name": "TavernGrove_Pine", "position": Vector3(-7.5, 0.0, 8.66), "family": "pine", "seed": 23, "scale": 0.94},
		{"name": "TavernGrove_Spruce", "position": Vector3(7.5, 0.0, -17.3), "family": "spruce", "seed": 24, "scale": 0.98}
	]
	WORLD_VEGETATION_SCRIPT.generate_authored_placements(self, decorative_trees)

	# Authored tutorial gatherables are deliberately close enough to test on
	# the first visit. Random wilderness spawning remains outside Hollowmere.
	var resource_placements: Array[Dictionary] = [
		{"hex": Vector2i(-6, 2), "terrain": "forest", "node": {"type": "fruit_tree", "available": true, "regrow_at": 0.0}},
		{"hex": Vector2i(6, -2), "terrain": "forest", "node": {"type": "timber_tree", "available": true, "regrow_at": 0.0}},
		{"hex": Vector2i(5, 4), "terrain": "grass", "node": {"type": "herb_patch", "available": true, "regrow_at": 0.0}},
		{"hex": Vector2i(4, -5), "terrain": "rocky_outcrop", "node": {"type": "ore_node", "item_id": "ore_iron", "depleted": false, "regrow_at": 0.0}},
		{"hex": Vector2i(-6, -2), "terrain": "rocky_outcrop", "node": {"type": "stone_deposit", "depleted": false, "regrow_at": 0.0}},
	]
	for placement in resource_placements:
		var hex: Vector2i = placement["hex"]
		var state: Dictionary = placement["node"]
		simulation.set_authored_resource_at(hex, String(placement["terrain"]), state)
		var visual := RESOURCE_VISUAL_SCRIPT.new() as WildernessResourceVisual
		visual.name = "Resource_%d_%d" % [hex.x, hex.y]
		visual.position = HexGrid.axial_to_world(hex, HEX_RADIUS, 0.0)
		add_child(visual)
		visual.refresh(state, int(simulation.clock.calendar_date()["month_index"]))
		resource_visuals_by_hex[hex] = visual
	_create_elder_locket_pickup()

func _create_elder_locket_pickup() -> void:
	var pickup_hex: Vector2i = HOLLOWMERE_PLACEMENTS.ELDER_LOCKET_PICKUP_HEX
	elder_locket_visual = Node3D.new()
	elder_locket_visual.name = "ElderMartaLocketPickup"
	elder_locket_visual.position = _hex_world_position(pickup_hex) + Vector3(0.0, 0.16, 0.0)
	elder_locket_visual.add_to_group("world_pickups")
	var ring_instance := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.11
	ring_mesh.outer_radius = 0.17
	ring_instance.mesh = ring_mesh
	ring_instance.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	var gold_material := StandardMaterial3D.new()
	gold_material.albedo_color = Color("#c49a43")
	gold_material.metallic = 0.82
	gold_material.roughness = 0.24
	gold_material.emission_enabled = true
	gold_material.emission = Color("#6d4815")
	gold_material.emission_energy_multiplier = 0.32
	ring_instance.material_override = gold_material
	elder_locket_visual.add_child(ring_instance)
	var gem_instance := MeshInstance3D.new()
	var gem_mesh := SphereMesh.new()
	gem_mesh.radius = 0.055
	gem_mesh.height = 0.11
	gem_instance.mesh = gem_mesh
	gem_instance.position = Vector3(0.0, 0.0, 0.15)
	var gem_material := StandardMaterial3D.new()
	gem_material.albedo_color = Color("#6d8c85")
	gem_material.metallic = 0.25
	gem_material.roughness = 0.2
	gem_instance.material_override = gem_material
	elder_locket_visual.add_child(gem_instance)
	var label := Label3D.new()
	label.text = "Tarnished Locket"
	label.position = Vector3(0.0, 0.48, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 18
	label.outline_size = 4
	elder_locket_visual.add_child(label)
	add_child(elder_locket_visual)
	elder_locket_visual.visible = not elder_locket_collected

func _interact_with_chapel_locket() -> bool:
	if elder_locket_collected:
		return false
	var active_state := simulation.get_character(active_character_id)
	if active_state == null or not simulation.is_hex_within_range(active_state.axial, HOLLOWMERE_PLACEMENTS.ELDER_LOCKET_PICKUP_HEX, 1):
		return false
	var player := simulation.get_character(simulation.player_character_id)
	var result: Dictionary = ELDER_LOCKET_PICKUP_SCRIPT.collect(player)
	if not bool(result.get("ok", false)):
		resource_status_label.text = "You cannot take the locket just now."
		return true
	elder_locket_collected = true
	if is_instance_valid(elder_locket_visual):
		elder_locket_visual.visible = false
	resource_status_label.text = "Found: Tarnished Locket. Elder Marta may know who lost it."
	return true

func _on_world_clock_ticked(_tick_index: int, _world_seconds: float) -> void:
	var month_index := int(simulation.clock.calendar_date()["month_index"])
	for tree in get_tree().get_nodes_in_group("seasonal_trees"):
		if tree is SeasonalTreeVisual:
			tree.refresh_month(month_index)
	_refresh_resource_visuals()

func _present_interior_layout() -> void:
	# Static interior geometry is authored in a location data manifest and
	# interpreted by the shared presenter. This controller retains only the
	# live references needed for door animation, floor visibility and cutaway.
	var result: Dictionary = INTERIOR_LAYOUT_PRESENTER.present(
		self,
		HOLLOW_TANKARD_LAYOUT.DEFINITION,
		{
			"grass": grass_material,
			"floor": floor_material,
			"blocked": blocked_material,
			"stone": stone_material,
			"timber": timber_material,
			"dark_wood": dark_wood_material,
			"plaster": plaster_material,
			"roof": roof_material,
			"glass": glass_material,
			"bottle_green": bottle_green_material
		},
		simulation.map_data,
		HEX_RADIUS
	)
	if not bool(result.get("ok", false)):
		push_error("Could not present Hollow Tankard authored interior: %s" % result)
		return
	tile_mesh = result.get("tile_mesh") as ArrayMesh
	tavern_door_pivot = result.get("door_pivot") as Node3D
	tavern_door_leaf = result.get("door_leaf") as MeshInstance3D
	upper_shell_group = result.get("upper_exterior") as Node3D
	upper_floor_group = result.get("upper_floor") as Node3D
	upper_floor_tiles = result.get("upper_tiles") as Node3D
	upper_interior_group = result.get("upper_interior") as Node3D
	roof_group = result.get("roof") as Node3D
	_refresh_tavern_door_presentation()
	_refresh_tavern_floor_presentation()

func _create_characters() -> void:
	starting_loadouts = _load_starting_loadouts()
	# Player and NPCs use the shared gendered Ara base mesh.
	_spawn_character("player", String(player_profile.get("name", "Adventurer")), HOLLOWMERE_PLACEMENTS.PLAYER_START_HEX, true)

	var profile_file := FileAccess.open("res://data/characters/hollowmere_npcs.json", FileAccess.READ)
	if profile_file == null:
		push_error("Hollowmere character manifest is missing.")
		return
	var parsed: Variant = JSON.parse_string(profile_file.get_as_text())
	if not parsed is Dictionary:
		push_error("Hollowmere character manifest is not valid JSON.")
		return
	for profile_variant in parsed.get("characters", []):
		if not profile_variant is Dictionary:
			continue
		var profile: Dictionary = profile_variant
		if str(profile.get("role", "")) == "player avatar":
			continue
		var actor_id := str(profile.get("game_id", profile.get("id", "")))
		var model_id := str(profile.get("id", ""))
		var display_name := str(profile.get("name", actor_id))
		if actor_id.is_empty() or model_id.is_empty():
			push_error("Invalid Hollowmere character profile: " + model_id)
			continue
		if not HOLLOWMERE_PLACEMENTS.CHARACTER_STARTS.has(model_id):
			if HOLLOWMERE_PLACEMENTS.DEFERRED_COMPANIONS.has(model_id):
				# Their recruitment regions are not in the opening world yet.
				# Do not create off-region companions at arbitrary Hollowmere coordinates.
				continue
			push_error("Missing authored Hollowmere start placement for character profile: " + model_id)
			continue
		var spawn: Vector2i = HOLLOWMERE_PLACEMENTS.CHARACTER_STARTS[model_id]
		_spawn_character(actor_id, display_name, spawn, false, model_id, profile)

	# Old Mac lives at his farmstead on the same continuous axial world grid.
	_spawn_character("old_mac", "Old Mac", HOLLOWMERE_PLACEMENTS.OLD_MAC_START_HEX, false, "", {"params": {"gender": 1}})
	var wolf_result := FARMSTEAD_DIRE_WOLF_SCRIPT.create_dire_wolf(simulation, HOLLOWMERE_PLACEMENTS.FARMSTEAD_DIRE_WOLF_HEX)
	if bool(wolf_result.get("ok", false)):
		_spawn_farmstead_dire_wolf()
	_refresh_tavern_floor_presentation()


func _create_reyna_shelter() -> void:
	var shelter := Node3D.new()
	shelter.name = "AbandonedShepherdShelter"
	shelter.position = _hex_world_position(HOLLOWMERE_PLACEMENTS.REYNA_SHELTER_HEX)
	_add_box(shelter, "ShelterStoneFooting", Vector3(0.0, 0.12, 0.0), Vector3(2.8, 0.24, 2.2), stone_material)
	_add_box(shelter, "ShelterRearWall", Vector3(0.0, 0.92, -0.92), Vector3(2.65, 1.55, 0.22), stone_material)
	_add_box(shelter, "ShelterLeftWall", Vector3(-1.22, 0.68, 0.0), Vector3(0.22, 1.1, 1.95), stone_material)
	var beam := _add_box(shelter, "ShelterRoofBeam", Vector3(0.0, 1.82, -0.25), Vector3(2.9, 0.18, 0.22), dark_wood_material)
	beam.rotation.z = deg_to_rad(-7.0)
	var roof := _add_box(shelter, "ShelterBrokenRoof", Vector3(0.0, 1.72, -0.55), Vector3(2.75, 0.14, 1.3), timber_material)
	roof.rotation.x = deg_to_rad(-12.0)
	roof.rotation.z = deg_to_rad(-7.0)
	add_child(shelter)


func _spawn_farmstead_dire_wolf() -> void:
	var actor := CREATURE_ACTOR_SCRIPT.new() as CreatureActor
	actor.creature_kind = "wolf"
	actor.behaviour = "predator"
	actor.model_path = "res://art/creatures/quaternius/Wolf.gltf"
	actor.model_scale = 1.65
	actor.name = FARMSTEAD_DIRE_WOLF_SCRIPT.DIRE_WOLF_ID
	actor.position = _hex_world_position(HOLLOWMERE_PLACEMENTS.FARMSTEAD_DIRE_WOLF_HEX)
	actor.set_meta("character_id", FARMSTEAD_DIRE_WOLF_SCRIPT.DIRE_WOLF_ID)
	actor.set_meta("ambient_enabled", false)
	actor.set_meta("dire_wolf_actor", true)
	add_child(actor)
	actor_by_id[FARMSTEAD_DIRE_WOLF_SCRIPT.DIRE_WOLF_ID] = actor


func _ensure_reyna_clue_visual() -> void:
	if is_instance_valid(reyna_clue_visual):
		return
	var root := Node3D.new()
	root.name = "ReynaMissingChildTrailClue"
	root.position = _hex_world_position(HOLLOWMERE_PLACEMENTS.REYNA_CLUE_HEX)
	var cloth := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.62, 0.055, 0.34)
	cloth.mesh = mesh
	cloth.position.y = 0.16
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.12, 0.28, 0.62)
	material.roughness = 0.95
	cloth.material_override = material
	root.add_child(cloth)
	var label := Label3D.new()
	label.text = "Torn blue cloth"
	label.position.y = 0.62
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 22
	label.outline_size = 5
	root.add_child(label)
	add_child(root)
	reyna_clue_visual = root


func _spawn_missing_child() -> void:
	if actor_by_id.has("missing_child_tessa"):
		return
	var existing := simulation.get_character("missing_child_tessa")
	var spawn_hex: Vector2i = HOLLOWMERE_PLACEMENTS.MISSING_CHILD_START_HEX
	if existing != null:
		spawn_hex = existing.axial
		if not simulation.unregister_character("missing_child_tessa"):
			push_warning("Could not replace the existing Tessa character state safely.")
			return
	_spawn_character("missing_child_tessa", "Tessa", spawn_hex, false, "", {"params":{"gender":0,"hair":"short02"}})
	var actor := actor_by_id.get("missing_child_tessa") as Node3D
	if actor != null:
		actor.scale = Vector3(0.72, 0.72, 0.72)
		actor.set_meta("ambient_enabled", false)
	var child_state := simulation.get_character("missing_child_tessa")
	if child_state != null:
		child_state.combat_dormant = true
		child_state.side = "neutral"


func _check_reyna_story_proximity() -> void:
	if simulation == null or dialogue_open or encounter_active or simulation.is_in_combat:
		return
	var near_clue := simulation.is_character_within_hex_range(active_character_id, HOLLOWMERE_PLACEMENTS.REYNA_CLUE_HEX, 2)
	var near_shelter := simulation.is_character_within_hex_range(active_character_id, HOLLOWMERE_PLACEMENTS.REYNA_SHELTER_HEX, 2)
	var action := REYNA_RESCUE_SERVICE.proximity_action(
		simulation,
		near_clue,
		near_shelter,
		actor_by_id.has("missing_child_tessa")
	)
	match String(action.get("action", "")):
		"show_trail_clue":
			_ensure_reyna_clue_visual()
		"record_trail_found":
			var recorded := REYNA_RESCUE_SERVICE.record_trail_found(simulation)
			if not bool(recorded.get("ok", false)):
				return
			if is_instance_valid(reyna_clue_visual):
				reyna_clue_visual.queue_free()
			reyna_clue_visual = null
			_show_dialogue("Reyna Fletcher", "A strip of Tessa's blue cloak. And look here — small footprints in the mud, beside the drag marks. She was alive when she left the fence. The trail leads to the old shepherd's shelter. Come on!", [{"id":"continue","label":"Follow the tracks","text":""}])
		"spawn_missing_child":
			_spawn_missing_child()
			_show_speech_bubble("companion_reyna_fletcher", "Tessa? It's Reyna. Stay where you are — we're getting you out.")
			_show_dialogue("Reyna Fletcher", "The shelter door is hanging open. There's a child inside. I can hear her. The dire wolf is circling outside, waiting. Get close and speak softly; don't frighten her.", [{"id":"continue","label":"I'll get her out","text":""}])


func _rescue_missing_child() -> void:
	_close_dialogue()
	var preparation := REYNA_RESCUE_SERVICE.prepare_rescue(simulation)
	if not bool(preparation.get("ok", false)):
		var message := "Tessa isn't here. We need to find the shelter."
		if String(preparation.get("reason", "")) != "missing_child":
			message = "We aren't ready to bring Tessa home yet. We need to find her trail and reach the shelter first."
		_show_dialogue("Reyna Fletcher", message, [{"id": "continue", "label": "Continue", "text": ""}])
		return
	var child_state := simulation.get_character("missing_child_tessa")
	if child_state == null:
		return
	_show_speech_bubble("companion_reyna_fletcher", "I'll draw it away from the door. Get Tessa to Old Mac — don't look back!")
	var destination: Vector2i = HOLLOWMERE_PLACEMENTS.OLD_MAC_RESCUE_DESTINATION_HEX
	var path := simulation.find_path("missing_child_tessa", destination)
	if path.is_empty() and child_state.axial != destination:
		_show_dialogue("Reyna Fletcher", "The way back to Old Mac's farm is blocked. Tessa is still in the shelter; we need a safe route before we can bring her home.", [{"id": "continue", "label": "We'll find another way.", "text": ""}])
		return
	var movement_failed := false
	if path.size() > 1:
		for index in range(1, path.size()):
			if not simulation.try_move_character_step("missing_child_tessa", path[index]):
				movement_failed = true
				break
			await get_tree().create_timer(0.16).timeout
			if not is_instance_valid(self):
				return
	if movement_failed:
		_show_dialogue("Reyna Fletcher", "Something has blocked the route. Tessa is not safe at Old Mac's yet.", [{"id": "continue", "label": "We'll clear the way.", "text": ""}])
		return
	var completion := REYNA_RESCUE_SERVICE.complete_rescue(simulation, destination)
	if not bool(completion.get("ok", false)):
		_show_dialogue("Reyna Fletcher", "Tessa has not reached safety yet. We need to get her all the way back to Old Mac.", [{"id": "continue", "label": "Keep going.", "text": ""}])
		return
	var child_actor := actor_by_id.get("missing_child_tessa") as Node3D
	if child_actor != null:
		child_actor.global_position = _hex_world_position(child_state.axial)
	_show_speech_bubble("missing_child_tessa", "I thought it was going to get me. Thank you.")
	_show_speech_bubble("companion_reyna_fletcher", "She's safe. Now we make sure that thing never comes back.")
	_show_dialogue("Reyna Fletcher", "Tessa is back at Old Mac's farm. She heard the wolf trying to break into the shelter. It has been hunting more than livestock. We finish this now — the beast is still out there, near the fields.", [{"id": "continue", "label": "Then let's end it", "text": ""}])

func _begin_dire_wolf_hunt_combat() -> void:
	_close_dialogue()
	var party_ids: Array[String] = []
	for value in simulation.get_party_member_ids():
		party_ids.append(String(value))
	var result := FARMSTEAD_DIRE_WOLF_SCRIPT.start(simulation, party_ids)
	if not bool(result.get("ok", false)):
		_show_dialogue("Reyna Fletcher", "We cannot face it just now: %s." % String(result.get("reason", "unknown reason")), [{"id":"continue","label":"Continue","text":""}])
		return
	active_combat_session = {"previous_states": result.get("previous_states", {})}
	active_encounter_resolver = Callable(FARMSTEAD_DIRE_WOLF_SCRIPT, "resolve_combat")
	var enemy_ids: Array[String] = [FARMSTEAD_DIRE_WOLF_SCRIPT.DIRE_WOLF_ID]
	var party_ids_active: Array[String] = []
	var controlled_ids: Array[String] = []
	for value in result.get("party_ids", []):
		party_ids_active.append(String(value))
		controlled_ids.append(String(value))
	encounter_active = true
	if not party_ids_active.has(active_character_id):
		active_character_id = "player"
	_activate_combat_controller(enemy_ids, party_ids_active, controlled_ids)
	_update_combat_ui()

func _load_starting_loadouts() -> Dictionary:
	return CampaignCharacterFactory.load_starting_loadouts()


func _spawn_character(id: String, display_name: String, hex: Vector2i, is_player: bool = false, ara_model_id: String = "", npc_profile: Dictionary = {}) -> void:
	var spawn_hex := _find_valid_spawn_hex(hex)
	CampaignCharacterSpawner.spawn_character(
		simulation,
		self,
		actor_by_id,
		player_profile,
		starting_loadouts,
		id,
		display_name,
		spawn_hex,
		_hex_world_position(spawn_hex),
		is_player,
		ara_model_id,
		npc_profile,
		_ambient_role_for_id(id)
	)

func _create_camera() -> void:
	camera_rig = OrbitCameraRig.new()
	camera_rig.name = "OrbitCameraRig"
	camera_rig.max_zoom = 90.0
	camera_rig.zoom_distance = 28.0

	var pitch_pivot := Node3D.new()
	pitch_pivot.name = "PitchPivot"
	camera_rig.add_child(pitch_pivot)

	var camera := Camera3D.new()
	camera.name = "Camera3D"
	camera.current = true
	camera.fov = 55.0
	pitch_pivot.add_child(camera)

	add_child(camera_rig)
	camera_rig.follow_target = actor_by_id["player"]

func _create_camp_presentation() -> void:
	camp_presentation = CAMP_WORLD_PRESENTATION_SCRIPT.new() as CampWorldPresentation
	camp_presentation.name = "CampWorldPresentation"
	camp_presentation.configure(Callable(self, "_hex_world_position"))
	add_child(camp_presentation)
	camp_activity_director = CAMP_PARTY_ACTIVITY_DIRECTOR_SCRIPT.new() as CampPartyActivityDirector
	camp_activity_director.name = "CampPartyActivityDirector"
	camp_activity_director.configure(simulation, Callable(self, "_camp_actor_for_id"))
	camp_activity_director.companion_exchange.connect(_on_camp_companion_exchange)
	add_child(camp_activity_director)
	rowan_world_service = ROWAN_WORLD_SERVICE_SCRIPT.new() as RowanFletcherWorldService
	rowan_world_service.name = "RowanFletcherWorldService"
	add_child(rowan_world_service)
	rowan_world_service.configure(simulation, camp_activity_director, Callable(self, "_show_dialogue"))



## Autonomous companion banter is presented over the characters themselves,
## not as player dialogue. Each speaker gets a turn and both actors are already
## playing their conversation animation when this arrives.
func _create_household_world_service() -> void:
	household_world_service = HOUSEHOLD_WORLD_SERVICE_SCRIPT.new() as CampaignHouseholdWorldService
	household_world_service.name = "CampaignHouseholdWorldService"
	add_child(household_world_service)
	household_world_service.configure(
		simulation, self, actor_by_id, player_profile, starting_loadouts,
		Callable(self, "_hex_world_position"), Callable(self, "_find_valid_spawn_hex")
	)

func _create_camp_lifecycle_controller() -> void:
	camp_lifecycle_controller = CAMP_LIFECYCLE_CONTROLLER_SCRIPT.new() as CampLifecycleController
	camp_lifecycle_controller.name = "CampLifecycleController"
	add_child(camp_lifecycle_controller)
	camp_lifecycle_controller.configure(
		simulation, camp_presentation, camp_activity_director,
		camp_sleep_button, camp_status_label,
		Callable(rowan_world_service, "return_after_night"),
		Callable(self, "_is_encounter_active")
	)

func _is_encounter_active() -> bool:
	return encounter_active

func _on_camp_companion_exchange(exchange: Dictionary) -> void:
	if dialogue_open or encounter_active or simulation == null or simulation.is_in_combat:
		return
	var lines: Array = exchange.get("lines", [])
	for line_value in lines:
		if dialogue_open or encounter_active or simulation == null:
			return
		if simulation.camp_simulation.phase != "evening" or simulation.is_in_combat:
			return
		var line: Dictionary = line_value
		var speaker_id := String(line.get("character_id", ""))
		var text := String(line.get("text", ""))
		if speaker_id.is_empty() or text.is_empty():
			continue
		_show_speech_bubble(speaker_id, text)
		await get_tree().create_timer(CampaignAmbientDialoguePresenter.duration_for_text(text)).timeout



func _camp_actor_for_id(character_id: String) -> AraCharacterActor:
	var actor := actor_by_id.get(character_id) as Node3D
	if actor == null:
		return null
	return actor.get_node_or_null("CharacterModel") as AraCharacterActor


func _toggle_camp_site_selection() -> void:
	if simulation == null or simulation.is_in_combat or simulation.has_pending_reaction():
		return
	if simulation.camp_simulation.phase == "evening" or simulation.camp_simulation.phase == "night":
		if camp_status_label != null:
			camp_status_label.text = "Your camp is already established. Finish the evening or sleep until morning."
		return
	camp_selection_mode = not camp_selection_mode
	if camp_status_label != null:
		camp_status_label.text = "Choose a clear, walkable ground hex for camp." if camp_selection_mode else "Camp placement cancelled."
	if camp_button != null:
		camp_button.text = "Cancel [B]" if camp_selection_mode else "Camp [B]"


func _select_camp_site(hex: Vector2i) -> void:
	camp_selection_mode = false
	if camp_button != null:
		camp_button.text = "Camp [B]"
	var assessment := CampSiteEvaluator.evaluate(
		simulation, hex, _is_upper_floor_hex(hex), _hex_world_position(hex)
	)
	if not bool(assessment.get("ok", false)):
		var reason := String(assessment.get("reason", "unsuitable_ground"))
		camp_status_label.text = "Choose an unoccupied patch of ground." if reason == "site_occupied" else "That ground is unsuitable for a campsite."
		return
	var site: Dictionary = assessment.get("site", {})
	var environment: Dictionary = assessment.get("environment", {})
	for dwelling_site in DWELLING_WORLD_SERVICE.nearby_sites(hex, 3):
		var dwelling_id := String(dwelling_site.get("dwelling_id", ""))
		var dwelling_profile := simulation.campaign_dwellings.camp_profile_for(dwelling_id)
		if not dwelling_profile.is_empty() and bool(dwelling_profile.get("is_sheltered", false)):
			site["dwelling_id"] = dwelling_id
			break
	environment["danger"] = clampf(1.0 - float(ambient_security) / 100.0, 0.05, 0.8)
	var result := simulation.begin_camp(site, environment, {}, active_character_id)
	if not bool(result.get("ok", false)):
		camp_status_label.text = "Could not establish camp: %s" % String(result.get("reason", "unknown"))
		return
	camp_presentation.present_camp(simulation.camp_simulation.site, simulation.camp_simulation.sleeping_arrangements, simulation.camp_simulation.environment)
	camp_activity_director.begin_camp(simulation.camp_simulation.site)
	var weather_summary := _camp_weather_summary(simulation.camp_simulation.environment)
	camp_status_label.text = "Camp established · %s. The party's evening routines will adapt to the conditions." % weather_summary
	if camp_sleep_button != null:
		camp_lifecycle_controller.camp_established() if camp_lifecycle_controller != null else null


func _sleep_or_pack_camp() -> void:
	if camp_lifecycle_controller != null:
		await camp_lifecycle_controller.sleep_or_pack()

func _create_hud() -> void:
	var layer := CanvasLayer.new()
	location_label = Label.new()
	location_label.position = Vector2(22.0, 68.0)
	location_label.text = "LOCATION  /  HOLLOW TANKARD"
	location_label.add_theme_font_size_override("font_size", 20)
	location_label.add_theme_color_override("font_color", Color(0.94, 0.84, 0.62))
	layer.add_child(location_label)

	var menu_button := Button.new()
	menu_button.text = "Menu"
	menu_button.position = Vector2(22.0, 18.0)
	menu_button.custom_minimum_size = Vector2(112.0, 40.0)
	layer.add_child(menu_button)
	var game_menu := PopupMenu.new()
	game_menu.name = "GameMenu"
	game_menu.add_item("Controls", 0)
	game_menu.add_separator()
	game_menu.add_item("Settings — coming later", 1)
	game_menu.add_item("Save game…", 2)
	game_menu.add_item("Load game…", 3)
	game_menu.add_separator()
	game_menu.add_item("Quick save  [F5]", 5)
	game_menu.add_item("Quick load  [F9]", 6)
	game_menu.add_item("Return to main menu — coming later", 4)
	for menu_index in [1, 4]:
		game_menu.set_item_disabled(game_menu.get_item_index(menu_index), true)
	game_menu.id_pressed.connect(_on_game_menu_selected)
	layer.add_child(game_menu)
	menu_button.pressed.connect(func():
		game_menu.position = Vector2i(22, 62)
		game_menu.popup()
	)

	var controls_dialog := AcceptDialog.new()
	controls_dialog.name = "ControlsDialog"
	controls_dialog.title = "Hollow Tankard — Controls"
	controls_dialog.dialog_text = "MOVE\nW / A / S / D / Q / E — move one hex\nClick a walkable hex — plot a path\n[ and ] — turn active character\n\nINTERACT\nF — use nearby door/stairs or talk to nearest person\nG — gather nearby resource\nTab — switch active party member\nC — character sheet\nK — skill trees and skill points\nI — inventory and equipment\n\nCOMBAT\nSpace — attack\nEnter — end turn\n\nWORLD\nV — toggle roof"
	controls_dialog.dialog_text = "MOVE\nW / A / S / D / Q / E — move one hex\nClick a walkable hex — plot a path\n[ and ] — turn active character\n\nINTERACT\nChoose a specific person from the Nearby panel, or press F for the nearest person\nG — gather nearby resource\nTab — switch active party member\nC — character sheet\nI — inventory and equipment\n\nCOMBAT\nSpace — attack\nEnter — end turn\n\nWORLD\nF5 — quick save\nF9 — quick load\nV — toggle roof"
	controls_dialog.min_size = Vector2i(420, 430)
	layer.add_child(controls_dialog)
	game_menu.set_meta("controls_dialog", controls_dialog)

	resource_status_label = Label.new()
	resource_status_label.position = Vector2(22.0, 112.0)
	resource_status_label.custom_minimum_size = Vector2(420.0, 36.0)
	resource_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	resource_status_label.add_theme_color_override("font_color", Color(0.96, 0.88, 0.64))
	layer.add_child(resource_status_label)

	var gather_button := Button.new()
	gather_button.text = "Gather [G]"
	gather_button.position = Vector2(840.0, 18.0)
	gather_button.custom_minimum_size = Vector2(145.0, 42.0)
	gather_button.pressed.connect(_gather_at_player)
	layer.add_child(gather_button)

	party_switch_button = Button.new()
	party_switch_button.text = "Active: You  [Tab] Switch"
	party_switch_button.position = Vector2(145.0, 18.0)
	party_switch_button.custom_minimum_size = Vector2(230.0, 42.0)
	party_switch_button.pressed.connect(_switch_party_member)
	layer.add_child(party_switch_button)

	var character_panel_button := Button.new()
	character_panel_button.text = "Character  [C]"
	character_panel_button.position = Vector2(385.0, 18.0)
	character_panel_button.custom_minimum_size = Vector2(145.0, 42.0)
	character_panel_button.pressed.connect(_open_character_panel)
	layer.add_child(character_panel_button)

	var inventory_panel_button := Button.new()
	inventory_panel_button.text = "Inventory  [I]"
	inventory_panel_button.position = Vector2(540.0, 18.0)
	inventory_panel_button.custom_minimum_size = Vector2(140.0, 42.0)
	inventory_panel_button.pressed.connect(_open_inventory_panel)
	layer.add_child(inventory_panel_button)

	var world_map_button := Button.new()
	world_map_button.text = "World Map"
	world_map_button.position = Vector2(690.0, 18.0)
	world_map_button.custom_minimum_size = Vector2(140.0, 42.0)
	world_map_button.pressed.connect(_toggle_world_map)
	layer.add_child(world_map_button)

	camp_button = Button.new()
	camp_button.text = "Camp [B]"
	camp_button.position = Vector2(990.0, 18.0)
	camp_button.custom_minimum_size = Vector2(125.0, 42.0)
	camp_button.pressed.connect(_toggle_camp_site_selection)
	layer.add_child(camp_button)

	camp_sleep_button = Button.new()
	camp_sleep_button.text = "Sleep until morning"
	camp_sleep_button.position = Vector2(990.0, 66.0)
	camp_sleep_button.custom_minimum_size = Vector2(190.0, 40.0)
	camp_sleep_button.visible = false
	camp_sleep_button.pressed.connect(_sleep_or_pack_camp)
	layer.add_child(camp_sleep_button)

	camp_status_label = Label.new()
	camp_status_label.position = Vector2(990.0, 112.0)
	camp_status_label.custom_minimum_size = Vector2(300.0, 72.0)
	camp_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	camp_status_label.add_theme_color_override("font_color", Color("#f0dfbd"))
	layer.add_child(camp_status_label)

	combat_hud = CampaignCombatHud.new()
	combat_hud.name = "CampaignCombatHud"
	layer.add_child(combat_hud)
	combat_controller = COMBAT_ENCOUNTER_CONTROLLER_SCRIPT.new() as CombatEncounterController
	combat_controller.configure(simulation, combat_hud)
	combat_controller.resolution_check_requested.connect(_check_encounter_resolution)
	combat_hud.attack_requested.connect(_attack_active_character)
	combat_hud.end_turn_requested.connect(_end_active_turn)

	var facing_panel := HBoxContainer.new()
	facing_panel.position = Vector2(22.0, 194.0)
	facing_panel.add_theme_constant_override("separation", 6)
	layer.add_child(facing_panel)

	rotate_left_button = Button.new()
	rotate_left_button.text = "↶ 60°"
	rotate_left_button.tooltip_text = "Turn active character 60 degrees left"
	rotate_left_button.pressed.connect(func(): _rotate_active_character(-1))
	facing_panel.add_child(rotate_left_button)

	rotate_right_button = Button.new()
	rotate_right_button.text = "↷ 60°"
	rotate_right_button.tooltip_text = "Turn active character 60 degrees right"
	rotate_right_button.pressed.connect(func(): _rotate_active_character(1))
	facing_panel.add_child(rotate_right_button)

	# Dedicated zoom controls for laptops and trackpads without a wheel.
	var zoom_panel := HBoxContainer.new()
	zoom_panel.anchor_left = 1.0
	zoom_panel.anchor_right = 1.0
	zoom_panel.offset_left = -292.0
	zoom_panel.offset_top = 18.0
	zoom_panel.offset_right = -18.0
	zoom_panel.offset_bottom = 62.0
	zoom_panel.add_theme_constant_override("separation", 6)
	layer.add_child(zoom_panel)

	var zoom_label := Label.new()
	zoom_label.text = "Zoom"
	zoom_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	zoom_panel.add_child(zoom_label)

	var zoom_out_button := Button.new()
	zoom_out_button.text = "−"
	zoom_out_button.tooltip_text = "Zoom in"
	zoom_out_button.custom_minimum_size = Vector2(42.0, 40.0)
	zoom_out_button.pressed.connect(func(): camera_rig.zoom_by(-1.5))
	zoom_panel.add_child(zoom_out_button)

	zoom_slider = HSlider.new()
	zoom_slider.custom_minimum_size = Vector2(130.0, 40.0)
	zoom_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zoom_slider.min_value = camera_rig.min_zoom
	zoom_slider.max_value = camera_rig.max_zoom
	zoom_slider.step = 0.25
	zoom_slider.value = camera_rig.zoom_distance
	zoom_slider.tooltip_text = "Camera distance"
	zoom_slider.value_changed.connect(_on_zoom_slider_changed)
	zoom_panel.add_child(zoom_slider)
	camera_rig.zoom_changed.connect(_on_camera_zoom_changed)

	var zoom_in_button := Button.new()
	zoom_in_button.text = "+"
	zoom_in_button.tooltip_text = "Zoom out"
	zoom_in_button.custom_minimum_size = Vector2(42.0, 40.0)
	zoom_in_button.pressed.connect(func(): camera_rig.zoom_by(1.5))
	zoom_panel.add_child(zoom_in_button)

	add_child(layer)
	save_load_menu = SAVE_LOAD_MENU_SCRIPT.new() as CanvasLayer
	save_load_menu.name = "SaveLoadMenu"
	add_child(save_load_menu)

	initiative_timeline = INITIATIVE_TIMELINE_SCRIPT.new() as CombatInitiativeTimeline
	initiative_timeline.configure(simulation)
	initiative_timeline.character_selected.connect(_on_initiative_character_selected)
	layer.add_child(initiative_timeline)

	character_panel = CHARACTER_PANEL_SCRIPT.new() as CharacterPanel
	character_panel.name = "CharacterPanel"
	layer.add_child(character_panel)
	character_panel.configure(simulation, active_character_id)
	character_panel.equipment_changed.connect(_on_character_equipment_changed)
	_create_dialogue_panel(layer)
	nearby_interaction_panel = PanelContainer.new()
	nearby_interaction_panel.name = "NearbyNPCInteractions"
	nearby_interaction_panel.position = Vector2(22.0, 244.0)
	nearby_interaction_panel.custom_minimum_size = Vector2(250.0, 0.0)
	nearby_interaction_panel.visible = false
	nearby_interaction_box = VBoxContainer.new()
	nearby_interaction_box.add_theme_constant_override("separation", 4)
	nearby_interaction_panel.add_child(nearby_interaction_box)
	layer.add_child(nearby_interaction_panel)

	world_map_panel = WORLD_MAP_PANEL_SCRIPT.new() as CanvasLayer
	world_map_panel.name = "MainCampaignWorldMap"
	add_child(world_map_panel)

	# Reactions are requested by the simulation and displayed here. The UI
	# never decides eligibility or spends TP; it returns a choice ID only.
	reaction_prompt = REACTION_PROMPT_SCRIPT.new()
	reaction_prompt.name = "ReactionPrompt"
	reaction_prompt.choice_selected.connect(_on_reaction_choice_selected)
	add_child(reaction_prompt)
	_refresh_tavern_floor_presentation()


func _on_game_menu_selected(item_id: int) -> void:
	match item_id:
		0:
			var menu := get_tree().root.find_child("GameMenu", true, false) as PopupMenu
			if menu != null:
				var dialog := menu.get_meta("controls_dialog") as AcceptDialog
				if dialog != null:
					dialog.popup_centered()
		2:
			_open_save_menu()
		3:
			_open_load_menu()
		5:
			_quick_save()
		6:
			_quick_load()

func _open_save_menu() -> void:
	if simulation.is_in_combat or simulation.has_pending_reaction() or dialogue_open or (shakedown_started and not shakedown_resolved):
		_show_save_notice("Save unavailable during combat, dialogue or the opening confrontation.")
		return
	save_load_menu.open_for_save(_build_save_snapshot())

func _open_load_menu() -> void:
	save_load_menu.open_for_load()

func _quick_save() -> void:
	if simulation.is_in_combat or simulation.has_pending_reaction() or dialogue_open or (shakedown_started and not shakedown_resolved):
		_show_save_notice("Quick save unavailable during combat, dialogue or the opening confrontation.")
		return
	var save_manager := _save_manager_service()
	if save_manager == null:
		_show_save_notice("Save service is unavailable.")
		return
	var result: Dictionary = save_manager.call("save_quick", _build_save_snapshot())
	_show_save_notice("Quick save complete." if bool(result.get("ok", false)) else "Quick save failed: %s" % String(result.get("reason", "unknown error")))

func _quick_load() -> void:
	var save_manager := _save_manager_service()
	if save_manager == null:
		_show_save_notice("Save service is unavailable.")
		return
	var result: Dictionary = save_manager.call("load_snapshot", SAVE_MANAGER_SCRIPT.QUICK_SLOT)
	if not bool(result.get("ok", false)):
		_show_save_notice("No usable quick save: %s" % String(result.get("reason", "unknown error")))
		return
	save_manager.call("set_pending_load", result["snapshot"])
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _show_save_notice(message: String) -> void:
	var notice := AcceptDialog.new()
	notice.dialog_text = message
	add_child(notice)
	notice.confirmed.connect(notice.queue_free)
	notice.canceled.connect(notice.queue_free)
	notice.popup_centered()

func _capture_initial_character_baselines() -> void:
	initial_character_baselines = CAMPAIGN_CHARACTER_SAVE_DIFFS.capture_character_baselines(simulation)


func _build_character_diffs() -> Dictionary:
	return CAMPAIGN_CHARACTER_SAVE_DIFFS.build_character_diffs(simulation, initial_character_baselines)


func _build_appearance_diffs() -> Dictionary:
	return CAMPAIGN_CHARACTER_SAVE_DIFFS.build_appearance_diffs(actor_by_id)

func _build_save_snapshot() -> Dictionary:
	return {
		"schema_version": 1,
		"location": "Hollowmere — Hollow Tankard",
		"player_profile": player_profile.duplicate(true),
		"character_diffs": _build_character_diffs(),
		"appearance_diffs": _build_appearance_diffs(),
		"party_member_ids": simulation.get_party_member_ids(),
		"active_character_id": active_character_id,
		"active_party_index": active_party_index,
		"active_multistory_location_id": String(active_multistory_runtime.definition.get("id", "")) if is_instance_valid(active_multistory_runtime) else "",
		"clock": simulation.clock.to_dict(),
		"world_weather": simulation.weather_state.to_dict(),
		"campaign_journal": simulation.campaign_journal.to_dict(),
		"persistent_character_relationships": PERSISTENT_RELATIONSHIP_STORE.to_dict(simulation),
		"companion_campaign_runtime": COMPANION_RUNTIME_STORE.to_dict(simulation),
		"wilderness_resources": simulation.wilderness_resources.to_dict(),
		"multistory_locations": simulation.multistory_location_states_to_dict(),
		"buildings": simulation.building_registry.to_dict(),
		"camp_simulation": simulation.camp_simulation.to_dict(),
		"companion_bonds": simulation.companion_bonds.to_dict(),
		"campaign_dwellings": simulation.campaign_dwellings.to_dict(),
		"dynamic_campaign_characters": _dynamic_campaign_character_records(),
		"world_flags": {
			"ambient_security": ambient_security,
			"shakedown_started": shakedown_started,
			"shakedown_resolved": shakedown_resolved,
			"abandoned_house_journal_read": abandoned_house_journal_read,
			"elder_locket_collected": elder_locket_collected,
			"farm_wolves_spawned": farm_wolves_spawned,
			"farm_wolves_retry_armed": farm_wolves_retry_armed,
			"wilderness_steps_since_spawn": wilderness_creature_spawner.steps_since_spawn if wilderness_creature_spawner != null else 0,
			"rowan_roaming_hex": rowan_world_service.roaming_hex if rowan_world_service != null else INVALID_HEX
		},
		"camera": {
			"zoom_distance": camera_rig.zoom_distance if camera_rig != null else 28.0,
			"rotation": camera_rig.rotation if camera_rig != null else Vector3.ZERO
		},
		"playtime_seconds": 0.0
	}

func _apply_save_data(data: Dictionary) -> void:
	var restore_result := CAMPAIGN_SIMULATION_SNAPSHOT_RESTORER.restore(simulation, data)
	if not bool(restore_result.get("ok", false)):
		push_error("Saved campaign simulation state could not be restored: %s" % String(restore_result.get("reason", "unknown error")))
		return

	# Actor appearance and dynamic actor creation remain presentation/world work.
	var appearance_diffs: Variant = data.get("appearance_diffs", {})
	if appearance_diffs is Dictionary:
		for actor_id_variant in appearance_diffs.keys():
			var actor_id := String(actor_id_variant)
			var actor := actor_by_id.get(actor_id) as Node3D
			if actor == null:
				continue
			var base: Dictionary = actor.get_meta("base_appearance_profile", {})
			var merged_appearance := base.duplicate(true)
			merged_appearance.merge(appearance_diffs[actor_id], true)
			CampaignCharacterActorFactory.apply_npc_parameters(actor, merged_appearance)
	# Dynamic Tessa is saved as a full character record. Recreate her presentation after journal restore.
	if simulation.get_character("missing_child_tessa") != null:
		_spawn_missing_child()

	var flags: Dictionary = data.get("world_flags", {})
	ambient_security = int(flags.get("ambient_security", ambient_security))
	shakedown_started = bool(flags.get("shakedown_started", false))
	shakedown_resolved = bool(flags.get("shakedown_resolved", false))
	abandoned_house_journal_read = bool(flags.get("abandoned_house_journal_read", false))
	elder_locket_collected = bool(flags.get("elder_locket_collected", false)) or _player_has_item(ELDER_LOCKET_PICKUP_SCRIPT.ITEM_ID)
	if is_instance_valid(elder_locket_visual):
		elder_locket_visual.visible = not elder_locket_collected
	farm_wolves_spawned = bool(flags.get("farm_wolves_spawned", false))
	farm_wolves_retry_armed = bool(flags.get("farm_wolves_retry_armed", false))
	if wilderness_creature_spawner != null:
		wilderness_creature_spawner.steps_since_spawn = int(flags.get("wilderness_steps_since_spawn", 0))
	var saved_rowan_hex: Variant = flags.get("rowan_roaming_hex", INVALID_HEX)
	if rowan_world_service != null:
		rowan_world_service.roaming_hex = saved_rowan_hex if saved_rowan_hex is Vector2i else INVALID_HEX
	active_character_id = String(data.get("active_character_id", "player"))
	var restored_party := simulation.get_party_member_ids()
	if not restored_party.has(active_character_id):
		active_character_id = restored_party[0] if not restored_party.is_empty() else "player"
	active_party_index = maxi(0, restored_party.find(active_character_id))
	if party_switch_button != null:
		var active_state := simulation.get_character(active_character_id)
		var active_name := "You" if active_character_id == "player" else (active_state.display_name if active_state != null else active_character_id)
		party_switch_button.text = "Active: " + active_name + "  [Tab] Switch"
	for character_id_variant in actor_by_id.keys():
		var character_id := String(character_id_variant)
		var state := simulation.get_character(character_id)
		var actor := actor_by_id[character_id] as Node3D
		if state == null or actor == null:
			continue
		actor.position = _hex_world_position(state.axial)
		actor.rotation.y = deg_to_rad(float(state.facing_direction - 2) * 60.0)
		CampaignCharacterActorFactory.apply_equipment_visuals(actor, state)
	_restore_farm_wolf_actor_presentations()
	var saved_dire_wolf := simulation.get_character(FARMSTEAD_DIRE_WOLF_SCRIPT.DIRE_WOLF_ID)
	if saved_dire_wolf == null or not saved_dire_wolf.can_act():
		var defeated_wolf_actor := actor_by_id.get(FARMSTEAD_DIRE_WOLF_SCRIPT.DIRE_WOLF_ID) as Node3D
		if is_instance_valid(defeated_wolf_actor):
			defeated_wolf_actor.queue_free()
		actor_by_id.erase(FARMSTEAD_DIRE_WOLF_SCRIPT.DIRE_WOLF_ID)
	camp_lifecycle_controller.restore_saved_camp()
	if camera_rig != null:
		camera_rig.follow_target = actor_by_id.get(active_character_id, actor_by_id.get("player")) as Node3D
		var camera_data: Dictionary = data.get("camera", {})
		camera_rig.zoom_distance = clampf(float(camera_data.get("zoom_distance", camera_rig.zoom_distance)), camera_rig.min_zoom, camera_rig.max_zoom)
		if camera_data.get("rotation", null) is Vector3:
			camera_rig.rotation = camera_data["rotation"]
	if character_panel != null:
		character_panel.set_character(active_character_id)
	_update_combat_ui()
	_refresh_resource_visuals()


func _create_dialogue_panel(layer: CanvasLayer) -> void:
	dialogue_panel = CampaignDialoguePanel.new()
	dialogue_panel.name = "CampaignDialoguePanel"
	layer.add_child(dialogue_panel)

	conversation_controller = CampaignConversationController.new()
	conversation_controller.name = "CampaignConversationController"
	add_child(conversation_controller)
	var configured := conversation_controller.configure(
		dialogue_panel,
		Callable(self, "_portrait_actor_for_speaker"),
		Callable(self, "_select_dialogue_choice")
	)
	if not bool(configured.get("ok", false)):
		push_error("Campaign conversation controller could not configure: %s" % configured)
		return
	conversation_controller.conversation_finished.connect(_on_campaign_conversation_finished)


func _show_dialogue(speaker: String, body: String, choices: Array, expression: String = "neutral") -> void:
	_show_conversation(speaker, "", body, choices, expression, "player")


func _show_conversation(
	speaker: String,
	context: String,
	body: String,
	choices: Array,
	expression: String = "neutral",
	initiation_source: String = "player"
) -> void:
	if conversation_controller == null:
		return
	var result := conversation_controller.present_prompt(
		speaker,
		context,
		body,
		choices,
		expression,
		initiation_source
	)
	dialogue_open = bool(result.get("ok", false))
	if not dialogue_open:
		push_warning("Campaign conversation could not be presented: %s" % result)


func _on_campaign_conversation_finished(_conversation_id: String, _reason: String) -> void:
	dialogue_open = false


func _portrait_actor_for_speaker(speaker: String) -> AraCharacterActor:
	if simulation == null:
		return null
	var speaker_key := speaker.strip_edges().to_lower()
	var speaker_id_key := speaker_key.replace(" ", "_").replace("'", "")
	if speaker_key.is_empty():
		return null
	for actor_id_value in actor_by_id.keys():
		var actor_id := String(actor_id_value)
		var state := simulation.get_character(actor_id)
		if state == null:
			continue
		var state_name := state.display_name.strip_edges().to_lower()
		var matches_name := state_name == speaker_key or state_name.begins_with(speaker_key)
		var matches_id := actor_id.to_lower().contains(speaker_id_key)
		if not matches_name and not matches_id:
			continue
		var actor := actor_by_id.get(actor_id) as Node3D
		if actor == null:
			continue
		var character_model := actor.get_node_or_null("CharacterModel") as AraCharacterActor
		if character_model != null and character_model.get_portrait_texture() != null:
			return character_model
	return null


func _select_dialogue_choice(choice: Dictionary) -> void:
	var choice_id := String(choice.get("id", ""))
	if choice_id.begins_with("rowan_camp:"):
		_resolve_rowan_camp_choice(choice)
		return
	if choice_id.begins_with("tunnel_search:"):
		_handle_tunnel_search(choice_id)
		return
	if choice_id.begins_with("tunnel_enter:") or choice_id.begins_with("tunnel_travel:") or choice_id.begins_with("tunnel_return:"):
		_handle_tunnel_choice(choice_id)
		return
	if choice_id == "continue_camp_sleep":
		if camp_lifecycle_controller != null:
			await camp_lifecycle_controller.continue_sleep_after_ambush()
		return
	if choice_id == "pack_camp_after_ambush":
		if simulation != null:
			await camp_lifecycle_controller.pack_after_ambush()
		return
	if choice_id.begins_with("furniture_buy:") or choice_id.begins_with("dwelling_action:"):
		var dwelling_result := DWELLING_DIALOGUE_SERVICE.resolve_dialogue_choice(
			simulation,
			choice,
			active_character_id
		)
		if bool(dwelling_result.get("handled", false)):
			if bool(dwelling_result.get("refresh_dwelling_world", false)):
				_refresh_dwelling_world_presentation()
			var dwelling_dialogue: Variant = dwelling_result.get("dialogue", {})
			if dwelling_dialogue is Dictionary and not dwelling_dialogue.is_empty():
				_show_dialogue(
					String(dwelling_dialogue.get("speaker", "Property")),
					String(dwelling_dialogue.get("text", "")),
					dwelling_dialogue.get("choices", [])
				)
		return
	if choice_id.begins_with("abandoned_house_"):
		var abandoned_house_result := ABANDONED_HOUSE_DIALOGUE_SERVICE.resolve_choice(simulation, choice)
		if bool(abandoned_house_result.get("handled", false)):
			var abandoned_action := String(abandoned_house_result.get("action", ""))
			if abandoned_action == "restore_guardian_actors":
				_restore_abandoned_house_guardian_actors()
			elif abandoned_action == "begin_encounter":
				_begin_abandoned_house_encounter()
			if bool(abandoned_house_result.get("journal_read", false)):
				abandoned_house_journal_read = true
			var abandoned_dialogue: Variant = abandoned_house_result.get("dialogue", {})
			if abandoned_dialogue is Dictionary and not abandoned_dialogue.is_empty():
				_show_dialogue(
					String(abandoned_dialogue.get("speaker", "Abandoned House")),
					String(abandoned_dialogue.get("text", "")),
					abandoned_dialogue.get("choices", [])
				)
			return
	if _handle_seraphine_choice(choice):
		return
	if _handle_ilsa_choice(choice):
		return
	if choice_id == "wren_arc_topic:why_stay":
		_show_wren_arc_topic("why_stay")
		return
	if choice_id == "wren_arc_topic:parents_reflection":
		_show_wren_arc_topic("parents_reflection")
		return
	var companion_choice_result := COMPANION_DIALOGUE_SERVICE.resolve_dialogue_choice(simulation, choice)
	if bool(companion_choice_result.get("handled", false)):
		var companion_action := String(companion_choice_result.get("action", ""))
		if companion_action == "show_companion_dialogue":
			_show_companion_dialogue(String(companion_choice_result.get("companion_id", "")))
		elif companion_action == "show_wren_dialogue":
			_show_wren_dialogue()
		else:
			var companion_dialogue: Variant = companion_choice_result.get("dialogue", {})
			if companion_dialogue is Dictionary and not companion_dialogue.is_empty():
				_show_dialogue(
					String(companion_dialogue.get("speaker", "Companion")),
					String(companion_dialogue.get("text", "")),
					companion_dialogue.get("choices", [])
				)
		return
	if choice_id.begins_with("start:"):
		var quest_id := choice_id.trim_prefix("start:")
		var start_result := campaign_quest_service.start(quest_id)
		if bool(start_result.get("ok", false)):
			_show_companion_dialogue(String(choice.get("companion_id", "")))
		else:
			_show_dialogue("Campaign journal", "That quest could not be started: %s." % String(start_result.get("reason", "unknown reason")), [{"id":"continue","label":"Continue","text":""}])
		return
	if choice_id.begins_with("recruit:"):
		_recruit_staged_companion(choice_id.trim_prefix("recruit:"))
		return
	var toll_ogre_alive := false
	if choice_id.begins_with("toll_ogre_"):
		toll_ogre_alive = TOLL_TAKER_ENCOUNTER_SCRIPT.is_alive(simulation)
	var local_quest_result := CAMPAIGN_LOCAL_QUEST_DIALOGUE_SERVICE.resolve_choice(
		simulation,
		choice,
		toll_ogre_alive
	)
	if bool(local_quest_result.get("handled", false)):
		if bool(local_quest_result.get("spawn_ogre", false)):
			var ogre_result := TOLL_TAKER_ENCOUNTER_SCRIPT.ensure_ogre(
				simulation,
				_find_valid_spawn_hex(TOLL_TAKER_ENCOUNTER_SCRIPT.OGRE_HEX)
			)
			if not bool(ogre_result.get("ok", false)):
				_show_dialogue("Petra Hollis", "I cannot send you after it until the road is clear enough to reach its camp.", [{"id": "continue", "label": "Understood.", "text": ""}])
				return
			_spawn_toll_ogre_actor()
		var local_status := String(local_quest_result.get("status_message", ""))
		if not local_status.is_empty() and resource_status_label != null:
			resource_status_label.text = local_status
		var local_dialogue: Variant = local_quest_result.get("dialogue", {})
		if local_dialogue is Dictionary and not local_dialogue.is_empty():
			_show_dialogue(
				String(local_dialogue.get("speaker", "Campaign")),
				String(local_dialogue.get("text", "")),
				local_dialogue.get("choices", [])
			)
		elif bool(local_quest_result.get("close", false)):
			_close_dialogue()
		return
	var ambassador_result := CAMPAIGN_AMBASSADOR_DIALOGUE_SERVICE.resolve_choice(simulation, choice)
	if bool(ambassador_result.get("handled", false)):
		var status_message := String(ambassador_result.get("status_message", ""))
		if not status_message.is_empty() and resource_status_label != null:
			resource_status_label.text = status_message
		var ambassador_dialogue: Variant = ambassador_result.get("dialogue", {})
		if ambassador_dialogue is Dictionary and not ambassador_dialogue.is_empty():
			_show_dialogue(
				String(ambassador_dialogue.get("speaker", "Campaign")),
				String(ambassador_dialogue.get("text", "")),
				ambassador_dialogue.get("choices", [])
			)
		elif bool(ambassador_result.get("close", false)):
			_close_dialogue()
		return
	if choice_id == "reyna_rescue_child":
		await _rescue_missing_child()
		return
	if choice_id == "fight" or choice.has("ironbond_delta"):
		var shakedown_result := HOLLOWMERE_SHAKEDOWN_DIALOGUE_SERVICE.resolve_choice(simulation, choice)
		if bool(shakedown_result.get("handled", false)):
			if not bool(shakedown_result.get("ok", false)):
				_show_dialogue("Hollowmere", "The choice could not be recorded: %s." % String(shakedown_result.get("reason", "unknown error")).replace("_", " "), [{"id": "continue", "label": "Continue", "text": ""}])
				return
			shakedown_resolved = true
			_record_wren_authored_event(String(shakedown_result.get("event_key", "")))
			if String(shakedown_result.get("action", "")) == "begin_combat":
				_begin_shakedown_combat()
			else:
				await _move_shakedown_soldiers_outside()
				var response := String(shakedown_result.get("response", ""))
				if response.is_empty():
					response = "The soldiers take their due and leave the tavern."
				_show_dialogue("Hollowmere", response, [{"id": "continue", "label": "Continue", "text": ""}])
			return
	if choice_id == "conversation_end" or choice_id == "continue":
		_close_dialogue()
		return

	var response_text := String(choice.get("text", ""))
	if choice_id == "spar":
		response_text += "\n\nA full sparring encounter is not connected to the 3D combat interface yet."
	_show_dialogue(dialogue_panel.speaker_text, response_text, [{"id": "continue", "label": "Continue", "text": ""}])

func _handle_seraphine_choice(choice: Dictionary) -> bool:
	var choice_id := String(choice.get("id", ""))
	if not choice_id.begins_with("seraphine_"):
		return false
	var content := PERSISTENT_DIALOGUE_CONTENT.new()
	var result: Dictionary = content.resolve_seraphine_campaign_choice_from_state(
		simulation,
		choice_id,
		PERSISTENT_RELATIONSHIP_STORE.state_for(simulation),
		active_character_id
	)
	if not bool(result.get("handled", false)):
		return false
	if bool(result.get("close", false)):
		_close_dialogue()
		return true
	if bool(result.get("refresh_dwelling_world", false)):
		_refresh_dwelling_world_presentation()
	var dialogue: Dictionary = result.get("dialogue", {})
	if dialogue.is_empty():
		return true
	var choices: Array = dialogue.get("choices", [])
	if choices.is_empty():
		choices = [{"id":"continue","label":String(dialogue.get("response_label", "Continue")),"kind":"leave"}]
	_show_dialogue(
		String(dialogue.get("speaker", "Queen Seraphine Corrin")),
		String(dialogue.get("text", "")),
		choices
	)
	return true

func _handle_ilsa_choice(choice: Dictionary) -> bool:
	var choice_id := String(choice.get("id", ""))
	if not choice_id.begins_with("ilsa_"):
		return false
	var relationships := PERSISTENT_RELATIONSHIP_STORE.state_for(simulation)
	var response := ILSA_WATCH_CAPTAIN_CONTENT_SCRIPT.resolve_choice(simulation.campaign_journal, relationships, choice_id)
	if not bool(response.get("ok", false)):
		_show_dialogue("Captain Ilsa Rennick", "That matter cannot be discussed just now.", [{"id": "ilsa_leave", "label": "Understood."}])
		return true
	if bool(response.get("close", false)):
		_close_dialogue()
		return true
	_show_dialogue(
		String(response.get("speaker", "Captain Ilsa Rennick")),
		String(response.get("text", "")),
		response.get("choices", [{"id": "ilsa_leave", "label": "Understood."}])
	)
	return true

func _show_rowan_camp_encounter() -> void:
	if rowan_world_service != null:
		rowan_world_service.show_camp_encounter()

func _resolve_rowan_camp_choice(choice: Dictionary) -> void:
	if rowan_world_service != null:
		rowan_world_service.resolve_camp_choice(choice)

func _close_dialogue() -> void:
	if conversation_controller != null:
		if conversation_controller.session.active:
			conversation_controller.finish_conversation("closed")
		else:
			dialogue_open = false
		return
	dialogue_open = false
	if dialogue_panel != null:
		dialogue_panel.dismiss()


func _interact_with_nearest_npc() -> void:
	if dialogue_open or ambient_exchange_running or encounter_active or shakedown_started and not shakedown_resolved:
		return
	var player_state := simulation.get_character(active_character_id)
	if player_state == null:
		return
	var nearest_id := ""
	var nearest_distance := 999
	for actor_id_value in actor_by_id.keys():
		var actor_id := String(actor_id_value)
		if actor_id == active_character_id or simulation.is_party_member(actor_id):
			continue
		var state := simulation.get_character(actor_id)
		if state == null or not state.can_act():
			continue
		if state.side == "enemy" and actor_id not in [FARMSTEAD_DIRE_WOLF_SCRIPT.DIRE_WOLF_ID, TOLL_TAKER_ENCOUNTER_SCRIPT.OGRE_ID]:
			continue
		var distance := simulation.hex_distance(player_state.axial, state.axial)
		if distance <= 2 and distance < nearest_distance:
			nearest_distance = distance
			nearest_id = actor_id
	if nearest_id.is_empty():
		_show_dialogue("No one nearby", "Move closer to someone if you want to speak with them.", [{"id": "continue", "label": "Close", "text": ""}])
		return
	_interact_with_character(nearest_id)


func _interact_with_character(character_id: String) -> void:
	if dialogue_open or ambient_exchange_running or encounter_active:
		return
	var player_state := simulation.get_character(active_character_id)
	var target_state := simulation.get_character(character_id)
	if player_state == null or target_state == null or not simulation.are_characters_within_hex_range(active_character_id, character_id, 2):
		return
	if character_id == "steward_halvard_greer":
		_show_halvard_household_dialogue()
		return
	if character_id == "rowan_fletcher":
		_show_rowan_camp_encounter()
		return
	if character_id == TOLL_TAKER_ENCOUNTER_SCRIPT.OGRE_ID:
		_begin_toll_taker_encounter()
		return
	if character_id == FARMSTEAD_DIRE_WOLF_SCRIPT.DIRE_WOLF_ID:
		if not REYNA_RESCUE_SERVICE.objective_complete(simulation, "child_rescued"): 
			_show_dialogue("Dire wolf", "The dire wolf circles the shepherd's shelter. You cannot safely engage it while Tessa is still inside.", [{"id":"continue","label":"Understood","text":""}])
			return
		_begin_dire_wolf_hunt_combat()
		return
	if character_id == "missing_child_tessa":
		if REYNA_RESCUE_SERVICE.objective_complete(simulation, "child_rescued"):
			_show_dialogue("Tessa", "Reyna said you were the one who got me out. I don't think I'll ever forget that.", [{"id":"continue","label":"You're safe now","text":""}], "smile")
		else:
			_show_dialogue("Tessa", "Please... it's outside. I can hear it moving around. Reyna said to stay quiet.", [{"id":"reyna_rescue_child","label":"Come with me. We'll get you home.","text":""}], "afraid")
		return
	if character_id in ["companion_wren_talbot", "wren_talbot"]:
		_show_wren_dialogue()
		return
	var chapter_consultation := COMPANION_DIALOGUE_SERVICE.consult_for_actor(simulation, character_id, target_state.display_name)
	if bool(chapter_consultation.get("ok", false)):
		var consultation_text := String(chapter_consultation.get("text", ""))
		var consultation_prompt := String(chapter_consultation.get("prompt", ""))
		if not consultation_prompt.is_empty():
			consultation_text += "\n\n" + consultation_prompt
		_show_dialogue(String(chapter_consultation.get("actor", target_state.display_name)), consultation_text, [{"id":"continue","label":"I'll speak with them.","text":""}])
		return
	if COMPANION_CAMPAIGN_SCRIPT.is_companion_id(character_id):
		_show_companion_dialogue(character_id)
		return
	var streamed_actor := _find_streamed_npc_actor(character_id)
	if streamed_actor != null and not actor_by_id.has(character_id):
		_show_streamed_npc_dialogue(streamed_actor, target_state)
		return
	if character_id == "old_mac":
		var farm_conversation := FARM_WOLVES_QUEST_SCRIPT.greeting(simulation.campaign_journal, _farm_wolves_remaining())
		_show_dialogue(String(farm_conversation.get("speaker", "Old Mac")), String(farm_conversation.get("text", "")), farm_conversation.get("choices", []))
		return
	if character_id in ["elder_marta", "marta_wynfield"]:
		var message_delivery := ALDENREACH_MESSAGE_CONTENT_SCRIPT.deliver_to_elder(simulation.campaign_journal)
		if bool(message_delivery.get("delivered_now", false)) and resource_status_label != null:
			resource_status_label.text = "Delivered Ambassador Cassia Wren's quiet word to Elder Marta."
		var marta_player := simulation.get_character(simulation.player_character_id)
		var marta_conversation := ELDER_MARTA_CONTENT_SCRIPT.greeting(simulation.campaign_journal, marta_player)
		if bool(marta_conversation.get("ok", false)):
			_show_dialogue(String(marta_conversation.get("speaker", "Elder Marta Wynfield")), String(marta_conversation.get("text", "")), marta_conversation.get("choices", []))
		return
	var conversation := HollowmereCampaignContent.npc_greeting_from_journal(
		simulation.campaign_journal,
		character_id,
		shakedown_resolved
	)
	var choices: Array[Dictionary] = []
	for choice_value in conversation.get("choices", []):
		var choice: Dictionary = choice_value
		choices.append(choice.duplicate(true))
	_show_dialogue(String(conversation.get("speaker", target_state.display_name)), String(conversation.get("text", "")), choices)

func _refresh_nearby_interactions() -> void:
	if nearby_interaction_panel == null or nearby_interaction_box == null or simulation == null:
		return
	if dialogue_open or encounter_active or simulation.is_in_combat:
		nearby_interaction_panel.visible = false
		return
	var active_state := simulation.get_character(active_character_id)
	if active_state == null:
		nearby_interaction_panel.visible = false
		return
	var nearby: Array[Dictionary] = NPC_INTERACTION_SERVICE.nearby_entries(
		simulation,
		active_character_id,
		actor_by_id,
		get_tree(),
		2
	)
	# Hostile campaign actors are handled by their encounter-specific systems;
	# the existing dire wolf is the one local exception with a direct engage UI.
	for index in range(nearby.size() - 1, -1, -1):
		if bool(nearby[index].get("hostile", false)) and String(nearby[index].get("id", "")) not in [FARMSTEAD_DIRE_WOLF_SCRIPT.DIRE_WOLF_ID, TOLL_TAKER_ENCOUNTER_SCRIPT.OGRE_ID]:
			nearby.remove_at(index)
	for child in nearby_interaction_box.get_children():
		child.free()
	# Party members are normally excluded from the NPC interaction service.
	# Keep nearby companion conversations reachable without switching control.
	for party_id_value in simulation.get_party_member_ids():
		var party_id := String(party_id_value)
		if party_id == active_character_id:
			continue
		if not COMPANION_CAMPAIGN_SCRIPT.is_companion_id(party_id) and party_id != "companion_wren_talbot":
			continue
		var party_state := simulation.get_character(party_id)
		if party_state == null or not simulation.are_characters_within_hex_range(active_character_id, party_id, 2):
			continue
		var already_listed := false
		for entry_value in nearby:
			if String(entry_value.get("id", "")) == party_id:
				already_listed = true
				break
		if not already_listed:
			nearby.push_front({"id":party_id,"name":party_state.display_name,"hostile":false})
	var nearby_sites := DWELLING_WORLD_SERVICE.nearby_sites(active_state.axial, 3)
	if nearby.is_empty() and nearby_sites.is_empty():
		nearby_interaction_panel.visible = false
		return
	if not nearby.is_empty():
		var heading := Label.new()
		heading.text = "NEARBY PEOPLE"
		heading.add_theme_color_override("font_color", Color(0.94, 0.84, 0.62))
		nearby_interaction_box.add_child(heading)
		for index in range(mini(nearby.size(), 6)):
			var entry: Dictionary = nearby[index]
			var target_id := String(entry.id)
			var talk_button := Button.new()
			talk_button.text = ("Engage · " if bool(entry.hostile) else "Talk · ") + String(entry.name)
			talk_button.custom_minimum_size = Vector2(225.0, 34.0)
			talk_button.pressed.connect(_on_nearby_interaction_pressed.bind(target_id))
			nearby_interaction_box.add_child(talk_button)
	if not nearby_sites.is_empty():
		var property_heading := Label.new()
		property_heading.text = "NEARBY LOCATIONS"
		property_heading.add_theme_color_override("font_color", Color(0.94, 0.84, 0.62))
		nearby_interaction_box.add_child(property_heading)
		for site in nearby_sites:
			var site_id := String(site.get("id", ""))
			var inspect_button := Button.new()
			inspect_button.text = "Inspect · " + String(site.get("name", "Property"))
			inspect_button.custom_minimum_size = Vector2(225.0, 34.0)
			inspect_button.pressed.connect(_on_nearby_dwelling_site_pressed.bind(site_id))
			nearby_interaction_box.add_child(inspect_button)
	nearby_interaction_panel.visible = true


func _on_nearby_interaction_pressed(character_id: String) -> void:
	_interact_with_character(character_id)


func _find_streamed_npc_actor(character_id: String) -> Node3D:
	return NPC_INTERACTION_SERVICE.actor_for(get_tree(), actor_by_id, character_id)


func _show_streamed_npc_dialogue(actor: Node3D, target_state: CharacterState) -> void:
	if actor == null or target_state == null:
		return
	var dialogue_id := String(actor.get_meta("dialogue_id", ""))
	if dialogue_id == "dray_coltayne":
		var courier_conversation := IRONBOND_MISSING_COURIER_CONTENT_SCRIPT.greeting(simulation.campaign_journal)
		if bool(courier_conversation.get("ok", false)):
			_show_dialogue(String(courier_conversation.get("speaker", target_state.display_name)), String(courier_conversation.get("text", "")), courier_conversation.get("choices", []))
		return
	if dialogue_id == "petra_hollis":
		var petra_conversation := TOLL_TAKER_CONTENT_SCRIPT.greeting(simulation.campaign_journal, TOLL_TAKER_ENCOUNTER_SCRIPT.is_alive(simulation))
		if bool(petra_conversation.get("ok", false)):
			_show_dialogue(String(petra_conversation.get("speaker", target_state.display_name)), String(petra_conversation.get("text", "")), petra_conversation.get("choices", []))
		return
	if dialogue_id == "reddale_innkeeper": 
		var nella_conversation := NELLA_CONTENT_SCRIPT.greeting(simulation.campaign_journal, simulation.get_character(simulation.player_character_id), abandoned_house_journal_read)
		if bool(nella_conversation.get("ok", false)):
			_show_dialogue(String(nella_conversation.get("speaker", target_state.display_name)), String(nella_conversation.get("text", "")), nella_conversation.get("choices", []))
		return
	if dialogue_id == "reddale_baron":
		var baron_conversation := BARON_TRIBUTE_CONTENT_SCRIPT.greeting(simulation.campaign_journal, simulation.get_character(simulation.player_character_id))
		if bool(baron_conversation.get("ok", false)):
			_show_dialogue(String(baron_conversation.get("speaker", target_state.display_name)), String(baron_conversation.get("text", "")), baron_conversation.get("choices", []))
		return
	if dialogue_id == "dwarven_ambassador":
		var brokk_conversation := DWARVEN_AMBASSADOR_CONTENT_SCRIPT.greeting(simulation.campaign_journal, simulation.get_character(simulation.player_character_id))
		if bool(brokk_conversation.get("ok", false)):
			_show_dialogue(String(brokk_conversation.get("speaker", target_state.display_name)), String(brokk_conversation.get("text", "")), brokk_conversation.get("choices", []))
		return
	if dialogue_id == "corvane_ambassador":
		var toren_conversation := CORVANE_AMBASSADOR_CONTENT_SCRIPT.greeting(simulation.campaign_journal, simulation.get_character(simulation.player_character_id))
		if bool(toren_conversation.get("ok", false)):
			_show_dialogue(String(toren_conversation.get("speaker", target_state.display_name)), String(toren_conversation.get("text", "")), toren_conversation.get("choices", []))
		return
	if dialogue_id == "reddale_captain":
		var ilsa_relationships := PERSISTENT_RELATIONSHIP_STORE.state_for(simulation)
		var ilsa_conversation := ILSA_WATCH_CAPTAIN_CONTENT_SCRIPT.greeting(simulation.campaign_journal, ilsa_relationships)
		if bool(ilsa_conversation.get("ok", false)):
			_show_dialogue(String(ilsa_conversation.get("speaker", target_state.display_name)), String(ilsa_conversation.get("text", "")), ilsa_conversation.get("choices", []))
		return
	if dialogue_id == "aldenreach_ambassador":
		var cassia_conversation := ALDENREACH_MESSAGE_CONTENT_SCRIPT.greeting(simulation.campaign_journal)
		_show_dialogue(String(cassia_conversation.get("speaker", target_state.display_name)), String(cassia_conversation.get("text", "")), cassia_conversation.get("choices", []))
		return
	if dialogue_id == "silverhart_queen":
		var relationships := PERSISTENT_RELATIONSHIP_STORE.state_for(simulation)
		var content := PERSISTENT_DIALOGUE_CONTENT.new()
		var conversation: Dictionary = content.seraphine_greeting_from_simulation(simulation, relationships)
		if bool(conversation.get("ok", false)):
			var supported_choices: Array[Dictionary] = []
			for choice_value in conversation.get("choices", []):
				var choice: Dictionary = choice_value
				if String(choice.get("id", "")) in ["seraphine_topic_greenskins", "seraphine_topic_ironbond", "seraphine_topic_necromancy", "seraphine_personal_burden", "seraphine_request_favour", "seraphine_manor_followup", "seraphine_leave"]:
					supported_choices.append(choice)
			_show_dialogue(String(conversation.get("speaker", target_state.display_name)), String(conversation.get("text", "")), supported_choices)
		else:
			_show_dialogue(String(conversation.get("speaker", target_state.display_name)), String(conversation.get("text", "The Queen has no audience for you.")), conversation.get("choices", [{"id":"continue","label":"Leave","kind":"leave"}]))
		return
	var title := String(actor.get_meta("title", ""))
	var body := "They regard you with measured curiosity, but have little to say just now."
	if not title.is_empty():
		body = "%s acknowledges you. Their duties leave little time for conversation." % title
	_show_dialogue(target_state.display_name, body, [{"id":"continue","label":"Continue","kind":"leave"}])


func _player_has_item(item_id: String) -> bool:
	var player := simulation.get_character(simulation.player_character_id)
	if player == null:
		return false
	for item in player.inventory:
		if String(item.get("id", "")) == item_id:
			return true
	return false


func _show_companion_dialogue(character_id: String) -> void:
	var canonical_id := character_id.trim_prefix("companion_")
	if canonical_id == "wren_talbot":
		_show_wren_dialogue()
		return
	var player_state := simulation.get_character("player")
	if player_state == null:
		return
	var conversation: Dictionary = COMPANION_CAMPAIGN_SCRIPT.conversation(
		character_id,
		simulation.campaign_journal,
		player_state.inventory,
		simulation.get_party_member_ids()
	)
	if conversation.is_empty():
		return
	var relationships := COMPANION_RUNTIME_STORE.relationship_state_for(simulation)
	var relationship_line := ""
	if relationships != null and relationships.has_profile(canonical_id):
		var conversation_key := "world_talk:" + str(int(simulation.clock.world_seconds))
		if canonical_id == "wren_talbot":
			relationships.note_personal_dialogue(canonical_id, conversation_key)
		else:
			relationships.note_conversation(canonical_id, conversation_key, 2.0)
		relationship_line = String(relationships.interpret_relationship(canonical_id).get("line", ""))
	var body := String(conversation.get("text", ""))
	if not relationship_line.is_empty():
		body += "\n\n" + relationship_line
	var choices: Array[Dictionary] = []
	for choice_value in conversation.get("choices", []):
		var choice: Dictionary = choice_value.duplicate(true)
		if String(choice.get("id", "")).begins_with("start:"):
			choice["companion_id"] = character_id
		choices.append(choice)
	var chapter_dialogue := COMPANION_DIALOGUE_SERVICE.chapter_dialogue_for_companion(simulation, character_id)
	if not chapter_dialogue.is_empty():
		body += String(chapter_dialogue.get("body", ""))
		for chapter_choice_value in chapter_dialogue.get("choices", []):
			choices.append(chapter_choice_value.duplicate(true))
	_show_dialogue(String(conversation.get("speaker", character_id)), body, choices)


func _show_wren_dialogue() -> void:
	var arc := COMPANION_RUNTIME_STORE.wren_arc_state_for(simulation)
	var relationships := COMPANION_RUNTIME_STORE.relationship_state_for(simulation)
	if arc == null:
		return
	if relationships != null:
		arc.sync_story_events(relationships)
		relationships.note_personal_dialogue("wren_talbot", "wren_personal_talk:" + str(int(simulation.clock.world_seconds)))
	var choices := arc.dialogue_topics(relationships, simulation.campaign_journal)
	choices.append({"id":"continue","label":"Nothing else for now.","text":""})
	_show_dialogue("Wren Talbot", "What's on your mind?", choices)


func _show_wren_arc_topic(topic_id: String) -> void:
	var arc := COMPANION_RUNTIME_STORE.wren_arc_state_for(simulation)
	var relationships := COMPANION_RUNTIME_STORE.relationship_state_for(simulation)
	if arc == null:
		return
	var body := arc.why_stays_line(relationships) if topic_id == "why_stay" else arc.parents_reflection_line()
	var choices := arc.dialogue_options_for_topic(topic_id)
	if choices.is_empty():
		choices.append({"id":"continue","label":"I understand.","text":""})
	_show_dialogue("Wren Talbot", body, choices)


func _recruit_staged_companion(character_id: String) -> void:
	var recruit_result: Dictionary = COMPANION_CAMPAIGN_SCRIPT.recruit_staged_companion(simulation, character_id)
	var state := simulation.get_character(character_id)
	if not bool(recruit_result.get("ok", false)):
		var reason := String(recruit_result.get("reason", "recruitment_failed"))
		if reason == "insufficient_herbs" or reason == "fenn_quest_not_active":
			_show_companion_dialogue(character_id)
			return
		if reason == "already_in_party" and state != null:
			_show_dialogue(state.display_name, "I'm already travelling with you.", [{"id":"continue","label":"Continue","text":""}])
		elif reason == "unknown_character":
			_show_dialogue("Recruitment", "That companion is not present in this location.", [{"id":"continue","label":"Continue","text":""}])
		elif state != null:
			_show_dialogue("Recruitment", "Could not recruit %s: %s." % [state.display_name, reason], [{"id":"continue","label":"Continue","text":""}])
		return
	if state == null:
		return
	var actor := actor_by_id.get(character_id) as Node3D
	if actor != null:
		actor.set_meta("ambient_enabled", false)
	if party_switch_button != null and active_character_id == character_id:
		party_switch_button.text = "Active: %s  [Tab] Switch" % state.display_name
	if character_panel != null and active_character_id == character_id:
		character_panel.set_character(active_character_id)
	_show_dialogue(state.display_name, "%s joins your party. Their existing skills and equipment are preserved; future skill points are yours to allocate." % state.display_name, [{"id":"continue","label":"Continue","text":""}])


func _record_wren_authored_event(event_key: String) -> void:
	var relationships := COMPANION_RUNTIME_STORE.relationship_state_for(simulation)
	if relationships == null:
		return
	var result := relationships.apply_wren_authored_event(event_key)
	if not bool(result.get("ok", false)) and String(result.get("reason", "")) != "unknown_wren_event":
		push_warning("Could not apply Wren campaign relationship event %s: %s" % [event_key, result])
	var character_arc := COMPANION_RUNTIME_STORE.wren_arc_state_for(simulation)
	if character_arc != null:
		character_arc.sync_story_events(relationships)

func _run_opening_sequence() -> void:
	var player_state := simulation.get_character("player")
	if player_state == null or player_state.race in ["goblin", "orc"]:
		return
	hollowmere_opening_sequence = HOLLOWMERE_OPENING_SEQUENCE_SCRIPT.new() as HollowmereOpeningSequenceController
	hollowmere_opening_sequence.name = "HollowmereOpeningSequence"
	hollowmere_opening_sequence.shakedown_started.connect(_on_opening_shakedown_started)
	add_child(hollowmere_opening_sequence)
	hollowmere_opening_sequence.begin(
		String(player_state.race),
		Callable(self, "_start_hollowmere_shakedown_quest"),
		Callable(self, "_show_speech_bubble"),
		Callable(self, "_move_shakedown_soldiers_inside"),
		Callable(self, "_show_hollowmere_opening_choice"),
		Callable(self, "_is_shakedown_resolved")
	)


func _on_opening_shakedown_started() -> void:
	shakedown_started = true


func _start_hollowmere_shakedown_quest() -> void:
	if campaign_quest_service != null:
		campaign_quest_service.start(HollowmereCampaignContent.QUEST_ID)


func _show_hollowmere_opening_choice() -> void:
	_show_conversation(
		"Dray Coltayne",
		HOLLOWMERE_OPENING_CONTEXT.TEXT,
		"What do you do?",
		HollowmereCampaignContent.shakedown_choices(),
		"neutral",
		"npc"
	)


func _is_shakedown_resolved() -> bool:
	return shakedown_resolved


func _move_shakedown_soldiers_outside() -> void:
	for index in range(HOLLOWMERE_ENCOUNTER_SCRIPT.ENEMY_IDS.size()):
		var character_id := HOLLOWMERE_ENCOUNTER_SCRIPT.ENEMY_IDS[index]
		var destination: Vector2i = HOLLOWMERE_PLACEMENTS.SHAKEDOWN_SOLDIER_WAIT_HEXES[index]
		var path := simulation.find_path(character_id, destination)
		for step_index in range(1, path.size()):
			if not simulation.try_move_character_step(character_id, path[step_index]):
				break
			await get_tree().create_timer(0.24).timeout
			if not is_instance_valid(self):
				return


func _move_shakedown_soldiers_inside() -> void:
	# The source opening has the soldiers open the locked front door, enter on
	# foot, then close it behind them. Unlocking is permanent so the player can
	# open it from inside and leave after the encounter.
	var tavern_door := simulation.building_registry.get_door(TAVERN_FRONT_DOOR_ID)
	if tavern_door == null:
		push_error("Hollowmere shakedown cannot open the missing Tankard front door.")
		return
	if tavern_door.locked and not simulation.building_registry.unlock_door(TAVERN_FRONT_DOOR_ID):
		push_error("Hollowmere shakedown could not unlock the Tankard front door.")
		return
	if not tavern_door.is_passable() and not simulation.building_registry.set_door_open(TAVERN_FRONT_DOOR_ID, true):
		push_error("Hollowmere shakedown could not open the Tankard front door.")
		return
	for index in range(HOLLOWMERE_ENCOUNTER_SCRIPT.ENEMY_IDS.size()):
		var character_id := HOLLOWMERE_ENCOUNTER_SCRIPT.ENEMY_IDS[index]
		var best_path: Array[Vector2i] = []
		var destinations: Array[Vector2i] = [HOLLOWMERE_PLACEMENTS.SHAKEDOWN_SOLDIER_INTERIOR_PREFERRED_HEXES[index]]
		destinations.append_array(HOLLOWMERE_PLACEMENTS.SHAKEDOWN_SOLDIER_INTERIOR_FALLBACK_HEXES)
		for destination in destinations:
			if not simulation.map_data.is_walkable(destination) or simulation.is_hex_occupied(destination):
				continue
			var path := simulation.find_path(character_id, destination)
			if path.size() > 1 and (best_path.is_empty() or path.size() < best_path.size()):
				best_path = path
		for step_index in range(1, best_path.size()):
			if not simulation.try_move_character_step(character_id, best_path[step_index]):
				break
			await get_tree().create_timer(0.24).timeout
			if not is_instance_valid(self):
				return
	# Re-close the door once the soldiers have passed through. It stays
	# unlocked, matching the source behaviour that lets the player leave later.
	if tavern_door != null and tavern_door.is_passable() and not simulation.is_hex_occupied(tavern_door.hex):
		simulation.building_registry.set_door_open(TAVERN_FRONT_DOOR_ID, false)


func _show_speech_bubble(character_id: String, text: String) -> Dictionary:
	var actor := actor_by_id.get(character_id) as Node3D
	if actor == null or ambient_dialogue_presenter == null:
		return {"ok": false, "reason": "missing_speaker_actor"}
	return ambient_dialogue_presenter.present_line(actor, text)


func _ambient_role_for_id(character_id: String) -> String:
	if character_id in ["dray_coltayne", "tomlin_brask", "hask_greel"]:
		return "guard"
	if character_id == "garrick_holt":
		return "merchant"
	if character_id == "wick_hallow":
		return "merchant"
	if character_id == "companion_wren_talbot":
		return "civilian"
	return "civilian"


func _update_ambient_chatter(delta: float) -> void:
	if dialogue_open or shakedown_started and not shakedown_resolved or simulation == null or simulation.is_in_combat or simulation.clock.paused or ambient_exchange_running:
		return
	ambient_accumulator += delta
	if ambient_accumulator < 16.0:
		return
	ambient_accumulator = 0.0
	var candidates: Array[String] = []
	for actor_id_value in actor_by_id.keys():
		var actor_id := String(actor_id_value)
		var actor := actor_by_id.get(actor_id) as Node3D
		var state := simulation.get_character(actor_id)
		if actor != null and bool(actor.get_meta("ambient_enabled", false)) and state != null and state.can_act() and state.side == "neutral":
			candidates.append(actor_id)
	if candidates.size() < 2:
		return
	var pairs: Array[Array] = []
	for i in range(candidates.size()):
		for j in range(i + 1, candidates.size()):
			var first_state := simulation.get_character(candidates[i])
			var second_state := simulation.get_character(candidates[j])
			if first_state != null and second_state != null and simulation.are_characters_within_hex_range(candidates[i], candidates[j], 2):
				pairs.append([candidates[i], candidates[j]])
	if pairs.is_empty():
		return
	var pair: Array = pairs[ambient_rng.randi_range(0, pairs.size() - 1)]
	var first_id := String(pair[0])
	var second_id := String(pair[1])
	var first_actor := actor_by_id.get(first_id) as Node3D
	var second_actor := actor_by_id.get(second_id) as Node3D
	var hour := int(fposmod(simulation.clock.world_seconds, 86400.0) / 3600.0)
	var quest_state := campaign_quest_service.state(HollowmereCampaignContent.QUEST_ID)
	var decisions: Dictionary = quest_state.get("decisions", {})
	var response_choice := String(decisions.get("response", ""))
	var exchange := ambient_chatter.choose_exchange(
		first_id, second_id,
		String(first_actor.get_meta("ambient_role", "civilian")),
		String(second_actor.get_meta("ambient_role", "civilian")),
		simulation.clock.world_seconds, hour, ambient_security, shakedown_resolved, ambient_rng, response_choice
	)
	if exchange.is_empty():
		return
	ambient_chatter.record_exchange(exchange, first_id, second_id, simulation.clock.world_seconds)
	_run_ambient_exchange(first_id, second_id, exchange)


func _run_ambient_exchange(first_id: String, second_id: String, exchange: Dictionary) -> void:
	ambient_exchange_running = true
	var lines: Array = exchange.get("lines", [])
	for index in range(lines.size()):
		var speaker_id := first_id if index % 2 == 0 else second_id
		_show_speech_bubble(speaker_id, String(lines[index]))
		if index < lines.size() - 1:
			await get_tree().create_timer(2.0).timeout
	ambient_exchange_running = false

func _begin_shakedown_combat() -> void:
	_close_dialogue()
	var additional_party_ids: Array[String] = []
	for party_id_value in simulation.get_party_member_ids():
		additional_party_ids.append(String(party_id_value))
	var result := HOLLOWMERE_ENCOUNTER_SCRIPT.start(simulation, additional_party_ids)
	if not bool(result.get("ok", false)):
		campaign_quest_service.fail(HollowmereCampaignContent.QUEST_ID, "The fight could not start: " + String(result.get("reason", "unknown error")))
		_show_dialogue("Hollowmere", "The confrontation cannot begin: " + String(result.get("reason", "unknown error")) + ".", [{"id": "continue", "label": "Continue", "text": ""}])
		return
	active_combat_session = {"previous_states": result.get("previous_states", {})}
	active_encounter_resolver = Callable(HOLLOWMERE_ENCOUNTER_SCRIPT, "resolve_combat")
	encounter_active = true
	var enemy_ids: Array[String] = HOLLOWMERE_ENCOUNTER_SCRIPT.ENEMY_IDS.duplicate()
	var party_ids_active: Array[String] = []
	var controlled_ids: Array[String] = []
	for party_id_value in result.get("party_ids", []):
		party_ids_active.append(String(party_id_value))
	for character_id_value in result.get("controlled_ids", []):
		controlled_ids.append(String(character_id_value))
	if not controlled_ids.has(active_character_id):
		active_character_id = "player"
	encounter_active = true
	_activate_combat_controller(enemy_ids, party_ids_active, controlled_ids)
	_update_combat_ui()


func _on_combat_turn_started(_character_id: String) -> void:
	if combat_controller != null:
		combat_controller.on_combat_turn_started()


func _update_combat(_delta: float) -> void:
	if combat_controller == null:
		return
	if not encounter_active:
		if combat_controller.active:
			combat_controller.end_encounter()
		return
	combat_controller.update_combat(true, active_character_id)


func _attack_active_character() -> void:
	if combat_controller != null:
		combat_controller.request_player_attack(encounter_active, active_character_id)


func _end_active_turn() -> void:
	if combat_controller != null:
		combat_controller.request_end_player_turn(encounter_active, active_character_id)


func _update_combat_ui() -> void:
	if combat_controller != null:
		combat_controller.update_hud(encounter_active, active_character_id)


func _activate_combat_controller(enemy_ids: Array[String], party_ids: Array[String], controlled_ids: Array[String]) -> void:
	if combat_controller == null:
		return
	combat_controller.begin_encounter(enemy_ids, party_ids, controlled_ids)


func _on_nearby_dwelling_site_pressed(site_id: String) -> void:
	var player := simulation.get_character(simulation.player_character_id)
	var remaining := ABANDONED_HOUSE_QUEST_SCRIPT.guardian_count_remaining(simulation) if site_id == "abandoned_house" else 0
	var inspection := DWELLING_WORLD_SERVICE.inspection_for_site(
		simulation.campaign_dwellings,
		simulation.campaign_journal,
		player,
		site_id,
		remaining
	)
	if not bool(inspection.get("ok", false)):
		_show_dialogue("Property", "This location cannot be inspected right now.", [{"id": "continue", "label": "Continue", "text": ""}])
		return
	_show_dialogue(String(inspection.get("speaker", "Property")), String(inspection.get("text", "")), inspection.get("choices", []))


func _show_halvard_household_dialogue() -> void:
	var line := household_world_service.dialogue_line() if household_world_service != null else "The manor is in good order. I shall see to the household while you are away."
	_show_dialogue("Steward Halvard Greer", line, [{"id": "continue", "label": "Thank you, Halvard.", "text": ""}])

func _refresh_dwelling_world_presentation() -> void:
	if simulation == null:
		return
	DWELLING_WORLD_PRESENTATION.present_all(self, simulation.campaign_dwellings, HEX_RADIUS)
	household_world_service.refresh_household()


func _restore_farm_wolf_actor_presentations() -> void:
	## Farm wolves are runtime-created combatants, not part of the static NPC
	## roster. Rebuild their visible actors after loading saved character states.
	for wolf_id in FARM_WOLVES_QUEST_SCRIPT.WOLF_IDS:
		var wolf_state := simulation.get_character(wolf_id)
		var existing_actor := actor_by_id.get(wolf_id) as Node3D
		if wolf_state == null or not wolf_state.can_act():
			if is_instance_valid(existing_actor):
				existing_actor.queue_free()
			actor_by_id.erase(wolf_id)
			continue
		if is_instance_valid(existing_actor):
			existing_actor.position = _hex_world_position(wolf_state.axial)
			continue
		var actor := CREATURE_ACTOR_SCRIPT.new() as CreatureActor
		actor.name = wolf_id
		actor.creature_kind = "wolf"
		actor.behaviour = "predator"
		actor.model_scale = 0.76
		actor.model_path = "res://art/creatures/quaternius/Wolf.gltf"
		actor.position = _hex_world_position(wolf_state.axial)
		actor.set_meta("character_id", wolf_id)
		actor.set_meta("ambient_enabled", false)
		actor.set_meta("farm_quest_wolf", true)
		add_child(actor)
		actor_by_id[wolf_id] = actor



func _dynamic_campaign_character_records() -> Dictionary:
	var records := ABANDONED_HOUSE_QUEST_SCRIPT.dynamic_character_records(simulation)
	records.merge(TOLL_TAKER_ENCOUNTER_SCRIPT.dynamic_character_records(simulation), true)
	return records


func _restore_toll_ogre_actor() -> void:
	if simulation == null:
		return
	var quest_state := campaign_quest_service.state(TOLL_TAKER_CONTENT_SCRIPT.QUEST_ID)
	if String(quest_state.get("status", "")) == "active" and simulation.get_character(TOLL_TAKER_ENCOUNTER_SCRIPT.OGRE_ID) == null:
		TOLL_TAKER_ENCOUNTER_SCRIPT.ensure_ogre(simulation, _find_valid_spawn_hex(TOLL_TAKER_ENCOUNTER_SCRIPT.OGRE_HEX))
	if TOLL_TAKER_ENCOUNTER_SCRIPT.is_alive(simulation):
		_spawn_toll_ogre_actor()


func _spawn_toll_ogre_actor() -> void:
	var ogre := simulation.get_character(TOLL_TAKER_ENCOUNTER_SCRIPT.OGRE_ID)
	if ogre == null or not ogre.alive:
		return
	var existing := actor_by_id.get(TOLL_TAKER_ENCOUNTER_SCRIPT.OGRE_ID) as Node3D
	if is_instance_valid(existing):
		existing.position = _hex_world_position(ogre.axial)
		return
	var profile := {
		"params": {"gender": 1, "hair": "short02", "height": 1.0, "muscle": 1.0, "weight": 0.9, "skinTint": "#71834a", "eyes": "green", "hairTint": "#3b3022"},
		"progression": {"race": "human", "class_levels": ["fighter"], "skill_picks": ["health", "health"]}
	}
	var actor := CampaignCharacterActorFactory.create_actor(
		ogre, _hex_world_position(ogre.axial), false, player_profile, profile, "", ""
	)
	if actor == null:
		push_error("Could not create the Toll-Taker ogre's Ara presentation actor.")
		return
	actor.name = TOLL_TAKER_ENCOUNTER_SCRIPT.OGRE_ID
	actor.scale = Vector3.ONE * 1.4
	actor.set_meta("character_id", TOLL_TAKER_ENCOUNTER_SCRIPT.OGRE_ID)
	actor.set_meta("ambient_enabled", false)
	actor.set_meta("side", "enemy")
	actor.add_to_group("campaign2_npc")
	add_child(actor)
	actor_by_id[TOLL_TAKER_ENCOUNTER_SCRIPT.OGRE_ID] = actor


func _begin_toll_taker_encounter() -> void:
	_close_dialogue()
	var active_state := simulation.get_character(active_character_id)
	var ogre := simulation.get_character(TOLL_TAKER_ENCOUNTER_SCRIPT.OGRE_ID)
	if active_state == null or ogre == null or not simulation.are_characters_within_hex_range(active_character_id, TOLL_TAKER_ENCOUNTER_SCRIPT.OGRE_ID, 2):
		_show_dialogue("North Road", "The ogre's camp is still some distance up the road.", [{"id": "continue", "label": "Continue", "text": ""}])
		return
	var party_ids: Array[String] = []
	for party_id_value in simulation.get_party_member_ids():
		party_ids.append(String(party_id_value))
	var started := TOLL_TAKER_ENCOUNTER_SCRIPT.start_encounter(simulation, party_ids)
	if not bool(started.get("ok", false)):
		_show_dialogue("North Road", "You cannot face the ogre just now: %s." % String(started.get("reason", "unknown error")).replace("_", " "), [{"id": "continue", "label": "Continue", "text": ""}])
		return
	active_combat_session = started.get("session", {})
	active_encounter_resolver = Callable(TOLL_TAKER_ENCOUNTER_SCRIPT, "resolve_combat")
	var party_ids_active: Array[String] = []
	var controlled_ids: Array[String] = []
	for party_id_value in started.get("party_ids", []):
		var party_id := String(party_id_value)
		party_ids_active.append(party_id)
		controlled_ids.append(party_id)
	encounter_active = true
	if not party_ids_active.has(active_character_id):
		active_character_id = simulation.player_character_id
	_activate_combat_controller([TOLL_TAKER_ENCOUNTER_SCRIPT.OGRE_ID], party_ids_active, controlled_ids)
	_update_combat_ui()
	_show_dialogue("Toll-Taker Ogre", "The hulking creature rises from its roadside camp, hefting a crude iron-shod club. It has no intention of letting you pass.", [{"id": "continue", "label": "Stand your ground.", "text": ""}])


func _restore_abandoned_house_guardian_actors() -> void:
	if simulation == null:
		return
	for guardian_id in ABANDONED_HOUSE_QUEST_SCRIPT.GUARDIAN_IDS:
		var guardian := simulation.get_character(guardian_id)
		if guardian == null or not guardian.alive or actor_by_id.has(guardian_id):
			continue
		_spawn_abandoned_house_guardian_actor(guardian_id, guardian.axial)


func _spawn_abandoned_house_guardian_actor(guardian_id: String, hex: Vector2i) -> void:
	if actor_by_id.has(guardian_id) and is_instance_valid(actor_by_id[guardian_id]):
		return
	var actor := SKELETAL_GUARDIAN_ACTOR_SCRIPT.new() as Node3D
	actor.name = guardian_id
	actor.position = _hex_world_position(hex)
	actor.set_meta("character_id", guardian_id)
	actor.set_meta("ambient_enabled", false)
	add_child(actor)
	actor_by_id[guardian_id] = actor


func _check_abandoned_house_proximity() -> void:
	if simulation == null or simulation.is_in_combat or encounter_active or dialogue_open:
		return
	var approach := ABANDONED_HOUSE_QUEST_SCRIPT.prepare_approach(simulation, active_character_id)
	if not bool(approach.get("ok", false)) or not bool(approach.get("should_present", false)):
		return
	for guardian_id_value in approach.get("guardian_ids", []):
		var guardian_id := String(guardian_id_value)
		var guardian := simulation.get_character(guardian_id)
		if guardian != null:
			_spawn_abandoned_house_guardian_actor(guardian_id, guardian.axial)


func _begin_abandoned_house_encounter() -> void:
	_close_dialogue()
	var party_ids: Array[String] = []
	for party_id_value in simulation.get_party_member_ids():
		party_ids.append(String(party_id_value))
	var result := ABANDONED_HOUSE_QUEST_SCRIPT.start_encounter_from_character(simulation, active_character_id, party_ids)
	if not bool(result.get("ok", false)):
		var reason := String(result.get("reason", "unknown error"))
		var message := "You cannot face the guardians just now: %s." % reason.replace("_", " ")
		if reason == "too_far_from_house":
			message = "You need to be at the house before you can enter it."
		_show_dialogue("Abandoned House", message, [{"id": "continue", "label": "Understood.", "text": ""}])
		return
	active_combat_session = {"previous_states": result.get("previous_states", {})}
	active_encounter_resolver = Callable(ABANDONED_HOUSE_QUEST_SCRIPT, "resolve_combat")
	var enemy_ids: Array[String] = []
	var party_ids_active: Array[String] = []
	var controlled_ids: Array[String] = []
	for enemy_id_value in result.get("enemy_ids", []):
		enemy_ids.append(String(enemy_id_value))
	for party_id_value in result.get("party_ids", []):
		party_ids_active.append(String(party_id_value))
		controlled_ids.append(String(party_id_value))
	encounter_active = true
	if not party_ids_active.has(active_character_id):
		active_character_id = simulation.player_character_id
	_activate_combat_controller(enemy_ids, party_ids_active, controlled_ids)
	_update_combat_ui()
	_show_dialogue("Abandoned House", "The three skeletal guardians turn as one. Rusted weapons rise from the dark, and the house erupts into violence.", [{"id": "continue", "label": "Stand your ground.", "text": ""}])


func _farm_wolves_remaining() -> int:
	return FARM_WOLVES_QUEST_SCRIPT.remaining_wolves(simulation, farm_wolves_spawned)


func _check_farm_wolf_proximity() -> void:
	if simulation == null or encounter_active:
		return
	# Quest rules own activation and retry decisions; map placement owns the den.
	var decision := FARM_WOLVES_QUEST_SCRIPT.evaluate_approach(
		simulation,
		HOLLOWMERE_PLACEMENTS.FARM_WOLF_DEN_HEX,
		farm_wolves_spawned,
		farm_wolves_retry_armed
	)
	if not bool(decision.get("ok", false)):
		return
	farm_wolves_retry_armed = bool(decision.get("retry_armed", farm_wolves_retry_armed))
	if bool(decision.get("should_spawn", false)):
		_start_farm_wolf_encounter()


func _start_farm_wolf_encounter() -> void:
	if simulation.is_in_combat or farm_wolves_spawned and _farm_wolves_remaining() == 0:
		return
	if not farm_wolves_spawned:
		var spawn_hexes: Array[Vector2i] = []
		for index in range(FARM_WOLVES_QUEST_SCRIPT.WOLF_IDS.size()):
			var preferred: Vector2i = HOLLOWMERE_PLACEMENTS.FARM_WOLF_DEN_HEX + HOLLOWMERE_PLACEMENTS.FARM_WOLF_SPAWN_OFFSETS[index]
			spawn_hexes.append(_find_valid_spawn_hex(preferred))
		var ensured: Dictionary = FARM_WOLVES_QUEST_SCRIPT.ensure_wolves(simulation, spawn_hexes)
		if not bool(ensured.get("ok", false)):
			push_error("Could not prepare farm wolf combatants: %s" % ensured)
			farm_wolves_retry_armed = true
			return
		farm_wolves_spawned = true
		_restore_farm_wolf_actor_presentations()
	farm_wolves_retry_armed = false

	var enemy_ids: Array[String] = FARM_WOLVES_QUEST_SCRIPT.WOLF_IDS.duplicate()
	var party_ids_active: Array[String] = []
	var controlled_ids: Array[String] = []
	for party_id_value in simulation.get_party_member_ids():
		var party_id := String(party_id_value)
		var member := simulation.get_character(party_id)
		if member == null or not member.can_act():
			continue
		party_ids_active.append(party_id)
		controlled_ids.append(party_id)
	var begin_result: Dictionary = FARM_WOLVES_QUEST_SCRIPT.start_encounter(simulation, party_ids_active, enemy_ids)
	if not bool(begin_result.get("ok", false)):
		farm_wolves_retry_armed = true
		push_error("Could not start farm wolf encounter: %s" % begin_result)
		return
	active_combat_session = begin_result.get("session", {})
	active_encounter_resolver = Callable(FARM_WOLVES_QUEST_SCRIPT, "resolve_combat")
	encounter_active = true
	if not party_ids_active.has(active_character_id):
		active_character_id = "player"
	_activate_combat_controller(enemy_ids, party_ids_active, controlled_ids)
	_update_combat_ui()
	_show_dialogue("Wilderness", "A low growl rolls through the trees. Three wolves emerge from the den and spread out to surround you.", [{"id": "continue", "label": "Stand your ground.", "text": ""}])



func _on_camp_night_encounter_resolved(result: Dictionary) -> void:
	if simulation == null or encounter_active or simulation.is_in_combat:
		return
	if not bool(result.get("attacked", false)):
		return
	var camp_hex_value: Variant = simulation.camp_simulation.site.get("hex", null)
	if not camp_hex_value is Vector2i:
		push_error("Camp night ambush has no valid campsite hex.")
		return
	var camp_hex: Vector2i = camp_hex_value
	var spawn_offsets: Array[Vector2i] = [
		Vector2i(3, 0), Vector2i(-3, 0), Vector2i(0, 3),
		Vector2i(0, -3), Vector2i(3, -3), Vector2i(-3, 3)
	]
	var spawn_hexes: Array[Vector2i] = []
	for offset in spawn_offsets:
		var candidate := _find_valid_spawn_hex(camp_hex + offset)
		if not spawn_hexes.has(candidate):
			spawn_hexes.append(candidate)
		if spawn_hexes.size() >= 2:
			break
	if spawn_hexes.size() < 2:
		push_error("Could not find two valid cells for the camp night ambush.")
		return
	var party_ids: Array[String] = []
	for party_id_value in simulation.get_party_member_ids():
		var party_id := String(party_id_value)
		var member := simulation.get_character(party_id)
		if member != null and member.can_act():
			party_ids.append(party_id)
	var detected := bool(result.get("detected", false))
	var started: Dictionary = CAMP_NIGHT_AMBUSH_ENCOUNTER_SCRIPT.start(
		simulation, party_ids, spawn_hexes, detected
	)
	if not bool(started.get("ok", false)):
		push_error("Could not start camp night ambush: %s" % started)
		return
	var enemy_ids: Array[String] = []
	for enemy_id_value in started.get("enemy_ids", []):
		var enemy_id := String(enemy_id_value)
		enemy_ids.append(enemy_id)
		var enemy := simulation.get_character(enemy_id)
		if enemy == null:
			continue
		var actor := CREATURE_ACTOR_SCRIPT.new() as CreatureActor
		actor.name = enemy_id
		actor.creature_kind = "wolf"
		actor.behaviour = "predator"
		actor.model_scale = 0.76
		actor.model_path = "res://art/creatures/quaternius/Wolf.gltf"
		actor.position = _hex_world_position(enemy.axial)
		add_child(actor)
		actor_by_id[enemy_id] = actor
	active_combat_session = started
	active_encounter_resolver = Callable(CAMP_NIGHT_AMBUSH_ENCOUNTER_SCRIPT, "resolve_combat")
	encounter_active = true
	if not party_ids.has(active_character_id):
		active_character_id = simulation.player_character_id
	_activate_combat_controller(enemy_ids, party_ids, party_ids)
	_update_combat_ui()
	if detected:
		_show_dialogue(
			"Night Watch",
			"%s spots movement beyond the firelight and raises the alarm. Two wolves rush the camp, but the party has time to ready itself." % String(result.get("watcher_id", "A watcher")),
			[{"id": "continue", "label": "Defend the camp.", "text": ""}]
		)
	else:
		_show_dialogue(
			"Night Ambush",
			"A sudden snarl tears through the darkness. Two wolves are already among the sleeping party!",
			[{"id": "continue", "label": "Fight back!", "text": ""}]
		)


func _check_encounter_resolution() -> void:
	if not encounter_active or not active_encounter_resolver.is_valid():
		return
	var result: Dictionary = active_encounter_resolver.call(
		simulation,
		simulation.campaign_journal,
		combat_controller.party_ids if combat_controller != null else [],
		active_combat_session
	)
	if not bool(result.get("resolved", false)):
		return
	encounter_active = false
	active_combat_session.clear()
	active_encounter_resolver = Callable()
	if combat_controller != null:
		combat_controller.end_encounter()
	var status_text := String(result.get("status_text", ""))
	if not status_text.is_empty():
		resource_status_label.text = status_text
	for actor_id_value in result.get("remove_actor_ids", []):
		var actor_id := String(actor_id_value)
		var actor := actor_by_id.get(actor_id) as Node3D
		if is_instance_valid(actor):
			actor.queue_free()
		actor_by_id.erase(actor_id)
	var speech_character_id := String(result.get("speech_bubble_character_id", ""))
	if not speech_character_id.is_empty():
		_show_speech_bubble(speech_character_id, String(result.get("message", "")))
	var companion_dialogue_id := String(result.get("companion_dialogue_id", ""))
	if not companion_dialogue_id.is_empty():
		_show_companion_dialogue(companion_dialogue_id)
		return
	if String(result.get("outcome", "")) == "victory" and simulation.camp_simulation.phase == "interrupted":
		camp_lifecycle_controller.sync_sleep_button_state() if camp_lifecycle_controller != null else null
		_show_dialogue(
			"Night Watch",
			"The wolves have been driven off. The camp is secure again, and there are %.1f hours left before morning." % maxf(0.0, simulation.camp_simulation.night_planned_hours - simulation.camp_simulation.night_elapsed_hours),
			[
				{"id": "continue_camp_sleep", "label": "Return to sleep", "text": ""},
				{"id": "pack_camp_after_ambush", "label": "Pack camp now", "text": ""}
			]
		)
		return
	var speaker := String(result.get("speaker", ""))
	var message := String(result.get("message", ""))
	var choice_label := String(result.get("choice_label", "Continue."))
	_show_dialogue(speaker, message, [{"id": "continue", "label": choice_label, "text": ""}])


func _on_initiative_character_selected(character_id: String) -> void:
	if character_panel == null or simulation == null or simulation.get_character(character_id) == null:
		return
	character_panel.set_character(character_id)
	character_panel.visible = true


func _on_character_equipment_changed(changed_character_id: String) -> void:
	var state := simulation.get_character(changed_character_id) if simulation != null else null
	var actor := actor_by_id.get(changed_character_id) as Node3D
	if state == null or actor == null:
		return
	CampaignCharacterActorFactory.apply_equipment_visuals(actor, state)


func _toggle_character_panel() -> void:
	_open_character_panel()

func _open_character_panel() -> void:
	if character_panel != null:
		character_panel.set_tab("character")
		if not character_panel.visible:
			character_panel.toggle_panel()

func _open_skill_panel() -> void:
	if character_panel != null:
		character_panel.set_character(active_character_id)
		character_panel.set_tab("skills")
		if not character_panel.visible:
			character_panel.toggle_panel()

func _open_inventory_panel() -> void:
	if character_panel != null:
		character_panel.set_tab("inventory")
		if not character_panel.visible:
			character_panel.toggle_panel()

func _toggle_world_map() -> void:
	if world_map_panel != null and world_map_panel.has_method("toggle_panel"):
		world_map_panel.toggle_panel()


func _on_reaction_requested(reactor_id: String, options: Array[Dictionary], request_id: int, _source_event_id: String) -> void:
	if combat_controller == null or not combat_controller.player_controlled_ids.has(reactor_id):
		_resolve_ai_reaction(reactor_id, options)
		return
	if reaction_prompt != null:
		reaction_prompt.present(reactor_id, options, request_id)


func _resolve_ai_reaction(reactor_id: String, options: Array[Dictionary]) -> void:
	var selected_id := ""
	var selected_priority := -1
	for option_value in options:
		var option: Dictionary = option_value
		var option_id := String(option.get("id", ""))
		var option_reactor_id := String(option.get("reactor_id", reactor_id))
		var priority := 0
		if option_id == "parry" and option_reactor_id == reactor_id:
			priority = 4
		elif option_id == "protector_parry":
			priority = 3
		elif option_id == "shield_other":
			priority = 2
		if priority > selected_priority:
			selected_priority = priority
			selected_id = option_id
	simulation.resolve_reaction(selected_id)

func _on_reaction_choice_selected(choice_id: String, _request_id: int) -> void:
	if simulation != null:
		simulation.resolve_reaction(choice_id)

func _on_reaction_resolved(_reactor_id: String, _choice_id: String, _request_id: int, _reason: String) -> void:
	if reaction_prompt != null:
		reaction_prompt.dismiss()

func _on_movement_reaction_resolved(_mover_id: String, halted: bool) -> void:
	if halted:
		_clear_path_markers()

func _on_zoom_slider_changed(value: float) -> void:
	camera_rig.set_zoom(value)

func _on_camera_zoom_changed(value: float) -> void:
	if is_instance_valid(zoom_slider):
		zoom_slider.set_value_no_signal(value)

func _switch_party_member() -> void:
	var party_ids := simulation.get_party_member_ids()
	if party_ids.is_empty():
		return
	_clear_path_markers()
	var current_index := party_ids.find(active_character_id)
	active_party_index = (current_index + 1) % party_ids.size()
	active_character_id = party_ids[active_party_index]
	if movement_controller != null:
		movement_controller.set_active_character_id(active_character_id)
	var target: Node3D = actor_by_id.get(active_character_id) as Node3D
	if target != null:
		camera_rig.follow_target = target
		var active_state := simulation.get_character(active_character_id)
		var display_name := "You" if active_character_id == "player" else (active_state.display_name if active_state != null else active_character_id)
		party_switch_button.text = "Active: " + display_name + "  [Tab] Switch"
	_refresh_tavern_floor_presentation()
	if character_panel != null:
		character_panel.set_character(active_character_id)

func _process(delta: float) -> void:
	if not simulation.is_in_combat and not simulation.has_pending_reaction() and not dialogue_open and not (shakedown_started and not shakedown_resolved):
		autosave_accumulator += delta
		if autosave_accumulator >= 300.0:
			autosave_accumulator = 0.0
			var save_manager := _save_manager_service()
			if save_manager != null:
				save_manager.call("save_autosave", _build_save_snapshot())
	_update_ambient_chatter(delta)
	_check_reyna_story_proximity()
	_check_farm_wolf_proximity()
	_check_abandoned_house_proximity()
	_update_combat(delta)
	_update_combat_ui()
	nearby_interaction_refresh += delta
	if nearby_interaction_refresh >= 0.25:
		nearby_interaction_refresh = 0.0
		_refresh_nearby_interactions()
	if movement_controller != null:
		movement_controller.process_movement(delta)
	if camp_activity_director != null:
		camp_activity_director.process_activity_movement(delta)
	if household_world_service != null:
		household_world_service.process(delta)
	if rowan_world_service != null:
		rowan_world_service.process(delta)
	if camp_lifecycle_controller != null:
		camp_lifecycle_controller.sync_sleep_button_state()

func _gather_at_player() -> void:
	var player := simulation.get_character("player")
	if player == null:
		return
	var result := simulation.harvest_resource_at("player", player.axial)
	if not bool(result.get("ok", false)):
		var reason := String(result.get("reason", "no_resource_here"))
		var messages := {
			"no_resource_here": "Nothing useful to gather on this hex.",
			"resource_depleted": "This resource has been exhausted for now.",
			"resource_regrowing": "This spot needs more time to recover.",
			"requires_pickaxe": "You need to carry a pickaxe to mine this outcrop.",
			"requires_axe": "You need to carry an axe to harvest timber.",
			"character_unavailable": "You cannot gather while incapacitated."
		}
		resource_status_label.text = String(messages.get(reason, "You cannot gather here."))
		return
	var names: Array[String] = []
	for item_id in result.get("item_ids", []):
		var definition := ItemCatalog.get_definition(String(item_id))
		names.append(String(definition.get("name", item_id)))
	var gathered_text := ""
	for item_name in names:
		if not gathered_text.is_empty():
			gathered_text += ", "
		gathered_text += item_name
	resource_status_label.text = "Gathered: " + gathered_text
	_refresh_resource_visual_at(player.axial)

func _refresh_resource_visual_at(hex: Vector2i) -> void:
	if not resource_visuals_by_hex.has(hex):
		return
	var visual := resource_visuals_by_hex[hex] as WildernessResourceVisual
	if not is_instance_valid(visual):
		return
	visual.refresh(simulation.ensure_resource_at(hex), int(simulation.clock.calendar_date()["month_index"]))

func _refresh_resource_visuals() -> void:
	var month_index := int(simulation.clock.calendar_date()["month_index"])
	for key in resource_visuals_by_hex:
		var hex: Vector2i = key
		var visual := resource_visuals_by_hex[key] as WildernessResourceVisual
		if is_instance_valid(visual):
			visual.refresh(simulation.ensure_resource_at(hex), month_index)

func _unhandled_input(event: InputEvent) -> void:
	if stair_traversal_running:
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			var clicked_hex: Vector2i = _screen_position_to_hex(mouse_event.position)
			if clicked_hex != INVALID_HEX:
				if camp_selection_mode:
					_select_camp_site(clicked_hex)
				else:
					_set_move_destination(clicked_hex)
				get_viewport().set_input_as_handled()
			return

	if event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		if key_event.keycode == KEY_B:
			_toggle_camp_site_selection()
			get_viewport().set_input_as_handled()
			return
		if key_event.keycode == KEY_F5:
			_quick_save()
			get_viewport().set_input_as_handled()
			return
		if key_event.keycode == KEY_F9:
			_quick_load()
			get_viewport().set_input_as_handled()
			return
		if key_event.keycode == KEY_SPACE:
			_attack_active_character()
			get_viewport().set_input_as_handled()
			return
		if key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER:
			_end_active_turn()
			get_viewport().set_input_as_handled()
			return
		if key_event.keycode == KEY_G:
			_gather_at_player()
			get_viewport().set_input_as_handled()
			return
		if key_event.keycode == KEY_F:
			if not _interact_with_multistory_tunnels() and not _interact_with_tavern_stairs() and not _interact_with_nearest_door() and not _interact_with_chapel_locket():
				_interact_with_nearest_npc()
			get_viewport().set_input_as_handled()
			return
		if key_event.keycode == KEY_TAB:
			_switch_party_member()
			get_viewport().set_input_as_handled()
			return
		if key_event.keycode == KEY_C:
			_toggle_character_panel()
			get_viewport().set_input_as_handled()
			return
		if key_event.keycode == KEY_K:
			_open_skill_panel()
			get_viewport().set_input_as_handled()
			return
		if key_event.keycode == KEY_I:
			_open_inventory_panel()
			get_viewport().set_input_as_handled()
			return
		if key_event.keycode == KEY_V:
			roof_group.visible = not roof_group.visible
			return
		if key_event.keycode == KEY_BRACKETLEFT:
			_rotate_active_character(-1)
			get_viewport().set_input_as_handled()
			return
		if key_event.keycode == KEY_BRACKETRIGHT:
			_rotate_active_character(1)
			get_viewport().set_input_as_handled()
			return

		if movement_controller != null and movement_controller.handle_directional_key(key_event.keycode):
			get_viewport().set_input_as_handled()
			return

func _screen_position_to_hex(screen_position: Vector2) -> Vector2i:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return INVALID_HEX
	var active_state := simulation.get_character(active_character_id)
	var upstairs := active_state != null and _is_upper_floor_hex(active_state.axial)
	var plane_y := UPPER_FLOOR_Y if upstairs else 0.0
	var ray_origin := camera.project_ray_origin(screen_position)
	var ray_direction := camera.project_ray_normal(screen_position)
	if absf(ray_direction.y) < 0.0001:
		return INVALID_HEX
	var distance := (plane_y - ray_origin.y) / ray_direction.y
	if distance < 0.0:
		return INVALID_HEX
	var hit := ray_origin + ray_direction * distance
	var hex := HexGrid.world_to_axial(hit, HEX_RADIUS)
	if upstairs:
		hex += UPPER_FLOOR_ORIGIN
	if not simulation.map_data.has_cell(hex):
		return INVALID_HEX
	return hex

func _set_move_destination(destination: Vector2i) -> void:
	if movement_controller != null:
		movement_controller.set_destination(destination)

func _clear_path_markers() -> void:
	if movement_controller != null:
		movement_controller.clear_path()

func _rotate_active_character(steps: int) -> void:
	var state := simulation.get_character(active_character_id)
	var actor: Node3D = actor_by_id.get(active_character_id) as Node3D
	if state == null or actor == null:
		return
	state.facing_direction = posmod(state.facing_direction + steps, 6)
	actor.rotation.y = deg_to_rad(float(2 - state.facing_direction) * 60.0)

func _attempt_move(relative_step: int) -> void:
	if simulation.clock.paused:
		return
	var state := simulation.get_character(active_character_id)
	if state == null:
		return
	var direction_index := posmod(state.facing_direction + relative_step, 6)
	simulation.try_move_character_step(state.id, state.axial + HexGrid.DIRECTIONS[direction_index])

func _find_valid_spawn_hex(preferred: Vector2i) -> Vector2i:
	# Search outward from the authored staging position to avoid furniture
	# and occupied cells as the blockout changes.
	var candidates: Array[Vector2i] = []
	for key in simulation.map_data.cells.keys():
		var cell: Vector2i = key
		if not simulation.map_data.is_walkable(cell):
			continue
		if simulation.is_hex_occupied(cell):
			continue
		candidates.append(cell)
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da := simulation.hex_distance(preferred, a)
		var db := simulation.hex_distance(preferred, b)
		if da == db:
			return a.x < b.x if a.x != b.x else a.y < b.y
		return da < db
	)
	if candidates.is_empty():
		push_error("No valid walkable spawn hex available near " + str(preferred))
		return preferred
	return candidates[0]

func _on_character_moved(character_id: String, from_hex: Vector2i, to_hex: Vector2i) -> void:
	var actor := actor_by_id.get(character_id) as Node3D
	if actor != null:
		var destination := _hex_world_position(to_hex)
		if _is_upper_floor_hex(from_hex) != _is_upper_floor_hex(to_hex):
			if character_id == stair_traversal_character_id and actor is HexActorPresentation:
				# The logical floor address changes immediately, but the actor
				# walks the real stair flight in world space instead of snapping.
				var presentation := actor as HexActorPresentation
				presentation.present_move_to(destination, NAN, TAVERN_STAIR_TRAVERSAL_DURATION)
				if presentation.movement_tween != null:
					presentation.movement_tween.finished.connect(
						_on_tavern_stair_traversal_finished,
						CONNECT_ONE_SHOT
					)
				else:
					_on_tavern_stair_traversal_finished()
			elif character_id == stair_traversal_character_id:
				var stair_tween := create_tween()
				stair_tween.set_trans(Tween.TRANS_SINE)
				stair_tween.set_ease(Tween.EASE_IN_OUT)
				stair_tween.tween_property(actor, "global_position", destination, TAVERN_STAIR_TRAVERSAL_DURATION)
				stair_tween.finished.connect(_on_tavern_stair_traversal_finished, CONNECT_ONE_SHOT)
			else:
				actor.global_position = destination
				if actor is HexActorPresentation:
					(actor as HexActorPresentation).stop_moving()
		elif actor is CreatureActor:
			var creature := actor as CreatureActor
			creature.play_move()
			var tween := create_tween()
			tween.tween_property(creature, "global_position", destination, 0.36)
			tween.tween_callback(creature.play_idle)
		elif actor is HexActorPresentation:
			var direction_index := _movement_direction_index(from_hex, to_hex)
			var facing_rotation := NAN
			if direction_index >= 0:
				facing_rotation = deg_to_rad(float(direction_index - 2) * 60.0)
			(actor as HexActorPresentation).present_move_to(destination, facing_rotation)
		else:
			var tween := create_tween()
			tween.set_trans(Tween.TRANS_SINE)
			tween.set_ease(Tween.EASE_IN_OUT)
			tween.tween_property(actor, "global_position", destination, 0.36)
	elif character_id == stair_traversal_character_id:
		_on_tavern_stair_traversal_finished()
	if character_id == active_character_id and not stair_traversal_running:
		_refresh_tavern_floor_presentation()
	if character_id == "player" and wilderness_creature_spawner != null:
		wilderness_creature_spawner.player_moved(to_hex)

func _on_tavern_stair_traversal_finished() -> void:
	stair_traversal_running = false
	stair_traversal_character_id = ""
	_refresh_tavern_floor_presentation()

func _movement_direction_index(from_hex: Vector2i, to_hex: Vector2i) -> int:
	var step := to_hex - from_hex
	for index in range(HexGrid.DIRECTIONS.size()):
		if HexGrid.DIRECTIONS[index] == step:
			return index
	return -1
func _is_upper_floor_hex(hex: Vector2i) -> bool:
	return hex.x >= UPPER_FLOOR_ORIGIN.x - 4 and hex.x <= UPPER_FLOOR_ORIGIN.x + 4 and hex.y >= UPPER_FLOOR_ORIGIN.y - 4 and hex.y <= UPPER_FLOOR_ORIGIN.y + 4 and simulation.map_data.has_cell(hex)

func _refresh_tavern_floor_presentation() -> void:
	if upper_shell_group == null or upper_floor_group == null:
		return
	var active_state := simulation.get_character(active_character_id)
	var upstairs := active_state != null and _is_upper_floor_hex(active_state.axial)
	upper_shell_group.visible = not upstairs
	upper_floor_group.visible = upstairs
	if location_label != null:
		location_label.text = "LOCATION  /  HOLLOW TANKARD  —  " + ("UPPER FLOOR" if upstairs else "TAPROOM")

## Called before a new runtime is added so its floor map snapshots the
## regional map, not the currently active interior's cells.
func prepare_multistory_location_runtime(location_id: String) -> void:
	if is_instance_valid(active_multistory_runtime) and String(active_multistory_runtime.definition.get("id", "")) != location_id:
		active_multistory_runtime.set_location_active(false)

## Called by Campaign2LocationLoader when a multi-story location is entered.
func register_multistory_location_runtime(runtime: Campaign2MultiStoryLocationRuntime) -> void:
	if runtime == null or not is_instance_valid(runtime):
		return
	var location_id := String(runtime.definition.get("id", ""))
	if location_id.is_empty():
		return
	if is_instance_valid(active_multistory_runtime) and active_multistory_runtime != runtime:
		active_multistory_runtime.set_location_active(false)
	var anchor_data: Dictionary = runtime.definition.get("anchor", {})
	var anchor := Vector2i(int(anchor_data.get("q", 0)), int(anchor_data.get("r", 0)))
	runtime.position = _hex_world_position(anchor)
	runtime.set_location_active(true)
	multistory_runtime_by_location[location_id] = runtime
	active_multistory_runtime = runtime
	var actor := actor_by_id.get(active_character_id) as Node3D
	if actor != null:
		runtime.register_character_actor(active_character_id, actor)

## Load or reactivate an authored multi-story location for a special tunnel-network destination.
## Ordinary building doors must never call this or transfer the player between locations.
func enter_multistory_location(location_id: String) -> Dictionary:
	if simulation == null or location_id.strip_edges().is_empty():
		return {"ok": false, "reason": "runtime_not_ready"}
	prepare_multistory_location_runtime(location_id)
	var runtime := _get_or_load_multistory_runtime(location_id)
	if runtime == null:
		if is_instance_valid(active_multistory_runtime):
			active_multistory_runtime.set_location_active(true)
		return {"ok": false, "reason": "could_not_load_multistory_location", "location_id": location_id}
	if is_instance_valid(active_multistory_runtime) and active_multistory_runtime != runtime:
		active_multistory_runtime.set_location_active(false)
	active_multistory_runtime = runtime
	runtime.set_location_active(true)
	var actor := actor_by_id.get(active_character_id) as Node3D
	if actor != null:
		runtime.register_character_actor(active_character_id, actor)
	if movement_controller != null:
		movement_controller.clear_path()
	return {"ok": true, "location_id": location_id, "floor": runtime.get_current_floor()}

func _get_or_load_multistory_runtime(location_id: String) -> Campaign2MultiStoryLocationRuntime:
	var existing := multistory_runtime_by_location.get(location_id) as Campaign2MultiStoryLocationRuntime
	if existing != null and is_instance_valid(existing):
		return existing
	var loaded: Dictionary = MULTISTORY_LOCATION_LOADER.load_multistory_location(self, location_id, simulation)
	if not bool(loaded.get("ok", false)):
		push_warning("Could not load multi-story location %s: %s" % [location_id, loaded])
		return null
	var runtime := loaded.get("runtime") as Campaign2MultiStoryLocationRuntime
	if runtime == null:
		return null
	var anchor_data: Dictionary = runtime.definition.get("anchor", {})
	var anchor := Vector2i(int(anchor_data.get("q", 0)), int(anchor_data.get("r", 0)))
	runtime.position = _hex_world_position(anchor)
	multistory_runtime_by_location[location_id] = runtime
	return runtime

func _interact_with_multistory_tunnels() -> bool:
	var player_state := simulation.get_character(active_character_id)
	if player_state == null:
		return false
	# Resolve a surface entrance when outdoors/on a surface floor. Do not let
	# the coincident palace/city surface coordinates steal input from a -9
	# tunnel junction beneath them.
	var can_resolve_surface := not is_instance_valid(active_multistory_runtime) or active_multistory_runtime.get_current_floor() == 0
	if can_resolve_surface:
		var surface_entry := TUNNEL_NETWORK.nearby_surface_location(player_state.axial)
		if not surface_entry.is_empty() and (
			not is_instance_valid(active_multistory_runtime)
			or String(active_multistory_runtime.definition.get("id", "")) != String(surface_entry.get("location_id", ""))
		):
			var entered: Dictionary = enter_multistory_location(String(surface_entry.get("location_id", "")))
			if not bool(entered.get("ok", false)):
				var prompt: Dictionary = TUNNEL_INTERACTION_CONTENT.entrance_unavailable_prompt()
				_show_dialogue(String(prompt.title), String(prompt.body), prompt.choices)
				return true
	if not is_instance_valid(active_multistory_runtime):
		return false
	var entry_node := active_multistory_runtime.get_tunnel_entry_node(active_character_id)
	if not entry_node.is_empty():
		var prompt: Dictionary = TUNNEL_INTERACTION_CONTENT.entry_prompt(entry_node)
		_show_dialogue(String(prompt.title), String(prompt.body), prompt.choices)
		return true
	var nearby_secret_id := active_multistory_runtime.get_nearby_undiscovered_secret_passage_id(active_character_id)
	if not nearby_secret_id.is_empty():
		var prompt: Dictionary = TUNNEL_INTERACTION_CONTENT.secret_search_prompt(nearby_secret_id)
		_show_dialogue(String(prompt.title), String(prompt.body), prompt.choices)
		return true
	var junction_node := active_multistory_runtime.get_tunnel_junction_node(active_character_id)
	if junction_node.is_empty():
		# The wilderness node uses ordinary authored stairs: surface → cave
		# level → tunnel junction. Keep this on the same F-key interaction path.
		var stair_result: Dictionary = active_multistory_runtime.interact_with_stair(active_character_id)
		if bool(stair_result.get("ok", false)):
			if movement_controller != null:
				movement_controller.clear_path()
			return true
		if String(stair_result.get("reason", "")) != "no_stair_nearby":
			_show_dialogue("Passage", "You cannot use those stairs: %s." % String(stair_result.get("reason", "travel_failed")).replace("_", " "), [{"id": "continue", "label": "Continue", "text": ""}])
			return true
		return false
	var current_node: Dictionary = TUNNEL_NETWORK.get_node(junction_node)
	var surface_location_id := String(current_node.get("surface_location_id", ""))
	var surface_secret_id := String(current_node.get("surface_secret_id", ""))
	var surface_state := simulation.multistory_location_states.get(surface_location_id) as Campaign2MultiStoryLocationState
	var can_return := surface_state != null and surface_state.is_secret_discovered(surface_secret_id)
	var prompt: Dictionary = TUNNEL_INTERACTION_CONTENT.junction_prompt(
		active_multistory_runtime.get_tunnel_junction_destinations(active_character_id),
		can_return,
		junction_node
	)
	_show_dialogue(String(prompt.title), String(prompt.body), prompt.choices)
	return true


func _handle_tunnel_search(choice_id: String) -> void:
	if not is_instance_valid(active_multistory_runtime):
		return
	var secret_id := choice_id.trim_prefix("tunnel_search:")
	var result: Dictionary = active_multistory_runtime.search_secret_passage(active_character_id, secret_id, ambient_rng.randf())
	var prompt: Dictionary = TUNNEL_INTERACTION_CONTENT.search_result(result)
	if bool(prompt.get("set_chancellor_tunnel_discovered", false)):
		simulation.set_meta("chancellor_tunnel_discovered", true)
	_show_dialogue(String(prompt.title), String(prompt.body), prompt.choices)


func _handle_tunnel_choice(choice_id: String) -> void:
	if not is_instance_valid(active_multistory_runtime):
		return
	var source_runtime := active_multistory_runtime
	var action := choice_id.get_slice(":", 0)
	var node_id := choice_id.get_slice(":", 1)
	var destination: Dictionary = TUNNEL_NETWORK.get_node(node_id)
	var target_location_id := String(destination.get("location_id", ""))
	if action == "tunnel_return":
		target_location_id = String(destination.get("surface_location_id", ""))
	if target_location_id.is_empty():
		var prompt: Dictionary = TUNNEL_INTERACTION_CONTENT.missing_passage_prompt()
		_show_dialogue(String(prompt.title), String(prompt.body), prompt.choices)
		return
	# Release the source map before the destination runtime captures its
	# previous cells; this prevents overlapping axial floors from restoring
	# stale source geometry into the shared simulation map.
	source_runtime.set_location_active(false)
	var target_runtime := _get_or_load_multistory_runtime(target_location_id)
	if target_runtime == null:
		source_runtime.set_location_active(true)
		var prompt: Dictionary = TUNNEL_INTERACTION_CONTENT.destination_load_failed_prompt()
		_show_dialogue(String(prompt.title), String(prompt.body), prompt.choices)
		return
	var result: Dictionary = {}
	match action:
		"tunnel_enter":
			result = source_runtime.enter_tunnel_node(active_character_id, target_runtime, node_id)
		"tunnel_travel":
			result = source_runtime.travel_to_tunnel_node(active_character_id, target_runtime, node_id)
		"tunnel_return":
			result = source_runtime.return_to_surface_passage(active_character_id, target_runtime, node_id)
	if not bool(result.get("ok", false)):
		source_runtime.set_location_active(true)
		active_multistory_runtime = source_runtime
		var prompt: Dictionary = TUNNEL_INTERACTION_CONTENT.travel_failed_prompt(String(result.get("reason", "travel_failed")))
		_show_dialogue(String(prompt.title), String(prompt.body), prompt.choices)
		return
	active_multistory_runtime = target_runtime
	var actor := actor_by_id.get(active_character_id) as Node3D
	if actor != null:
		target_runtime.register_character_actor(active_character_id, actor)
	if camera_rig != null:
		camera_rig.follow_target = actor
	if movement_controller != null:
		movement_controller.clear_path()
	var prompt: Dictionary = TUNNEL_INTERACTION_CONTENT.arrival_prompt(
		action,
		String(destination.get("label", "the passage"))
	)
	_show_dialogue(String(prompt.title), String(prompt.body), prompt.choices)

func _interact_with_tavern_stairs() -> bool:
	if stair_traversal_running:
		return true
	var state := simulation.get_character(active_character_id)
	if state == null:
		return false
	var upstairs := _is_upper_floor_hex(state.axial)
	var stair_hex := TAVERN_STAIR_UPPER_HEX if upstairs else TAVERN_STAIR_GROUND_HEX
	if not simulation.is_hex_within_range(state.axial, stair_hex, 1):
		return false
	var destination := TAVERN_STAIR_GROUND_HEX if upstairs else TAVERN_STAIR_UPPER_HEX
	_clear_path_markers()
	stair_traversal_running = true
	stair_traversal_character_id = active_character_id
	# Keep the upper deck present while the actor physically climbs the
	# authored staircase; floor cutaway changes only when traversal finishes.
	if is_instance_valid(upper_floor_group):
		upper_floor_group.visible = true
	if not simulation.relocate_character(active_character_id, destination):
		stair_traversal_running = false
		stair_traversal_character_id = ""
		_refresh_tavern_floor_presentation()
		print("The staircase is blocked.")
	return true

func _interact_with_nearest_door() -> bool:
	var state := simulation.get_character(active_character_id)
	if state == null:
		return false
	var door := simulation.building_registry.get_door(TAVERN_FRONT_DOOR_ID)
	if door == null or not simulation.is_hex_within_range(state.axial, door.hex, 1):
		return false
	var should_open := not door.is_passable()
	if not should_open and simulation.is_hex_occupied(door.hex):
		print("The doorway is occupied; move clear before closing it.")
		return true
	var changed := simulation.building_registry.set_door_open(door.id, should_open)
	if not changed:
		print("The Hollow Tankard door is locked or cannot be moved.")
		return true
	return true

func _on_building_door_state_changed(door_id: String) -> void:
	if door_id != TAVERN_FRONT_DOOR_ID:
		return
	_apply_tavern_door_state()

func _apply_tavern_door_state() -> void:
	var door := simulation.building_registry.get_door(TAVERN_FRONT_DOOR_ID)
	if door == null:
		return
	simulation.map_data.set_walkable(door.hex, door.is_passable())
	_refresh_tavern_door_presentation()

func _refresh_tavern_door_presentation() -> void:
	if not is_instance_valid(tavern_door_pivot):
		return
	var door := simulation.building_registry.get_door(TAVERN_FRONT_DOOR_ID)
	if door == null:
		return
	tavern_door_pivot.rotation.y = deg_to_rad(82.0) if door.is_passable() else 0.0


func _create_wilderness_creature_spawn_service() -> void:
	wilderness_creature_spawner = WILDERNESS_CREATURE_SPAWN_SERVICE.new() as WildernessCreatureSpawnService
	wilderness_creature_spawner.configure(
		simulation,
		self,
		Callable(self, "_hex_world_position"),
		Callable(self, "_is_wilderness_spawn_excluded"),
		ambient_rng
	)


func _is_wilderness_spawn_excluded(hex: Vector2i) -> bool:
	# The original Hollowmere/farm safety region remains authored by this
	# location; the shared service only owns the travel spawn lifecycle.
	return simulation.is_hex_within_range(Vector2i.ZERO, hex, 35) or HOLLOWMERE_TERRAIN_PROVIDER.is_farm_land(hex, HOLLOWMERE_TERRAIN_DEFINITION.DEFINITION)


func _hex_world_position(hex: Vector2i) -> Vector3:
	if _is_upper_floor_hex(hex):
		var local_hex := hex - UPPER_FLOOR_ORIGIN
		return HexGrid.axial_to_world(local_hex, HEX_RADIUS, UPPER_FLOOR_Y + 0.12)
	var centre := HexGrid.axial_to_world(hex, HEX_RADIUS)
	var inside_room: bool = absf(centre.x) < ROOM_HALF_WIDTH - 0.2 and absf(centre.z) < ROOM_HALF_DEPTH - 0.2
	return HexGrid.axial_to_world(hex, HEX_RADIUS, 0.12 if inside_room else 0.0)

func _add_box(parent: Node3D, node_name: String, position: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var box := BoxMesh.new()
	box.size = size
	instance.mesh = box
	instance.position = position
	instance.material_override = material
	parent.add_child(instance)
	return instance


func apply_player_profile(profile: Dictionary) -> void:
	var actor := actor_by_id.get("player") as Node3D
	if actor == null:
		return
	CampaignCharacterActorFactory.apply_player_profile(actor, profile)
