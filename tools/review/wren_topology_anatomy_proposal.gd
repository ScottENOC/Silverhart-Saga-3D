extends SceneTree
## Topology-aware, review-only proposal generator for Wren's first garment regions.
## Re-run trigger: extend finger channels along their mesh paths and tighten nipple islands.
##
## Spatial seed volumes are hypotheses only. Candidate weights are propagated over
## the source triangle-edge graph, not through Euclidean space. This avoids selecting
## a nearby but disconnected skin surface (for example, front-to-back torso leakage).
## It does not create production masks or modify the anatomy manifest.

const MODEL_PATH := "res://build/wren-native/Wren.glb"
const OUTPUT_PATH := "res://build/wren-anatomy-topology-proposal"
const MASK_SCRIPT := preload("res://scripts/characters/character_surface_region_mask.gd")
const SIZE := Vector2i(1200, 1000)
const MAX_GRAPH_HOPS := 5
const HOP_FALLOFF := 0.68
const PAIRED_REGION_MIDLINE_GAP := 0.008
const REGIONS := {
    "breast_left": [Vector3(-0.115, 1.190, 0.145), Vector3(0.070, 0.105, 0.065), Color("#ef476f")],
    "breast_right": [Vector3(0.115, 1.190, 0.145), Vector3(0.070, 0.105, 0.065), Color("#f78c6b")],
    "nipple_left": [Vector3(-0.115, 1.190, 0.198), Vector3(0.008, 0.008, 0.005), Color("#ff4d6d")],
    "nipple_right": [Vector3(0.115, 1.190, 0.198), Vector3(0.008, 0.008, 0.005), Color("#c9184a")],
    "chest_front_left": [Vector3(-0.090, 1.255, 0.145), Vector3(0.070, 0.060, 0.055), Color("#ffd166")],
    "chest_front_right": [Vector3(0.090, 1.255, 0.145), Vector3(0.070, 0.060, 0.055), Color("#06d6a0")],
    "pectoral_left": [Vector3(-0.125, 1.290, 0.055), Vector3(0.065, 0.055, 0.065), Color("#118ab2")],
    "pectoral_right": [Vector3(0.125, 1.290, 0.055), Vector3(0.065, 0.055, 0.065), Color("#9b5de5")],
    "sternum": [Vector3(0.0, 1.285, 0.155), Vector3(0.065, 0.175, 0.070), Color("#f4a261")],
    "underbust": [Vector3(0.0, 1.085, 0.115), Vector3(0.220, 0.030, 0.060), Color("#e9c46a")],
    "ribcage_left": [Vector3(-0.145, 1.105, 0.045), Vector3(0.100, 0.120, 0.090), Color("#2a9d8f")],
    "ribcage_right": [Vector3(0.145, 1.105, 0.045), Vector3(0.100, 0.120, 0.090), Color("#457b9d")],
    "clavicle_left": [Vector3(-0.105, 1.405, 0.025), Vector3(0.090, 0.035, 0.060), Color("#a8dadc")],
    "clavicle_right": [Vector3(0.105, 1.405, 0.025), Vector3(0.090, 0.035, 0.060), Color("#ffafcc")],
    "shoulder_left": [Vector3(-0.205, 1.365, 0.015), Vector3(0.070, 0.075, 0.075), Color("#f4a261")],
    "shoulder_right": [Vector3(0.205, 1.365, 0.015), Vector3(0.070, 0.075, 0.075), Color("#e76f51")],
    "upper_arm_left": [Vector3(-0.275, 1.225, 0.000), Vector3(0.060, 0.145, 0.060), Color("#2a9d8f")],
    "upper_arm_right": [Vector3(0.275, 1.225, 0.000), Vector3(0.060, 0.145, 0.060), Color("#457b9d")],
    "bicep_left": [Vector3(-0.285, 1.245, 0.045), Vector3(0.043, 0.095, 0.043), Color("#e9c46a")],
    "bicep_right": [Vector3(0.285, 1.245, 0.045), Vector3(0.043, 0.095, 0.043), Color("#f4a261")],
    "tricep_left": [Vector3(-0.285, 1.245, -0.045), Vector3(0.043, 0.095, 0.043), Color("#90be6d")],
    "tricep_right": [Vector3(0.285, 1.245, -0.045), Vector3(0.043, 0.095, 0.043), Color("#43aa8b")],
    "elbow_left": [Vector3(-0.325, 1.075, 0.000), Vector3(0.050, 0.055, 0.055), Color("#577590")],
    "elbow_right": [Vector3(0.325, 1.075, 0.000), Vector3(0.050, 0.055, 0.055), Color("#277da1")],
    "forearm_left": [Vector3(-0.405, 1.075, 0.090), Vector3(0.035, 0.085, 0.065), Color("#f94144")],
    "forearm_right": [Vector3(0.405, 1.075, 0.090), Vector3(0.035, 0.085, 0.065), Color("#f3722c")],
    "wrist_left": [Vector3(-0.460, 1.005, 0.190), Vector3(0.025, 0.025, 0.040), Color("#f8961e")],
    "wrist_right": [Vector3(0.460, 1.005, 0.190), Vector3(0.025, 0.025, 0.040), Color("#f9c74f")],
    "palm_left": [Vector3(-0.490, 0.960, 0.245), Vector3(0.025, 0.035, 0.045), Color("#90be6d")],
    "palm_right": [Vector3(0.490, 0.960, 0.245), Vector3(0.025, 0.035, 0.045), Color("#43aa8b")],
    "hand_back_left": [Vector3(-0.470, 0.960, 0.245), Vector3(0.012, 0.035, 0.035), Color("#4d908e")],
    "hand_back_right": [Vector3(0.470, 0.960, 0.245), Vector3(0.012, 0.035, 0.035), Color("#577590")],
    "thumb_left": [Vector3(-0.485, 0.985, 0.175), Vector3(0.035, 0.020, 0.014), Color("#f94144")],
    "thumb_right": [Vector3(0.485, 0.985, 0.175), Vector3(0.035, 0.020, 0.014), Color("#f3722c")],
    "index_finger_left": [Vector3(-0.535, 0.930, 0.215), Vector3(0.085, 0.016, 0.008), Color("#f8961e")],
    "index_finger_right": [Vector3(0.535, 0.930, 0.215), Vector3(0.085, 0.016, 0.008), Color("#f9c74f")],
    "middle_finger_left": [Vector3(-0.540, 0.930, 0.240), Vector3(0.090, 0.016, 0.008), Color("#90be6d")],
    "middle_finger_right": [Vector3(0.540, 0.930, 0.240), Vector3(0.090, 0.016, 0.008), Color("#43aa8b")],
    "ring_finger_left": [Vector3(-0.535, 0.930, 0.265), Vector3(0.085, 0.016, 0.008), Color("#4d908e")],
    "ring_finger_right": [Vector3(0.535, 0.930, 0.265), Vector3(0.085, 0.016, 0.008), Color("#577590")],
    "little_finger_left": [Vector3(-0.525, 0.930, 0.290), Vector3(0.075, 0.016, 0.008), Color("#277da1")],
    "little_finger_right": [Vector3(0.525, 0.930, 0.290), Vector3(0.075, 0.016, 0.008), Color("#7209b7")],
    "head": [Vector3(0.0, 1.585, 0.085), Vector3(0.095, 0.105, 0.090), Color("#f94144")],
    "face_front": [Vector3(0.0, 1.565, 0.145), Vector3(0.070, 0.070, 0.040), Color("#f3722c")],
    "ear_left": [Vector3(-0.090, 1.575, 0.075), Vector3(0.020, 0.035, 0.035), Color("#f8961e")],
    "ear_right": [Vector3(0.090, 1.575, 0.075), Vector3(0.020, 0.035, 0.035), Color("#f9c74f")],
    "neck_front": [Vector3(0.0, 1.445, 0.065), Vector3(0.045, 0.060, 0.035), Color("#90be6d")],
    "neck_back": [Vector3(0.0, 1.445, -0.045), Vector3(0.050, 0.065, 0.035), Color("#43aa8b")],
    "abdomen_front": [Vector3(0.0, 0.985, 0.105), Vector3(0.105, 0.090, 0.040), Color("#4d908e")],
    "flank_left": [Vector3(-0.125, 1.005, 0.005), Vector3(0.055, 0.125, 0.085), Color("#577590")],
    "flank_right": [Vector3(0.125, 1.005, 0.005), Vector3(0.055, 0.125, 0.085), Color("#277da1")],
    "upper_back_left": [Vector3(-0.090, 1.285, -0.065), Vector3(0.085, 0.115, 0.040), Color("#7209b7")],
    "upper_back_right": [Vector3(0.090, 1.285, -0.065), Vector3(0.085, 0.115, 0.040), Color("#b5179e")],
    "lower_back_left": [Vector3(-0.075, 1.035, -0.070), Vector3(0.080, 0.105, 0.040), Color("#f72585")],
    "lower_back_right": [Vector3(0.075, 1.035, -0.070), Vector3(0.080, 0.105, 0.040), Color("#4361ee")],
    "hip_left": [Vector3(-0.155, 0.865, 0.005), Vector3(0.070, 0.105, 0.095), Color("#4895ef")],
    "hip_right": [Vector3(0.155, 0.865, 0.005), Vector3(0.070, 0.105, 0.095), Color("#4cc9f0")],
    "glute_left": [Vector3(-0.095, 0.865, -0.075), Vector3(0.090, 0.085, 0.045), Color("#80ed99")],
    "glute_right": [Vector3(0.095, 0.865, -0.075), Vector3(0.090, 0.085, 0.045), Color("#b8f2e6")],
    "pubic_region": [Vector3(0.0, 0.815, 0.090), Vector3(0.075, 0.050, 0.035), Color("#ffd6a5")],
    "vulva_external": [Vector3(0.0, 0.835, 0.105), Vector3(0.070, 0.105, 0.065), Color("#f15bb5")],
    "pelvic_mons_pubis": [Vector3(0.0, 0.850, 0.120), Vector3(0.045, 0.025, 0.025), Color("#f4a261")],
    "pelvic_labia_majora_left": [Vector3(-0.030, 0.795, 0.105), Vector3(0.020, 0.030, 0.018), Color("#e76f51")],
    "pelvic_labia_majora_right": [Vector3(0.030, 0.795, 0.105), Vector3(0.020, 0.030, 0.018), Color("#2a9d8f")],
    "pelvic_clitoral_contact_proxy": [Vector3(0.0, 0.824, 0.108), Vector3(0.012, 0.012, 0.012), Color("#e63946")],
    "pelvic_perineal_surface": [Vector3(0.0, 0.765, 0.080), Vector3(0.040, 0.020, 0.030), Color("#9b5de5")],
    "pelvic_inguinal_fold_left": [Vector3(-0.105, 0.805, 0.115), Vector3(0.025, 0.045, 0.025), Color("#457b9d")],
    "pelvic_inguinal_fold_right": [Vector3(0.105, 0.805, 0.115), Vector3(0.025, 0.045, 0.025), Color("#06d6a0")],
    "inner_thigh_left": [Vector3(-0.075, 0.690, 0.025), Vector3(0.050, 0.145, 0.060), Color("#fdffb6")],
    "inner_thigh_right": [Vector3(0.075, 0.690, 0.025), Vector3(0.050, 0.145, 0.060), Color("#caffbf")],
    "thigh_left": [Vector3(-0.115, 0.690, 0.000), Vector3(0.075, 0.165, 0.080), Color("#9bf6ff")],
    "thigh_right": [Vector3(0.115, 0.690, 0.000), Vector3(0.075, 0.165, 0.080), Color("#a0c4ff")],
    "knee_left": [Vector3(-0.115, 0.445, 0.015), Vector3(0.055, 0.065, 0.065), Color("#bdb2ff")],
    "knee_right": [Vector3(0.115, 0.445, 0.015), Vector3(0.055, 0.065, 0.065), Color("#ffc6ff")],
    "calf_left": [Vector3(-0.115, 0.270, -0.005), Vector3(0.055, 0.125, 0.065), Color("#fffffc")],
    "calf_right": [Vector3(0.115, 0.270, -0.005), Vector3(0.055, 0.125, 0.065), Color("#e7c6ff")],
    "ankle_left": [Vector3(-0.115, 0.095, 0.005), Vector3(0.040, 0.055, 0.050), Color("#c8b6ff")],
    "ankle_right": [Vector3(0.115, 0.095, 0.005), Vector3(0.040, 0.055, 0.050), Color("#b8c0ff")],
    "foot_left": [Vector3(-0.115, 0.045, 0.105), Vector3(0.060, 0.040, 0.105), Color("#bbd0ff")],
    "foot_right": [Vector3(0.115, 0.045, 0.105), Vector3(0.060, 0.040, 0.105), Color("#caffbf")],
    "toes_left": [Vector3(-0.115, 0.035, 0.185), Vector3(0.055, 0.025, 0.045), Color("#ffd6a5")],
    "toes_right": [Vector3(0.115, 0.035, 0.185), Vector3(0.055, 0.025, 0.045), Color("#ffadad")]
}

