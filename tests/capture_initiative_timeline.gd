extends SceneTree

func _initialize() -> void:
    call_deferred("_run_capture")

func _run_capture() -> void:
    # Build a small deterministic encounter around the real HUD control.
    get_root().size = Vector2i(1280, 720)
    var simulation := WorldSimulation.new()
    var player := CharacterState.new("player", "Adventurer", Vector2i.ZERO)
    player.side = "player"
    player.time_points = 82.0
    simulation.register_character(player)

    var wren := CharacterState.new("companion_wren_talbot", "Wren Talbot", Vector2i(1, 0))
    wren.side = "player"
    wren.time_points = 116.0
    simulation.register_character(wren)

    var guard := CharacterState.new("dray_coltayne", "Dray Coltayne", Vector2i(0, 1))
    guard.side = "enemy"
    guard.time_points = 134.0
    simulation.register_character(guard)

    var downed := CharacterState.new("fallen_ally", "Fallen Ally", Vector2i(1, 1))
    downed.side = "player"
    downed.time_points = 64.0
    downed.unconscious = true
    simulation.register_character(downed)

    simulation.start_combat()
    simulation.turn_scheduler.current_character_id = "dray_coltayne"

    var stage := Control.new()
    stage.name = "InitiativeCaptureStage"
    stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    get_root().add_child(stage)

    var background := ColorRect.new()
    background.color = Color("#111923")
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    stage.add_child(background)

    var heading := Label.new()
    heading.text = "SILVERHART SAGA — COMBAT PREVIEW"
    heading.position = Vector2(32, 28)
    heading.add_theme_font_size_override("font_size", 22)
    heading.add_theme_color_override("font_color", Color("#e8d8b6"))
    stage.add_child(heading)

    var timeline := CombatInitiativeTimeline.new()
    stage.add_child(timeline)
    timeline.configure(simulation)

    await process_frame
    await process_frame
    await create_timer(0.5).timeout

    var image := get_root().get_texture().get_image()
    var output_directory := ProjectSettings.globalize_path("res://artifacts")
    DirAccess.make_dir_recursive_absolute(output_directory)
    var output_path := output_directory.path_join("initiative-timeline.png")
    var error := image.save_png(output_path)
    if error != OK:
        push_error("Could not save initiative screenshot: %s" % error)
        quit(1)
        return

    print("Initiative screenshot saved: %s" % output_path)
    quit(0)
