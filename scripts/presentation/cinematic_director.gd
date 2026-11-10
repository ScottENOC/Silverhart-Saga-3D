class_name CinematicDirector
extends Node
## Small reusable in-engine cutscene presenter.
## It borrows the live actors and world, but uses its own camera and UI so
## gameplay camera controls and HUD state are not repurposed by a sequence.

var _actors: Dictionary = {}
var _gameplay_hud: CanvasLayer
var _gameplay_camera: Camera3D
var _cinematic_camera: Camera3D
var _cinematic_layer: CanvasLayer
var _subtitle_label: Label
var _skipped: bool = false
var _finished: bool = false
var _original_actor_transforms: Dictionary = {}
var _table_mugs: Array[MeshInstance3D] = []


func begin(actors: Dictionary, gameplay_hud: CanvasLayer, gameplay_camera: Camera3D) -> void:
    _actors = actors
    _gameplay_hud = gameplay_hud
    _gameplay_camera = gameplay_camera
    _skipped = false
    _finished = false
    _original_actor_transforms.clear()
    _save_actor_transforms()
    _stage_table_conversation()
    _create_table_mugs()

    if is_instance_valid(_gameplay_hud):
        _gameplay_hud.visible = false
    if is_instance_valid(_gameplay_camera):
        _gameplay_camera.current = false

    _cinematic_camera = Camera3D.new()
    _cinematic_camera.name = "CinematicCamera"
    _cinematic_camera.fov = 48.0
    add_child(_cinematic_camera)
    if is_instance_valid(_gameplay_camera):
        _cinematic_camera.global_transform = _gameplay_camera.global_transform
    _cinematic_camera.current = true

    _cinematic_layer = CanvasLayer.new()
    _cinematic_layer.name = "CinematicPresentation"
    add_child(_cinematic_layer)

    var subtitle_panel := PanelContainer.new()
    subtitle_panel.anchor_left = 0.08
    subtitle_panel.anchor_right = 0.92
    subtitle_panel.anchor_top = 1.0
    subtitle_panel.anchor_bottom = 1.0
    subtitle_panel.offset_top = -166.0
    subtitle_panel.offset_bottom = -28.0
    _cinematic_layer.add_child(subtitle_panel)

    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 18)
    margin.add_theme_constant_override("margin_right", 18)
    margin.add_theme_constant_override("margin_top", 12)
    margin.add_theme_constant_override("margin_bottom", 12)
    subtitle_panel.add_child(margin)

    _subtitle_label = Label.new()
    _subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _subtitle_label.add_theme_font_size_override("font_size", 20)
    margin.add_child(_subtitle_label)

    var skip_button := Button.new()
    skip_button.text = "Skip scene"
    skip_button.anchor_left = 1.0
    skip_button.anchor_right = 1.0
    skip_button.offset_left = -142.0
    skip_button.offset_right = -22.0
    skip_button.offset_top = 20.0
    skip_button.offset_bottom = 64.0
    skip_button.pressed.connect(_on_skip_pressed)
    _cinematic_layer.add_child(skip_button)


func present_line(line: Dictionary, duration: float = 3.5) -> void:
    if _skipped or _finished:
        return

    var speaker_id := String(line.get("speaker_id", ""))
    var speaker := String(line.get("speaker", "Narrator"))
    var spoken_text := String(line.get("text", ""))
    if spoken_text.is_empty():
        return

    if speaker_id == "narrator":
        await _frame_group()
    else:
        await _frame_actor(speaker_id)

    if _skipped or _finished or not is_instance_valid(_subtitle_label):
        return
    _subtitle_label.text = speaker + "\n\n" + spoken_text
    if not speaker_id.is_empty() and speaker_id != "narrator":
        play_actor_animation(speaker_id, ["talk", "speaking", "gesture"], ["idle", "sit"])

    # A process-frame wait lets the skip control interrupt a line immediately,
    # rather than forcing the player to wait for a long timer to expire.
    var elapsed := 0.0
    while elapsed < duration and not _skipped and not _finished:
        var frame_start := Time.get_ticks_msec()
        await get_tree().process_frame
        elapsed += float(Time.get_ticks_msec() - frame_start) / 1000.0


func was_skipped() -> bool:
    return _skipped


func finish() -> void:
    if _finished:
        return
    _finished = true

    _restore_actor_transforms()
    for mug in _table_mugs:
        if is_instance_valid(mug):
            mug.queue_free()
    _table_mugs.clear()
    if is_instance_valid(_cinematic_layer):
        _cinematic_layer.queue_free()
    if is_instance_valid(_cinematic_camera):
        _cinematic_camera.current = false
        _cinematic_camera.queue_free()
    if is_instance_valid(_gameplay_camera):
        _gameplay_camera.current = true
    if is_instance_valid(_gameplay_hud):
        _gameplay_hud.visible = true