var stage: Node3D
var camera: Camera3D
var mask_import_validation: Dictionary = {}


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    root.size = SIZE
    stage = Node3D.new()
    root.add_child(stage)
    _build_lighting()
    camera = Camera3D.new()
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.current = true
    stage.add_child(camera)

    var packed := load(MODEL_PATH) as PackedScene
    if packed == null:
        push_error("Missing native Wren build")
        quit(1)
        return
    var body := packed.instantiate() as Node3D
    stage.add_child(body)
    await process_frame

    var skin_surfaces: Array[Dictionary] = []
    var surface_inventory: Array[Dictionary] = []
    _collect_skin_surfaces(body, skin_surfaces, surface_inventory)
    print("GODOT_IMPORTED_SURFACE_INVENTORY=", JSON.stringify(surface_inventory))
    if skin_surfaces.is_empty():
        push_error("Skin_Anatomy surface not found")
        quit(1)
        return
    # Keep the first surface as the geometric-proposal reference. The authored
    # Ara mask is validated across every Skin_Anatomy surface below.
    var mesh_instance: MeshInstance3D = skin_surfaces[0]["mesh_instance"]
    var surface_index: int = skin_surfaces[0]["surface_index"]
    var arrays: Array = skin_surfaces[0]["arrays"]
    var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
    var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
    var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
    var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
    if vertices.is_empty() or indices.is_empty():
        push_error("Source surface has no indexed geometry")
        quit(1)
        return

    var adjacency := _build_adjacency(vertices.size(), indices)
    var candidate_weights: Dictionary = {}
    var counts: Dictionary = {}
    var seeds: Dictionary = {}
    for region_id in REGIONS:
        if region_id == "vulva_external":
            if uv2.size() != vertices.size():
                push_error(
                    "Ara vulva/mons mask TEXCOORD_1.y missing or mismatched: "
                    + str(uv2.size()) + " UV2 values for " + str(vertices.size()) + " vertices"
                )
                quit(1)
                return
            var mask_report_file := FileAccess.open("res://build/wren-native/vulva-mons-mask-report.json", FileAccess.READ)
            if mask_report_file == null:
                push_error("Painter mask report missing; cannot validate imported TEXCOORD_1")
                quit(1)
                return
            var mask_report: Dictionary = JSON.parse_string(mask_report_file.get_as_text())
            mask_report_file.close()
            var expected_ids := int(mask_report.get("source_correspondence_vertex_count", 0))
            var expected_weighted := int(mask_report.get("weighted_vertices_at_0_15", -1))
            if expected_ids <= 0 or expected_weighted < 0:
                push_error("Painter mask report has invalid correspondence or weight counts")
                quit(1)
                return
            var id_weights: Dictionary = {}
            var ara_weights := PackedFloat32Array()
            var nonzero_count := 0
            var weighted_count := 0
            var min_id := expected_ids
            var max_id := -1
            var min_weight := INF
            var max_weight := -INF
            var imported_vertex_count := 0
            var imported_surface_count := 0
            for skin_surface in skin_surfaces:
                var surface_uv2: PackedVector2Array = skin_surface["arrays"][Mesh.ARRAY_TEX_UV2]
                var surface_vertices: PackedVector3Array = skin_surface["arrays"][Mesh.ARRAY_VERTEX]
                if surface_uv2.size() != surface_vertices.size():
                    push_error(
                        "Ara mask TEXCOORD_1 missing/mismatched on Skin_Anatomy surface "
                        + str(skin_surface["surface_index"])
                    )
                    quit(1)
                    return
                imported_surface_count += 1
                imported_vertex_count += surface_vertices.size()
                for uv in surface_uv2:
                    # TEXCOORD_1.x encodes (source vertex ID + 0.5) / source count.
                    var decoded_id := int(round(uv.x * expected_ids - 0.5))
                    if decoded_id < 0 or decoded_id >= expected_ids:
                        push_error("Godot UV2.x is not the Ara CorrespondenceID channel")
                        quit(1)
                        return
                    var weight := clampf(uv.y, 0.0, 1.0)
                    if id_weights.has(decoded_id) and absf(float(id_weights[decoded_id]) - weight) > 0.00001:
                        push_error("Godot import has inconsistent mask values for a split correspondence vertex")
                        quit(1)
                        return
                    id_weights[decoded_id] = weight
                    min_id = mini(min_id, decoded_id)
                    max_id = maxi(max_id, decoded_id)
                    min_weight = minf(min_weight, weight)
                    max_weight = maxf(max_weight, weight)
                    if weight > 0.0:
                        nonzero_count += 1
                    if weight >= 0.15:
                        weighted_count += 1
            # Keep first-surface weights for the existing geometric overlay path;
            # the dedicated mask overlay below draws all imported skin surfaces.
            for uv in uv2:
                ara_weights.append(clampf(uv.y, 0.0, 1.0))
            var unique_weighted := 0
            for weight in id_weights.values():
                if float(weight) >= 0.15:
                    unique_weighted += 1
            if id_weights.size() != expected_ids:
                push_error("Godot imported %d correspondence IDs; expected %d" % [id_weights.size(), expected_ids])
                quit(1)
                return
            if unique_weighted != expected_weighted:
                push_error("Godot imported %d weighted IDs; painter reported %d" % [unique_weighted, expected_weighted])
                quit(1)
                return
            seeds[region_id] = nonzero_count
            counts[region_id] = unique_weighted
            candidate_weights[region_id] = ara_weights
            mask_import_validation = {
                "status": "PASS",
                "imported_skin_surface_count": imported_surface_count,
                "imported_skin_vertex_count_including_splits": imported_vertex_count,
                "unique_correspondence_ids": id_weights.size(),
                "weighted_unique_ids_at_0_15": unique_weighted,
                "expected_weighted_unique_ids_at_0_15": expected_weighted,
                "min_decoded_id": min_id,
                "max_decoded_id": max_id,
                "min_uv2_y": min_weight,
                "max_uv2_y": max_weight
            }
            continue
        var definition: Array = REGIONS[region_id]
        var seed_vertices := _find_seed_vertices(vertices, normals, definition[0], definition[1], region_id)
        seed_vertices = _filter_region_side(vertices, seed_vertices, region_id)
        seeds[region_id] = seed_vertices.size()
        var weights := _propagate_over_surface(adjacency, vertices, normals, seed_vertices, region_id)
        candidate_weights[region_id] = weights
        var count := 0
        for weight in weights:
            if weight >= 0.15:
                count += 1
        counts[region_id] = count

    var overlay := _build_overlay(mesh_instance, vertices, candidate_weights)
    stage.add_child(overlay)
    var vulva_mask_overlay := _build_vulva_mask_overlay(skin_surfaces)
    stage.add_child(vulva_mask_overlay)
    await process_frame

    var output_directory := ProjectSettings.globalize_path(OUTPUT_PATH)
    DirAccess.make_dir_recursive_absolute(output_directory)
    var views := {
        "front": [Vector3(0.0, 1.23, 4.2), Vector3(0.0, 1.23, 0.0), 0.78],
        "side": [Vector3(4.2, 1.23, 0.0), Vector3(0.0, 1.23, 0.0), 0.78],
        "rear": [Vector3(0.0, 1.23, -4.2), Vector3(0.0, 1.23, 0.0), 0.78],
        "arms_front": [Vector3(0.0, 1.08, 4.2), Vector3(0.0, 1.08, 0.0), 1.30],
        "arms_side": [Vector3(4.2, 1.08, 0.0), Vector3(0.0, 1.08, 0.0), 1.30]
    }
    for view_name in views:
        var view: Array = views[view_name]
        camera.position = view[0]
        camera.look_at(view[1], Vector3.UP)
        camera.size = view[2]
        await process_frame
        await process_frame
        await RenderingServer.frame_post_draw
        var image := root.get_texture().get_image()
        if image.save_png(output_directory.path_join(view_name + "-topology-candidate.png")) != OK:
            push_error("Failed to save " + view_name + " proposal render")
            quit(1)
            return

    stage.remove_child(overlay)
    overlay.queue_free()
    stage.remove_child(vulva_mask_overlay)
    vulva_mask_overlay.queue_free()
    await process_frame

    # Export each overlapping channel separately as well as the combined context
    # views above. This makes boundaries reviewable without colour blending.
    var isolated_root := output_directory.path_join("regions")
    DirAccess.make_dir_recursive_absolute(isolated_root)
    for region_id in REGIONS:
        var region_directory := isolated_root.path_join(region_id)
        DirAccess.make_dir_recursive_absolute(region_directory)
        var region_overlay := _build_vulva_mask_overlay(skin_surfaces) if region_id == "vulva_external" else _build_overlay(mesh_instance, vertices, candidate_weights, region_id)
        stage.add_child(region_overlay)
        var region_views: Dictionary = views.duplicate()
        if region_id.begins_with("thumb_") or region_id.ends_with("_finger_left") or region_id.ends_with("_finger_right") or region_id.begins_with("palm_") or region_id.begins_with("hand_back_"):
            var hand_x := -0.490 if region_id.ends_with("_left") else 0.490
            region_views["hand_detail_front"] = [Vector3(0.0, 0.955, 2.0), Vector3(hand_x, 0.955, 0.0), 0.30]
            region_views["hand_detail_side"] = [Vector3(hand_x + (1.8 if hand_x > 0.0 else -1.8), 0.955, 0.25), Vector3(hand_x, 0.955, 0.25), 0.30]
        if region_id == "head" or region_id == "face_front" or region_id.begins_with("ear_") or region_id.begins_with("neck_"):
            region_views["head_detail_front"] = [Vector3(0.0, 1.585, 1.15), Vector3(0.0, 1.585, 0.0), 0.27]
            region_views["head_detail_side"] = [Vector3(1.15, 1.585, 0.0), Vector3(0.0, 1.585, 0.0), 0.27]
        if region_id in ["abdomen_front", "flank_left", "flank_right", "upper_back_left", "upper_back_right", "lower_back_left", "lower_back_right", "sternum", "underbust", "ribcage_left", "ribcage_right", "chest_front_left", "chest_front_right", "pectoral_left", "pectoral_right", "breast_left", "breast_right"]:
            region_views["torso_detail_front"] = [Vector3(0.0, 1.105, 1.35), Vector3(0.0, 1.105, 0.0), 0.52]
            region_views["torso_detail_rear"] = [Vector3(0.0, 1.105, -1.35), Vector3(0.0, 1.105, 0.0), 0.52]
        if region_id in ["hip_left", "hip_right", "glute_left", "glute_right", "pubic_region", "inner_thigh_left", "inner_thigh_right"]:
            region_views["pelvis_detail_front"] = [Vector3(0.0, 0.835, 1.15), Vector3(0.0, 0.835, 0.0), 0.38]
            region_views["pelvis_detail_rear"] = [Vector3(0.0, 0.835, -1.15), Vector3(0.0, 0.835, 0.0), 0.38]
        if region_id == "vulva_external":
            region_views["vulva_detail_front"] = [Vector3(0.0, 0.835, 1.05), Vector3(0.0, 0.835, 0.0), 0.24]
            region_views["vulva_detail_oblique"] = [Vector3(0.90, 0.835, 0.90), Vector3(0.0, 0.820, 0.0), 0.24]
            region_views["vulva_detail_side"] = [Vector3(1.05, 0.835, 0.0), Vector3(0.0, 0.835, 0.0), 0.24]
        if region_id.begins_with("thigh_") or region_id.begins_with("knee_") or region_id.begins_with("calf_") or region_id.begins_with("ankle_"):
            region_views["leg_detail_front"] = [Vector3(0.0, 0.45, 1.6), Vector3(0.0, 0.45, 0.0), 0.72]
            region_views["leg_detail_side"] = [Vector3(1.6, 0.45, 0.0), Vector3(0.0, 0.45, 0.0), 0.72]
        if region_id.begins_with("foot_") or region_id.begins_with("toes_"):
            region_views["foot_detail_front"] = [Vector3(0.0, 0.28, 1.2), Vector3(0.0, 0.045, 0.10), 0.34]
            region_views["foot_detail_side"] = [Vector3(1.2, 0.28, 0.10), Vector3(0.0, 0.045, 0.10), 0.34]
        if region_id.begins_with("nipple_"):
            var nipple_x := -0.115 if region_id == "nipple_left" else 0.115
            region_views["nipple_detail_front"] = [Vector3(nipple_x, 1.190, 1.8), Vector3(nipple_x, 1.190, 0.0), 0.24]
            var side_sign := -1.0 if region_id == "nipple_left" else 1.0
            region_views["nipple_detail_side"] = [Vector3(nipple_x + side_sign * 1.25, 1.190, 1.25), Vector3(nipple_x, 1.190, 0.145), 0.24]
        for view_name in region_views:
            var view: Array = region_views[view_name]
            camera.position = view[0]
            camera.look_at(view[1], Vector3.UP)
            camera.size = view[2]
            await process_frame
            await process_frame
            await RenderingServer.frame_post_draw
            var region_image := root.get_texture().get_image()
            if region_image.save_png(region_directory.path_join(view_name + ".png")) != OK:
                push_error("Failed to save isolated " + region_id + " " + view_name + " render")
                quit(1)
                return
        stage.remove_child(region_overlay)
        region_overlay.queue_free()
        await process_frame

    var report := {
        "status": "DRAFT_TOPOLOGY_PROPOSAL_NOT_APPROVED",
        "character": "Wren",
        "model": MODEL_PATH,
        "surface_name": mesh_instance.mesh.surface_get_name(surface_index),
        "surface_index": surface_index,
        "skin_surface_count": skin_surfaces.size(),
        "vertex_count": vertices.size(),
        "triangle_count": indices.size() / 3,
        "surface_signature": MASK_SCRIPT.build_surface_signature(mesh_instance.mesh, surface_index),
        "max_graph_hops": MAX_GRAPH_HOPS,
        "region_specific_graph_hops": {"nipple_left": 0, "nipple_right": 0, "individual_fingers": 18},
        "hop_falloff": HOP_FALLOFF,
        "paired_region_midline_exclusion_m": PAIRED_REGION_MIDLINE_GAP,
        "candidate_weight_threshold": 0.15,
        "region_seed_vertex_counts": seeds,
        "animation_contact_anchor_review": {
            "coordinate_space": "Wren Skin_Anatomy local mesh space",
            "anchors": _build_contact_anchor_report(vertices, normals),
            "production_requirements": [
                "Replace nearest-vertex review anchors with barycentric triangle anchors bound to the validated surface signature.",
                "Store contact frames in participant-local rig space and solve hand placement with IK.",
                "Retarget interaction paths against actual arm length, shoulder width, torso depth, hip width and participant height.",
                "Use collision and contact constraints to prevent hand-through-body intersections."
            ],
            "warning": "The current contact proxy is not a validated anatomical landmark and must not drive a shipped intimate animation."
        },
        "anatomical_detail_assessment": {
            "surface_proxy_channels": ["vulva_external"],
            "combined_region_includes": ["external_vulva", "mons_pubis"],
            "source": "Ara add_female_anatomy_surface.py surface-following midline coordinates",
            "mask_storage": "TEXCOORD_1.y / Godot ARRAY_TEX_UV2.y; CorrespondenceID remains in TEXCOORD_1.x",
            "subregions_deferred": ["clitoral_hood", "clitoral_glans", "labia_majora_left", "labia_majora_right", "labia_minora_left", "labia_minora_right", "urethral_meatus", "vaginal_introitus", "mons_pubis"],
            "note": "Ara already sculpts these external structures into the continuous skin surface. The first semantic mask intentionally groups the external vulva and mons pubis as one region; later subregions can be authored from the same surface-coordinate frame without changing the mask resource model."
        },
        "candidate_vertex_counts_at_weight_0_15": counts,
        "ara_mask_import_validation": mask_import_validation,
        "candidate_to_seed_vertex_ratios": _build_candidate_seed_ratios(seeds, counts),
        "method": "Review-only Ara-authored vulva_external weights are read directly from TEXCOORD_1.y and include the mons pubis; remaining geometric hypotheses expand through adjacent source-mesh vertices with decaying weights.",
        "limitations": [
            "Seed centres and radii remain geometric hypotheses, not anatomically authored boundaries.",
            "Graph propagation is constrained to a modest expanded seed volume to reduce spread into adjacent anatomical areas; the seed remains a hypothesis, not an authored boundary.",
            "Nipple channels are seed-only (zero graph hops); all other hop limits are review heuristics and local mesh density affects physical reach.",
            "The combined vulva_external mask is authored from Ara surface-following coordinates and includes the mons pubis; finer subregions are intentionally deferred until the basic body-region workflow is reviewed.",
            "Finger candidates use longer local-X seed corridors and up to 18 topology hops, constrained to a narrow per-digit depth corridor; the close-up renders must confirm continuous lengthwise coverage and separation.",
            "Nipple candidates now use seed-only surface vertices (zero topology expansion) to avoid propagating onto the adjacent areolar/side-surface arc; the isolated renders must confirm the smaller island remains centred.",
            "Candidate weights are preview-only; no Resource or production manifest is written.",
            "This review includes provisional whole-body coverage: head/face/ears/neck, chest/abdomen/flanks/back, pelvis/glutes/pubic region, both legs and feet, and shoulder-to-individual-finger arm channels. The vulva_external region is the exception: its weights are derived from the Ara anatomy surface-coordinate method, with the mons pubis included."
        ]
    }
    var report_file := FileAccess.open(output_directory.path_join("proposal.json"), FileAccess.WRITE)
    report_file.store_string(JSON.stringify(report, "\t"))
    report_file.close()
    print("WREN_TOPOLOGY_PROPOSAL_OK vertices=%d regions=%d" % [vertices.size(), REGIONS.size()])
    quit(0)


