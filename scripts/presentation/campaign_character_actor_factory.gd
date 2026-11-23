class_name CampaignCharacterActorFactory
extends RefCounted
## Builds every human character through one Ara presentation path.
## Simulation state and world placement remain owned by the caller.

const ARA_CHARACTER_ACTOR = preload("res://scripts/presentation/ara_character_actor.gd")
const PLAYER_FEMALE_ASSET := "res://art/characters/ara_runtime/ara_player_female_body.glb"
const PLAYER_MALE_ASSET := "res://art/characters/ara_runtime/ara_player_male_body.glb"
const HOLLOWMERE_PROFILE_PATH := "res://art/characters/hollowmere/profiles.json"
const COMPANION_ASSETS := {
	"wren_talbot": {"path": "res://art/characters/companions/wren.glb", "body_variant": "female"},
	"wren": {"path": "res://art/characters/companions/wren.glb", "body_variant": "female"},
	"companion_wren_talbot": {"path": "res://art/characters/companions/wren.glb", "body_variant": "female"},
	"ser_aldric_thorne": {"path": "res://art/characters/companions/aldric.glb", "body_variant": "male"},
	"ser_aldric_thorne_human_male": {"path": "res://art/characters/companions/aldric.glb", "body_variant": "male"},
	"companion_ser_aldric_thorne": {"path": "res://art/characters/companions/aldric.glb", "body_variant": "male"},
	"aldric_thorne": {"path": "res://art/characters/companions/aldric.glb", "body_variant": "male"},
	"dagna_stoneward": {"path": "res://art/characters/companions/dagna.glb", "body_variant": "female"},
	"dagna": {"path": "res://art/characters/companions/dagna.glb", "body_variant": "female"},
	"companion_dagna": {"path": "res://art/characters/companions/dagna.glb", "body_variant": "female"},
	"companion_dagna_stoneward": {"path": "res://art/characters/companions/dagna.glb", "body_variant": "female"}
}
static var _hollowmere_model_index: Dictionary = {}
static var _hollowmere_body_variant_index: Dictionary = {}
static var _hollowmere_model_index_loaded := false


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
	if not is_player:
		var companion_asset := _companion_asset_definition(state.id)
		if not companion_asset.is_empty():
			body_variant = String(companion_asset.get("body_variant", body_variant))
		else:
			body_variant = _hollowmere_body_variant_for(state.id, body_variant)
		model_path = _resolve_character_model_path(state.id, npc_profile, body_variant)

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
	var companion_asset := _companion_asset_definition(character_id)
	if not companion_asset.is_empty():
		body_variant = String(companion_asset.get("body_variant", body_variant))
	else:
		body_variant = _hollowmere_body_variant_for(character_id, body_variant)
	var model_path := _resolve_character_model_path(character_id, npc, body_variant)
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
		actor.name = "NPC_" + character_id
		# Non-human source races use the shared Ara rig as a temporary visual
		# stand-in. Scale the model root only; world interaction and nameplate
		# anchors remain at the character's authored world position.
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
		actor.set_meta("source_monster_type", _safe_metadata_string(npc.get("source_monster_type", "")))
		actor.set_meta("source_custom_skills", npc.get("source_custom_skills", {}).duplicate(true))
		actor.set_meta("source_custom_equipment", npc.get("source_custom_equipment", []).duplicate(true))
		actor.set_meta("behavior_type", _safe_metadata_string(npc.get("behavior_type", "")))
		if npc.has("home_position"):
			actor.set_meta("home_position", npc.get("home_position", {}).duplicate(true))
		if npc.has("camp_spots"):
			actor.set_meta("camp_spots", npc.get("camp_spots", []).duplicate(true))
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
		var has_baked_appearance := ara.loaded_asset_path.contains("/companions/") or ara.loaded_asset_path.contains("/hollowmere/")
		if not has_baked_appearance:
			ara.apply_npc_parameters(params)



static func _companion_asset_definition(character_id: String) -> Dictionary:
	return (COMPANION_ASSETS.get(character_id.to_lower(), {}) as Dictionary).duplicate(true)


