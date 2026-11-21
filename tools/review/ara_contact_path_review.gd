extends SceneTree
## Renders a technical surface-contact-path trace on each canonical Ara body.
## The trace is deliberately generated from real source triangles at runtime; it
## is a topology/evaluation visual test, NOT an authored anatomical trajectory.

const REGION_SCRIPT := preload("res://scripts/characters/character_surface_regions.gd")
const PATH_SCRIPT := preload("res://scripts/characters/character_surface_contact_path.gd")
const SIZE := Vector2i(1280, 1200)
const BODY_ASSETS := {
    "female": "res://art/characters/ara_runtime/ara_person_body_anatomy.glb",
    "male": "res://art/characters/ara_runtime/ara_person_male_body.glb"
}
var _stage: Node3D
var _camera: Camera3D

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    root.size = SIZE
    _stage = Node3D.new()
    root.add_child(_stage)
    _setup_lighting()
    _camera = Camera3D.new()
    _camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    _camera.current = true
    _stage.add_child(_camera)
    for body_key in BODY_ASSETS:
        await _render_body(body_key, BODY_ASSETS[body_key])
    print("ARA_CONTACT_PATH_VISUAL_REVIEW: PASS")
    quit(0)

func _render_body(body_key: String, asset_path: String) -> void:
    var packed := load(asset_path) as PackedScene
    assert(packed != null, "Could not load canonical Ara asset: " + asset_path)
    var actor_root := Node3D.new()
    actor_root.name = body_key + "_actor"
    _stage.add_child(actor_root)
    var body_root := packed.instantiate() as Node3D
    assert(body_root != null, "Ara asset root is not Node3D: " + asset_path)
    actor_root.add_child(body_root)
    await process_frame
    var skeleton := _find_skeleton(body_root)
    assert(skeleton != null, "No Skeleton3D in " + asset_path)
    var meshes: Array[MeshInstance3D] = []
    _collect_skinned_meshes(body_root, meshes)
    assert(not meshes.is_empty(), "No skinned meshes in " + asset_path)
    for mesh in meshes:
        mesh.set_skeleton_path(mesh.get_path_to(skeleton))
        mesh.set_skin(mesh.skin)
    await process_frame
    await process_frame

    var regions = REGION_SCRIPT.new()
    assert(regions.configure(actor_root, body_root, [], asset_path),
        "Surface evaluator failed: " + regions.get_configuration_error())
    var path := _build_real_surface_test_path(body_root, meshes, asset_path)
    var validation := path.validate_for_mesh(
        regions.get_surface_mesh_instance(path.mesh_node_path, path.surface_index),
        body_root,
        asset_path
    )
    assert(validation.is_empty(), "Generated path failed topology validation: " + validation)
    var samples: Array[Dictionary] = path.evaluate_surface_path(regions)
    assert(samples.size() >= 3, "Could not evaluate dense surface route: " + path.last_evaluation_error)
    for sample in samples:
        assert(sample["position"].is_finite() and sample["normal"].is_finite(),
            "Surface route contains a non-finite sample")
    _draw_path(samples)
    var bounds := _body_bounds(actor_root, meshes)
    var centre: Vector3 = bounds.get_center()
    var extent: Vector3 = bounds.size
    var camera_size := maxf(extent.y * 1.12, extent.x * 1.5, 1.8)
    var views := {
        "front": [centre + Vector3(0, 0, maxf(extent.z * 3.0, 3.8)), centre],
        "side": [centre + Vector3(maxf(extent.z * 3.0, 3.8), 0, 0), centre],
        "rear": [centre + Vector3(0, 0, -maxf(extent.z * 3.0, 3.8)), centre]
    }
    var output_dir := ProjectSettings.globalize_path("res://build/ara-contact-path-review/" + body_key)
    DirAccess.make_dir_recursive_absolute(output_dir)
    for view_name in views:
        var view: Array = views[view_name]
        _camera.position = view[0]
        _camera.look_at(view[1], Vector3.UP)
        _camera.size = camera_size
        await process_frame
        await process_frame
        await RenderingServer.frame_post_draw
        var image := root.get_texture().get_image()
        assert(image.save_png(output_dir.path_join(view_name + ".png")) == OK,
            "Could not save " + body_key + " " + view_name + " review image")
    var report := {
        "body": body_key,
        "asset": asset_path,
        "mesh": String(path.mesh_node_path),
        "surface_index": path.surface_index,
        "surface_name": path.surface_name,
        "control_points": path.points.size(),
        "evaluated_samples": samples.size(),
        "path_id": path.path_id,
        "interpretation": "Synthetic topology/evaluation trace on real canonical Ara geometry. Not an authored anatomical or fingertip path."
    }
    var report_file := FileAccess.open(output_dir.path_join("report.json"), FileAccess.WRITE)
    report_file.store_string(JSON.stringify(report, "\t"))
    report_file.close()
    print("ARA_CONTACT_PATH_BODY_OK body=%s mesh=%s surface=%d samples=%d" % [
        body_key, path.mesh_node_path, path.surface_index, samples.size()
    ])
    _clear_path_draw()
    actor_root.queue_free()
    await process_frame