func _build_contact_anchor_report(
    vertices: PackedVector3Array,
    normals: PackedVector3Array
) -> Dictionary:
    var requested_targets := {
        "pelvic_clitoral_contact_proxy": Vector3(0.0, 0.824, 0.108)
    }
    var result: Dictionary = {}
    for target_id in requested_targets:
        var requested: Vector3 = requested_targets[target_id]
        var nearest_index := -1
        var nearest_distance_squared := INF
        for vertex_index in vertices.size():
            var distance_squared := vertices[vertex_index].distance_squared_to(requested)
            if distance_squared < nearest_distance_squared:
                nearest_distance_squared = distance_squared
                nearest_index = vertex_index
        if nearest_index < 0:
            result[target_id] = {"status": "UNAVAILABLE"}
            continue
        var normal := normals[nearest_index] if nearest_index < normals.size() else Vector3.ZERO
        result[target_id] = {
            "status": "PROVISIONAL_SURFACE_PROXY_NOT_ANATOMICAL_LANDMARK",
            "anchor_type": "nearest_vertex_review_only",
            "vertex_index": nearest_index,
            "position_local": [vertices[nearest_index].x, vertices[nearest_index].y, vertices[nearest_index].z],
            "normal_local": [normal.x, normal.y, normal.z],
            "distance_from_requested_point_m": sqrt(nearest_distance_squared)
        }
    return result