## Put the player and Wren at the existing east dining table for the opening.
## Their world transforms are restored when the cinematic hands control back.
func _save_actor_transforms() -> void:
    for actor_id in ["player", "companion_wren_talbot"]:
        var actor := _actors.get(actor_id) as Node3D
        if actor != null and is_instance_valid(actor):
            _original_actor_transforms[actor_id] = actor.global_transform


func _stage_table_conversation() -> void:
    var player := _actors.get("player") as Node3D
    var wren := _actors.get("companion_wren_talbot") as Node3D
    if player == null or wren == null:
        return
    # The east table is centred at x=2.65; its benches are already part of
    # HollowTankard's furniture layout.
    player.global_position = Vector3(2.65, 0.0, 1.25)
    player.rotation.y = 0.0
    wren.global_position = Vector3(2.65, 0.0, -1.25)
    wren.rotation.y = PI
    play_actor_animation("player", ["sit", "sitting", "seated"], ["idle"])
    play_actor_animation("companion_wren_talbot", ["sit", "sitting", "seated"], ["idle"])


func _create_table_mugs() -> void:
    for x_position in [2.25, 3.05]:
        var mug := MeshInstance3D.new()
        mug.name = "CinematicTankard"
        var mesh := CylinderMesh.new()
        mesh.top_radius = 0.13
        mesh.bottom_radius = 0.11
        mesh.height = 0.32
        mug.mesh = mesh
        var material := StandardMaterial3D.new()
        material.albedo_color = Color(0.34, 0.19, 0.09)
        material.metallic = 0.28
        material.roughness = 0.42
        mug.material_override = material
        mug.position = Vector3(x_position, 1.12, 0.0)
        add_child(mug)
        _table_mugs.append(mug)


## Called as the Ironbond entrance is announced.
func stage_confrontation() -> void:
    for mug in _table_mugs:
        if is_instance_valid(mug):
            mug.visible = false
    var player := _actors.get("player") as Node3D
    var wren := _actors.get("companion_wren_talbot") as Node3D
    if player != null and is_instance_valid(player):
        player.global_position = Vector3(2.1, 0.0, 1.0)
        player.rotation.y = PI
        play_actor_animation("player", ["stand", "standing", "rise"], ["idle"])
    if wren != null and is_instance_valid(wren):
        wren.global_position = Vector3(3.2, 0.0, 1.0)
        wren.rotation.y = PI
        play_actor_animation("companion_wren_talbot", ["stand", "standing", "rise"], ["idle"])


## Resolve the AraCharacterActor wrapper below a live world actor and play a
## compatible clip by semantic name. Missing clips safely leave the current pose.
func play_actor_animation(actor_id: String, preferred_terms: Array[String], fallback_terms: Array[String] = []) -> String:
    var actor := _actors.get(actor_id) as Node
    if actor == null or not is_instance_valid(actor):
        return ""
    var character_model := actor.get_node_or_null("CharacterModel") as AraCharacterActor
    if character_model == null:
        return ""
    var clip := character_model.play_animation_matching(preferred_terms, fallback_terms)
    if clip.is_empty() and not preferred_terms.is_empty():
        print("[Cinematic] No Ara clip matched %s for %s. Available: %s" % [
            ", ".join(preferred_terms), actor_id, ", ".join(character_model.available_animation_names())
        ])
    return clip


func _restore_actor_transforms() -> void:
    for actor_id in _original_actor_transforms:
        var actor := _actors.get(actor_id) as Node3D
        if actor != null and is_instance_valid(actor):
            actor.global_transform = _original_actor_transforms[actor_id]
            play_actor_animation(actor_id, ["idle"], ["stand"])
    _original_actor_transforms.clear()

func _on_skip_pressed() -> void:
    _skipped = true


func _frame_actor(actor_id: String) -> void:
    var actor := _actors.get(actor_id) as Node3D
    if actor == null or not is_instance_valid(actor):
        await _frame_group()
        return
    var focus := actor.global_position + Vector3(0.0, 1.45, 0.0)
    var destination := focus + Vector3(4.2, 2.3, 5.8)
    await _move_camera(destination, focus)


func _frame_group() -> void:
    var focus := Vector3.ZERO
    var count := 0
    for actor_id in ["player", "companion_wren_talbot", "garrick_holt", "dray_coltayne"]:
        var actor := _actors.get(actor_id) as Node3D
        if actor != null and is_instance_valid(actor):
            focus += actor.global_position + Vector3(0.0, 1.0, 0.0)
            count += 1
    if count > 0:
        focus /= float(count)
    var destination := focus + Vector3(0.0, 6.0, 10.5)
    await _move_camera(destination, focus)


func _move_camera(destination: Vector3, focus: Vector3) -> void:
    if not is_instance_valid(_cinematic_camera) or _skipped or _finished:
        return
    var tween := create_tween()
    tween.set_trans(Tween.TRANS_SINE)
    tween.set_ease(Tween.EASE_IN_OUT)
    tween.tween_property(_cinematic_camera, "global_position", destination, 0.55)
    await tween.finished
    if is_instance_valid(_cinematic_camera) and not _skipped and not _finished:
        _cinematic_camera.look_at(focus, Vector3.UP)
