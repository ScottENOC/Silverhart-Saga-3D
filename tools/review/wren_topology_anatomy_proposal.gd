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
    "little_finger_right": [Vector3(0.525, 0.930, 0.290), Vector3(0.075, 0.016, 0.008), Color("#7209b7")]
}

var stage: Node3D
var camera: Camera3D


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

    var mesh_instance := _find_skin_mesh(body)
    if mesh_instance == null:
        push_error("Skin_Anatomy mesh not found")
        quit(1)
        return
    var surface_index := _find_skin_surface(mesh_instance.mesh)
    if surface_index < 0:
        push_error("Skin_Anatomy surface not found")
        quit(1)
        return

    var arrays := mesh_instance.mesh.surface_get_arrays(surface_index)
    var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
    var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
    if vertices.is_empty() or indices.is_empty():
        push_error("Source surface has no indexed geometry")
        quit(1)
        return

    var adjacency := _build_adjacency(vertices.size(), indices)
    var candidate_weights: Dictionary = {}
    var counts: Dictionary = {}
    var seeds: Dictionary = {}
    for region_id in REGIONS:
        var definition: Array = REGIONS[region_id]
        var seed_vertices := _find_seed_vertices(vertices, definition[0], definition[1])
        seed_vertices = _filter_region_side(vertices, seed_vertices, region_id)
        seeds[region_id] = seed_vertices.size()
        var weights := _propagate_over_surface(adjacency, vertices, seed_vertices, region_id)
        candidate_weights[region_id] = weights
        var count := 0
        for weight in weights:
            if weight >= 0.15:
                count += 1
        counts[region_id] = count

    var overlay := _build_overlay(mesh_instance, vertices, candidate_weights)
    stage.add_child(overlay)
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
    await process_frame

    # Export each overlapping channel separately as well as the combined context
    # views above. This makes boundaries reviewable without colour blending.
    var isolated_root := output_directory.path_join("regions")
    DirAccess.make_dir_recursive_absolute(isolated_root)
    for region_id in REGIONS:
        var region_directory := isolated_root.path_join(region_id)
        DirAccess.make_dir_recursive_absolute(region_directory)
        var region_overlay := _build_overlay(mesh_instance, vertices, candidate_weights, region_id)
        stage.add_child(region_overlay)
        var region_views: Dictionary = views.duplicate()
        if region_id.begins_with("thumb_") or region_id.ends_with("_finger_left") or region_id.ends_with("_finger_right") or region_id.begins_with("palm_") or region_id.begins_with("hand_back_"):
            var hand_x := -0.490 if region_id.ends_with("_left") else 0.490
            region_views["hand_detail_front"] = [Vector3(0.0, 0.955, 2.0), Vector3(hand_x, 0.955, 0.0), 0.30]
            region_views["hand_detail_side"] = [Vector3(hand_x + (1.8 if hand_x > 0.0 else -1.8), 0.955, 0.25), Vector3(hand_x, 0.955, 0.25), 0.30]
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
        "vertex_count": vertices.size(),
        "triangle_count": indices.size() / 3,
        "surface_signature": MASK_SCRIPT.build_surface_signature(mesh_instance.mesh, surface_index),
        "max_graph_hops": MAX_GRAPH_HOPS,
        "region_specific_graph_hops": {"nipple_left": 0, "nipple_right": 0, "individual_fingers": 18},
        "hop_falloff": HOP_FALLOFF,
        "paired_region_midline_exclusion_m": PAIRED_REGION_MIDLINE_GAP,
        "candidate_weight_threshold": 0.15,
        "region_seed_vertex_counts": seeds,
        "candidate_vertex_counts_at_weight_0_15": counts,
        "candidate_to_seed_vertex_ratios": _build_candidate_seed_ratios(seeds, counts),
        "method": "Ellipsoidal seed hypotheses expanded only through adjacent source-mesh vertices with decaying weights; nipple channels use two graph hops and other channels use five.",
        "limitations": [
            "Seed centres and radii remain geometric hypotheses, not anatomically authored boundaries.",
            "Graph propagation is constrained to a modest expanded seed volume to reduce spread into adjacent anatomical areas; the seed remains a hypothesis, not an authored boundary.",
            "The two-hop nipple radius and five-hop radius for other regions are review heuristics; local mesh density affects physical reach and each boundary needs visual review.",
            "Finger candidates use longer local-X seed corridors and up to 18 topology hops, constrained to a narrow per-digit depth corridor; the close-up renders must confirm continuous lengthwise coverage and separation.",
            "Nipple candidates now use seed-only surface vertices (zero topology expansion) to avoid propagating onto the adjacent areolar/side-surface arc; the isolated renders must confirm the smaller island remains centred.",
            "Candidate weights are preview-only; no Resource or production manifest is written.",
            "This review includes the previously reviewed torso channels, refined breast channels, nipple channels and a first shoulder-to-individual-finger arm tranche; finger channels are separate per digit and side, but remain provisional seed hypotheses."
        ]
    }
    var report_file := FileAccess.open(output_directory.path_join("proposal.json"), FileAccess.WRITE)
    report_file.store_string(JSON.stringify(report, "\t"))
    report_file.close()
    print("WREN_TOPOLOGY_PROPOSAL_OK vertices=%d regions=%d" % [vertices.size(), REGIONS.size()])
    quit(0)


func _build_candidate_seed_ratios(seed_counts: Dictionary, candidate_counts: Dictionary) -> Dictionary:
    var ratios: Dictionary = {}
    for region_id in REGIONS:
        var seed_count: int = seed_counts.get(region_id, 0)
        var candidate_count: int = candidate_counts.get(region_id, 0)
        ratios[region_id] = snappedf(float(candidate_count) / maxf(float(seed_count), 1.0), 0.01)
    return ratios


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


func _find_seed_vertices(vertices: PackedVector3Array, centre: Vector3, radii: Vector3) -> PackedInt32Array:
    var result := PackedInt32Array()
    for vertex_index in vertices.size():
        var normalized := (vertices[vertex_index] - centre) / radii
        if normalized.length() <= 1.0:
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
        return 2
    return MAX_GRAPH_HOPS


func _propagate_over_surface(
    adjacency: Array[PackedInt32Array],
    vertices: PackedVector3Array,
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
    material.no_depth_test = true
    marker.material = material

    var transforms: Array[Transform3D] = []
    var colours: Array[Color] = []
    for vertex_index in vertices.size():
        var accumulated := Color(0.0, 0.0, 0.0, 0.0)
        var strongest := 0.0
        for region_id in REGIONS:
            if not only_region.is_empty() and region_id != only_region:
                continue
            var weights: PackedFloat32Array = candidate_weights[region_id]
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
