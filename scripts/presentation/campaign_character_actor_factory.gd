class_name CampaignCharacterActorFactory
extends RefCounted
## Builds every human character through one Ara presentation path.
## Simulation state and world placement remain owned by the caller.

const ARA_CHARACTER_ACTOR = preload("res://scripts/presentation/ara_character_actor.gd")
const PLAYER_FEMALE_ASSET := "res://art/characters/ara_runtime/ara_person_body_anatomy.glb"
const PLAYER_MALE_ASSET := "res://art/characters/ara_runtime/ara_person_male_body.glb"


static func create_actor(
	state: CharacterState,
	world_position: Vector3,
	is_player: bool,
	player_profile: Dictionary,
	npc_profile: Dictionary,
	ara_model_id: String,
	ambient_role: String
) -> Node3D:
	if state == null:
		push_error("Cannot create character presentation without simulation state.")
		return null

	var body_variant := String(player_profile.get("body_variant", "female")) if is_player else ("male" if int(npc_profile.get("params", {}).get("gender", 0)) == 1 else "female")
	var model_path := PLAYER_MALE_ASSET if body_variant == "male" else PLAYER_FEMALE_ASSET
	# All campaign characters use the same gendered Ara runtime base as the
	# player. Per-NPC GLBs bake in their own body, hair and materials, which
	# prevents consistent runtime morphs and appearance customisation.
	# Individual identity comes from each NPC's params and attached hair.
	model_path = PLAYER_MALE_ASSET if body_variant == "male" else PLAYER_FEMALE_ASSET

	var hair_id := String(player_profile.get("hair_style_id", "short02")) if is_player else String(npc_profile.get("params", {}).get("hair", "short02"))
	var appearance := player_profile if is_player else npc_profile
	return _create_actor_presentation(
		state.id,
		state.display_name,
		world_position,
		model_path,
		body_variant,
		appearance,
		state.equipped_item_data,
		is_player,
		ambient_role,
		hair_id,
		deg_to_rad(float(state.facing_direction - 2) * 60.0)
	)


## Settlement NPCs use the same Ara renderer, equipment mapping, hair
## attachment and nameplate as campaign characters. This builder supplies only
## settlement-specific appearance data and world placement.
static func create_settlement_actor(npc: Dictionary, world_position: Vector3) -> Node3D:
	var character_id := String(npc.get("id", "campaign2_npc"))
	var display_name := String(npc.get("name", character_id))
	var appearance: Dictionary = npc.get("appearance", {})
	var body_variant := String(npc.get("body_base", npc.get("body_variant", appearance.get("body_variant", ""))))
	if body_variant.is_empty():
		var presentation := String(appearance.get("gender_presentation", "")).to_lower()
		body_variant = "male" if presentation in ["male", "masculine", "man"] else "female"
	var height_scale := clampf(float(appearance.get("height_scale", 1.0)), 0.5, 1.25)
	var build_scale := float(appearance.get("build_scale", 1.0))
	var body_scale := clampf(float(appearance.get("body_scale", build_scale)), 0.5, 1.25)
	var profile := {
		"skin_colour": String(appearance.get("skin_colour", "#b9825f")),
		"eye_colour": String(appearance.get("eye_colour", "Brown")),
		"hair_colour": String(appearance.get("hair_colour", "Dark brown")),
		"height": float(appearance.get("height", clampf((height_scale - 0.8) / 0.4, 0.0, 1.0))),
		"muscle": float(appearance.get("muscle", clampf((build_scale - 0.8) / 0.4, 0.0, 1.0))),
		"weight": float(appearance.get("weight", 0.5)),
		"proportions": float(appearance.get("proportions", 0.5)),
		"breasts": float(appearance.get("breasts", 0.5)),
		"legs": float(appearance.get("legs", 0.5)),
		"body_variant": body_variant,
		"gender_presentation": String(appearance.get("gender_presentation", "Androgynous")),
		"pronouns": String(appearance.get("pronouns", "they/them"))
	}
	var model_path := PLAYER_MALE_ASSET if body_variant == "male" else PLAYER_FEMALE_ASSET
	var equipment: Dictionary = npc.get("visual_equipment", {})
	var actor := _create_actor_presentation(
		character_id,
		display_name,
		world_position,
		model_path,
		body_variant,
		profile,
		equipment,
		false,
		"",
		String(appearance.get("hair_style", "")),
		deg_to_rad(180.0)
	)
	if actor != null:
		# Explicit per-character scaling lets non-human races use the shared
		# Ara rig as a temporary stand-in without changing identity, animation
		# or equipment systems. The actor/nameplate stays at human world scale.
		var ara_model := _get_ara_actor(actor)
		if ara_model != null and ara_model.model_root != null:
			ara_model.model_root.scale *= Vector3(body_scale, height_scale, body_scale)
			ara_model.set_meta("campaign_body_scale", body_scale)
			ara_model.set_meta("campaign_height_scale", height_scale)
		var name_label := actor.get_node_or_null("CharacterNameLabel") as Label3D
		if name_label != null:
			name_label.position.y = 2.08 * height_scale
		actor.set_meta("body_scale", body_scale)
		actor.set_meta("height_scale", height_scale)
		actor.set_meta("campaign2_npc_id", character_id)
		actor.set_meta("dialogue_id", _safe_metadata_string(npc.get("dialogue_id", "")))
		actor.set_meta("faction_id", _safe_metadata_string(npc.get("faction_id", "")))
		actor.set_meta("side", _safe_metadata_string(npc.get("side", "neutral"), "neutral"))
		actor.set_meta("class_levels", npc.get("class_levels", []))
		actor.set_meta("skill_picks", npc.get("skill_picks", []))
		actor.set_meta("quest_hooks", npc.get("quest_hooks", []))
		actor.set_meta("race", _safe_metadata_string(npc.get("race", "human"), "human"))
		actor.set_meta("title", _safe_metadata_string(npc.get("title", "")))
		actor.set_meta("tied_up", bool(npc.get("tied_up", false)))
		if npc.has("wants"):
			actor.set_meta("wants", npc.get("wants", {}).duplicate(true))
		actor.set_meta("ambient_enabled", false)
		actor.add_to_group("campaign2_npc")
	return actor


