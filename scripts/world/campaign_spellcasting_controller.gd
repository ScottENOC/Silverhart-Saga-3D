class_name CampaignSpellcastingController
extends Node

const SPELLBOOK_PANEL_SCRIPT = preload("res://scripts/ui/spellbook_panel.gd")
const CHARACTER_CREATOR_SCRIPT = preload("res://scripts/ui/player_character_creator.gd")
const CREATURE_ACTOR_SCRIPT = preload("res://scripts/presentation/creature_actor.gd")
const SPELL_TERRAIN_SAVE_KEY := "spell_terrain_effects"
const INVALID_HEX := Vector2i(2147483647, 2147483647)

var simulation: WorldSimulation
var location_controller: Node3D
var spellbook_panel: SpellbookPanel
var disguise_creator: CanvasLayer
var active_disguise_profile: Dictionary = {}
var hud_layer: CanvasLayer
var last_active_character_id: String = "player"


func configure(campaign_simulation: WorldSimulation, location: Node3D) -> void:
	if campaign_simulation == null or location == null:
		push_error("CampaignSpellcastingController requires the shared simulation and active location controller.")
		return
	simulation = campaign_simulation
	location_controller = location
	last_active_character_id = _active_character_id()
	spellbook_panel = SPELLBOOK_PANEL_SCRIPT.new() as SpellbookPanel
	spellbook_panel.name = "SpellbookPanel"
	add_child(spellbook_panel)
	spellbook_panel.configure(simulation, last_active_character_id)
	_create_spellbook_button()
	if not simulation.action_committed.is_connected(_on_action_committed):
		simulation.action_committed.connect(_on_action_committed)
	SaveManager.register_snapshot_extension(SPELL_TERRAIN_SAVE_KEY, Callable(self, "_spell_terrain_save_data"))


func _exit_tree() -> void:
	SaveManager.unregister_snapshot_extension(SPELL_TERRAIN_SAVE_KEY)


func _create_spellbook_button() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.name = "SpellcastingHud"
	hud_layer.layer = 35
	add_child(hud_layer)
	var button := Button.new()
	button.name = "SpellbookButton"
	button.text = "Spellbook  [M]"
	button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	button.offset_left = -158.0
	button.offset_top = 68.0
	button.offset_right = -18.0
	button.offset_bottom = 110.0
	button.pressed.connect(_toggle_spellbook)
	hud_layer.add_child(button)


func _process(_delta: float) -> void:
	if spellbook_panel == null or location_controller == null:
		return
	var current_id := _active_character_id()
	if current_id != last_active_character_id:
		last_active_character_id = current_id
		spellbook_panel.set_character(current_id)


func _input(event: InputEvent) -> void:
	if location_controller == null or spellbook_panel == null:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed and spellbook_panel.is_awaiting_hex_target():
			var clicked_value: Variant = location_controller.call("_screen_position_to_hex", mouse_event.position)
			if clicked_value is Vector2i and clicked_value != INVALID_HEX:
				spellbook_panel.handle_hex_click(clicked_value)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		if key_event.keycode == KEY_ESCAPE and spellbook_panel.is_awaiting_hex_target():
			spellbook_panel.cancel_hex_targeting()
			get_viewport().set_input_as_handled()
			return
		if key_event.keycode == KEY_M:
			_toggle_spellbook()
			get_viewport().set_input_as_handled()


func _toggle_spellbook() -> void:
	if spellbook_panel == null:
		return
	last_active_character_id = _active_character_id()
	spellbook_panel.toggle_for_character(last_active_character_id)


func _active_character_id() -> String:
	if location_controller == null:
		return "player"
	return String(location_controller.get("active_character_id"))


func _actor_map() -> Dictionary:
	if location_controller == null:
		return {}
	var value: Variant = location_controller.get("actor_by_id")
	return value if value is Dictionary else {}


func _actor_for(character_id: String) -> Node3D:
	return _actor_map().get(character_id) as Node3D


