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
var _failed := false

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
        if _failed:
            return
    print("ARA_CONTACT_PATH_VISUAL_REVIEW: PASS")
    quit(0)

func _render_body(body_key: String, asset_path: String) -> void:
    var packed := load(asset_path) as PackedScene
    if packed == null:
        _fail("Could not load canonical Ara asset: " + asset_path)
        return
    var actor_root := Node3D.new()
    actor_root.name = body_key + "_actor"
    _stage.add_child(actor_root)
    var body_root := packed.instantiate() as Node3D
    if body_root == null:
        _fail("Ara asset root is not Node3D: " + asset_path)
        return
    actor_root.add_child(body_root)
    await process_frame
    var skeleton := _find_skeleton(body_root)
    if skeleton == null:
        _fail("No Skeleton3D in " + asset_path)
        return
    var meshes: Array[MeshInstance3D] = []
    _collect_skinned_meshes(body_root, meshes)
    if meshes.is_empty():
        _fail("No skinned meshes in " + asset_path)
        return
    for mesh in meshes:
        mesh.set_skeleton_path(mesh.get_path_to(skeleton))
        mesh.set_skin(mesh.skin)
    await process_frame
    await process_frame

    var regions = REGION_SCRIPT.new()
    if not regions.configure(actor_root, body_root, [], asset_path):
        _fail("Surface evaluator failed: " + regions.get_configuration_error())
        actor_root.queue_free()
        return
    var path := _build_real_surface_test_path(body_root, meshes, asset_path)
    if path == null:
        actor_root.queue_free()
        return
    var validation := path.validate_for_mesh(
        regions.get_surface_mesh_instance(path.mesh_node_path, path.surface_index),
        body_root,
        asset_path
    )
    if not validation.is_empty():
        _fail("Generated path failed topology validation: " + validation)
        actor_root.queue_free()
        return
    var samples: Array[Dictionary] = path.evaluate_surface_path(regions)
    if samples.size() < 3:
        _fail("Could not evaluate dense surface route: " + path.last_evaluation_error)
        actor_root.queue_free()
        return
    for sample in samples:
        if not sample["position"].is_finite() or not sample["normal"].is_finite():
            _fail("Surface route contains a non-finite sample")
            actor_root.queue_free()
            return
    _draw_path(samples)
    var bounds := _body_bounds(actor_root, meshes)
    var centre: Vector3 = bounds.get_center()
    var extent: Vector3 = bounds.size
    var camera_size := maxf(maxf(extent.y * 1.12, extent.x * 1.5), 1.8)
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
        if image.save_png(output_dir.path_join(view_name + ".png")) != OK:
            _fail("Could not save " + body_key + " " + view_name + " review image")
            actor_root.queue_free()
            return
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

