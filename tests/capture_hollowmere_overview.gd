extends SceneTree

func _initialize() -> void:
    call_deferred("_capture")

func _capture() -> void:
    var main_scene_path := str(ProjectSettings.get_setting("application/run/main_scene"))
    var packed := load(main_scene_path) as PackedScene
    assert(packed != null, "Could not load the configured main scene: %s" % main_scene_path)
    var game := packed.instantiate()
    root.add_child(game)
    root.size = Vector2i(1600, 900)

    for _frame in range(8):
        await process_frame

    # Hide the gameplay HUD so the environment screenshots read as map views.
    for node in root.find_children("*", "CanvasLayer", true, false):
        node.visible = false

    var camera := Camera3D.new()
    camera.name = "HollowmereReviewCamera"
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = 190.0
    root.add_child(camera)
    camera.current = true

    camera.global_position = Vector3(105.0, 145.0, 105.0)
    camera.look_at(Vector3(0.0, 0.0, 0.0), Vector3.UP)
    for _frame in range(6):
        await process_frame
    _save_view("hollowmere_overview.png")

    camera.projection = Camera3D.PROJECTION_PERSPECTIVE
    camera.fov = 52.0
    camera.global_position = Vector3(48.0, 62.0, 76.0)
    camera.look_at(Vector3(0.0, 0.0, 22.0), Vector3.UP)
    for _frame in range(6):
        await process_frame
    _save_view("hollowmere_village_three_quarter.png")

    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = 22.0
    camera.global_position = Vector3(0.0, 18.0, 15.0)
    camera.look_at(Vector3(0.0, 1.0, 0.0), Vector3.UP)
    await create_timer(2.0).timeout
    for _frame in range(6):
        await process_frame
    _save_view("hollowmere_tavern_characters.png")
    quit()

func _save_view(filename: String) -> void:
    var output_dir := ProjectSettings.globalize_path("res://art/review")
    DirAccess.make_dir_recursive_absolute(output_dir)
    var image := root.get_texture().get_image()
    image.save_png(output_dir.path_join(filename))
    print("Saved Hollowmere review image: ", output_dir.path_join(filename))
