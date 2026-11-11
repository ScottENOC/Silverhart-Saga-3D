extends SceneTree

const HORSE_MODEL := "res://art/creatures/quaternius/Horse.gltf"
const FEMALE_RIDER_MODEL := "res://art/characters/hollowmere/player_avatar.glb"
const MALE_RIDER_MODEL := "res://art/characters/ara_runtime/ara_person_male_body.glb"

var _stage: Node3D
var _camera: Camera3D


func _initialize() -> void:
    call_deferred("_run_capture")


func _run_capture() -> void:
    get_root().size = Vector2i(1440, 900)
    var world_environment := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color("#9aaeb8")
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color("#d8d0bd")
    environment.ambient_light_energy = 0.8
    world_environment.environment = environment
    get_root().add_child(world_environment)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-42.0, -32.0, 0.0)
    sun.light_energy = 1.5
    get_root().add_child(sun)

    var output_directory := ProjectSettings.globalize_path("res://artifacts")
    DirAccess.make_dir_recursive_absolute(output_directory)

    var female_ok := await _capture_variant(FEMALE_RIDER_MODEL, "riding-preview-female.png", Vector3(4.6, 3.0, 6.2))
    var male_ok := await _capture_variant(MALE_RIDER_MODEL, "riding-preview-male.png", Vector3(4.6, 3.0, 6.2))
    var side_ok := await _capture_variant(FEMALE_RIDER_MODEL, "riding-preview-side.png", Vector3(7.5, 2.4, 0.4))
    if not female_ok or not male_ok or not side_ok:
        push_error("One or more rider-on-horse preview images could not be rendered.")
        quit(1)
        return
    print("Rider-on-horse preview images saved to res://artifacts.")
    quit(0)


func _capture_variant(rider_path: String, filename: String, camera_position: Vector3) -> bool:
    _stage = Node3D.new()
    _stage.name = "RidingPreviewStage"
    get_root().add_child(_stage)

    var ground := MeshInstance3D.new()
    var ground_mesh := PlaneMesh.new()
    ground_mesh.size = Vector2(18.0, 18.0)
    ground.mesh = ground_mesh
    var ground_material := StandardMaterial3D.new()
    ground_material.albedo_color = Color("#667b57")
    ground_material.roughness = 0.95
    ground.material_override = ground_material
    ground.position.y = -0.04
    _stage.add_child(ground)

    var horse := CreatureActor.new()
    horse.name = "PreviewHorse"
    horse.creature_kind = "horse"
    horse.behaviour = "mount"
    horse.model_path = HORSE_MODEL
    horse.model_scale = 0.82
    _stage.add_child(horse)

    var rider := AraCharacterActor.new()
    rider.name = "PreviewRider"
    _stage.add_child(rider)
    if not rider.configure(rider_path):
        push_error("Could not load rider preview model: " + rider_path)
        _stage.queue_free()
        await process_frame
        return false
    rider.reparent(horse, false)
    # The seat transform is shared with the runtime mount presentation code.
    rider.position = Vector3(0.0, 1.35, 0.0)
    rider.rotation = Vector3.ZERO

    _camera = Camera3D.new()
    _camera.name = "PreviewCamera"
    _camera.fov = 43.0
    _camera.position = camera_position
    _stage.add_child(_camera)
    _camera.look_at(Vector3(0.0, 1.2, 0.0), Vector3.UP)
    _camera.current = true

    await process_frame
    await process_frame
    await create_timer(0.35).timeout
    var image := get_root().get_texture().get_image()
    var output_directory := ProjectSettings.globalize_path("res://artifacts")
    var output_path := output_directory.path_join(filename)
    var error := image.save_png(output_path)
    if error != OK:
        push_error("Could not save riding preview %s: %s" % [filename, error])
        _stage.queue_free()
        await process_frame
        return false

    var skeleton := _find_skeleton(rider)
    if skeleton != null:
        var bone_names: Array[String] = []
        for bone_index in range(skeleton.get_bone_count()):
            bone_names.append(skeleton.get_bone_name(bone_index))
        print("Rider skeleton (%s): %s" % [filename, ", ".join(bone_names)])
    print("Riding preview saved: " + output_path)
    _stage.queue_free()
    await process_frame
    return true


func _find_skeleton(node: Node) -> Skeleton3D:
    if node is Skeleton3D:
        return node as Skeleton3D
    for child in node.get_children():
        var found := _find_skeleton(child)
        if found != null:
            return found
    return null
