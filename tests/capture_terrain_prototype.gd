extends SceneTree

const TERRAIN_SCENE := "res://scenes/prototypes/terrain_elevation_prototype.tscn"
const OUTPUT_DIR := "res://artifacts"

func _initialize() -> void:
    call_deferred("_capture_views")

func _capture_views() -> void:
    var output_path := ProjectSettings.globalize_path(OUTPUT_DIR)
    DirAccess.make_dir_recursive_absolute(output_path)

    var packed_scene := load(TERRAIN_SCENE) as PackedScene
    if packed_scene == null:
        push_error("Could not load terrain prototype scene.")
        quit(1)
        return

    var terrain_scene := packed_scene.instantiate()
    root.add_child(terrain_scene)

    # Allow scene setup, rendering-server submission and one physics update.
    await process_frame
    await physics_frame
    await process_frame

    var rig := terrain_scene.get_node_or_null("TerrainOrbitCamera") as OrbitCameraRig
    if rig == null:
        push_error("Terrain prototype is missing TerrainOrbitCamera.")
        quit(1)
        return

    var pitch_pivot := rig.get_node_or_null("PitchPivot") as Node3D
    if pitch_pivot == null:
        push_error("Terrain camera is missing PitchPivot.")
        quit(1)
        return

    var views := [
        {"name": "terrain-overview.png", "yaw": 0.0, "pitch": -52.0, "zoom": 34.0},
        {"name": "terrain-overhead.png", "yaw": 0.0, "pitch": -78.0, "zoom": 34.0},
        {"name": "terrain-ridge-oblique.png", "yaw": 38.0, "pitch": -42.0, "zoom": 25.0}
    ]

    for view in views:
        rig.rotation_degrees.y = view["yaw"]
        pitch_pivot.rotation_degrees.x = view["pitch"]
        rig.set_zoom(view["zoom"])
        await process_frame
        await physics_frame
        await process_frame
        RenderingServer.force_draw(false)
        var screenshot := root.get_texture().get_image()
        if screenshot.is_empty():
            push_error("Viewport returned an empty screenshot for %s." % view["name"])
            quit(1)
            return
        var destination := output_path.path_join(view["name"])
        var error := screenshot.save_png(destination)
        if error != OK:
            push_error("Could not save screenshot %s (error %d)." % [destination, error])
            quit(1)
            return
        print("Saved screenshot: %s (%dx%d)" % [destination, screenshot.get_width(), screenshot.get_height()])

    print("Terrain prototype screenshots captured.")
    quit(0)
