extends SceneTree
## Capture the real Quaternius horse with the modular tack attached.

const CREATURE_ACTOR = preload("res://scripts/presentation/creature_actor.gd")
const HORSE_MODEL := "res://art/creatures/quaternius/Horse.gltf"
const OUTPUTS := [
    {"name": "side", "camera": Vector3(7.0, 3.0, 0.0), "target": Vector3(0.0, 2.0, 0.0)},
    # The imported horse faces +Z: positive Z is the front view.
    {"name": "front", "camera": Vector3(0.0, 3.0, 8.0), "target": Vector3(0.0, 2.0, 0.15)},
    {"name": "rear", "camera": Vector3(0.0, 3.0, -8.0), "target": Vector3(0.0, 2.0, -0.15)}
]

func _initialize() -> void:
    call_deferred("_capture")

func _capture() -> void:
    root.size = Vector2i(1800, 1100)
    DisplayServer.window_set_size(Vector2i(1800, 1100))
    root.title = "Silverhart Saga - horse tack visual review"

    var world := Node3D.new()
    root.add_child(world)

    var environment_node := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color(0.48, 0.56, 0.62)
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.82, 0.80, 0.76)
    environment.ambient_light_energy = 1.0
    environment_node.environment = environment
    world.add_child(environment_node)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-35.0, -35.0, 0.0)
    sun.light_energy = 1.15
    world.add_child(sun)

    # Soft fill from the opposite side keeps rear-facing tack details readable.
    var fill := DirectionalLight3D.new()
    fill.rotation_degrees = Vector3(-18.0, 145.0, 0.0)
    fill.light_energy = 0.75
    fill.light_color = Color(0.78, 0.84, 1.0)
    world.add_child(fill)

    var ground := MeshInstance3D.new()
    var ground_mesh := PlaneMesh.new()
    ground_mesh.size = Vector2(18.0, 18.0)
    ground.mesh = ground_mesh
    var ground_material := StandardMaterial3D.new()
    ground_material.albedo_color = Color(0.25, 0.31, 0.27)
    ground.material_override = ground_material
    ground.position.y = -0.04
    world.add_child(ground)

    var horse := CREATURE_ACTOR.new() as CreatureActor
    horse.name = "TackReviewHorse"
    horse.creature_kind = "horse"
    horse.behaviour = "mount"
    horse.model_scale = 0.45
    horse.model_path = HORSE_MODEL
    world.add_child(horse)

    var camera := Camera3D.new()
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = 4.2
    world.add_child(camera)
    camera.current = true

    for frame_index in range(30):
        await process_frame
    if horse.model_root == null:
        push_error("Horse model failed to load for tack review")
        quit(1)
        return
    if horse.model_root.get_node_or_null("HorseTack") == null:
        push_error("HorseTack was not attached to the imported horse model")
        quit(1)
        return

    for view in OUTPUTS:
        camera.position = view.camera
        camera.look_at(view.target, Vector3.UP)
        await process_frame
        await process_frame
        var image := root.get_texture().get_image()
        if image == null or image.is_empty():
            push_error("No rendered image for %s view" % view.name)
            quit(1)
            return
        var output_path := "res://horse-tack-review-%s.png" % view.name
        var error_code := image.save_png(ProjectSettings.globalize_path(output_path))
        if error_code != OK:
            push_error("Could not save %s: %s" % [output_path, error_string(error_code)])
            quit(1)
            return
        print("HORSE_TACK_REVIEW_IMAGE=" + ProjectSettings.globalize_path(output_path))

    print("Horse tack visual review images captured.")
    quit(0)