func _build_real_surface_test_path(body_root: Node3D, meshes: Array[MeshInstance3D], asset_path: String) -> Resource:
    var best: Dictionary = {}
    var best_score := -INF
    for mesh in meshes:
        var array_mesh := mesh.mesh as ArrayMesh
        if array_mesh == null:
            continue
        for surface_index in range(array_mesh.get_surface_count()):
            var arrays := array_mesh.surface_get_arrays(surface_index)
            var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
            if vertices.size() < 3:
                continue
            var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
            var y_min := INF
            var y_max := -INF
            var z_min := INF
            var z_max := -INF
            for vertex in vertices:
                y_min = minf(y_min, vertex.y)
                y_max = maxf(y_max, vertex.y)
                z_min = minf(z_min, vertex.z)
                z_max = maxf(z_max, vertex.z)
            var height := maxf(y_max - y_min, 0.001)
            var front_sign := 1.0 if absf(z_max) >= absf(z_min) else -1.0
            var candidates: Array[Dictionary] = []
            var triangle_count := indices.size() if not indices.is_empty() else vertices.size()
            for offset in range(0, triangle_count - 2, 3):
                var tri := PackedInt32Array()
                if indices.is_empty():
                    tri = PackedInt32Array([offset, offset + 1, offset + 2])
                else:
                    tri = PackedInt32Array([indices[offset], indices[offset + 1], indices[offset + 2]])
                if tri[0] >= vertices.size() or tri[1] >= vertices.size() or tri[2] >= vertices.size():
                    continue
                var a: Vector3 = vertices[tri[0]]
                var b: Vector3 = vertices[tri[1]]
                var c: Vector3 = vertices[tri[2]]
                var normal := (b - a).cross(c - a)
                if normal.length_squared() < 0.0000001:
                    continue
                normal = normal.normalized()
                var centre := (a + b + c) / 3.0
                var y_ratio := (centre.y - y_min) / height
                if y_ratio < 0.34 or y_ratio > 0.66 or normal.z * front_sign < 0.45:
                    continue
                candidates.append({"triangle": tri, "centre": centre})
            if candidates.size() < 3:
                continue
            candidates.sort_custom(func(a: Dictionary, b: Dictionary): return a["centre"].x < b["centre"].x)
            var x_span: float = candidates[-1]["centre"].x - candidates[0]["centre"].x
            var score := float(candidates.size()) * maxf(x_span, 0.001)
            if score > best_score:
                best_score = score
                best = {"mesh": mesh, "surface": surface_index, "vertices": vertices, "candidates": candidates}
    assert(not best.is_empty(), "Could not find a broad front-facing torso-like triangle band on either canonical mesh")
    var candidates: Array[Dictionary] = best["candidates"]
    var selected: Array[Dictionary] = []
    for fraction in [0.2, 0.5, 0.8]:
        var candidate_index := clampi(roundi((candidates.size() - 1) * fraction), 0, candidates.size() - 1)
        var candidate: Dictionary = candidates[candidate_index]
        if selected.is_empty() or candidate["triangle"] != selected[-1]["triangle"]:
            selected.append(candidate)
    assert(selected.size() == 3, "Could not select three distinct surface triangles for the visual trace")
    var mesh: MeshInstance3D = best["mesh"]
    var surface_index: int = best["surface"]
    var path = PATH_SCRIPT.new()
    path.body_asset_path = asset_path
    path.mesh_node_path = body_root.get_path_to(mesh)
    path.surface_index = surface_index
    path.surface_name = mesh.mesh.surface_get_name(surface_index)
    path.vertex_count = best["vertices"].size()
    path.surface_signature = CharacterSurfaceRegionMask.build_surface_signature(mesh.mesh, surface_index)
    path.path_id = "synthetic_front_surface_trace"
    path.closed_loop = false
    for candidate in selected:
        path.points.append({
            "triangle_indices": candidate["triangle"],
            "barycentric": PackedFloat32Array([0.33333334, 0.33333333, 0.33333333])
        })
    return path