func _build_candidate_seed_ratios(seed_counts: Dictionary, candidate_counts: Dictionary) -> Dictionary:
    var ratios: Dictionary = {}
    for region_id in REGIONS:
        var seed_count: int = seed_counts.get(region_id, 0)
        var candidate_count: int = candidate_counts.get(region_id, 0)
        ratios[region_id] = snappedf(float(candidate_count) / maxf(float(seed_count), 1.0), 0.01)
    return ratios


func _collect_skin_surfaces(
    node: Node,
    result: Array[Dictionary],
    inventory: Array[Dictionary]
) -> void:
    if node is MeshInstance3D and node.mesh != null:
        var mesh_instance := node as MeshInstance3D
        for index in mesh_instance.mesh.get_surface_count():
            var surface_name: String = mesh_instance.mesh.surface_get_name(index)
            var material := mesh_instance.mesh.surface_get_material(index)
            var material_name := material.resource_name if material != null else ""
            var surface_arrays := mesh_instance.mesh.surface_get_arrays(index)
            var surface_vertices: PackedVector3Array = surface_arrays[Mesh.ARRAY_VERTEX]
            var surface_uv2: PackedVector2Array = surface_arrays[Mesh.ARRAY_TEX_UV2]
            var entry := {
                "node_name": str(mesh_instance.name),
                "mesh_resource_name": mesh_instance.mesh.resource_name,
                "surface_index": index,
                "surface_name": surface_name,
                "material_name": material_name,
                "vertex_count": surface_vertices.size(),
                "texcoord_1_count": surface_uv2.size()
            }
            inventory.append(entry)
            var identity: String = (
                str(mesh_instance.name) + " " +
                mesh_instance.mesh.resource_name + " " +
                surface_name + " " + material_name
            ).to_lower()
            if identity.contains("skin"):
                result.append({
                    "mesh_instance": mesh_instance,
                    "surface_index": index,
                    "arrays": surface_arrays
                })
    for child in node.get_children():
        _collect_skin_surfaces(child, result, inventory)


