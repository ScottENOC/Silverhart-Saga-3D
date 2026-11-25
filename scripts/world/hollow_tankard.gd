class_name HollowTankard
extends Node3D

const REACTION_PROMPT_SCRIPT = preload("res://scripts/ui/reaction_prompt.gd")
const INITIATIVE_TIMELINE_SCRIPT = preload("res://scripts/ui/combat_initiative_timeline.gd")
const CHARACTER_PANEL_SCRIPT = preload("res://scripts/ui/character_panel.gd")
const WORLD_MAP_PANEL_SCRIPT = preload("res://scripts/ui/main_campaign_world_map.gd")
const AMBIENT_CHATTER_SCRIPT = preload("res://scripts/simulation/ambient_chatter.gd")
const WORLD_VEGETATION_SCRIPT = preload("res://scripts/world/world_vegetation_generator.gd")
const RESOURCE_VISUAL_SCRIPT = preload("res://scripts/presentation/wilderness_resource_visual.gd")
const HOLLOWMERE_ENCOUNTER_SCRIPT = preload("res://scripts/simulation/hollowmere_encounter.gd")
const COMPANION_CAMPAIGN_SCRIPT = preload("res://scripts/simulation/companion_campaign_content.gd")
const COMPANION_RUNTIME_STORE = preload("res://scripts/simulation/companion_campaign_runtime_store.gd")
const COMPANION_DIALOGUE_SERVICE = preload("res://scripts/simulation/companion_campaign_dialogue_service.gd")
const FARM_WOLVES_QUEST_SCRIPT = preload("res://scripts/simulation/farm_wolves_quest.gd")
const FARMSTEAD_DIRE_WOLF_SCRIPT = preload("res://scripts/simulation/farmstead_dire_wolf_encounter.gd")
const DWELLING_WORLD_SERVICE = preload("res://scripts/world/campaign_dwelling_world_service.gd")
const ABANDONED_HOUSE_QUEST_SCRIPT = preload("res://scripts/simulation/abandoned_house_clearing_quest.gd")
const DWELLING_WORLD_PRESENTATION = preload("res://scripts/presentation/campaign_dwelling_world_presentation.gd")
const SKELETAL_GUARDIAN_ACTOR_SCRIPT = preload("res://scripts/presentation/skeletal_guardian_actor.gd")
const HOLLOWMERE_PLACEMENTS = preload("res://data/settlements/hollowmere/placements.gd")
const HOLLOWMERE_TERRAIN_PROVIDER = preload("res://scripts/world/authored_settlement_terrain_provider.gd")
const HOLLOWMERE_TERRAIN_DEFINITION = preload("res://data/settlements/hollowmere/terrain.gd")
const WORLD_CELL_LOADER_SCRIPT = preload("res://scripts/world/campaign2_world_cell_loader.gd")
const WORLD_PLAYER_MOVEMENT_CONTROLLER = preload("res://scripts/world/world_player_movement_controller.gd")
const NPC_INTERACTION_SERVICE = preload("res://scripts/world/campaign_npc_interaction_service.gd")
const INTERIOR_LAYOUT_REGISTRAR = preload("res://scripts/world/world_interior_layout_registrar.gd")
const INTERIOR_LAYOUT_PRESENTER = preload("res://scripts/world/world_interior_layout_presenter.gd")
const HOLLOW_TANKARD_LAYOUT = preload("res://data/settlements/hollowmere/interiors/hollow_tankard_layout.gd")
const COMBAT_AI_SCRIPT = preload("res://scripts/simulation/combat_ai.gd")
const CREATURE_ACTOR_SCRIPT = preload("res://scripts/presentation/creature_actor.gd")
const SPELL_VFX_SCRIPT = preload("res://scripts/presentation/spell_vfx_controller.gd")
const SAVE_LOAD_MENU_SCRIPT = preload("res://scripts/ui/save_load_menu.gd")
const SAVE_MANAGER_SCRIPT = preload("res://scripts/save/save_manager.gd")
const PERSISTENT_RELATIONSHIP_STORE = preload("res://scripts/simulation/persistent_character_relationship_store.gd")
const PERSISTENT_DIALOGUE_CONTENT = preload("res://scripts/simulation/persistent_character_dialogue_content.gd")
const CAMPAIGN2_SOURCE_DIALOGUE_CONTENT = preload("res://scripts/simulation/campaign2_source_dialogue_content.gd")
const CAMPAIGN_FACTION_SIMULATION_SCRIPT = preload("res://scripts/simulation/campaign_faction_simulation.gd")
const CAMP_WORLD_PRESENTATION_SCRIPT = preload("res://scripts/presentation/camp_world_presentation.gd")
const CAMP_PARTY_ACTIVITY_DIRECTOR_SCRIPT = preload("res://scripts/presentation/camp_party_activity_director.gd")
const TAVERN_BUILDING_ID: String = HOLLOW_TANKARD_LAYOUT.BUILDING_ID
const TAVERN_FRONT_DOOR_ID: String = HOLLOW_TANKARD_LAYOUT.FRONT_DOOR_ID
const TAVERN_DOOR_HEX: Vector2i = HOLLOW_TANKARD_LAYOUT.DOOR_HEX
const UPPER_FLOOR_ORIGIN: Vector2i = HOLLOW_TANKARD_LAYOUT.UPPER_FLOOR_ORIGIN
const UPPER_FLOOR_Y: float = HOLLOW_TANKARD_LAYOUT.UPPER_FLOOR_Y
const TAVERN_STAIR_GROUND_HEX: Vector2i = HOLLOW_TANKARD_LAYOUT.STAIR_GROUND_HEX
const TAVERN_STAIR_UPPER_HEX: Vector2i = HOLLOW_TANKARD_LAYOUT.STAIR_UPPER_HEX
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
var spell_vfx: Node3D
var save_load_menu: CanvasLayer
var pending_save_data: Dictionary = {}
var campaign_faction_simulation: CampaignFactionSimulation
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
var ambient_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var ambient_accumulator: float = 0.0
var ambient_exchange_running: bool = false
var ambient_security: int = 50
var shakedown_started: bool = false
var shakedown_resolved: bool = false
var dialogue_open: bool = false
var dialogue_panel: CampaignDialoguePanel
var combat_hud: CampaignCombatHud
var resource_status_label: Label
var resource_visuals_by_hex: Dictionary = {}
var encounter_active: bool = false
var active_combat_kind: String = "ironbond"
var active_enemy_ids: Array[String] = []
var active_party_ids: Array[String] = []
var active_combat_controlled_ids: Array[String] = []
var nearby_interaction_panel: PanelContainer
var nearby_interaction_box: VBoxContainer
var nearby_interaction_refresh: float = 0.0
var farm_wolves_spawned: bool = false
var farm_wolves_retry_armed: bool = false
var reyna_clue_visual: Node3D
var active_encounter_character_states: Dictionary = {}
var wilderness_steps_since_spawn: int = 0
var wilderness_creature_nodes: Array[Node3D] = []
var enemy_turn_processed: bool = false
var enemy_turn_waiting_for_reaction: bool = false
var camp_presentation: CampWorldPresentation
var camp_activity_director: CampPartyActivityDirector
var camp_selection_mode: bool = false
var camp_button: Button
var camp_sleep_button: Button
var camp_status_label: Label

func _save_manager_service() -> Node:
	return get_node_or_null("/root/SaveManager")

func _ready() -> void:
	_create_materials()
	_create_lighting()
	spell_vfx = SPELL_VFX_SCRIPT.new() as Node3D
	spell_vfx.name = "SpellVisualEffects"
	add_child(spell_vfx)
	_configure_location_simulation()
	COMPANION_RUNTIME_STORE.register_quest_definitions(simulation)
	campaign_faction_simulation = CAMPAIGN_FACTION_SIMULATION_SCRIPT.new() as CampaignFactionSimulation
	_present_interior_layout()
	movement_controller = WORLD_PLAYER_MOVEMENT_CONTROLLER.new()
	movement_controller.name = "WorldPlayerMovementController"
	add_child(movement_controller)
	movement_controller.configure(simulation, self, tile_mesh, path_material, Callable(self, "_hex_world_position"), active_character_id)
	_create_wilderness_gatherable_grove()
	_create_characters()
	_create_reyna_shelter()
	_capture_initial_character_baselines()
	_create_camera()
	_create_camp_presentation()
	_create_hud()
	ambient_chatter = AMBIENT_CHATTER_SCRIPT.new() as AmbientChatter
	ambient_rng.randomize()
	var restored_from_save := not pending_save_data.is_empty()
	ABANDONED_HOUSE_QUEST_SCRIPT.register_definition(simulation.campaign_journal)
	if restored_from_save:
		_apply_save_data(pending_save_data)
		pending_save_data.clear()
	_refresh_dwelling_world_presentation()
	_restore_abandoned_house_guardian_actors()
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


func _reyna_objective_done(objective_id: String) -> bool:
	var quest := simulation.campaign_journal.quest_state("reyna_dire_wolf_hunt")
	var objectives: Dictionary = quest.get("objectives", {})
	if not objectives.has(objective_id):
		return false
	var objective: Dictionary = objectives[objective_id]
	return bool(objective.get("completed", false)) or float(objective.get("progress", 0.0)) >= float(objective.get("target", 1.0))