func _draw_path(samples: Array[Dictionary]) -> void:
    var line := ImmediateMesh.new()
    line.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
    for sample in samples:
        line.surface_add_vertex(sample["position"])
    line.surface_end()
    var line_instance := MeshInstance3D.new()
    line_instance.mesh = line
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.albedo_color = Color("#00f5ff")
    material.no_depth_test = true
    line_instance.material_override = material
    _stage.add_child(line_instance)
    var marker_mesh := SphereMesh.new()
    marker_mesh.radius = 0.012
    marker_mesh.height = 0.024
    var marker_material := StandardMaterial3D.new()
    marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    marker_material.albedo_color = Color("#ffcc33")
    marker_material.no_depth_test = true
    marker_mesh.material = marker_material
    var markers := MultiMesh.new()
    markers.transform_format = MultiMesh.TRANSFORM_3D
    markers.mesh = marker_mesh
    markers.instance_count = samples.size()
    for index in samples.size():
        markers.set_instance_transform(index, Transform3D(Basis.IDENTITY, samples[index]["position"]))
    var marker_instance := MultiMeshInstance3D.new()
    marker_instance.multimesh = markers
    _stage.add_child(marker_instance)

func _clear_path_draw() -> void:
    for child in _stage.get_children():
        if child is MeshInstance3D or child is MultiMeshInstance3D:
            if child != _camera:
                child.queue_free()

func _body_bounds(actor_root: Node3D, meshes: Array[MeshInstance3D]) -> AABB:
    var result := AABB()
    var first := true
    for mesh in meshes:
        var local_bounds := mesh.get_aabb()
        var transform := actor_root.global_transform.affine_inverse() * mesh.global_transform
        for x in [local_bounds.position.x, local_bounds.end.x]:
            for y in [local_bounds.position.y, local_bounds.end.y]:
                for z in [local_bounds.position.z, local_bounds.end.z]:
                    var point := transform * Vector3(x, y, z)
                    if first:
                        result = AABB(point, Vector3.ZERO)
                        first = false
                    else:
                        result = result.expand(point)
    return result

func _find_skeleton(node: Node) -> Skeleton3D:
    if node is Skeleton3D:
        return node as Skeleton3D
    for child in node.get_children():
        var found := _find_skeleton(child)
        if found != null:
            return found
    return null

func _collect_skinned_meshes(node: Node, output: Array[MeshInstance3D]) -> void:
    if node is MeshInstance3D and node.mesh != null and node.skin != null:
        output.append(node)
    for child in node.get_children():
        _collect_skinned_meshes(child, output)

func _setup_lighting() -> void:
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color("#252a30")
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color("#c5cbd2")
    environment.ambient_light_energy = 0.7
    var world := WorldEnvironment.new()
    world.environment = environment
    _stage.add_child(world)
    var light := DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-25, -25, 0)
    light.light_energy = 1.35
    _stage.add_child(light)