func _build_vulva_mask_overlay(skin_surfaces: Array[Dictionary]) -> MultiMeshInstance3D:
    var marker := SphereMesh.new()
    marker.radius = 0.0032
    marker.height = 0.0064
    marker.radial_segments = 5
    marker.rings = 3
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.vertex_color_use_as_albedo = true
    marker.material = material
    var transforms: Array[Transform3D] = []
    var colours: Array[Color] = []
    var mask_colour: Color = REGIONS["vulva_external"][2]
    for skin_surface in skin_surfaces:
        var mesh_instance: MeshInstance3D = skin_surface["mesh_instance"]
        var surface_vertices: PackedVector3Array = skin_surface["arrays"][Mesh.ARRAY_VERTEX]
        var surface_uv2: PackedVector2Array = skin_surface["arrays"][Mesh.ARRAY_TEX_UV2]
        for vertex_index in mini(surface_vertices.size(), surface_uv2.size()):
            var weight := clampf(surface_uv2[vertex_index].y, 0.0, 1.0)
            if weight < 0.15:
                continue
            transforms.append(mesh_instance.global_transform * Transform3D(Basis.IDENTITY, surface_vertices[vertex_index]))
            var colour := mask_colour
            colour.a = clampf(weight, 0.35, 1.0)
            colours.append(colour)
    var multi := MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.use_colors = true
    multi.mesh = marker
    multi.instance_count = transforms.size()
    for index in transforms.size():
        multi.set_instance_transform(index, transforms[index])
        multi.set_instance_color(index, colours[index])
    var result := MultiMeshInstance3D.new()
    result.name = "AraVulvaMonsMaskAllSkinSurfaces"
    result.multimesh = multi
    return result