func _set_reyna_objective(objective_id: String) -> void:
	simulation.campaign_journal.set_objective_progress("reyna_dire_wolf_hunt", objective_id, 1.0)


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
	var quest := simulation.campaign_journal.quest_state("reyna_dire_wolf_hunt")
	if String(quest.get("status", "")) != "active":
		return
	if not _reyna_objective_done("trail_found"):
		_ensure_reyna_clue_visual()
		var active_state := simulation.get_character(active_character_id)
		if active_state != null and HexGrid.distance(active_state.axial, HOLLOWMERE_PLACEMENTS.REYNA_CLUE_HEX) <= 2:
			_set_reyna_objective("trail_found")
			if is_instance_valid(reyna_clue_visual):
				reyna_clue_visual.queue_free()
			reyna_clue_visual = null
			_show_dialogue("Reyna Fletcher", "A strip of Tessa's blue cloak. And look here — small footprints in the mud, beside the drag marks. She was alive when she left the fence. The trail leads to the old shepherd's shelter. Come on!", [{"id":"continue","label":"Follow the tracks","text":""}])
		return
	if not _reyna_objective_done("child_rescued") and not actor_by_id.has("missing_child_tessa"):
		var active_state_at_shelter := simulation.get_character(active_character_id)
		if active_state_at_shelter != null and HexGrid.distance(active_state_at_shelter.axial, HOLLOWMERE_PLACEMENTS.REYNA_SHELTER_HEX) <= 2:
			_spawn_missing_child()
			_show_speech_bubble("companion_reyna_fletcher", "Tessa? It's Reyna. Stay where you are — we're getting you out.")
			_show_dialogue("Reyna Fletcher", "The shelter door is hanging open. There's a child inside. I can hear her. The dire wolf is circling outside, waiting. Get close and speak softly; don't frighten her.", [{"id":"continue","label":"I'll get her out","text":""}])


func _rescue_missing_child() -> void:
	_close_dialogue()
	var child_state := simulation.get_character("missing_child_tessa")
	if child_state == null:
		_show_dialogue("Reyna Fletcher", "Tessa isn't here. We need to find the shelter.", [{"id":"continue","label":"Continue","text":""}])
		return
	_show_speech_bubble("companion_reyna_fletcher", "I'll draw it away from the door. Get Tessa to Old Mac — don't look back!")
	var path := simulation.find_path("missing_child_tessa", HOLLOWMERE_PLACEMENTS.OLD_MAC_RESCUE_DESTINATION_HEX)
	if path.size() > 1:
		for index in range(1, path.size()):
			if not simulation.try_move_character_step("missing_child_tessa", path[index]):
				break
			await get_tree().create_timer(0.16).timeout
			if not is_instance_valid(self):
				return
	var child_actor := actor_by_id.get("missing_child_tessa") as Node3D
	if child_actor != null:
		child_actor.global_position = _hex_world_position(child_state.axial)
	_set_reyna_objective("child_rescued")
	_show_speech_bubble("missing_child_tessa", "I thought it was going to get me. Thank you.")
	_show_speech_bubble("companion_reyna_fletcher", "She's safe. Now we make sure that thing never comes back.")
	_show_dialogue("Reyna Fletcher", "Tessa is back at Old Mac's farm. She heard the wolf trying to break into the shelter. It has been hunting more than livestock. We finish this now — the beast is still out there, near the fields.", [{"id":"continue","label":"Then let's end it","text":""}])

func _begin_dire_wolf_hunt_combat() -> void:
	_close_dialogue()
	var party_ids: Array[String] = []
	for value in simulation.get_party_member_ids():
		party_ids.append(String(value))
	var result := FARMSTEAD_DIRE_WOLF_SCRIPT.start(simulation, party_ids)
	if not bool(result.get("ok", false)):
		_show_dialogue("Reyna Fletcher", "We cannot face it just now: %s." % String(result.get("reason", "unknown reason")), [{"id":"continue","label":"Continue","text":""}])
		return
	active_encounter_character_states = result.get("previous_states", {})
	active_combat_kind = "dire_wolf_hunt"
	active_enemy_ids = [FARMSTEAD_DIRE_WOLF_SCRIPT.DIRE_WOLF_ID]
	active_party_ids.clear()
	active_combat_controlled_ids.clear()
	for value in result.get("party_ids", []):
		active_party_ids.append(String(value))
		active_combat_controlled_ids.append(String(value))
	encounter_active = true
	enemy_turn_processed = false
	enemy_turn_waiting_for_reaction = false
	if not active_party_ids.has(active_character_id):
		active_character_id = "player"
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



## Autonomous companion banter is presented over the characters themselves,
## not as player dialogue. Each speaker gets a turn and both actors are already
## playing their conversation animation when this arrives.
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
		await get_tree().create_timer(_speech_bubble_duration(text)).timeout



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
	if _is_upper_floor_hex(hex) or not simulation.map_data.has_cell(hex) or not simulation.map_data.is_walkable(hex):
		camp_status_label.text = "That ground is unsuitable for a campsite."
		return
	if simulation.is_hex_occupied(hex):
		camp_status_label.text = "Choose an unoccupied patch of ground."
		return
	var nearby_trees := false
	var water_nearby := false
	for candidate in simulation.map_data.cells:
		var candidate_hex: Vector2i = candidate
		if HexGrid.distance(hex, candidate_hex) > 4:
			continue
		var terrain := simulation.map_data.terrain_id_at(candidate_hex)
		if terrain == "forest":
			nearby_trees = true
		elif terrain == "water":
			water_nearby = true
		if nearby_trees and water_nearby:
			break
	var site := {
		"hex": hex,
		"position": _hex_world_position(hex),
		"walkable": true,
		"occupied": false,
		"terrain_id": simulation.map_data.terrain_id_at(hex)
	}
	for dwelling_site in DWELLING_WORLD_SERVICE.nearby_sites(hex, 3):
		var dwelling_id := String(dwelling_site.get("dwelling_id", ""))
		var dwelling_profile := simulation.campaign_dwellings.camp_profile_for(dwelling_id)
		if not dwelling_profile.is_empty() and bool(dwelling_profile.get("is_sheltered", false)):
			site["dwelling_id"] = dwelling_id
			break
	var environment := {
		"trees_nearby": nearby_trees,
		"water_nearby": water_nearby,
		"danger": clampf(1.0 - float(ambient_security) / 100.0, 0.05, 0.8)
	}
	var result := simulation.begin_camp(site, environment, {}, active_character_id)
	if not bool(result.get("ok", false)):
		camp_status_label.text = "Could not establish camp: %s" % String(result.get("reason", "unknown"))
		return
	camp_presentation.present_camp(simulation.camp_simulation.site, simulation.camp_simulation.sleeping_arrangements, simulation.camp_simulation.environment)
	camp_activity_director.begin_camp(simulation.camp_simulation.site)
	var weather_summary := _camp_weather_summary(simulation.camp_simulation.environment)
	camp_status_label.text = "Camp established · %s. The party's evening routines will adapt to the conditions." % weather_summary
	if camp_sleep_button != null:
		camp_sleep_button.visible = true
		camp_sleep_button.text = "Sleep until morning"


func _sleep_or_pack_camp() -> void:
	if simulation == null:
		return
	if simulation.camp_simulation.phase == "evening":
		camp_activity_director.stop()
		var result := simulation.skip_camp_to_morning()
		if not bool(result.get("ok", false)):
			camp_status_label.text = "Could not begin the night: %s" % String(result.get("reason", "unknown"))
			return
		var summary: Dictionary = result.get("summary", {})
		camp_presentation.present_camp(simulation.camp_simulation.site, simulation.camp_simulation.sleeping_arrangements, simulation.camp_simulation.environment)
		camp_status_label.text = "Morning. Camp comfort: %d/100 · estimated overnight ambush risk: %d%%." % [
			roundi(float(summary.get("average_comfort", 0.0))),
			roundi(float(summary.get("ambush_chance", 0.0)) * 100.0)
		]
		camp_sleep_button.text = "Pack camp"
	elif simulation.camp_simulation.phase == "resolved":
		camp_activity_director.stop()
		camp_presentation.clear_camp()
		camp_sleep_button.visible = false
		camp_status_label.text = "Camp packed. Ready to continue travelling."
		simulation.camp_simulation.phase = "inactive"


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
	controls_dialog.dialog_text = "MOVE\\nW / A / S / D / Q / E — move one hex\\nClick a walkable hex — plot a path\\n[ and ] — turn active character\\n\\nINTERACT\\nF — use nearby door/stairs or talk to nearest person\\nG — gather nearby resource\\nTab — switch active party member\\nC — character sheet\\nK — skill trees and skill points\\nI — inventory and equipment\\n\\nCOMBAT\\nSpace — attack\\nEnter — end turn\\n\\nWORLD\\nV — toggle roof"
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
	initial_character_baselines.clear()
	for state in simulation.character_states():
		initial_character_baselines[state.id] = state.to_dict()

func _build_character_diffs() -> Dictionary:
	var diffs: Dictionary = {}
	for state in simulation.character_states():
		var character_id := state.id
		var current := state.to_dict()
		if not initial_character_baselines.has(character_id):
			diffs[character_id] = {"__full_record": current}
			continue
		var baseline: Dictionary = initial_character_baselines[character_id]
		var changed: Dictionary = {}
		for field in current.keys():
			if not baseline.has(field) or current[field] != baseline[field]:
				changed[field] = current[field]
		if not changed.is_empty():
			diffs[character_id] = changed
	return diffs

