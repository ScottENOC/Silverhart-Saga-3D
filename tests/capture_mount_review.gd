extends SceneTree
## Captures the actual Ara rider + Quaternius horse models for visual review.
## Run with a graphical display (CI uses xvfb-run), not --headless.

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
    root.size = Vector2i(1600, 900)
    DisplayServer.window_set_size(Vector2i(1600, 900))
    root.title = "Silverhart Saga — mounted rider visual review"

    var world := Node3D.new()
    world.name = "MountReviewWorld"
    root.add_child(world)

    var environment_node := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color(0.42, 0.52, 0.59)
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.72, 0.70, 0.66)
    environment.ambient_light_energy = 0.8
    environment_node.environment = environment
    world.add_child(environment_node)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-42.0, -28.0, 0.0)
    sun.light_energy = 1.5
    world.add_child(sun)

    var ground := MeshInstance3D.new()
    var ground_mesh := PlaneMesh.new()
    ground_mesh.size = Vector2(18.0, 14.0)
    ground.mesh = ground_mesh
    var ground_material := StandardMaterial3D.new()
    ground_material.albedo_color = Color(0.24, 0.29, 0.25)
    ground_material.roughness = 0.95
    ground.material_override = ground_material
    ground.position.y = -0.08
    world.add_child(ground)

    var camera := Camera3D.new()
    camera.position = Vector3(0.0, 3.5, 10.5)
    camera.look_at(Vector3(0.0, 1.35, 0.0), Vector3.UP)
    camera.fov = 42.0
    world.add_child(camera)
    camera.current = true

    var female_ok := _add_pair(world, -2.8, FEMALE_BODY, "FEMALE BASE")
    var male_ok := _add_pair(world, 2.8, MALE_BODY, "MALE BASE")
    if not female_ok or not male_ok:
        push_error("Could not load one or more rider/horse models for the mount review.")
        quit(1)
        return

    for _frame in range(8):
        await process_frame
    await create_timer(1.5).timeout
    var screenshot := root.get_texture().get_image()
    if screenshot == null or screenshot.is_empty():
        push_error("Godot did not return a rendered mount review image.")
        quit(1)
        return
    var output_file := ProjectSettings.globalize_path(OUTPUT_PATH)
    var save_error := screenshot.save_png(output_file)
    if save_error != OK:
        push_error("Could not save mount review image: %s" % error_string(save_error))
        quit(1)
        return
    print("MOUNT_REVIEW_IMAGE=" + output_file)
    quit(0)

func _add_pair(world: Node3D, x_offset: float, body_path: String, label_text: String) -> bool:
    var horse := CREATURE_ACTOR.new() as CreatureActor
    horse.name = label_text.replace(" ", "") + "Horse"
    horse.creature_kind = "horse"
    horse.behaviour = "mount"
    horse.model_scale = 0.82
    horse.model_path = HORSE_MODEL
    horse.position = Vector3(x_offset, 0.0, 0.0)
    world.add_child(horse)

    var rider := ARA_ACTOR.new() as AraCharacterActor
    rider.name = label_text.replace(" ", "") + "Rider"
    world.add_child(rider)
    if not rider.configure(body_path):
        return false
    if not MOUNT_PRESENTATION.attach_rider(rider, horse):
        return false

    var label := Label3D.new()
    label.text = label_text
    label.position = Vector3(x_offset, 3.1, 0.0)
    label.font_size = 48
    label.outline_size = 10
    label.modulate = Color(1.0, 0.94, 0.78)
    world.add_child(label)
    return true