func _find_skin_mesh(node: Node) -> MeshInstance3D:
    if node is MeshInstance3D and node.mesh != null and _find_skin_surface(node.mesh) >= 0:
        return node
    for child in node.get_children():
        var found := _find_skin_mesh(child)
        if found != null:
            return found
    return null


func _find_skin_surface(mesh: Mesh) -> int:
    if mesh == null:
        return -1
    for surface_index in mesh.get_surface_count():
        if mesh.surface_get_name(surface_index) == "Skin_Anatomy":
            return surface_index
    return -1


func _build_adjacency(vertex_count: int, indices: PackedInt32Array) -> Array[PackedInt32Array]:
    var adjacency: Array[PackedInt32Array] = []
    adjacency.resize(vertex_count)
    for vertex_index in vertex_count:
        adjacency[vertex_index] = PackedInt32Array()
    for offset in range(0, indices.size(), 3):
        var a := indices[offset]
        var b := indices[offset + 1]
        var c := indices[offset + 2]
        _add_edge(adjacency, a, b)
        _add_edge(adjacency, b, a)
        _add_edge(adjacency, b, c)
        _add_edge(adjacency, c, b)
        _add_edge(adjacency, c, a)
        _add_edge(adjacency, a, c)
    return adjacency


func _add_edge(adjacency: Array[PackedInt32Array], from_vertex: int, to_vertex: int) -> void:
    if not adjacency[from_vertex].has(to_vertex):
        adjacency[from_vertex].append(to_vertex)


