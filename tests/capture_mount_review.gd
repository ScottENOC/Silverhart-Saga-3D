extends SceneTree
## Rendered front and rear rider/mount diagnostics.
const MOUNT_PRESENTATION = preload("res://scripts/presentation/mount_presentation.gd")
const CREATURE_ACTOR = preload("res://scripts/presentation/creature_actor.gd")
const ARA_ACTOR = preload("res://scripts/presentation/ara_character_actor.gd")
const HORSE_MODEL := "res://art/creatures/quaternius/Horse.gltf"
const FEMALE_BODY := "res://art/characters/ara_runtime/ara_person_body.glb"
const MALE_BODY := "res://art/characters/ara_runtime/ara_person_male_body.glb"
const FRONT_OUTPUT_PATH := "res://mount-review-front.png"
const REAR_OUTPUT_PATH := "res://mount-review-rear.png"

func _initialize() -> void:
    call_deferred("_capture")

func _capture() -> void:
    root.size = Vector2i(1800, 1000)
    DisplayServer.window_set_size(Vector2i(1800, 1000))
    root.title = "Silverhart Saga — mounted rider front/rear review"
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

    # Front and rear views show whether the rider is centred over the spine
    # and whether both legs hang evenly around the horse.
    var camera := Camera3D.new()
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = 11.5
    camera.position = Vector3(0.0, 3.0, -10.0)
    world.add_child(camera)
    camera.look_at(Vector3(0.0, 1.9, 0.0), Vector3.UP)
    camera.current = true

    # Compare the existing 1.05 m attachment with a 0.85 m bareback position.
    # Both sexes use the production motorcycle astride animation.
    var ok_female_current := _add_pair(world, -4.8, FEMALE_BODY, "FEMALE CURRENT 1.05", 0.45, 1.05, "Ride motorcycle")
    var ok_male_current := _add_pair(world, -1.6, MALE_BODY, "MALE CURRENT 1.05", 0.45, 1.05, "Ride motorcycle")
    var ok_female_lower := _add_pair(world, 1.6, FEMALE_BODY, "FEMALE LOWER 0.85", 0.45, 0.85, "Ride motorcycle")
    var ok_male_lower := _add_pair(world, 4.8, MALE_BODY, "MALE LOWER 0.85", 0.45, 0.85, "Ride motorcycle")
    if not ok_female_current or not ok_male_current or not ok_female_lower or not ok_male_lower:
        push_error("Failed to load one or more Ara/horse models")
        quit(1)
        return
    for _i in range(12):
        await process_frame
    var riding_clips_ok := _play_riding_clip_for_all_riders(world)
    if not riding_clips_ok:
        push_error("Riding animation is missing from one or more Ara rigs")
        quit(1)
        return
    await create_timer(1.0).timeout
    _report_runtime_model_bounds(world)
    if not await _save_view(camera, Vector3(0.0, 3.0, -10.0), Vector3(0.0, 1.9, 0.0), 0.0, FRONT_OUTPUT_PATH):
        quit(1)
        return
    if not await _save_view(camera, Vector3(0.0, 3.0, 10.0), Vector3(0.0, 1.9, 0.0), 180.0, REAR_OUTPUT_PATH):
        quit(1)
        return
    quit(0)

func _save_view(camera: Camera3D, camera_position: Vector3, target: Vector3, label_y_rotation: float, output_path: String) -> bool:
    camera.position = camera_position
    camera.look_at(target, Vector3.UP)
    for label_node in root.get_tree().get_nodes_in_group("mount_review_labels"):
        var label := label_node as Label3D
        if label != null:
            label.rotation_degrees.y = label_y_rotation
    await process_frame
    await process_frame
    var img := root.get_texture().get_image()
    if img == null or img.is_empty():
        push_error("No rendered image for %s" % output_path)
        return false
    var err := img.save_png(ProjectSettings.globalize_path(output_path))
    if err != OK:
        push_error("PNG save failed for %s: %s" % [output_path, error_string(err)])
        return false
    print("MOUNT_REVIEW_IMAGE=" + ProjectSettings.globalize_path(output_path))
    return true

func _add_pair(world: Node3D, x: float, body_path: String, title: String, horse_scale: float, rider_seat_y: float, clip: String) -> bool:
    var horse := CREATURE_ACTOR.new() as CreatureActor
    horse.name = title.replace(" ", "") + "Horse"
    horse.add_to_group("mount_size_review_horses")
    horse.creature_kind = "horse"
    horse.behaviour = "mount"
    horse.model_scale = horse_scale
    horse.model_path = HORSE_MODEL
    horse.position = Vector3(x, 0, 0)
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
    label.position = Vector3(x, 4.15, 0.0)
    label.rotation_degrees.y = 90
    label.add_to_group("mount_review_labels")
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