func _build_real_surface_test_path(body_root: Node3D, meshes: Array[MeshInstance3D], asset_path: String) -> CharacterSurfaceContactPath:
    # Imported Ara assets do not guarantee a particular local forward axis or
    # triangle winding. Select a broad band using surface bounds and spatial
    # spread; do not infer the front from a normal component.
    var best: Dictionary = {}
    var best_score := -INF
    for mesh in meshes:
        var array_mesh := mesh.mesh as ArrayMesh
        if array_mesh == null:
            continue
        for surface_index in range(array_mesh.get_surface_count()):
            # The skinned body mesh also contains hair/face/accessory surfaces.
            # Those are valid topology, but not useful for a skin-contact review.
            var surface_label := array_mesh.surface_get_name(surface_index).to_lower()
            if surface_label.contains("hair") or surface_label.contains("eye") or surface_label.contains("lash") or surface_label.contains("brow") or surface_label.contains("teeth") or surface_label.contains("tongue"):
                continue
            var arrays := array_mesh.surface_get_arrays(surface_index)
            var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
            if vertices.size() < 3:
                continue
            var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
            var vertex_bounds := AABB(vertices[0], Vector3.ZERO)
            for vertex in vertices:
                vertex_bounds = vertex_bounds.expand(vertex)
            var extents := vertex_bounds.size
            var vertical_axis := 1
            if extents.x > extents.y and extents.x >= extents.z:
                vertical_axis = 0
            elif extents.z > extents.y and extents.z > extents.x:
                vertical_axis = 2
            var horizontal_axis := 0 if vertical_axis != 0 else 2
            if vertical_axis == 1:
                horizontal_axis = 0 if extents.x >= extents.z else 2
            var vertical_min := _axis_value(vertex_bounds.position, vertical_axis)
            var vertical_extent := maxf(_axis_value(extents, vertical_axis), 0.001)
            var triangle_count := indices.size() if not indices.is_empty() else vertices.size()
            var candidates: Array[Dictionary] = []
            var all_candidates: Array[Dictionary] = []
            for offset in range(0, triangle_count - 2, 3):
                var tri := PackedInt32Array()
                if indices.is_empty():
                    tri = PackedInt32Array([offset, offset + 1, offset + 2])
                else:
                    tri = PackedInt32Array([indices[offset], indices[offset + 1], indices[offset + 2]])
                if tri[0] < 0 or tri[1] < 0 or tri[2] < 0 or tri[0] >= vertices.size() or tri[1] >= vertices.size() or tri[2] >= vertices.size():
                    continue
                var a: Vector3 = vertices[tri[0]]
                var b: Vector3 = vertices[tri[1]]
                var c: Vector3 = vertices[tri[2]]
                if (b - a).cross(c - a).length_squared() < 0.0000001:
                    continue
                var centre := (a + b + c) / 3.0
                var candidate := {"triangle": tri, "centre": centre}
                all_candidates.append(candidate)
                var height_ratio := (_axis_value(centre, vertical_axis) - vertical_min) / vertical_extent
                if height_ratio >= 0.34 and height_ratio <= 0.66:
                    candidates.append(candidate)
            # If the middle third is sparse, fall back to all valid triangles.
            if candidates.size() < 3:
                candidates = all_candidates
            if candidates.size() < 3:
                continue
            candidates.sort_custom(func(a: Dictionary, b: Dictionary):
                return _axis_value(a["centre"], horizontal_axis) < _axis_value(b["centre"], horizontal_axis)
            )
            var spread := absf(
                _axis_value(candidates[-1]["centre"], horizontal_axis)
                - _axis_value(candidates[0]["centre"], horizontal_axis)
            )
            var score := float(candidates.size()) * maxf(spread, 0.001)
            if score > best_score:
                best_score = score
                best = {"mesh": mesh, "surface": surface_index, "vertices": vertices, "candidates": candidates}
    if best.is_empty():
        _fail("No canonical Ara surface contained three valid, non-degenerate triangles")
        return null
    var candidates: Array[Dictionary] = best["candidates"]
    var selected: Array[Dictionary] = []
    for fraction in [0.2, 0.5, 0.8]:
        var candidate_index := clampi(roundi((candidates.size() - 1) * fraction), 0, candidates.size() - 1)
        var candidate: Dictionary = candidates[candidate_index]
        if selected.is_empty() or candidate["triangle"] != selected[-1]["triangle"]:
            selected.append(candidate)
    if selected.size() != 3:
        _fail("Could not select three distinct source triangles for the synthetic trace")
        return null
    var mesh: MeshInstance3D = best["mesh"]
    var surface_index: int = best["surface"]
    var path: CharacterSurfaceContactPath = PATH_SCRIPT.new()
    path.body_asset_path = asset_path
    path.mesh_node_path = body_root.get_path_to(mesh)
    path.surface_index = surface_index
    path.surface_name = mesh.mesh.surface_get_name(surface_index)
    path.vertex_count = best["vertices"].size()
    path.surface_signature = CharacterSurfaceRegionMask.build_surface_signature(mesh.mesh, surface_index)
    path.path_id = "synthetic_surface_trace"
    path.closed_loop = false
    for candidate in selected:
        path.points.append({
            "triangle_indices": candidate["triangle"],
            "barycentric": PackedFloat32Array([0.33333334, 0.33333333, 0.33333333])
        })
    return path


func _axis_value(value: Vector3, axis: int) -> float:
    if axis == 0:
        return value.x
    if axis == 1:
        return value.y
    return value.z


func _fail(message: String) -> void:
    _failed = true
    push_error("ARA_CONTACT_PATH_VISUAL_REVIEW: FAIL — " + message)
    quit(1)


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
