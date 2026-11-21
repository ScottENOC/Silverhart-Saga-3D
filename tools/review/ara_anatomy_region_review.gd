extends SceneTree
## Coloured vertex-sample overlay for broad rig-derived torso regions.
## These are orientation guides, not authored fine anatomical masks.

const REGION_SCRIPT := preload("res://scripts/characters/character_surface_regions.gd")
const SIZE := Vector2i(1400, 1200)
const BODIES := {
    "wren": "res://build/wren-native/Wren.glb",
    "aldric": "res://build/aldric-native/Aldric.glb"
}
const REGION_COLOURS := {
    "chest": Color("#28B8D8"),
    "abdomen": Color("#F39A32"),
    "pelvis": Color("#B477D8")
}
var stage: Node3D
var camera: Camera3D
var failed := false

func _initialize() -> void:
    call_deferred("run_review")

func run_review() -> void:
    root.size = SIZE
    stage = Node3D.new()
    root.add_child(stage)
    setup_lighting()
    camera = Camera3D.new()
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.current = true
    stage.add_child(camera)
    for body_id in BODIES:
        await render_body(body_id, BODIES[body_id])
        if failed:
            quit(1)
            return
    print("NATIVE_TORSO_REGION_REVIEW: PASS")
    quit(0)

func render_body(body_id: String, asset_path: String) -> void:
    var packed := load(asset_path) as PackedScene
    if packed == null:
        fail("Could not load " + asset_path)
        return
    var actor := Node3D.new()
    stage.add_child(actor)
    var body := packed.instantiate() as Node3D
    if body == null:
        fail("Asset root is not Node3D: " + asset_path)
        return
    actor.add_child(body)
    await process_frame
    var skeleton := find_skeleton(body)
    var meshes: Array[MeshInstance3D] = []
    collect_skinned_meshes(body, meshes)
    if skeleton == null or meshes.is_empty():
        fail("Missing skeleton or skinned surfaces for " + body_id)
        return
    for mesh in meshes:
        mesh.set_skeleton_path(mesh.get_path_to(skeleton))
        mesh.set_skin(mesh.skin)
    await process_frame
    await process_frame
    var evaluator = REGION_SCRIPT.new()
    if not evaluator.configure(actor, body, [], asset_path):
        fail("Region evaluator failed for %s: %s" % [body_id, evaluator.get_configuration_error()])
        return

    var report := {"body": body_id, "asset": asset_path, "interpretation": "Broad rig-weight overlays only; not authored fine anatomical masks or garment boundaries.", "regions": {}}
    for region_id in REGION_COLOURS:
        var samples: Array[Dictionary] = evaluator.get_region_surface_samples(region_id, 0.20, 0)
        if samples.is_empty():
            report["regions"][region_id] = {"samples": 0, "colour": REGION_COLOURS[region_id].to_html()}
            continue
        var marker := MultiMeshInstance3D.new()
        marker.name = region_id + "_region_overlay"
        var sphere := SphereMesh.new()
        sphere.radius = 0.008
        sphere.height = 0.016
        sphere.radial_segments = 6
        sphere.rings = 4
        var mat := StandardMaterial3D.new()
        mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        mat.albedo_color = REGION_COLOURS[region_id]
        mat.no_depth_test = true
        sphere.material = mat
        var multi := MultiMesh.new()
        multi.transform_format = MultiMesh.TRANSFORM_3D
        multi.mesh = sphere
        multi.instance_count = samples.size()
        for index in range(samples.size()):
            var point: Vector3 = samples[index]["position"]
            var normal: Vector3 = samples[index]["normal"]
            multi.set_instance_transform(index, Transform3D(Basis.IDENTITY, point + normal * 0.004))
        marker.multimesh = multi
        actor.add_child(marker)
        report["regions"][region_id] = {"samples": samples.size(), "colour": REGION_COLOURS[region_id].to_html()}

    await process_frame
    await process_frame
    var output := "build/ara-anatomy-region-review/" + body_id
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
    for view in ["front", "side", "rear"]:
        set_camera(body, view)
        await process_frame
        await process_frame
        root.get_texture().get_image().save_png(output + "/" + view + ".png")
    var file := FileAccess.open(output + "/report.json", FileAccess.WRITE)
    file.store_string(JSON.stringify(report, "\t"))
    file.close()
    actor.queue_free()
    await process_frame

func set_camera(body: Node3D, view: String) -> void:
    var centre := Vector3(0, 0.95, 0)
    if view == "front":
        camera.position = centre + Vector3(0, 0, 2.8)
    elif view == "rear":
        camera.position = centre + Vector3(0, 0, -2.8)
    else:
        camera.position = centre + Vector3(2.8, 0, 0)
    camera.look_at(centre, Vector3.UP)
    camera.size = 2.1

func setup_lighting() -> void:
    var env_node := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("#111820")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("#B7C2D0")
    env.ambient_light_energy = 0.9
    env_node.environment = env
    stage.add_child(env_node)
    var light := DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-28, -32, 0)
    light.light_energy = 1.5
    stage.add_child(light)

func find_skeleton(node: Node) -> Skeleton3D:
    if node is Skeleton3D:
        return node as Skeleton3D
    for child in node.get_children():
        var found := find_skeleton(child)
        if found != null:
            return found
    return null

func collect_skinned_meshes(node: Node, output: Array[MeshInstance3D]) -> void:
    if node is MeshInstance3D and (node as MeshInstance3D).mesh != null and (node as MeshInstance3D).skin != null:
        output.append(node as MeshInstance3D)
    for child in node.get_children():
        collect_skinned_meshes(child, output)

func fail(message: String) -> void:
    failed = true
    push_error("NATIVE_TORSO_REGION_REVIEW: FAIL — " + message)