func _build_appearance_diffs() -> Dictionary:
	var diffs: Dictionary = {}
	for actor_id_variant in actor_by_id.keys():
		var actor_id := String(actor_id_variant)
		var actor := actor_by_id[actor_id] as Node3D
		if actor == null or actor_id == "player":
			continue
		var base: Dictionary = actor.get_meta("base_appearance_profile", {})
		var current: Dictionary = actor.get_meta("appearance_profile", base)
		var changed: Dictionary = {}
		for field in current.keys():
			if not base.has(field) or current[field] != base[field]:
				changed[field] = current[field]
		if not changed.is_empty():
			diffs[actor_id] = changed
	return diffs

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
		"dynamic_campaign_characters": ABANDONED_HOUSE_QUEST_SCRIPT.dynamic_character_records(simulation),
		"world_flags": {
			"ambient_security": ambient_security,
			"shakedown_started": shakedown_started,
			"shakedown_resolved": shakedown_resolved,
			"farm_wolves_spawned": farm_wolves_spawned,
			"farm_wolves_retry_armed": farm_wolves_retry_armed,
			"wilderness_steps_since_spawn": wilderness_steps_since_spawn
		},
		"camera": {
			"zoom_distance": camera_rig.zoom_distance if camera_rig != null else 28.0,
			"rotation": camera_rig.rotation if camera_rig != null else Vector3.ZERO
		},
		"playtime_seconds": 0.0
	}

func _apply_save_data(data: Dictionary) -> void:
	simulation.reset_transient_combat_state()
	var restored_states: Array[CharacterState] = []
	var saved_diffs: Variant = data.get("character_diffs", {})
	if saved_diffs is Dictionary:
		for character_id_variant in saved_diffs.keys():
			var character_id := String(character_id_variant)
			var diff: Variant = saved_diffs[character_id_variant]
			if not diff is Dictionary:
				continue
			var restored: CharacterState
			if diff.has("__full_record"):
				restored = CharacterState.from_dict(diff["__full_record"])
			else:
				var existing := simulation.get_character(character_id)
				if existing == null:
					push_warning("Save references unknown base character '%s'; skipped." % character_id)
					continue
				var merged := existing.to_dict()
				merged.merge(diff, true)
				restored = CharacterState.from_dict(merged)
			restored.id = character_id
			restored_states.append(restored)
	if not simulation.restore_character_states(restored_states):
		push_error("Saved character states could not be restored without invalid occupancy or mount links.")
		return
	var dynamic_records: Variant = data.get("dynamic_campaign_characters", {})
	if dynamic_records is Dictionary:
		for character_id_value in dynamic_records.keys():
			var character_id := String(character_id_value)
			if simulation.get_character(character_id) != null or not (dynamic_records[character_id_value] is Dictionary):
				continue
			var dynamic_state := CharacterState.from_dict(dynamic_records[character_id_value])
			if dynamic_state != null:
				simulation.register_character(dynamic_state)
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
	# Older saves stored both a location-side roster and a simulation roster.
	# Prefer the former for historical party ordering, then retain any members
	# present only in the simulation snapshot. New saves write one canonical list.
	var restored_party_ids: Array[String] = []
	var legacy_location_party: Variant = data.get("party_member_ids", null)
	var legacy_simulation_party: Variant = data.get("simulation_party_member_ids", null)
	if legacy_location_party is Array:
		for member_id in legacy_location_party:
			var id := String(member_id)
			if not restored_party_ids.has(id):
				restored_party_ids.append(id)
	if legacy_simulation_party is Array:
		for member_id in legacy_simulation_party:
			var id := String(member_id)
			if not restored_party_ids.has(id):
				restored_party_ids.append(id)
	if restored_party_ids.is_empty():
		restored_party_ids = ["player", "companion_wren_talbot"]
	simulation.restore_party_members(restored_party_ids)
	var clock_data: Variant = data.get("clock", {})
	if clock_data is Dictionary:
		simulation.clock.load_dict(clock_data)
	var weather_data: Variant = data.get("world_weather", {})
	if weather_data is Dictionary and not weather_data.is_empty():
		if not simulation.weather_state.load_dict(weather_data):
			push_warning("Saved world weather seed was invalid; a new weather sequence was generated.")
	simulation.weather_state.update_to(simulation.clock.world_seconds)
	var saved_camp: Variant = data.get("camp_simulation", {})
	if saved_camp is Dictionary and not saved_camp.is_empty():
		if not simulation.camp_simulation.from_dict(saved_camp):
			push_warning("Saved camp state was invalid and has been reset.")
			simulation.camp_simulation = CampSimulation.new()
	var saved_dwellings: Variant = data.get("campaign_dwellings", {})
	if saved_dwellings is Dictionary and not saved_dwellings.is_empty():
		if not simulation.campaign_dwellings.from_dict(saved_dwellings):
			push_warning("Saved player dwelling ownership was invalid and has been reset.")
			simulation.campaign_dwellings = CampaignDwellingState.new()
	var saved_bonds: Variant = data.get("companion_bonds", {})
	if saved_bonds is Dictionary and not saved_bonds.is_empty():
		if not simulation.companion_bonds.from_dict(saved_bonds):
			push_warning("Saved companion-to-companion relationships were invalid and have been reset.")
			simulation.companion_bonds = CompanionBondState.new()
	var journal_data: Variant = data.get("campaign_journal", {})
	if journal_data is Dictionary:
		simulation.campaign_journal.load_dict(journal_data)
	var persistent_relationship_data: Variant = data.get("persistent_character_relationships", {})
	if persistent_relationship_data is Dictionary:
		if not PERSISTENT_RELATIONSHIP_STORE.restore(simulation, persistent_relationship_data):
			push_warning("Persistent NPC relationship state could not be fully synchronised with the campaign journal.")
	var companion_runtime_data: Variant = data.get("companion_campaign_runtime", {})
	if companion_runtime_data is Dictionary and not COMPANION_RUNTIME_STORE.restore(simulation, companion_runtime_data):
		push_warning("Companion relationship and personal quest state could not be fully restored.")
	# Dynamic Tessa is saved as a full character record. Recreate her presentation
	# after the journal is restored, retaining her saved axial position.
	if simulation.get_character("missing_child_tessa") != null:
		_spawn_missing_child()
	var multistory_data: Variant = data.get("multistory_locations", {})
	if multistory_data is Dictionary and not simulation.restore_multistory_location_states(multistory_data):
		push_warning("Some multi-story location state could not be restored; affected locations will use their validated defaults.")
	var resource_data: Variant = data.get("wilderness_resources", {})
	if resource_data is Dictionary:
		simulation.wilderness_resources.load_dict(resource_data)
	var building_data: Variant = data.get("buildings", {})
	if building_data is Dictionary:
		simulation.building_registry.load_dict(building_data)
	var flags: Dictionary = data.get("world_flags", {})
	ambient_security = int(flags.get("ambient_security", ambient_security))
	shakedown_started = bool(flags.get("shakedown_started", false))
	shakedown_resolved = bool(flags.get("shakedown_resolved", false))
	farm_wolves_spawned = bool(flags.get("farm_wolves_spawned", false))
	farm_wolves_retry_armed = bool(flags.get("farm_wolves_retry_armed", false))
	wilderness_steps_since_spawn = int(flags.get("wilderness_steps_since_spawn", 0))
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
	var saved_dire_wolf := simulation.get_character(FARMSTEAD_DIRE_WOLF_SCRIPT.DIRE_WOLF_ID)
	if saved_dire_wolf == null or not saved_dire_wolf.can_act():
		var defeated_wolf_actor := actor_by_id.get(FARMSTEAD_DIRE_WOLF_SCRIPT.DIRE_WOLF_ID) as Node3D
		if is_instance_valid(defeated_wolf_actor):
			defeated_wolf_actor.queue_free()
		actor_by_id.erase(FARMSTEAD_DIRE_WOLF_SCRIPT.DIRE_WOLF_ID)
	if simulation.camp_simulation.phase in ["evening", "night", "resolved"]:
		camp_presentation.present_camp(simulation.camp_simulation.site, simulation.camp_simulation.sleeping_arrangements, simulation.camp_simulation.environment)
		if simulation.camp_simulation.phase == "evening":
			camp_activity_director.begin_camp(simulation.camp_simulation.site)
		camp_sleep_button.visible = true
		camp_sleep_button.text = "Sleep until morning" if simulation.camp_simulation.phase == "evening" else "Pack camp"
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
	dialogue_panel.choice_selected.connect(_select_dialogue_choice)
	layer.add_child(dialogue_panel)