static func _resolve_character_model_path(character_id: String, profile: Dictionary, body_variant: String) -> String:
	var companion_asset := _companion_asset_definition(character_id)
	if not companion_asset.is_empty():
		var companion_path := String(companion_asset.get("path", ""))
		if ResourceLoader.exists(companion_path):
			return companion_path
		push_warning("Approved companion model is not installed for '%s': %s" % [character_id, companion_path])

	var explicit_path := String(profile.get("model_path", profile.get("model", ""))).strip_edges()
	if not explicit_path.is_empty():
		var candidate := explicit_path if explicit_path.begins_with("res://") else "res://art/characters/hollowmere/" + explicit_path
		if ResourceLoader.exists(candidate):
			return candidate

	_ensure_hollowmere_model_index()
	var indexed_path := String(_hollowmere_model_index.get(character_id.to_lower(), ""))
	if not indexed_path.is_empty() and ResourceLoader.exists(indexed_path):
		return indexed_path

	return PLAYER_MALE_ASSET if body_variant == "male" else PLAYER_FEMALE_ASSET


static func _ensure_hollowmere_model_index() -> void:
	if _hollowmere_model_index_loaded:
		return
	_hollowmere_model_index_loaded = true
	if not FileAccess.file_exists(HOLLOWMERE_PROFILE_PATH):
		return
	var file := FileAccess.open(HOLLOWMERE_PROFILE_PATH, FileAccess.READ)
	if file == null:
		push_warning("Could not open Hollowmere character model index.")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or not parsed.get("characters", []) is Array:
		push_warning("Hollowmere character model index is invalid.")
		return
	for value in parsed.get("characters", []):
		if not value is Dictionary:
			continue
		var character: Dictionary = value
		var model_name := String(character.get("model", "")).strip_edges()
		if model_name.is_empty():
			continue
		var model_path := "res://art/characters/hollowmere/" + model_name
		var params: Dictionary = character.get("params", {})
		var character_body_variant := "male" if int(params.get("gender", 0)) == 1 else "female"
		for key in ["id", "game_id"]:
			var identity := String(character.get(key, "")).strip_edges().to_lower()
			if not identity.is_empty():
				_hollowmere_model_index[identity] = model_path
				_hollowmere_body_variant_index[identity] = character_body_variant


static func _hollowmere_body_variant_for(character_id: String, fallback: String) -> String:
	_ensure_hollowmere_model_index()
	return String(_hollowmere_body_variant_index.get(character_id.to_lower(), fallback))


static func _male_anatomy_scales_for_id(character_id: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(character_id)
	var z_length := clampf(rng.randfn(0.0, 1.0), -2.0, 2.0)
	var z_girth := clampf(rng.randfn(0.0, 1.0), -2.0, 2.0)
	return {
		"length_scale": (13.12 + z_length * 1.66) / 13.12,
		"girth_scale": (11.66 + z_girth * 1.10) / 11.66
	}


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
		var has_baked_appearance := (
		model_path.contains("/companions/")
		or model_path.contains("/hollowmere/")
		or model_path.contains("/tavern_npcs/generated/")
	)
		if has_baked_appearance:
			# Native companion and generated Hollowmere GLBs already contain
			# their approved body proportions, skin/eye/hair colours and details.
			# Reapplying procedural params here would overwrite that accepted look.
			ara_model.body_variant = body_variant
			ara_model.set_meta("body_variant", body_variant)
			ara_model.set_meta("gender_presentation", "Masculine" if body_variant == "male" else "Feminine")
		elif appearance_profile.has("params"):
			ara_model.apply_npc_parameters(appearance_profile.get("params", {}))
		else:
			ara_model.apply_player_profile(appearance_profile)

		# Individually generated Hollowmere NPCs already have their seeded size
		# baked into the GLB. Shared generic male bases need a stable runtime draw;
		# named companions may supply an authored override (e.g. Aldric).
		if body_variant == "male" and not is_player:
			var authored_size: Dictionary = appearance_profile.get("anatomy_size", {})
			if not authored_size.is_empty():
				# Named companion/Hollowmere meshes bake this override during their
				# Blender build. Keep the requested values on the actor for inspection.
				ara_model.set_meta("male_anatomy_size_requested", authored_size.duplicate(true))
				if model_path == PLAYER_MALE_ASSET:
					ara_model.apply_male_anatomy_size(
						float(authored_size.get("length_scale", 1.0)),
						float(authored_size.get("girth_scale", 1.0))
					)
			elif model_path == PLAYER_MALE_ASSET:
				var profile_params: Dictionary = appearance_profile.get("params", {})
				var variation_seed := str(profile_params.get("seed", character_id))
				var generated_size := _male_anatomy_scales_for_id(variation_seed)
				ara_model.apply_male_anatomy_size(
					float(generated_size.length_scale),
					float(generated_size.girth_scale)
				)
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
