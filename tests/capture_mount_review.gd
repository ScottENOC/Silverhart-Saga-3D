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

    # The previous +Z camera produced a head-on view. This +X camera
    # gives a true side profile so seat height, pelvis contact and leg
    # placement can be judged against the horse's back.
    var camera := Camera3D.new()
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = 14.0
    camera.position = Vector3(18.0, 3.3, 0.0)
    world.add_child(camera)
    camera.look_at(Vector3(0.0, 2.0, 0.0), Vector3.UP)
    camera.current = true

    # Camera looks along +X, so separate comparison subjects along Z (screen horizontal), not X (depth).
    var ok_female_horse := _add_pair(world, -4.8, FEMALE_BODY, "FEMALE HORSE TROT", 0.45, 1.05, "Ride horse (trot)")
    var ok_male_horse := _add_pair(world, -1.6, MALE_BODY, "MALE HORSE TROT", 0.45, 1.05, "Ride horse (trot)")
    var ok_female_motorcycle := _add_pair(world, 1.6, FEMALE_BODY, "FEMALE MOTORCYCLE", 0.45, 1.05, "Ride motorcycle")
    var ok_male_motorcycle := _add_pair(world, 4.8, MALE_BODY, "MALE MOTORCYCLE", 0.45, 1.05, "Ride motorcycle")
    if not ok_female_horse or not ok_male_horse or not ok_female_motorcycle or not ok_male_motorcycle:
        push_error("Failed to load one or more Ara/horse models")
        quit(1)
        return
    for _i in range(12):
        await process_frame
    var riding_clips_ok := _play_riding_clip_for_all_riders(world)
    if not riding_clips_ok:
        push_error("Ride horse (trot) animation is missing from one or more Ara rigs")
        quit(1)
        return
    await create_timer(1.0).timeout
    _report_runtime_model_bounds(world)
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

func _add_pair(world: Node3D, z: float, body_path: String, title: String, horse_scale: float, rider_seat_y: float, clip: String) -> bool:
    var horse := CREATURE_ACTOR.new() as CreatureActor
    horse.name = title.replace(" ", "") + "Horse"
    horse.add_to_group("mount_size_review_horses")
    horse.creature_kind = "horse"
    horse.behaviour = "mount"
    horse.model_scale = horse_scale
    horse.model_path = HORSE_MODEL
    horse.position = Vector3(0, 0, z)
    world.add_child(horse)

    var rider := ARA_ACTOR.new() as AraCharacterActor
    rider.name = title.replace(" ", "") + "Rider"
    rider.add_to_group("mount_size_review_riders")
    world.add_child(rider)
    if not rider.configure(body_path):
        return false
    if not MOUNT_PRESENTATION.attach_rider(rider, horse):
        return false
    rider.position = Vector3(0.0, rider_seat_y, 0.0)
    var label := Label3D.new()
    label.text = title
    label.font_size = 48
    label.outline_size = 10
    label.modulate = Color(1.0, 0.95, 0.78)
    label.position = Vector3(0.0, 4.15, z)
    label.rotation_degrees.y = 90
    world.add_child(label)
    rider.set_meta("review_clip", clip)
    print("[Mount review] %s clip=%s horse_scale=%.3f rider_seat_y=%.3f rider_root=%s model=%s rider_global=%s horse_global=%s" % [
        title, clip, horse_scale, rider_seat_y, rider.transform, rider.model_root.transform, rider.global_position, horse.global_position
    ])
    return true

func _play_riding_clip_for_all_riders(world: Node3D) -> bool:
    var all_ok := true
    for rider_node in world.get_tree().get_nodes_in_group("mount_size_review_riders"):
        var rider := rider_node as AraCharacterActor
        if rider == null or rider.animation_player == null:
            all_ok = false
            continue
        var clip := StringName(rider.get_meta("review_clip", "Ride horse (trot)"))
        if not rider.animation_player.has_animation(clip):
            push_error("Ara rig %s does not contain %s" % [rider.name, clip])
            all_ok = false
            continue
        rider.animation_player.play(clip)
        print("[Mount review] RIDING_ANIMATION rider=%s clip=%s" % [rider.name, clip])
    return all_ok

func _report_runtime_model_bounds(world: Node3D) -> void:
    for horse in world.get_tree().get_nodes_in_group("mount_size_review_horses"):
        if horse is CreatureActor and horse.model_root != null:
            var bounds := _combined_mesh_bounds(horse.model_root)
            print("[Mount size] HORSE runtime_scale=%.3f mesh_bounds_m=(%.3f, %.3f, %.3f) min=%s max=%s" % [
                horse.model_scale, bounds.size.x, bounds.size.y, bounds.size.z, bounds.position, bounds.end
            ])
    for rider in world.get_tree().get_nodes_in_group("mount_size_review_riders"):
        if rider is AraCharacterActor and rider.model_root != null:
            var bounds := _combined_mesh_bounds(rider.model_root)
            print("[Mount size] ARA asset=%s mesh_bounds_m=(%.3f, %.3f, %.3f) min=%s max=%s" % [
                rider.loaded_asset_path, bounds.size.x, bounds.size.y, bounds.size.z, bounds.position, bounds.end
            ])

func _combined_mesh_bounds(model: Node3D) -> AABB:
    var found := false
    var combined := AABB()
    var meshes := model.find_children("*", "MeshInstance3D", true, false)
    for node in meshes:
        var mesh_instance := node as MeshInstance3D
        if mesh_instance == null or mesh_instance.mesh == null:
            continue
        var world_bounds: AABB = mesh_instance.global_transform * mesh_instance.get_aabb()
        if not found:
            combined = world_bounds
            found = true
        else:
            combined = combined.merge(world_bounds)
    return combined