func _show_dialogue(speaker: String, body: String, choices: Array[Dictionary], expression: String = "neutral") -> void:
	if dialogue_panel == null:
		return
	dialogue_open = true
	var speaker_actor := _portrait_actor_for_speaker(speaker)
	dialogue_panel.present(speaker, body, choices, null, speaker_actor, expression)


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
	if choice_id.begins_with("furniture_buy:"):
		var item_id := choice_id.trim_prefix("furniture_buy:")
		var purchase := simulation.buy_dwelling_furniture(item_id, 1, active_character_id)
		var inspection := DWELLING_WORLD_SERVICE.furniture_shop_inspection(simulation.get_character(simulation.player_character_id))
		if bool(purchase.get("ok", false)):
			_show_dialogue(String(inspection.get("speaker", "Furniture Shop")), "%s purchased. The piece is now in your furniture inventory.\n\n%s" % [String(CampaignFurnitureCatalog.definition(item_id).get("name", item_id)), String(inspection.get("text", ""))], inspection.get("choices", []))
		else:
			var reason := String(purchase.get("reason", "purchase_failed")).replace("_", " ")
			_show_dialogue(String(inspection.get("speaker", "Furniture Shop")), "The purchase could not be completed: %s.\n\n%s" % [reason, String(inspection.get("text", ""))], inspection.get("choices", []))
		return
	if choice_id.begins_with("dwelling_action:"):
		var parts := choice_id.split(":")
		if parts.size() == 4:
			var result := simulation.claim_dwelling(String(parts[1]), String(parts[2]), String(parts[3]), active_character_id)
			if bool(result.get("ok", false)):
				_refresh_dwelling_world_presentation()
				var dwelling_name := String(result.get("dwelling_id", "Property")).replace("_", " ")
				var layout_id := String(result.get("layout_id", ""))
				_show_dialogue("Property", "The work is complete. %s is now yours.\nLayout identity: %s." % [dwelling_name.capitalize(), layout_id], [{"id": "continue", "label": "Continue", "text": ""}])
			else:
				_show_dialogue("Property", "That work cannot be completed: %s." % String(result.get("reason", "requirements_not_met")).replace("_", " "), [{"id": "continue", "label": "Understood.", "text": ""}])
		else:
			_show_dialogue("Property", "That property action is invalid.", [{"id": "continue", "label": "Understood.", "text": ""}])
		return
	if choice_id == "abandoned_house_investigate":
		var started := ABANDONED_HOUSE_QUEST_SCRIPT.ensure_started(simulation.campaign_journal)
		var spawned := ABANDONED_HOUSE_QUEST_SCRIPT.ensure_guardians(simulation)
		if bool(started.get("ok", false)) and bool(spawned.get("ok", false)):
			_restore_abandoned_house_guardian_actors()
			_show_dialogue("Abandoned House", "The journal lies in the centre of the room. Three skeletons turn towards you, their weapons scraping against the old floorboards.", [{"id": "abandoned_house_enter", "label": "Face the guardians.", "text": ""}, {"id": "continue", "label": "Withdraw for now.", "text": ""}])
		else:
			_show_dialogue("Abandoned House", "The house cannot be investigated right now.", [{"id": "continue", "label": "Continue", "text": ""}])
		return
	if choice_id == "abandoned_house_finalize":
		ABANDONED_HOUSE_QUEST_SCRIPT.apply_defeat_consequences(simulation.campaign_journal, simulation)
		var clearing := ABANDONED_HOUSE_QUEST_SCRIPT.resolve_clearing(simulation.campaign_journal, simulation)
		if bool(clearing.get("ok", false)) and bool(clearing.get("completed", false)):
			_show_dialogue("Abandoned House", "The last of the necromancer's undead minions is gone. The house can now be restored.", [{"id": "continue", "label": "Continue", "text": ""}])
		else:
			_show_dialogue("Abandoned House", "The clearing is not yet resolved: %s." % String(clearing.get("reason", "remaining necromancer minions")).replace("_", " "), [{"id": "continue", "label": "Understood.", "text": ""}])
		return
	if choice_id == "abandoned_house_enter":
		_begin_abandoned_house_encounter()
		return
	if _handle_seraphine_choice(choice):
		return
	if choice_id == "wren_arc_topic:why_stay":
		_show_wren_arc_topic("why_stay")
		return
	if choice_id == "wren_arc_topic:parents_reflection":
		_show_wren_arc_topic("parents_reflection")
		return
	if choice_id.begins_with("wren_arc_choice:"):
		var wren_choice_id := choice_id.trim_prefix("wren_arc_choice:")
		var wren_arc := COMPANION_RUNTIME_STORE.wren_arc_state_for(simulation)
		var wren_relationships := COMPANION_RUNTIME_STORE.relationship_state_for(simulation)
		if wren_arc != null:
			var applied := wren_arc.apply_dialogue_choice(wren_choice_id, wren_relationships)
			if bool(applied.get("ok", false)):
				_show_dialogue("Wren Talbot", wren_arc.dialogue_response_for(wren_choice_id), [{"id":"continue","label":"I understand.","text":""}])
				return
		_show_wren_dialogue()
		return
	if choice_id == "companion_chapter_start":
		var chapter_id := String(choice.get("chapter_id", ""))
		var start_result := COMPANION_DIALOGUE_SERVICE.start_chapter(simulation, chapter_id)
		if bool(start_result.get("ok", false)):
			_show_companion_dialogue(String(choice.get("companion_id", "")))
		else:
			_show_dialogue("Campaign journal", "That chapter could not be started: %s." % String(start_result.get("reason", "unknown reason")), [{"id":"continue","label":"Continue","text":""}])
		return
	if choice_id == "companion_chapter_resolve":
		var resolution_result := COMPANION_DIALOGUE_SERVICE.resolve_chapter(simulation, String(choice.get("chapter_id", "")), String(choice.get("resolution_id", "")))
		if bool(resolution_result.get("ok", false)):
			var reward_text := String(resolution_result.get("line", "The decision is made."))
			var xp_reward := int(resolution_result.get("xp_reward", 0))
			var player_state := simulation.get_character("player")
			if player_state != null and xp_reward > 0:
				player_state.experience += xp_reward
				reward_text += "\n\nChapter complete · %d XP gained." % xp_reward
			_show_dialogue(String(choice.get("companion_name", "Companion")), reward_text, [{"id":"continue","label":"Continue","text":""}])
		else:
			_show_dialogue("Campaign journal", "That resolution could not be recorded: %s." % String(resolution_result.get("reason", "unknown reason")), [{"id":"continue","label":"Continue","text":""}])
		return
	if choice_id.begins_with("start:"):
		var quest_id := choice_id.trim_prefix("start:")
		var start_result := simulation.campaign_journal.start_quest(quest_id)
		if bool(start_result.get("ok", false)):
			_show_companion_dialogue(String(choice.get("companion_id", "")))
		else:
			_show_dialogue("Campaign journal", "That quest could not be started: %s." % String(start_result.get("reason", "unknown reason")), [{"id":"continue","label":"Continue","text":""}])
		return
	if choice_id.begins_with("recruit:"):
		_recruit_staged_companion(choice_id.trim_prefix("recruit:"))
		return
	if choice_id == "farm_wolves_accept":
		var accepted := FARM_WOLVES_QUEST_SCRIPT.accept(simulation.campaign_journal)
		if bool(accepted.get("ok", false)):
			_show_dialogue("Old Mac", "Bless you. The fence is broken on the western side of the pasture. I found blood leading into the trees. Their den must be out there somewhere.", [{"id": "continue", "label": "I'll follow the trail.", "text": ""}])
		else:
			_show_dialogue("Old Mac", "I cannot ask you to take that on just now.", [{"id": "continue", "label": "All right.", "text": ""}])
		return
	if choice_id == "farm_wolves_turn_in":
		var player := simulation.get_character("player")
		var reward := FARM_WOLVES_QUEST_SCRIPT.turn_in(simulation.campaign_journal, player)
		if bool(reward.get("ok", false)):
			_show_dialogue("Old Mac", "I won't forget what you've done. Take this, and know the farm owes you a favour.", [{"id": "continue", "label": "Thank you.", "text": ""}])
			resource_status_label.text = "Quest complete: Wolves at the Farm  ·  +25 gold  ·  +150 XP"
		else:
			_show_dialogue("Old Mac", "The cattle are not safe yet.", [{"id": "continue", "label": "I'll return.", "text": ""}])
		return
	if choice_id == "farm_wolves_continue" or choice_id == "farm_wolves_decline":
		_show_dialogue("Old Mac", String(choice.get("text", "Take care on the road.")), [{"id": "continue", "label": "Continue", "text": ""}])
		return
	if choice_id == "reyna_rescue_child":
		await _rescue_missing_child()
		return
	if choice_id == "continue":
		_close_dialogue()
		return
	if choice_id == "fight":
		_begin_shakedown_combat()
		return
	if choice.has("ironbond_delta"):
		_resolve_shakedown(choice_id)
		await _move_shakedown_soldiers_outside()
		var response := String(choice.get("response", ""))
		if response.is_empty():
			response = "You stand with Garrick. The encounter is ready to begin once combat targeting and enemy AI are connected."
		_show_dialogue("Hollowmere", response, [{"id": "continue", "label": "Continue", "text": ""}])
		return

	var response_text := String(choice.get("text", ""))
	if choice_id == "spar":
		response_text += "\n\nA full sparring encounter is not connected to the 3D combat interface yet."
	_show_dialogue(dialogue_panel.speaker_text, response_text, [{"id": "continue", "label": "Continue", "text": ""}])

