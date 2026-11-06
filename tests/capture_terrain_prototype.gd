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

    var terrain_renderer := terrain_scene.get_node_or_null("ElevationPrototypeTerrain") as HexTerrainRenderer
    if terrain_renderer == null:
        push_error("Terrain prototype is missing its HexTerrainRenderer.")
        quit(1)
        return
    var terrain_body := terrain_renderer.get_node_or_null("TerrainCollision") as StaticBody3D
    if terrain_body == null:
        push_error("Terrain renderer did not create TerrainCollision.")
        quit(1)
        return
    var terrain_shape_node := terrain_body.get_node_or_null("TerrainCollisionShape") as CollisionShape3D
    if terrain_shape_node == null:
        push_error("TerrainCollision is missing its named TerrainCollisionShape child.")
        print("TerrainCollision children: ", terrain_body.get_children().map(func(child): return "%s (%s)" % [child.name, child.get_class()]))
        quit(1)
        return
    var terrain_shape := terrain_shape_node.shape as ConcavePolygonShape3D
    if terrain_shape == null:
        push_error("TerrainCollisionShape does not contain a ConcavePolygonShape3D.")
        quit(1)
        return
    var face_count := terrain_shape.get_faces().size() / 3 if terrain_shape != null else 0
    print("Terrain collider diagnostics: faces=%d layer=%d mask=%d disabled=%s" % [
        face_count, terrain_body.collision_layer, terrain_body.collision_mask, terrain_shape_node.disabled
    ])

    # First prove the terrain collision is queryable at the actor start points.
    # This separates a missing / misoriented terrain collider from a character
    # controller or spawn-height problem.
    var space_state: PhysicsDirectSpaceState3D = terrain_scene.get_world_3d().direct_space_state
    for actor_name in ["ValleyCharacter", "SlopeCharacter", "RidgeCharacter", "RidgeWalker"]:
        var probe_actor := terrain_scene.get_node_or_null(actor_name) as CharacterBody3D
        if probe_actor == null:
            push_error("Missing terrain test actor: %s" % actor_name)
            quit(1)
            return
        var probe_from := probe_actor.global_position + Vector3.UP * 8.0
        var probe_to := probe_actor.global_position + Vector3.DOWN * 8.0
        var query := PhysicsRayQueryParameters3D.create(probe_from, probe_to)
        query.collision_mask = 0xFFFFFFFF
        query.exclude = [probe_actor.get_rid()]
        var hit: Dictionary = space_state.intersect_ray(query)
        if hit.is_empty():
            # A second probe accepting back faces distinguishes reversed
            # triangle winding from a missing/unregistered collision shape.
            query.hit_back_faces = true
            hit = space_state.intersect_ray(query)
            if not hit.is_empty():
                push_error("Terrain ray only hits back faces for %s; inspect triangle winding. Hit normal: %s" % [actor_name, hit.normal])
                quit(1)
                return
            push_error("Terrain collision ray missed even with back-face hits enabled at %s for %s" % [probe_actor.global_position, actor_name])
            quit(1)
            return
        print("Terrain ray hit for %s at %s on %s with normal %s" % [actor_name, hit.position, hit.collider.name, hit.normal])

    # Let the CharacterBody3D proxies fall onto the generated terrain collider.
    for _frame in range(30):
        await physics_frame
    for actor_name in ["ValleyCharacter", "SlopeCharacter", "RidgeCharacter", "RidgeWalker"]:
        var actor := terrain_scene.get_node_or_null(actor_name) as CharacterBody3D
        if actor == null:
            push_error("Missing terrain test actor: %s" % actor_name)
            quit(1)
            return
        if not actor.is_on_floor():
            push_error("Terrain test actor did not ground on the mesh: %s at %s" % [actor_name, actor.global_position])
            quit(1)
            return
        print("Grounded %s at %s" % [actor_name, actor.global_position])


    var views := [
        {"name": "terrain-overview.png", "position": Vector3(0.0, 0.8, 0.0), "yaw": 0.0, "pitch": -52.0, "zoom": 34.0},
        {"name": "terrain-overhead.png", "position": Vector3(0.0, 0.8, 0.0), "yaw": 0.0, "pitch": -78.0, "zoom": 34.0},
        {"name": "terrain-ridge-oblique.png", "position": Vector3(0.0, 0.8, 0.0), "yaw": 38.0, "pitch": -42.0, "zoom": 25.0},
        {"name": "terrain-character-grounding.png", "position": Vector3(4.2, 3.1, 0.0), "yaw": 24.0, "pitch": -38.0, "zoom": 13.0}
    ]

    for view in views:
        rig.position = view["position"]
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
