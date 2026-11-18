class_name HollowmereOpeningSequence
extends Node
## Presentation-only staging for the Hollowmere Ironbond opening.
## Campaign quest state, enemy movement and choice resolution remain outside this component.

const DIRECTOR_SCRIPT = preload("res://scripts/presentation/cinematic_director.gd")

var _director: CinematicDirector
var _actors: Dictionary = {}
var _saved_transforms: Dictionary = {}
var _tankards: Array[MeshInstance3D] = []


func play(
    actors: Dictionary,
    gameplay_hud: CanvasLayer,
    gameplay_camera: Camera3D,
    opening_conversation_lines: Array,
    opening_lines: Array,
    move_enforcers: Callable,
    enforcer_ids: Array[String]
) -> void:
    _actors = actors
    _save_actor_transforms()

    _director = DIRECTOR_SCRIPT.new() as CinematicDirector
    _director.name = "CinematicDirector"
    add_child(_director)
    _director.begin(_actors, gameplay_hud, gameplay_camera)
    _stage_table_conversation()
    _log_character_animation_catalogues()

    await get_tree().create_timer(2.0).timeout
    # Dialogue text belongs to campaign content; this component only presents it.
    for conversation_line_variant in opening_conversation_lines:
        var conversation_line: Dictionary = conversation_line_variant
        await _director.present_line(conversation_line, 3.2)

    var enforcers_entered := false
    for line_variant in opening_lines:
        var line: Dictionary = line_variant
        var speaker_id := String(line.get("speaker_id", "dray_coltayne"))
        if speaker_id == "narrator" and not enforcers_entered:
            await _stage_confrontation()
            _play_enforcer_movement(enforcer_ids, true)
            # Even when the player skips, the actual campaign actors still enter.
            await move_enforcers.call()
            _play_enforcer_movement(enforcer_ids, false)
            enforcers_entered = true
        await _director.present_line(line, 3.2 if speaker_id == "narrator" else 3.5)

    if not enforcers_entered:
        await _stage_confrontation()
        _play_enforcer_movement(enforcer_ids, true)
        await move_enforcers.call()
        _play_enforcer_movement(enforcer_ids, false)

    _director.finish()
    _restore_actor_transforms()


func _save_actor_transforms() -> void:
    _saved_transforms.clear()
    for actor_id in ["player", "companion_wren_talbot"]:
        var actor := _actors.get(actor_id) as Node3D
        if actor != null and is_instance_valid(actor):
            _saved_transforms[actor_id] = actor.global_transform


func _stage_table_conversation() -> void:
    var player := _actors.get("player") as Node3D
    var wren := _actors.get("companion_wren_talbot") as Node3D
    if player == null or wren == null:
        push_warning("Hollowmere opening cannot stage its table conversation: player or Wren actor is missing.")
        return

    # These positions align with the east table and benches in the current taproom layout.
    player.global_position = Vector3(2.65, 0.0, 1.45)
    player.rotation.y = PI
    wren.global_position = Vector3(2.65, 0.0, -1.45)
    wren.rotation.y = 0.0
    _play_actor_animation("player", ["Sit idle", "sit_idle"], ["Idle"])
    _play_actor_animation("companion_wren_talbot", ["Sit idle", "sit_idle"], ["Idle"])
    _create_table_tankards()


func _create_table_tankards() -> void:
    for x_position in [2.25, 3.05]:
        var tankard := MeshInstance3D.new()
        tankard.name = "OpeningTankard"
        var mesh := CylinderMesh.new()
        mesh.top_radius = 0.13
        mesh.bottom_radius = 0.11
        mesh.height = 0.32
        tankard.mesh = mesh
        var material := StandardMaterial3D.new()
        material.albedo_color = Color(0.34, 0.19, 0.09)
        material.metallic = 0.28
        material.roughness = 0.42
        tankard.material_override = material
        tankard.position = Vector3(x_position, 1.12, 0.0)
        add_child(tankard)
        _tankards.append(tankard)


func _stage_confrontation() -> void:
    for tankard in _tankards:
        if is_instance_valid(tankard):
            tankard.visible = false
    if _director.was_skipped():
        return

    _play_actor_animation("player", ["Stand up (on a chair)", "stand_up_on_chair"], ["Idle"])
    _play_actor_animation("companion_wren_talbot", ["Stand up (on a chair)", "stand_up_on_chair"], ["Idle"])
    var elapsed := 0.0
    while elapsed < 1.25 and not _director.was_skipped():
        var frame_start := Time.get_ticks_msec()
        await get_tree().process_frame
        elapsed += float(Time.get_ticks_msec() - frame_start) / 1000.0

    if _director.was_skipped():
        return

    var player := _actors.get("player") as Node3D
    var wren := _actors.get("companion_wren_talbot") as Node3D
    var movement := create_tween()
    movement.set_parallel(true)
    var has_movement := false
    if player != null and is_instance_valid(player):
        player.rotation.y = -PI / 2.0
        _play_actor_animation("player", ["Walk"], ["Idle"])
        movement.tween_property(player, "global_position", Vector3(1.38, 0.0, 1.55), 0.9)
        has_movement = true
    if wren != null and is_instance_valid(wren):
        wren.rotation.y = PI / 2.0
        _play_actor_animation("companion_wren_talbot", ["Walk"], ["Idle"])
        movement.tween_property(wren, "global_position", Vector3(3.92, 0.0, -1.55), 0.9)
        has_movement = true
    if has_movement:
        await movement.finished

    if player != null and is_instance_valid(player):
        player.rotation.y = 0.0
        _play_actor_animation("player", ["Idle"], [])
    if wren != null and is_instance_valid(wren):
        wren.rotation.y = 0.0
        _play_actor_animation("companion_wren_talbot", ["Idle"], [])


func _play_enforcer_movement(enforcer_ids: Array[String], walking: bool) -> void:
    for character_id in enforcer_ids:
        if walking:
            _play_actor_animation(character_id, ["Walk", "Walking"], ["Idle"])
        else:
            _play_actor_animation(character_id, ["Idle", "Stand"], [])


func _play_actor_animation(actor_id: String, preferred: Array[String], fallback: Array[String] = []) -> String:
    if _director == null:
        return ""
    return _director.play_actor_animation(actor_id, preferred, fallback)


func _log_character_animation_catalogues() -> void:
    for actor_id in ["player", "companion_wren_talbot"]:
        var actor := _actors.get(actor_id) as Node
        if actor == null or not is_instance_valid(actor):
            continue
        var character_model := actor.get_node_or_null("CharacterModel") as AraCharacterActor
        if character_model != null:
            print("[Ara animation catalogue] actor=%s asset=%s clips=%s" % [
                actor_id,
                character_model.loaded_asset_path,
                ", ".join(character_model.available_animation_names())
            ])


func _restore_actor_transforms() -> void:
    for actor_id in _saved_transforms:
        var actor := _actors.get(actor_id) as Node3D
        if actor != null and is_instance_valid(actor):
            actor.global_transform = _saved_transforms[actor_id]
            _play_actor_animation(actor_id, ["Idle"], ["Stand"])
    _saved_transforms.clear()

    for tankard in _tankards:
        if is_instance_valid(tankard):
            tankard.queue_free()
    _tankards.clear()