func _requires_front_surface_normal(region_id: String) -> bool:
    return region_id == "pubic_region" or region_id.begins_with("pelvic_")


func _find_seed_vertices(
    vertices: PackedVector3Array,
    normals: PackedVector3Array,
    centre: Vector3,
    radii: Vector3,
    region_id: String
) -> PackedInt32Array:
    var result := PackedInt32Array()
    for vertex_index in vertices.size():
        var normalized := (vertices[vertex_index] - centre) / radii
        if normalized.length() > 1.0:
            continue
        if _requires_front_surface_normal(region_id):
            if vertex_index >= normals.size() or normals[vertex_index].dot(Vector3(0.0, 0.0, 1.0)) < 0.25:
                continue
        result.append(vertex_index)
    return result


func _filter_region_side(
    vertices: PackedVector3Array,
    seed_vertices: PackedInt32Array,
    region_id: String
) -> PackedInt32Array:
    var filtered := PackedInt32Array()
    for vertex_index in seed_vertices:
        if _matches_region_side(region_id, vertices[vertex_index]):
            filtered.append(vertex_index)
    return filtered


func _matches_region_side(region_id: String, vertex: Vector3) -> bool:
    if region_id.ends_with("_left"):
        return vertex.x <= -PAIRED_REGION_MIDLINE_GAP
    if region_id.ends_with("_right"):
        return vertex.x >= PAIRED_REGION_MIDLINE_GAP
    return true