func _handle_seraphine_choice(choice: Dictionary) -> bool:
	var choice_id := String(choice.get("id", ""))
	if not choice_id.begins_with("seraphine_"):
		return false
	if choice_id == "seraphine_leave":
		_close_dialogue()
		return true
	var content := PERSISTENT_DIALOGUE_CONTENT.new()
	var relationships := PERSISTENT_RELATIONSHIP_STORE.state_for(simulation)
	var journal := simulation.campaign_journal
	var context := {
		"silverhart_standing": journal.faction_standing("silverhart_kingdom"),
		"goblin_standing": journal.faction_standing("goblin_tribe"),
		"ironbond_influence": journal.merchant_influence_for("ironbond_company", "silverhart_kingdom"),
		"necromancer_standing": journal.faction_standing("necromancer_cult"),
		"phylactery_returned": bool(simulation.get_meta("phylactery_returned", false)),
		"manor_granted": bool(simulation.campaign_dwellings.owned.get("silverhart_manor", false)),
		"has_phylactery_shard": _player_has_item("phylactery_shard"),
		"wizard_vendetta_active": String(journal.quest_state("wizard_vendetta").get("status", "")) == "active",
		"has_wizard_corruption_evidence": _player_has_item("wizard_corruption_evidence"),
		"chancellor_tunnel_discovered": bool(simulation.get_meta("chancellor_tunnel_discovered", false)),
		"chancellor_tunnel_reported": bool(simulation.get_meta("chancellor_tunnel_reported_to_queen", false))
	}
	var response: Dictionary = {}
	match choice_id:
		"seraphine_topic_greenskins":
			response = content.seraphine_topic_response("greenskins", context, relationships)
		"seraphine_topic_ironbond":
			response = content.seraphine_topic_response("ironbond", context, relationships)
		"seraphine_topic_necromancy":
			response = content.seraphine_topic_response("necromancy", context, relationships)
		"seraphine_personal_burden":
			response = content.seraphine_personal_response(relationships)
		"seraphine_request_favour":
			response = content.seraphine_manor_request_response()
		"seraphine_manor_accept":
			var grant := simulation.claim_dwelling("claim_silverhart_manor", "materials", "silverhart_palace", active_character_id)
			if not bool(grant.get("ok", false)):
				_show_dialogue("Queen Seraphine Corrin", "I cannot grant the townhouse just now: %s." % String(grant.get("reason", "requirements_not_met")).replace("_", " "), [{"id":"continue","label":"Understood","kind":"leave"}])
				return true
			simulation.set_meta("silverhart_manor_granted", true)
			_refresh_dwelling_world_presentation()
			response = content.seraphine_manor_granted_response()
		"seraphine_manor_followup":
			response = {"ok": true, "speaker": "Queen Seraphine Corrin", "text": "The grant remains yours. The townhouse is still in need of fortification; timber and stone will see it restored.", "response_label": "I will see to it."}
		"seraphine_wizard_evidence":
			response = content.seraphine_wizard_evidence_response()
		"seraphine_report_chancellor_tunnel":
			response = content.seraphine_chancellor_tunnel_response()
			if bool(response.get("ok", false)):
				simulation.set_meta("chancellor_tunnel_reported_to_queen", true)
				journal.adjust_faction_standing("silverhart_kingdom", 15, "reported_chancellor_tunnel_to_queen")
				journal.adjust_faction_standing("thieves_guild", -20, "reported_chancellor_tunnel_to_queen")
		_:
			return false
	if not bool(response.get("ok", false)):
		_show_dialogue("Queen Seraphine Corrin", "That matter cannot be discussed just now.", [{"id":"continue","label":"Understood","kind":"leave"}])
		return true
	var response_choices: Array = response.get("choices", [])
	if response_choices.is_empty():
		response_choices = [{"id":"continue","label":String(response.get("response_label", "Continue")),"kind":"leave"}]
	_show_dialogue(
		String(response.get("speaker", "Queen Seraphine Corrin")),
		String(response.get("text", "")),
		response_choices
	)
	return true


func _close_dialogue() -> void:
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
		if state.side == "enemy" and actor_id != FARMSTEAD_DIRE_WOLF_SCRIPT.DIRE_WOLF_ID:
			continue
		var distance := HexGrid.distance(player_state.axial, state.axial)
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
	if player_state == null or target_state == null or HexGrid.distance(player_state.axial, target_state.axial) > 2:
		return
	if character_id == FARMSTEAD_DIRE_WOLF_SCRIPT.DIRE_WOLF_ID:
		if not _reyna_objective_done("child_rescued"):
			_show_dialogue("Dire wolf", "The dire wolf circles the shepherd's shelter. You cannot safely engage it while Tessa is still inside.", [{"id":"continue","label":"Understood","text":""}])
			return
		_begin_dire_wolf_hunt_combat()
		return
	if character_id == "missing_child_tessa":
		if _reyna_objective_done("child_rescued"):
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
	var quest_state := simulation.campaign_journal.quest_state(HollowmereCampaignContent.QUEST_ID)
	var decisions: Dictionary = quest_state.get("decisions", {})
	var response_choice := String(decisions.get("response", ""))
	var standing := simulation.campaign_journal.npc_standing(character_id)
	var conversation := HollowmereCampaignContent.npc_greeting(character_id, shakedown_resolved, standing, response_choice)
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
		if bool(nearby[index].get("hostile", false)) and String(nearby[index].get("id", "")) != FARMSTEAD_DIRE_WOLF_SCRIPT.DIRE_WOLF_ID:
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
		if party_state == null or HexGrid.distance(active_state.axial, party_state.axial) > 2:
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
	if dialogue_id == "silverhart_queen":
		var relationships := PERSISTENT_RELATIONSHIP_STORE.state_for(simulation)
		var content := PERSISTENT_DIALOGUE_CONTENT.new()
		var journal := simulation.campaign_journal
		var context := {
			"silverhart_standing": journal.faction_standing("silverhart_kingdom"),
			"manor_granted": bool(simulation.campaign_dwellings.owned.get("silverhart_manor", false)),
			"goblin_standing": journal.faction_standing("goblin_tribe"),
			"ironbond_influence": journal.merchant_influence_for("ironbond_company", "silverhart_kingdom"),
			"necromancer_standing": journal.faction_standing("necromancer_cult")
		}
		var conversation: Dictionary = content.seraphine_greeting(context, relationships)
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
	var journal := simulation.campaign_journal
	var guild_favor_state := journal.quest_state("guild_favor")
	var wizard_vendetta_state := journal.quest_state("wizard_vendetta")
	var dragon_state := journal.quest_state("millbrook_dragon")
	var goblin_state := journal.quest_state("goblin_threat")
	var goblin_decisions: Dictionary = goblin_state.get("decisions", {})
	var context := {
		"guild_favor_active": String(guild_favor_state.get("status", "")) == "active",
		"ironbond_influence": journal.merchant_influence_for("ironbond_company", "silverhart_kingdom"),
		"ironbond_standing": journal.faction_standing("ironbond_company"),
		"wizard_resolution": String(wizard_vendetta_state.get("resolution", "")),
		"wizard_standing": journal.npc_standing("court_wizard_thessaly"),
		"millbrook_dragon_active": String(dragon_state.get("status", "")) == "active",
		"millbrook_dragon_completed": String(dragon_state.get("status", "")) == "completed",
		"goblin_resolution": String(goblin_state.get("resolution", goblin_decisions.get("resolution", "")))
	}
	var conversation := CAMPAIGN2_SOURCE_DIALOGUE_CONTENT.greeting(dialogue_id, target_state.display_name, context)
	if conversation.is_empty():
		conversation = CAMPAIGN2_SOURCE_DIALOGUE_CONTENT.role_greeting(
			target_state.id,
			target_state.display_name,
			String(actor.get_meta("title", "")),
			String(actor.get_meta("ambient_role", "civilian"))
		)
	var choices: Array[Dictionary] = []
	for choice_value in conversation.get("choices", []):
		if choice_value is Dictionary:
			choices.append(choice_value.duplicate(true))
	_show_dialogue(String(conversation.get("speaker", target_state.display_name)), String(conversation.get("text", "")), choices)


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
	var state := simulation.get_character(character_id)
	if state == null:
		_show_dialogue("Recruitment", "That companion is not present in this location.", [{"id":"continue","label":"Continue","text":""}])
		return
	if simulation.is_party_member(character_id):
		_show_dialogue(state.display_name, "I'm already travelling with you.", [{"id":"continue","label":"Continue","text":""}])
		return
	var player_state := simulation.get_character("player")
	if player_state == null:
		return
	if character_id == "companion_fenn_oakheart" and COMPANION_CAMPAIGN_SCRIPT.count_item(player_state.inventory, "herbs") < 3:
		_show_companion_dialogue(character_id)
		return
	var recruit_result := simulation.recruit_companion(character_id)
	if not bool(recruit_result.get("ok", false)):
		_show_dialogue("Recruitment", "Could not recruit %s: %s." % [state.display_name, String(recruit_result.get("reason", "unknown reason"))], [{"id":"continue","label":"Continue","text":""}])
		return
	if character_id == "companion_fenn_oakheart":
		COMPANION_CAMPAIGN_SCRIPT.consume_item(player_state.inventory, "herbs", 3)
		COMPANION_CAMPAIGN_SCRIPT.complete_objective(simulation.campaign_journal, "fenn_herb_gathering", "herbs_delivered")
	var actor := actor_by_id.get(character_id) as Node3D
	if actor != null:
		actor.set_meta("ambient_enabled", false)
	if party_switch_button != null and active_character_id == character_id:
		party_switch_button.text = "Active: %s  [Tab] Switch" % state.display_name
	if character_panel != null and active_character_id == character_id:
		character_panel.set_character(active_character_id)
	_show_dialogue(state.display_name, "%s joins your party. Their existing skills and equipment are preserved; future skill points are yours to allocate." % state.display_name, [{"id":"continue","label":"Continue","text":""}])


func _resolve_shakedown(choice_id: String) -> void:
	if shakedown_resolved:
		return
	var result := HollowmereCampaignContent.resolve_shakedown(simulation.campaign_journal, choice_id)
	if not bool(result.get("ok", false)):
		return
	shakedown_resolved = true
	_record_wren_authored_event("hollowmere_shakedown:" + choice_id)

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
	simulation.campaign_journal.start_quest(HollowmereCampaignContent.QUEST_ID)
	await get_tree().create_timer(2.0).timeout
	if not is_instance_valid(self):
		return
	_show_speech_bubble("companion_wren_talbot", "Well, here we are then. Try not to get us both killed, yeah?")
	await get_tree().create_timer(6.0).timeout
	if not is_instance_valid(self) or shakedown_started:
		return
	shakedown_started = true
	var opening_lines := HollowmereCampaignContent.opening_lines()
	for index in range(opening_lines.size()):
		var line: Dictionary = opening_lines[index]
		var speaker_id := String(line.get("speaker_id", "dray_coltayne"))
		if speaker_id == "narrator":
			_show_world_narration(String(line.get("text", "")))
			await _move_shakedown_soldiers_inside()
		else:
			_show_speech_bubble(speaker_id, String(line.get("text", "")))
		await get_tree().create_timer(2.25).timeout
	if not shakedown_resolved:
		_show_dialogue("Dray Coltayne", "What do you do?", HollowmereCampaignContent.shakedown_choices())


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