func _player_profile() -> Dictionary:
	if location_controller == null:
		return {}
	var value: Variant = location_controller.get("player_profile")
	return value.duplicate(true) if value is Dictionary else {}


func get_disguise_copy_profiles() -> Array[Dictionary]:
	var profiles: Array[Dictionary] = []
	for actor_id_value in _actor_map().keys():
		var actor_id := String(actor_id_value)
		if actor_id == "player":
			continue
		var actor := _actor_for(actor_id)
		if actor == null:
			continue
		var profile: Variant = actor.get_meta("base_appearance_profile", {})
		if not profile is Dictionary or profile.is_empty():
			continue
		var state := simulation.get_character(actor_id) if simulation != null else null
		profiles.append({"id": actor_id, "name": state.display_name if state != null else actor_id})
	profiles.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("name", "")) < String(b.get("name", ""))
	)
	return profiles


func _on_action_committed(event: SimulationEvent) -> void:
	if event == null:
		return
	if event.event_type in ["summon_expired", "animal_companion_died"]:
		_remove_summoned_actor(event.actor_id)
	elif event.event_type == "spell_cast" and String(event.payload.get("spell_id", "")) == "summon_animal":
		var summoned_id := String(event.payload.get("summoned_id", ""))
		if not summoned_id.is_empty():
			_ensure_summoned_animal_actor(simulation.get_character(summoned_id))
	if event.event_type == "spell_cast" and event.actor_id == "player" and String(event.payload.get("spell_id", "")) == "disguise_self":
		_open_disguise_creator(String(event.payload.get("copy_character_id", "")))
	elif event.event_type == "spell_countered" and not active_disguise_profile.is_empty():
		var player_state := simulation.get_character("player")
		if player_state == null or not player_state.has_spell_effect("disguise_self"):
			_clear_disguise()


func _remove_summoned_actor(character_id: String) -> void:
	var actors := _actor_map()
	var actor := actors.get(character_id) as Node3D
	if is_instance_valid(actor):
		actor.queue_free()
	actors.erase(character_id)


func _restore_summoned_actors() -> void:
	if simulation == null:
		return
	for value in simulation.characters.values():
		var state := value as CharacterState
		if state != null and state.alive and (state.is_summoned or state.is_animal_companion):
			_ensure_summoned_animal_actor(state)


func _ensure_summoned_animal_actor(state: CharacterState) -> void:
	if state == null or not state.alive or (not state.is_summoned and not state.is_animal_companion):
		return
	var actors := _actor_map()
	if actors.has(state.id):
		return
	var kind := state.creature_kind.to_lower()
	var model_path := ""
	var actor_kind := kind
	if kind == "wolf":
		model_path = "res://art/creatures/quaternius/Wolf.gltf"
	elif kind == "horse":
		model_path = "res://art/creatures/quaternius/Horse.gltf"
	elif kind == "unicorn":
		model_path = "res://art/creatures/quaternius/Horse_White.gltf"
		actor_kind = "horse"
	if not model_path.is_empty() and ResourceLoader.exists(model_path):
		var creature := CREATURE_ACTOR_SCRIPT.new() as CreatureActor
		creature.name = state.id
		creature.creature_kind = actor_kind
		creature.behaviour = "mount" if state.mountable else "predator"
		creature.model_path = model_path
		creature.model_scale = 0.9 if kind in ["horse", "unicorn"] else 0.82
		creature.position = location_controller.call("_hex_world_position", state.axial)
		creature.set_meta("character_id", state.id)
		creature.set_meta("summoned_kind", kind)
		location_controller.add_child(creature)
		actors[state.id] = creature
		return

	# Boar, tiger and eagle use visible placeholders until dedicated meshes exist.
	var placeholder := Node3D.new()
	placeholder.name = state.id
	placeholder.position = location_controller.call("_hex_world_position", state.axial)
	placeholder.set_meta("character_id", state.id)
	placeholder.set_meta("summoned_kind", kind)
	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.34 if kind != "eagle" else 0.22
	body_mesh.height = 0.95 if kind != "eagle" else 0.62
	body.mesh = body_mesh
	body.rotation.x = PI * 0.5
	body.position.y = 0.58
	var material := StandardMaterial3D.new()
	match kind:
		"boar": material.albedo_color = Color(0.34, 0.20, 0.12)
		"tiger": material.albedo_color = Color(0.88, 0.43, 0.12)
		"eagle": material.albedo_color = Color(0.40, 0.29, 0.16)
		_: material.albedo_color = Color(0.48, 0.48, 0.48)
	body.material_override = material
	placeholder.add_child(body)
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.23
	head_mesh.height = 0.46
	head.mesh = head_mesh
	head.position = Vector3(0.0, 0.82, -0.38)
	head.material_override = material
	placeholder.add_child(head)
	var label := Label3D.new()
	label.text = state.display_name
	label.position.y = 1.35
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 22
	label.outline_size = 4
	placeholder.add_child(label)
	location_controller.add_child(placeholder)
	actors[state.id] = placeholder


