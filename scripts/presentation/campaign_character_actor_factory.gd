class_name CampaignCharacterActorFactory
extends RefCounted
## Builds the 3D presentation for a campaign character.
## Simulation state and world placement remain owned by the caller.

const ARA_CHARACTER_ACTOR = preload("res://scripts/presentation/ara_character_actor.gd")
const PLAYER_FEMALE_ASSET := "res://art/characters/ara_runtime/ara_person_body.glb"
const PLAYER_CUSTOM_FEMALE_ASSET := "res://art/characters/hollowmere/player_avatar.glb"
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

    var actor := HexActorPresentation.new()
    actor.name = state.id
    actor.position = world_position
    actor.set_meta("character_id", state.id)
    actor.set_meta("ambient_enabled", not is_player and state.id != "companion_wren_talbot")
    actor.set_meta("ambient_role", ambient_role)
    var base_appearance: Dictionary = npc_profile.get("params", {}).duplicate(true) if not is_player else {}
    actor.set_meta("base_appearance_profile", base_appearance.duplicate(true))
    actor.set_meta("appearance_profile", base_appearance.duplicate(true))
    actor.rotation.y = deg_to_rad(float(state.facing_direction - 2) * 60.0)

    var ara_model := ARA_CHARACTER_ACTOR.new() as AraCharacterActor
    ara_model.name = "CharacterModel"
    actor.add_child(ara_model)

    var body_variant := str(player_profile.get("body_variant", "female")) if is_player else ("male" if int(npc_profile.get("params", {}).get("gender", 0)) == 1 else "female")
    var model_path := PLAYER_MALE_ASSET if body_variant == "male" else PLAYER_FEMALE_ASSET
    if is_player and body_variant == "female" and ResourceLoader.exists(PLAYER_CUSTOM_FEMALE_ASSET):
        model_path = PLAYER_CUSTOM_FEMALE_ASSET
    if not is_player and not ara_model_id.is_empty():
        var authored_npc_path := "res://art/characters/hollowmere/%s.glb" % ara_model_id
        if ResourceLoader.exists(authored_npc_path):
            model_path = authored_npc_path

    var model_loaded := ara_model.configure(model_path)
    if model_loaded:
        if is_player:
            ara_model.apply_player_profile(player_profile)
        else:
            ara_model.apply_npc_parameters(npc_profile.get("params", {}))
        if model_path.contains("/ara_runtime/"):
            var hair_id := str(player_profile.get("hair_style_id", "short02")) if is_player else str(npc_profile.get("params", {}).get("hair", "short02"))
            _attach_ara_hair(ara_model, body_variant, hair_id)
        # Authored Hollowmere NPC GLBs already contain their selected Ara garments.
        # Runtime base bodies and the player avatar need the separate modular layer.
        if is_player or model_path.contains("/ara_runtime/"):
            ara_model.configure_modular_garments()
        ara_model.apply_equipment_visuals(state.equipped_item_data)
    else:
        push_error("Character '%s' could not load Ara model '%s'. No primitive substitute will be shown." % [state.display_name, model_path])
        ara_model.queue_free()

    var name_label := Label3D.new()
    name_label.name = "PlayerNameLabel" if is_player else "CharacterNameLabel"
    name_label.text = "You" if is_player else state.display_name
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