func _within_region_extent(region_id: String, vertex: Vector3) -> bool:
    var definition: Array = REGIONS[region_id]
    var centre: Vector3 = definition[0]
    var radii: Vector3 = definition[1]
    var normalized := (vertex - centre) / (radii * 1.25)
    return normalized.length() <= 1.0


func _max_graph_hops_for_region(region_id: String) -> int:
    if region_id.begins_with("nipple_"):
        return 0
    if region_id.ends_with("_finger_left") or region_id.ends_with("_finger_right"):
        return 18
    return MAX_GRAPH_HOPS


func _propagate_over_surface(
    adjacency: Array[PackedInt32Array],
    vertices: PackedVector3Array,
    normals: PackedVector3Array,
    seed_vertices: PackedInt32Array,
    region_id: String
) -> PackedFloat32Array:
    var weights := PackedFloat32Array()
    weights.resize(adjacency.size())
    if seed_vertices.is_empty():
        return weights

    var hop_distance := PackedInt32Array()
    hop_distance.resize(adjacency.size())
    hop_distance.fill(-1)
    var queue := PackedInt32Array()
    for seed_vertex in seed_vertices:
        hop_distance[seed_vertex] = 0
        weights[seed_vertex] = 1.0
        queue.append(seed_vertex)

    var queue_index := 0
    while queue_index < queue.size():
        var current := queue[queue_index]
        queue_index += 1
        var next_hop := hop_distance[current] + 1
        if next_hop > _max_graph_hops_for_region(region_id):
            continue
        for neighbour in adjacency[current]:
            if not _matches_region_side(region_id, vertices[neighbour]):
                continue
            if not _within_region_extent(region_id, vertices[neighbour]):
                continue
            if _requires_front_surface_normal(region_id):
                if neighbour >= normals.size() or normals[neighbour].dot(Vector3(0.0, 0.0, 1.0)) < 0.25:
                    continue
            if hop_distance[neighbour] >= 0:
                continue
            hop_distance[neighbour] = next_hop
            weights[neighbour] = pow(HOP_FALLOFF, next_hop)
            queue.append(neighbour)
    return weights


func _build_overlay(
    mesh_instance: MeshInstance3D,
    vertices: PackedVector3Array,
    candidate_weights: Dictionary,
    only_region: String = ""
) -> MultiMeshInstance3D:
    var marker := SphereMesh.new()
    marker.radius = 0.0032
    marker.height = 0.0064
    marker.radial_segments = 5
    marker.rings = 3
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.vertex_color_use_as_albedo = true
    material.no_depth_test = false
    marker.material = material

    var transforms: Array[Transform3D] = []
    var colours: Array[Color] = []
    for vertex_index in vertices.size():
        var accumulated := Color(0.0, 0.0, 0.0, 0.0)
        var strongest := 0.0
        for region_id in REGIONS:
            if not only_region.is_empty() and region_id != only_region:
                continue
            if region_id == "vulva_external":
                continue
            var weights: PackedFloat32Array = candidate_weights[region_id]
            if vertex_index >= weights.size():
                continue
            var weight := weights[vertex_index]
            if weight < 0.15:
                continue
            var region_colour: Color = REGIONS[region_id][2]
            accumulated += region_colour * weight
            strongest = maxf(strongest, weight)
        if strongest <= 0.0:
            continue
        var colour := accumulated / maxf(accumulated.r + accumulated.g + accumulated.b, 0.001)
        colour.a = clampf(strongest, 0.35, 1.0)
        transforms.append(mesh_instance.global_transform * Transform3D(Basis.IDENTITY, vertices[vertex_index]))
        colours.append(colour)

    var multi := MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.use_colors = true
    multi.mesh = marker
    multi.instance_count = transforms.size()
    for index in transforms.size():
        multi.set_instance_transform(index, transforms[index])
        multi.set_instance_color(index, colours[index])
    var overlay := MultiMeshInstance3D.new()
    overlay.name = "TopologyAwareCandidateWeights"
    overlay.multimesh = multi
    return overlay


func _build_lighting() -> void:
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color("#252a30")
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color("#c5cbd2")
    environment.ambient_light_energy = 0.7
    var world := WorldEnvironment.new()
    world.environment = environment
    stage.add_child(world)
    var light := DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-25.0, -25.0, 0.0)
    light.light_energy = 1.3
    stage.add_child(light)