## Equipment refreshes are routed through the presentation factory so callers
## never need to know where the AraCharacterActor sits in the scene tree.
static func apply_equipment_visuals(actor: Node3D, state: CharacterState) -> void:
	if actor == null or state == null or not is_instance_valid(actor):
		return
	var ara := _get_ara_actor(actor)
	if ara != null:
		ara.apply_equipment_visuals(state.equipped_item_data)


static func apply_player_profile(actor: Node3D, profile: Dictionary) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	actor.set_meta("player_profile", profile.duplicate(true))
	actor.set_meta("appearance_profile", profile.duplicate(true))
	actor.set_meta("body_variant", String(profile.get("body_variant", "female")))
	actor.set_meta("gender_presentation", String(profile.get("gender_presentation", "Androgynous")))
	actor.set_meta("pronouns", String(profile.get("pronouns", "they/them")))
	var name_label := actor.get_node_or_null("PlayerNameLabel") as Label3D
	if name_label != null:
		name_label.text = String(profile.get("name", "Adventurer"))
	var ara := _get_ara_actor(actor)
	if ara != null:
		ara.apply_player_profile(profile)


static func apply_npc_parameters(actor: Node3D, params: Dictionary) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	actor.set_meta("appearance_profile", params.duplicate(true))
	var ara := _get_ara_actor(actor)
	if ara != null:
		ara.apply_npc_parameters(params)


static func _safe_metadata_string(value: Variant, fallback: String = "") -> String:
	if value is String or value is StringName:
		return String(value)
	return fallback


static func _get_ara_actor(actor: Node3D) -> AraCharacterActor:
	var ara := actor as AraCharacterActor
	if ara == null:
		ara = actor.get_node_or_null("CharacterModel") as AraCharacterActor
	return ara


static func _create_actor_presentation(
	character_id: String,
	display_name: String,
	world_position: Vector3,
	model_path: String,
	body_variant: String,
	appearance_profile: Dictionary,
	equipped_item_data: Dictionary,
	is_player: bool,
	ambient_role: String,
	hair_id: String,
	facing_rotation: float
) -> Node3D:
	var actor := HexActorPresentation.new()
	actor.name = character_id
	actor.position = world_position
	actor.set_meta("character_id", character_id)
	actor.set_meta("ambient_enabled", not is_player)
	actor.set_meta("ambient_role", ambient_role)
	var base_appearance: Dictionary = appearance_profile.get("params", {}).duplicate(true) if appearance_profile.has("params") else appearance_profile.duplicate(true)
	actor.set_meta("base_appearance_profile", base_appearance)
	actor.set_meta("appearance_profile", appearance_profile.duplicate(true))
	actor.rotation.y = facing_rotation

	var ara_model := ARA_CHARACTER_ACTOR.new() as AraCharacterActor
	ara_model.name = "CharacterModel"
	actor.add_child(ara_model)

	if ara_model.configure(model_path):
		if appearance_profile.has("params"):
			ara_model.apply_npc_parameters(appearance_profile.get("params", {}))
		else:
			ara_model.apply_player_profile(appearance_profile)
		if model_path.contains("/ara_runtime/"):
			_attach_ara_hair(ara_model, body_variant, hair_id)
		ara_model.apply_equipment_visuals(equipped_item_data)
	else:
		push_error("Character '%s' could not load Ara model '%s'. No primitive substitute will be shown." % [display_name, model_path])
		ara_model.queue_free()

	var name_label := Label3D.new()
	name_label.name = "PlayerNameLabel" if is_player else "CharacterNameLabel"
	name_label.text = "You" if is_player else display_name
	name_label.position.y = 2.08
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_label.font_size = 32
	name_label.outline_size = 6
	name_label.modulate = Color(1.0, 0.95, 0.82)
	actor.add_child(name_label)
	return actor


static func _attach_ara_hair(actor: AraCharacterActor, body_variant: String, hair_id: String) -> void:
	if hair_id.is_empty() or hair_id == "none":
		actor.clear_hairstyle()
		return
	var hair_path := "res://art/characters/ara_runtime/hair/%s_%s.glb" % [body_variant, hair_id]
	if not ResourceLoader.exists(hair_path):
		push_warning("Ara hairstyle '%s' is unavailable at %s; retaining base hair." % [hair_id, hair_path])
		return
	if not actor.set_hairstyle(hair_path):
		push_warning("Ara hairstyle '%s' could not be attached to the shared %s body." % [hair_id, body_variant])