func _open_disguise_creator(copy_character_id: String = "") -> void:
	if disguise_creator != null and is_instance_valid(disguise_creator):
		return
	var initial_profile := active_disguise_profile if not active_disguise_profile.is_empty() else _player_profile()
	if not copy_character_id.is_empty():
		var source_actor := _actor_for(copy_character_id)
		if source_actor != null:
			var source_profile: Variant = source_actor.get_meta("base_appearance_profile", {})
			if source_profile is Dictionary and not source_profile.is_empty():
				initial_profile = source_profile.duplicate(true)
	disguise_creator = CHARACTER_CREATOR_SCRIPT.new() as CanvasLayer
	disguise_creator.name = "DisguiseSelfCreator"
	disguise_creator.call("configure_disguise", initial_profile)
	disguise_creator.connect("completed", Callable(self, "_on_disguise_profile_completed"))
	add_child(disguise_creator)


func _on_disguise_profile_completed(profile: Dictionary) -> void:
	disguise_creator = null
	active_disguise_profile = profile.duplicate(true)
	var player_state := simulation.get_character("player") if simulation != null else null
	if player_state != null:
		var effect := player_state.get_spell_effect("disguise_self")
		if not effect.is_empty():
			effect["profile"] = active_disguise_profile.duplicate(true)
			player_state.add_spell_effect(effect)
	var actor := _actor_for("player")
	if actor != null:
		CampaignCharacterActorFactory.apply_player_profile(actor, active_disguise_profile)


func _restore_disguise_from_character_state() -> void:
	var player_state := simulation.get_character("player") if simulation != null else null
	if player_state == null:
		return
	var effect := player_state.get_spell_effect("disguise_self")
	var saved_profile: Variant = effect.get("profile", {})
	if saved_profile is Dictionary and not saved_profile.is_empty():
		active_disguise_profile = saved_profile.duplicate(true)
		var actor := _actor_for("player")
		if actor != null:
			CampaignCharacterActorFactory.apply_player_profile(actor, active_disguise_profile)


func _clear_disguise() -> void:
	active_disguise_profile.clear()
	var actor := _actor_for("player")
	if actor != null:
		CampaignCharacterActorFactory.apply_player_profile(actor, _player_profile())


func _spell_terrain_save_data() -> Array[Dictionary]:
	return simulation.spell_terrain_effects_to_dict() if simulation != null else []


func restore_from_save_data(data: Dictionary) -> void:
	if simulation == null:
		return
	var saved_spell_terrain: Variant = data.get(SPELL_TERRAIN_SAVE_KEY, [])
	if saved_spell_terrain is Array:
		simulation.restore_spell_terrain_effects(saved_spell_terrain)
	_restore_disguise_from_character_state()
	_restore_summoned_actors()
