extends SceneTree
## Renders broad, rig-derived torso region overlays on the native Wren and Aldric builds.
## These are orientation maps only; they are not authored fine anatomical masks.

const REGION_SCRIPT := preload("res://scripts/characters/character_surface_regions.gd")
const SIZE := Vector2i(1400, 1200)
const BODY_ASSETS := {
    "wren": "res://build/wren-native/Wren.glb",
    "aldric": "res://build/aldric-native/Aldric.glb"
}
const REGIONS := {
    "chest": Color(0.12, 0.72, 0.88, 1.0),
    "abdomen": Color(1.0, 0.58, 0.12, 1.0),
    "pelvis": Color(0.72, 0.38, 0.88, 1.0)
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
            quit(1)
            return
    print("NATIVE_TORSO_REGION_REVIEW: PASS")
    quit(0)

func _render_body(body_key: String, asset_path: String) -> void:
    var packed := load(asset_path) as PackedScene
    if packed == null:
        _fail("Could not load native body: " + asset_path)
        return
    var actor := Node3D.new()
    actor.name = body_key
    _stage.add_child(actor)
    var body := packed.instantiate() as Node3D
    if body == null:
        _fail("Body root is not Node3D: " + asset_path)
        return
    actor.add_child(body)
    await process_frame
    var skeleton := _find_skeleton(body)
    var meshes: Array[MeshInstance3D] = []
    _collect_skinned_meshes(body, meshes)
    if skeleton == null or meshes.is_empty():
        _fail("Missing skeleton or skinned meshes: " + body_key)
        return
    for mesh in meshes:
        mesh.set_skeleton_path(mesh.get_path_to(skeleton))
        mesh.set_skin(mesh.skin)
    await process_frame
    await process_frame

    var regions = REGION_SCRIPT.new()
    if not regions.configure(actor, body, [], asset_path):
        _fail("Surface evaluator failed for %s: %s" % [body_key, regions.get_configuration_error()])
        return

    var region_samples := {}
    for region_id in REGIONS:
        region_samples[region_id] = regions.get_region_surface_samples(region_id, 0.20, 0)
    var painted_vertices := 0
    for mesh in meshes:
        for surface_index in range(mesh.mesh.get_surface_count()):
            var arrays := mesh.mesh.surface_get_arrays(surface_index)
            var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
            if vertices.is_empty():
                continue
            var colors := PackedColorArray()
            colors.resize(vertices.size())
            for vertex_index in range(vertices.size()):
                colors[vertex_index] = Color(0.72, 0.74, 0.76, 1.0)
            var weights_by_vertex := {}
            for region_id in REGIONS:
                for sample in region_samples[region_id]:
                    if sample["mesh_instance"] != mesh or int(sample["surface_index"]) != surface_index:
                        continue
                    var vertex_index: int = sample["vertex_index"]
                    weights_by_vertex[vertex_index] = {
                        "region": region_id,
                        "weight": float(sample["weight"])
                    }
            for vertex_index in weights_by_vertex:
                var entry: Dictionary = weights_by_vertex[vertex_index]
                var base: Color = REGIONS[entry["region"]]
                var strength := clampf(float(entry["weight"]), 0.0, 1.0)
                colors[vertex_index] = Color(0.72, 0.74, 0.76, 1.0).lerp(base, strength)
                painted_vertices += 1
            arrays[Mesh.ARRAY_COLOR] = colors
            var colored_mesh := ArrayMesh.new()
            colored_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
            for blend_index in range(mesh.mesh.get_blend_shape_count()):
                colored_mesh.add_blend_shape(mesh.mesh.get_blend_shape_name(blend_index))
            colored_mesh.blend_shape_mode = mesh.mesh.blend_shape_mode
            for blend_index in range(mesh.mesh.get_blend_shape_count()):
                colored_mesh.surface_set_blend_shape_values(0, mesh.mesh.surface_get_blend_shape_arrays(surface_index))
            var source_material := mesh.get_active_material(surface_index)
            var material := StandardMaterial3D.new()
            material.vertex_color_use_as_albedo = true
            material.roughness = 0.82
            material.metallic = 0.0
            material.cull_mode = BaseMaterial3D.CULL_DISABLED
            if source_material is BaseMaterial3D:
                material.metallic = (source_material as BaseMaterial3D).metallic
            colored_mesh.surface_set_material(0, material)
            mesh.mesh = _replace_surface(mesh.mesh, surface_index, colored_mesh)
    if painted_vertices == 0:
        _fail("No chest/abdomen/pelvis skin-weight samples found for " + body_key)
        return

    await process_frame
    await process_frame
    var report := {
        "body": body_key,
        "asset": asset_path,
        "interpretation": "Broad rig-weight regions only; not authored anatomical masks or garment boundaries.",
        "regions": {
            "chest": {"colour": "#1FB8E0", "samples": region_samples["chest"].size()},
            "abdomen": {"colour": "#FF941F", "samples": region_samples["abdomen"].size()},
            "pelvis": {"colour": "#B861E0", "samples": region_samples["pelvis"].size()}
        },
        "coloured_vertices": painted_vertices
    }
    var output_dir := "build/ara-anatomy-region-review/" + body_key
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
    for view in ["front", "side", "rear"]:
        _position_camera(body, view)
        await process_frame
        await process_frame
        var image := root.get_texture().get_image()
        image.save_png(output_dir + "/" + view + ".png")
    var file := FileAccess.open(output_dir + "/report.json", FileAccess.WRITE)
    file.store_string(JSON.stringify(report, "\t"))
    file.close()
    actor.queue_free()
    await process_frame

func _replace_surface(source: Mesh, selected_index: int, replacement: ArrayMesh) -> Mesh:
    var result := ArrayMesh.new()
    for index in range(source.get_surface_count()):
        if index == selected_index:
            var arrays := replacement.surface_get_arrays(0)
            result.add_surface_from_arrays(source.surface_get_primitive_type(index), arrays)
            result.surface_set_material(result.get_surface_count() - 1, replacement.surface_get_material(0))
        else:
            result.add_surface_from_arrays(source.surface_get_primitive_type(index), source.surface_get_arrays(index))
            result.surface_set_material(result.get_surface_count() - 1, source.surface_get_material(index))
    return result

func _position_camera(body: Node3D, view: String) -> void:
    var centre := _body_centre(body)
    var distance := 2.6
    if view == "front":
        _camera.position = centre + Vector3(0.0, 0.0, distance)
        _camera.look_at(centre, Vector3.UP)
    elif view == "rear":
        _camera.position = centre + Vector3(0.0, 0.0, -distance)
        _camera.look_at(centre, Vector3.UP)
    else:
        _camera.position = centre + Vector3(distance, 0.0, 0.0)
        _camera.look_at(centre, Vector3.UP)
    _camera.size = 2.05

func _body_centre(body: Node3D) -> Vector3:
    var bounds := AABB()
    var found := false
    var meshes: Array[MeshInstance3D] = []
    _collect_meshes(body, meshes)
    for mesh in meshes:
        var box := mesh.get_aabb()
        var transformed := AABB()
        for corner in [box.position, box.position + Vector3(box.size.x,0,0), box.position + Vector3(0,box.size.y,0), box.position + Vector3(0,0,box.size.z), box.position + Vector3(box.size.x,box.size.y,0), box.position + Vector3(box.size.x,0,box.size.z), box.position + Vector3(0,box.size.y,box.size.z), box.position + box.size]:
            transformed = transformed.expand(mesh.global_transform * corner)
        if not found:
            bounds = transformed
            found = true
        else:
            bounds = bounds.merge(transformed)
    return bounds.get_center() if found else Vector3(0, 0.9, 0)

func _setup_lighting() -> void:
    var environment := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.055, 0.065, 0.08)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.72, 0.76, 0.82)
    env.ambient_light_energy = 0.9
    environment.environment = env
    _stage.add_child(environment)
    var key := DirectionalLight3D.new()
    key.rotation_degrees = Vector3(-25, -30, 0)
    key.light_energy = 1.6
    _stage.add_child(key)

func _find_skeleton(node: Node) -> Skeleton3D:
    if node is Skeleton3D:
        return node as Skeleton3D
    for child in node.get_children():
        var result := _find_skeleton(child)
        if result != null:
            return result
    return null

func _collect_skinned_meshes(node: Node, output: Array[MeshInstance3D]) -> void:
    if node is MeshInstance3D and (node as MeshInstance3D).mesh != null and (node as MeshInstance3D).skin != null:
        output.append(node as MeshInstance3D)
    for child in node.get_children():
        _collect_skinned_meshes(child, output)

func _collect_meshes(node: Node, output: Array[MeshInstance3D]) -> void:
    if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
        output.append(node as MeshInstance3D)
    for child in node.get_children():
        _collect_meshes(child, output)

func _fail(message: String) -> void:
    _failed = true
    push_error("NATIVE_TORSO_REGION_REVIEW: FAIL — " + message)