func _show_world_narration(text: String) -> void:
	var bubble := Label3D.new()
	bubble.name = "NarrationBubble"
	bubble.text = _wrap_speech_bubble_text(text)
	bubble.position = Vector3(0.0, 4.4, 0.0)
	bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bubble.font_size = 22
	bubble.pixel_size = 0.008
	bubble.outline_size = 6
	bubble.modulate = Color(0.98, 0.96, 0.86)
	add_child(bubble)
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = _speech_bubble_duration(text)
	add_child(timer)
	timer.timeout.connect(func():
		if is_instance_valid(bubble):
			bubble.queue_free()
		if is_instance_valid(timer):
			timer.queue_free()
	)
	timer.start()


func _show_speech_bubble(character_id: String, text: String) -> void:
	var actor := actor_by_id.get(character_id) as Node3D
	if actor == null:
		return
	var bubble := Label3D.new()
	bubble.name = "SpeechBubble"
	bubble.text = text
	bubble.position = Vector3(0.0, 3.0, 0.0)
	bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bubble.font_size = 22
	bubble.pixel_size = 0.008
	bubble.outline_size = 6
	bubble.modulate = Color(1.0, 0.97, 0.86)
	actor.add_child(bubble)
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = 2.15
	actor.add_child(timer)
	timer.timeout.connect(func():
		if is_instance_valid(bubble):
			bubble.queue_free()
		if is_instance_valid(timer):
			timer.queue_free()
	)
	timer.start()



func _wrap_speech_bubble_text(value: String, max_characters: int = 34) -> String:
	var wrapped_lines := PackedStringArray()
	var current_line := ""
	for word_value in value.split(" ", false):
		var word := String(word_value)
		if current_line.is_empty():
			current_line = word
		elif current_line.length() + 1 + word.length() > max_characters:
			wrapped_lines.append(current_line)
			current_line = word
		else:
			current_line += " " + word
	if not current_line.is_empty():
		wrapped_lines.append(current_line)
	return "\n".join(wrapped_lines)


func _speech_bubble_duration(value: String) -> float:
	var line_count := _wrap_speech_bubble_text(value).split("\n", false).size()
	return clampf(1.8 + float(line_count) * 0.85 + float(value.length()) * 0.008, 2.5, 6.5)


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
			if first_state != null and second_state != null and HexGrid.distance(first_state.axial, second_state.axial) <= 2:
				pairs.append([candidates[i], candidates[j]])
	if pairs.is_empty():
		return
	var pair: Array = pairs[ambient_rng.randi_range(0, pairs.size() - 1)]
	var first_id := String(pair[0])
	var second_id := String(pair[1])
	var first_actor := actor_by_id.get(first_id) as Node3D
	var second_actor := actor_by_id.get(second_id) as Node3D
	var hour := int(fposmod(simulation.clock.world_seconds, 86400.0) / 3600.0)
	var quest_state := simulation.campaign_journal.quest_state(HollowmereCampaignContent.QUEST_ID)
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
	var branch_result := HollowmereCampaignContent.apply_shakedown_choice(simulation.campaign_journal, "fight")
	if not bool(branch_result.get("ok", false)):
		_show_dialogue("Hollowmere", "The choice could not be recorded: " + String(branch_result.get("reason", "unknown error")) + ".", [{"id": "continue", "label": "Continue", "text": ""}])
		return
	shakedown_resolved = true
	_record_wren_authored_event("hollowmere_shakedown:fight")
	var result := HOLLOWMERE_ENCOUNTER_SCRIPT.start(simulation)
	if not bool(result.get("ok", false)):
		simulation.campaign_journal.fail_quest(HollowmereCampaignContent.QUEST_ID, "The fight could not start: " + String(result.get("reason", "unknown error")))
		_show_dialogue("Hollowmere", "The confrontation cannot begin: " + String(result.get("reason", "unknown error")) + ".", [{"id": "continue", "label": "Continue", "text": ""}])
		return
	encounter_active = true
	active_combat_kind = "ironbond"
	active_enemy_ids = HOLLOWMERE_ENCOUNTER_SCRIPT.ENEMY_IDS.duplicate()
	active_party_ids = HOLLOWMERE_ENCOUNTER_SCRIPT.COMBAT_ALLY_IDS.duplicate()
	active_combat_controlled_ids = HOLLOWMERE_ENCOUNTER_SCRIPT.PLAYER_CONTROLLED_IDS.duplicate()
	for party_id_value in simulation.get_party_member_ids():
		var party_id := String(party_id_value)
		if not active_party_ids.has(party_id):
			active_party_ids.append(party_id)
		if not active_combat_controlled_ids.has(party_id):
			active_combat_controlled_ids.append(party_id)
		var party_state := simulation.get_character(party_id)
		if party_state != null:
			party_state.side = "player"
			party_state.combat_dormant = false
			party_state.time_points = 100.0
	enemy_turn_processed = false
	enemy_turn_waiting_for_reaction = false
	if not HOLLOWMERE_ENCOUNTER_SCRIPT.PLAYER_CONTROLLED_IDS.has(active_character_id):
		active_character_id = "player"
	_update_combat_ui()


func _on_combat_turn_started(_character_id: String) -> void:
	enemy_turn_processed = false


func _update_combat(_delta: float) -> void:
	if not encounter_active or simulation == null or not simulation.is_in_combat:
		return
	_check_encounter_resolution()
	if not encounter_active or not simulation.is_in_combat:
		return
	if enemy_turn_waiting_for_reaction and not simulation.has_pending_reaction():
		enemy_turn_waiting_for_reaction = false
		simulation.try_end_current_turn(true)
		return
	if simulation.has_pending_reaction():
		return
	var current := simulation.get_current_turn_character()
	if current == null or enemy_turn_processed:
		return
	var is_ai_turn := current.side == "enemy" or (current.side == "player" and not active_combat_controlled_ids.has(current.id))
	if not is_ai_turn:
		return
	enemy_turn_processed = true
	_run_ai_combat_turn(current)


func _run_ai_combat_turn(combatant: CharacterState) -> void:
	enemy_turn_waiting_for_reaction = COMBAT_AI_SCRIPT.take_turn(
		simulation,
		combatant,
		active_enemy_ids,
		active_party_ids
	)


func _attack_active_character() -> void:
	if not encounter_active or not simulation.is_in_combat or simulation.has_pending_reaction():
		return
	var current := simulation.get_current_turn_character()
	if current == null or current.id != active_character_id or current.side != "player":
		combat_hud.set_status_text("It is not this character turn. Switch party members with Tab.")
		return
	var target := _nearest_enemy_in_attack_range(current)
	if target == null:
		combat_hud.set_status_text("No enemy in reach. Move closer to an enemy first.")
		return
	var weapon_id := String(current.equipment.get("weapon", ""))
	var result := simulation.try_attack_character(current.id, target.id, {
		"time_point_cost": 10.0,
		"weapon_id": weapon_id
	}, int(current.id.hash() + target.id.hash()))
	if bool(result.get("pending", false)) or simulation.has_pending_reaction():
		combat_hud.set_status_text("Resolving a defensive reaction...")
	elif bool(result.get("ok", false)):
		combat_hud.set_status_text("Attack resolved against %s." % target.display_name)
	else:
		combat_hud.set_status_text("Attack unavailable: %s" % String(result.get("reason", "unknown")))
	_check_encounter_resolution()


func _nearest_enemy_in_attack_range(attacker: CharacterState) -> CharacterState:
	var best: CharacterState
	var best_distance := 999
	for enemy_id in active_enemy_ids:
		var enemy := simulation.get_character(enemy_id)
		if enemy == null or not enemy.can_act():
			continue
		var distance := HexGrid.distance(attacker.axial, enemy.axial)
		if distance <= COMBAT_AI_SCRIPT.attack_range_for(attacker) and distance < best_distance:
			best_distance = distance
			best = enemy
	return best


func _end_active_turn() -> void:
	if not encounter_active or not simulation.is_in_combat or simulation.has_pending_reaction():
		return
	var current := simulation.get_current_turn_character()
	if current == null or current.id != active_character_id or current.side != "player":
		return
	simulation.try_end_current_turn(true)


func _update_combat_ui() -> void:
	if combat_hud == null:
		return
	var combat_visible := encounter_active and simulation != null and simulation.is_in_combat
	if not combat_visible:
		combat_hud.present(false, false, false, "")
		return
	var current := simulation.get_current_turn_character()
	var player_turn := current != null and current.side == "player" and current.id == active_character_id and current.can_act() and not simulation.has_pending_reaction()
	var can_attack := player_turn and _nearest_enemy_in_attack_range(current) != null
	var status_text := ""
	if simulation.has_pending_reaction():
		status_text = "Reaction pending..."
	elif current == null:
		status_text = "Waiting for the next combat turn..."
	elif current.side == "enemy":
		status_text = "%s is acting..." % current.display_name
	elif current.id != active_character_id and active_combat_controlled_ids.has(current.id):
		status_text = "Switch to %s with Tab." % current.display_name
	elif current.id != active_character_id:
		status_text = "%s is acting..." % current.display_name
	else:
		status_text = "%s  ·  HP %d/%d  ·  TP %d" % [current.display_name, current.health, current.max_health, roundi(current.time_points)]
	combat_hud.present(true, player_turn, can_attack, status_text)


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


