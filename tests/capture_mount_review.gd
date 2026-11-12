extends SceneTree
## Rendered side-on and three-quarter rider/mount diagnostics.
const MOUNT_PRESENTATION = preload("res://scripts/presentation/mount_presentation.gd")
const CREATURE_ACTOR = preload("res://scripts/presentation/creature_actor.gd")
const ARA_ACTOR = preload("res://scripts/presentation/ara_character_actor.gd")
const HORSE_MODEL := "res://art/creatures/quaternius/Horse.gltf"
const FEMALE_BODY := "res://art/characters/ara_runtime/ara_person_body.glb"
const MALE_BODY := "res://art/characters/ara_runtime/ara_person_male_body.glb"
const OUTPUT_PATH := "res://mount-review.png"

func _initialize() -> void:
    call_deferred("_capture")

func _capture() -> void:
    root.size = Vector2i(1800, 1000)
    DisplayServer.window_set_size(Vector2i(1800, 1000))
    root.title = "Silverhart Saga — mounted rider side review"
    var world := Node3D.new()
    root.add_child(world)
    var env_node := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.48, 0.56, 0.62)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.78, 0.76, 0.72)
    env.ambient_light_energy = 1.0
    env_node.environment = env
    world.add_child(env_node)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-35, -35, 0)
    sun.light_energy = 1.5
    world.add_child(sun)
    var ground := MeshInstance3D.new()
    var plane := PlaneMesh.new()
    plane.size = Vector2(22, 16)
    ground.mesh = plane
    var gm := StandardMaterial3D.new()
    gm.albedo_color = Color(0.25, 0.31, 0.27)
    ground.material_override = gm
    ground.position.y = -0.05
    world.add_child(ground)

    # Quaternius Horse.gltf faces along local +X. A camera on +X therefore
    # sees the horse head-on; use +Z for a genuine broadside rider silhouette.
    # Add the camera before look_at() so Godot can orient it in the scene tree.
    var camera := Camera3D.new()
    camera.position = Vector3(0.0, 3.0, 11.5)
    camera.fov = 48
    world.add_child(camera)
    camera.look_at(Vector3(0.0, 1.45, 0.0), Vector3.UP)
    camera.current = true

    var ok_f := _add_pair(world, -3.8, FEMALE_BODY, "FEMALE BASE")
    var ok_m := _add_pair(world, 3.8, MALE_BODY, "MALE BASE")
    if not ok_f or not ok_m:
        push_error("Failed to load one or more Ara/horse models")
        quit(1)
        return
    for _i in range(12):
        await process_frame
    await create_timer(1.0).timeout
    var img := root.get_texture().get_image()
    if img == null or img.is_empty():
        push_error("No rendered image")
        quit(1)
        return
    var err := img.save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
    if err != OK:
        push_error("PNG save failed: %s" % error_string(err))
        quit(1)
        return
    print("MOUNT_REVIEW_IMAGE=" + ProjectSettings.globalize_path(OUTPUT_PATH))
    quit(0)

func _add_pair(world: Node3D, x: float, body_path: String, title: String) -> bool:
    var horse := CREATURE_ACTOR.new() as CreatureActor
    horse.name = title.replace(" ", "") + "Horse"
    horse.creature_kind = "horse"
    horse.behaviour = "mount"
    horse.model_scale = 0.82
    horse.model_path = HORSE_MODEL
    horse.position = Vector3(x, 0, 0)
    world.add_child(horse)

    var rider := ARA_ACTOR.new() as AraCharacterActor
    rider.name = title.replace(" ", "") + "Rider"
    world.add_child(rider)
    if not rider.configure(body_path):
        return false
    if not MOUNT_PRESENTATION.attach_rider(rider, horse):
        return false
    var label := Label3D.new()
    label.text = title
    label.font_size = 48
    label.outline_size = 10
    label.modulate = Color(1.0, 0.95, 0.78)
    label.position = Vector3(x, 3.5, 0.0)
    label.rotation_degrees.y = 90
    world.add_child(label)
    print("[Mount review] %s rider root=%s model=%s rider_global=%s horse_global=%s" % [
        title, rider.transform, rider.model_root.transform, rider.global_position, horse.global_position
    ])
    return true