func _refresh_dwelling_world_presentation() -> void:
	if simulation == null:
		return
	DWELLING_WORLD_PRESENTATION.present_all(self, simulation.campaign_dwellings, HEX_RADIUS)


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
	var active_state := simulation.get_character(active_character_id)
	if active_state == null or HexGrid.distance(active_state.axial, ABANDONED_HOUSE_QUEST_SCRIPT.HOUSE_CENTRE) > 8:
		return
	var start_result := ABANDONED_HOUSE_QUEST_SCRIPT.ensure_started(simulation.campaign_journal)
	if not bool(start_result.get("ok", false)) or bool(start_result.get("already_completed", false)):
		return
	var spawn_result := ABANDONED_HOUSE_QUEST_SCRIPT.ensure_guardians(simulation)
	if not bool(spawn_result.get("ok", false)):
		return
	for guardian_id in ABANDONED_HOUSE_QUEST_SCRIPT.GUARDIAN_IDS:
		var guardian := simulation.get_character(guardian_id)
		if guardian != null and guardian.alive:
			_spawn_abandoned_house_guardian_actor(guardian_id, guardian.axial)


func _begin_abandoned_house_encounter() -> void:
	_close_dialogue()
	var active_state := simulation.get_character(active_character_id)
	if active_state == null or HexGrid.distance(active_state.axial, ABANDONED_HOUSE_QUEST_SCRIPT.HOUSE_CENTRE) > 2:
		_show_dialogue("Abandoned House", "You need to be at the house before you can enter it.", [{"id": "continue", "label": "Understood.", "text": ""}])
		return
	var started := ABANDONED_HOUSE_QUEST_SCRIPT.ensure_started(simulation.campaign_journal)
	if not bool(started.get("ok", false)):
		_show_dialogue("Abandoned House", "The encounter cannot begin: %s." % String(started.get("reason", "unknown error")), [{"id": "continue", "label": "Continue", "text": ""}])
		return
	var party_ids: Array[String] = []
	for party_id_value in simulation.get_party_member_ids():
		party_ids.append(String(party_id_value))
	var result := ABANDONED_HOUSE_QUEST_SCRIPT.start_encounter(simulation, party_ids)
	if not bool(result.get("ok", false)):
		_show_dialogue("Abandoned House", "You cannot face the guardians just now: %s." % String(result.get("reason", "unknown error")).replace("_", " "), [{"id": "continue", "label": "Continue", "text": ""}])
		return
	active_encounter_character_states = result.get("previous_states", {})
	active_combat_kind = "abandoned_house"
	active_enemy_ids.clear()
	active_party_ids.clear()
	active_combat_controlled_ids.clear()
	for enemy_id_value in result.get("enemy_ids", []):
		active_enemy_ids.append(String(enemy_id_value))
	for party_id_value in result.get("party_ids", []):
		active_party_ids.append(String(party_id_value))
		active_combat_controlled_ids.append(String(party_id_value))
	encounter_active = true
	enemy_turn_processed = false
	enemy_turn_waiting_for_reaction = false
	if not active_party_ids.has(active_character_id):
		active_character_id = simulation.player_character_id
	_update_combat_ui()
	_show_dialogue("Abandoned House", "The three skeletal guardians turn as one. Rusted weapons rise from the dark, and the house erupts into violence.", [{"id": "continue", "label": "Stand your ground.", "text": ""}])


func _farm_wolves_remaining() -> int:
	if not farm_wolves_spawned:
		return -1
	var remaining := 0
	for wolf_id in FARM_WOLVES_QUEST_SCRIPT.WOLF_IDS:
		var wolf := simulation.get_character(wolf_id)
		if wolf != null and wolf.can_act():
			remaining += 1
	return remaining


func _check_farm_wolf_proximity() -> void:
	if simulation == null or encounter_active:
		return
	var quest := simulation.campaign_journal.quest_state(FARM_WOLVES_QUEST_SCRIPT.QUEST_ID)
	if String(quest.get("status", "")) != "active":
		return
	var player := simulation.get_character("player")
	if player == null:
		return
	# The den is deliberately well beyond the farm and the village sightline.
	var distance_to_den := HexGrid.distance(player.axial, HOLLOWMERE_PLACEMENTS.FARM_WOLF_DEN_HEX)
	if distance_to_den > 8:
		if farm_wolves_spawned:
			farm_wolves_retry_armed = true
		return
	if not farm_wolves_spawned or farm_wolves_retry_armed and _farm_wolves_remaining() > 0:
		_start_farm_wolf_encounter()


func _start_farm_wolf_encounter() -> void:
	if simulation.is_in_combat or farm_wolves_spawned and _farm_wolves_remaining() == 0:
		return
	if not farm_wolves_spawned:
		farm_wolves_spawned = true
		for index in range(FARM_WOLVES_QUEST_SCRIPT.WOLF_IDS.size()):
			var wolf_id := FARM_WOLVES_QUEST_SCRIPT.WOLF_IDS[index]
			var preferred: Vector2i = HOLLOWMERE_PLACEMENTS.FARM_WOLF_DEN_HEX + HOLLOWMERE_PLACEMENTS.FARM_WOLF_SPAWN_OFFSETS[index]
			var spawn_hex := _find_valid_spawn_hex(preferred)
			var wolf := CharacterState.new(wolf_id, "Wolf", spawn_hex)
			wolf.side = "enemy"
			wolf.max_health = 75
			wolf.health = 75
			wolf.base_damage = 4
			wolf.to_hit_melee = 4.0
			wolf.skills = {"bite_hit": 1, "bite_dmg": 1}
			wolf.tags.append("animal")
			wolf.tags.append("farm_quest_wolf")
			wolf.time_points = wolf.max_time_points
			simulation.register_character(wolf)

			var actor := CREATURE_ACTOR_SCRIPT.new() as CreatureActor
			actor.name = wolf_id
			actor.creature_kind = "wolf"
			actor.behaviour = "predator"
			actor.model_scale = 0.76
			actor.model_path = "res://art/creatures/quaternius/Wolf.gltf"
			actor.position = _hex_world_position(spawn_hex)
			add_child(actor)
			actor_by_id[wolf_id] = actor
	farm_wolves_retry_armed = false

	active_combat_kind = "farm_wolves"
	active_enemy_ids = FARM_WOLVES_QUEST_SCRIPT.WOLF_IDS.duplicate()
	active_party_ids.clear()
	active_combat_controlled_ids.clear()
	for party_id in simulation.get_party_member_ids():
		active_party_ids.append(String(party_id))
		active_combat_controlled_ids.append(String(party_id))
	for value in simulation.character_states():
		var state: CharacterState = value
		state.combat_dormant = true
		if active_party_ids.has(state.id):
			state.side = "player"
			state.combat_dormant = false
			state.time_points = 100.0
		elif active_enemy_ids.has(state.id):
			state.side = "enemy"
			state.combat_dormant = false
			state.time_points = state.max_time_points
	simulation.start_combat()
	encounter_active = true
	enemy_turn_processed = false
	enemy_turn_waiting_for_reaction = false
	if not active_party_ids.has(active_character_id):
		active_character_id = "player"
	_update_combat_ui()
	_show_dialogue("Wilderness", "A low growl rolls through the trees. Three wolves emerge from the den and spread out to surround you.", [{"id": "continue", "label": "Stand your ground.", "text": ""}])


func _check_farm_wolf_resolution() -> void:
	var party_defeated := true
	for party_id in active_party_ids:
		var member := simulation.get_character(party_id)
		if member != null and member.can_act():
			party_defeated = false
			break
	if party_defeated:
		simulation.end_combat()
		encounter_active = false
		for wolf_id in active_enemy_ids:
			var wolf := simulation.get_character(wolf_id)
			if wolf != null:
				wolf.combat_dormant = true
		for party_id in active_party_ids:
			var member := simulation.get_character(party_id)
			if member != null:
				member.side = "player"
				member.combat_dormant = false
		farm_wolves_retry_armed = false
		_show_dialogue("Wilderness", "The wolves drive you back. They remain at their den, and Old Mac's cattle are still in danger. You can return when ready.", [{"id": "continue", "label": "Retreat.", "text": ""}])
		return

	var all_defeated := true
	for wolf_id in active_enemy_ids:
		var wolf := simulation.get_character(wolf_id)
		if wolf != null and wolf.can_act():
			all_defeated = false
			break
	if all_defeated:
		simulation.end_combat()
		encounter_active = false
		for wolf_id in active_enemy_ids:
			var wolf := simulation.get_character(wolf_id)
			if wolf != null:
				wolf.combat_dormant = true
		for party_id in active_party_ids:
			var member := simulation.get_character(party_id)
			if member != null:
				member.side = "player"
				member.combat_dormant = false
		FARM_WOLVES_QUEST_SCRIPT.record_wolf_defeat(simulation.campaign_journal, FARM_WOLVES_QUEST_SCRIPT.WOLF_IDS.size())
		resource_status_label.text = "The wolf pack is defeated. Return to Old Mac."
		_show_dialogue("Wilderness", "The last wolf falls. The den is quiet. Old Mac will want to know the cattle are safe.", [{"id": "continue", "label": "Return to the farm.", "text": ""}])


func _active_party_defeated() -> bool:
	for character_id in active_party_ids:
		var member := simulation.get_character(character_id)
		if member != null and member.can_act():
			return false
	return true


func _restore_active_party_after_combat() -> void:
	for character_id in simulation.get_party_member_ids():
		var member := simulation.get_character(character_id)
		if member != null:
			member.side = "player"
			member.combat_dormant = false


func _check_encounter_resolution() -> void:
	if not encounter_active:
		return
	if active_combat_kind == "abandoned_house":
		ABANDONED_HOUSE_QUEST_SCRIPT.apply_defeat_consequences(simulation.campaign_journal, simulation)
		if ABANDONED_HOUSE_QUEST_SCRIPT.party_defeated(simulation, active_party_ids):
			simulation.end_combat()
			ABANDONED_HOUSE_QUEST_SCRIPT.finish_encounter(simulation, active_encounter_character_states)
			active_encounter_character_states.clear()
			_restore_active_party_after_combat()
			encounter_active = false
			_show_dialogue("Abandoned House", "The guardians drive you back. They remain in the house, but you can return when the party is ready.", [{"id": "continue", "label": "Retreat.", "text": ""}])
		elif ABANDONED_HOUSE_QUEST_SCRIPT.enemies_defeated(simulation):
			simulation.end_combat()
			ABANDONED_HOUSE_QUEST_SCRIPT.finish_encounter(simulation, active_encounter_character_states)
			active_encounter_character_states.clear()
			_restore_active_party_after_combat()
			encounter_active = false
			var clearing := ABANDONED_HOUSE_QUEST_SCRIPT.resolve_clearing(simulation.campaign_journal, simulation)
			if bool(clearing.get("ok", false)) and bool(clearing.get("completed", false)):
				resource_status_label.text = "Quest complete: The Abandoned House · all three guardians defeated."
				_show_dialogue("Abandoned House", "The last guardian collapses. The house is quiet at last. Its rooms can now be restored, though the work will still require timber and stone.", [{"id": "continue", "label": "The house is clear.", "text": ""}])
			else:
				_show_dialogue("Abandoned House", "The guardians are defeated, but the clearing could not be recorded: %s." % String(clearing.get("reason", "unknown error")), [{"id": "continue", "label": "Continue", "text": ""}])
		return
	if active_combat_kind == "dire_wolf_hunt":
		if FARMSTEAD_DIRE_WOLF_SCRIPT.party_defeated(simulation, active_party_ids):
			simulation.end_combat()
			FARMSTEAD_DIRE_WOLF_SCRIPT.finish(simulation, active_party_ids, active_encounter_character_states)
			active_encounter_character_states.clear()
			encounter_active = false
			_show_dialogue("Reyna Fletcher", "The dire wolf drives you back. It is still stalking the farmstead. Tessa is safe for now, but we cannot leave the beast alive. We can try again when we're ready.", [{"id":"continue","label":"Continue","text":""}])
		elif FARMSTEAD_DIRE_WOLF_SCRIPT.dire_wolf_defeated(simulation):
			simulation.end_combat()
			FARMSTEAD_DIRE_WOLF_SCRIPT.finish(simulation, active_party_ids, active_encounter_character_states)
			active_encounter_character_states.clear()
			encounter_active = false
			COMPANION_CAMPAIGN_SCRIPT.complete_objective(simulation.campaign_journal, "reyna_dire_wolf_hunt", "dire_wolf_slain")
			var wolf_actor := actor_by_id.get(FARMSTEAD_DIRE_WOLF_SCRIPT.DIRE_WOLF_ID) as Node3D
			if is_instance_valid(wolf_actor):
				wolf_actor.queue_free()
			actor_by_id.erase(FARMSTEAD_DIRE_WOLF_SCRIPT.DIRE_WOLF_ID)
			_show_speech_bubble("companion_reyna_fletcher", "Tessa is safe. Old Mac's farm can breathe again.")
			_show_companion_dialogue("companion_reyna_fletcher")
		return
	if active_combat_kind == "farm_wolves":
		_check_farm_wolf_resolution()
		return
	if _active_party_defeated():
		simulation.end_combat()
		HOLLOWMERE_ENCOUNTER_SCRIPT.finish(simulation)
		_restore_active_party_after_combat()
		encounter_active = false
		shakedown_resolved = true
		simulation.campaign_journal.fail_quest(HollowmereCampaignContent.QUEST_ID, "The party was defeated during the Ironbond shakedown.")
		_show_dialogue("Garrick Holt", "The soldiers overpower you. Garrick has no choice but to surrender the due. The confrontation is lost.", [{"id": "continue", "label": "Continue", "text": ""}])
	elif HOLLOWMERE_ENCOUNTER_SCRIPT.enemies_defeated(simulation):
		simulation.end_combat()
		HOLLOWMERE_ENCOUNTER_SCRIPT.finish(simulation)
		_restore_active_party_after_combat()
		encounter_active = false
		HollowmereCampaignContent.complete_shakedown(simulation.campaign_journal)
		_show_speech_bubble("garrick_holt", HollowmereCampaignContent.shakedown_victory_text())
		_show_dialogue("Garrick Holt", HollowmereCampaignContent.shakedown_victory_text(), [{"id": "continue", "label": "Continue", "text": ""}])

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
	if not active_combat_controlled_ids.has(reactor_id):
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
			if not _interact_with_tavern_stairs() and not _interact_with_nearest_door():
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
		var da := HexGrid.distance(preferred, a)
		var db := HexGrid.distance(preferred, b)
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
			# Stair transitions change elevation/floor ownership, so they remain
			# an authored snap rather than interpolating through the tavern shell.
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
	if character_id == active_character_id:
		_refresh_tavern_floor_presentation()
	if character_id == "player":
		_maybe_spawn_wilderness_creature(to_hex)

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

func _interact_with_tavern_stairs() -> bool:
	var state := simulation.get_character(active_character_id)
	if state == null:
		return false
	var upstairs := _is_upper_floor_hex(state.axial)
	var stair_hex := TAVERN_STAIR_UPPER_HEX if upstairs else TAVERN_STAIR_GROUND_HEX
	if HexGrid.distance(state.axial, stair_hex) > 1:
		return false
	var destination := TAVERN_STAIR_GROUND_HEX if upstairs else TAVERN_STAIR_UPPER_HEX
	_clear_path_markers()
	if not simulation.relocate_character(active_character_id, destination):
		print("The staircase is blocked.")
	return true

func _interact_with_nearest_door() -> bool:
	var state := simulation.get_character(active_character_id)
	if state == null:
		return false
	var door := simulation.building_registry.get_door(TAVERN_FRONT_DOOR_ID)
	if door == null or HexGrid.distance(state.axial, door.hex) > 1:
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


func _maybe_spawn_wilderness_creature(player_hex: Vector2i) -> void:
	# Keep the authored settlement/farm quiet. Wildlife starts beyond the
	# original 35-hex Hollowmere safety radius and is rolled by travel, not
	# every frame, so it cannot spam into existence.
	if HexGrid.distance(Vector2i.ZERO, player_hex) <= 35 or HOLLOWMERE_TERRAIN_PROVIDER.is_farm_land(player_hex, HOLLOWMERE_TERRAIN_DEFINITION.DEFINITION):
		return
	wilderness_steps_since_spawn += 1
	if wilderness_steps_since_spawn < 12:
		return
	wilderness_steps_since_spawn = 0
	var player_world := _hex_world_position(player_hex)
	for index in range(wilderness_creature_nodes.size() - 1, -1, -1):
		var existing := wilderness_creature_nodes[index]
		if not is_instance_valid(existing) or existing.global_position.distance_to(player_world) > 60.0:
			if is_instance_valid(existing):
				existing.queue_free()
			wilderness_creature_nodes.remove_at(index)
	if wilderness_creature_nodes.size() >= 5 or ambient_rng.randf() > 0.42:
		return

	var kinds: Array[String] = ["wolf", "fox", "deer", "stag"]
	var weights := PackedFloat32Array([0.25, 0.25, 0.30, 0.20])
	var roll := ambient_rng.randf()
	var kind := "deer"
	var cumulative := 0.0
	for index in range(kinds.size()):
		cumulative += weights[index]
		if roll <= cumulative:
			kind = kinds[index]
			break

	for attempt in range(18):
		var candidate := player_hex + Vector2i(ambient_rng.randi_range(-12, 12), ambient_rng.randi_range(-12, 12))
		if HexGrid.distance(player_hex, candidate) < 7 or HexGrid.distance(player_hex, candidate) > 13:
			continue
		if HexGrid.distance(Vector2i.ZERO, candidate) <= 35 or HOLLOWMERE_TERRAIN_PROVIDER.is_farm_land(candidate, HOLLOWMERE_TERRAIN_DEFINITION.DEFINITION):
			continue
		if not simulation.map_data.is_walkable(candidate) or simulation.is_hex_occupied(candidate):
			continue
		var creature := CREATURE_ACTOR_SCRIPT.new() as CreatureActor
		creature.name = "Wilderness_%s_%d" % [kind, wilderness_creature_nodes.size() + 1]
		creature.creature_kind = kind
		creature.behaviour = "predator" if kind == "wolf" else "passive_wildlife"
		creature.model_scale = 0.72 if kind == "fox" else 0.78
		creature.model_path = "res://art/creatures/quaternius/%s.gltf" % kind.capitalize()
		creature.position = _hex_world_position(candidate)
		add_child(creature)
		wilderness_creature_nodes.append(creature)
		return

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
