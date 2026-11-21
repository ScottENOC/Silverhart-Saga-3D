extends SceneTree
## Renders the actual native Wren and Aldric build artifacts with rig-derived
## surface-region samples overlaid. Dots show qualifying source vertices, not
## hand-painted anatomical boundaries.

const REGION_SCRIPT := preload("res://scripts/characters/character_surface_regions.gd")
const MASK_SCRIPT := preload("res://scripts/characters/character_surface_region_mask.gd")
const SIZE := Vector2i(1000, 1100)
const REGION_COLOURS := {
    "head": Color("#f4d35e"), "neck": Color("#ee964b"), "chest": Color("#f95738"),
    "abdomen": Color("#90be6d"), "pelvis": Color("#577590"),
    "shoulder_left": Color("#43aa8b"), "shoulder_right": Color("#43aa8b"),
    "upper_arm_left": Color("#4d908e"), "upper_arm_right": Color("#4d908e"),
    "forearm_left": Color("#277da1"), "forearm_right": Color("#277da1"),
    "hand_left": Color("#9b5de5"), "hand_right": Color("#9b5de5"),
    "thigh_left": Color("#f15bb5"), "thigh_right": Color("#f15bb5"),
    "calf_left": Color("#00bbf9"), "calf_right": Color("#00bbf9"),
    "foot_left": Color("#adb5bd"), "foot_right": Color("#adb5bd")
}
var camera: Camera3D
var stage: Node3D
var report := {}

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    root.size = SIZE
    stage = Node3D.new()
    root.add_child(stage)
    _lighting()
    camera = Camera3D.new()
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.current = true
    stage.add_child(camera)
    var args := OS.get_cmdline_user_args()
    var character_name := args[0] if args.size() > 0 else "Wren"
    var model_path := "res://build/wren-native/Wren.glb" if character_name == "Wren" else "res://build/aldric-native/Aldric.glb"
    var output := "res://build/anatomy-review/" + character_name.to_lower()
    var packed := load(model_path) as PackedScene
    if packed == null:
        push_error("Missing native companion model: " + model_path)
        quit(1)
        return
    var body := packed.instantiate() as Node3D
    if body == null:
        push_error("Companion model root is not Node3D")
        quit(1)
        return
    stage.add_child(body)
    await process_frame
    if character_name == "Aldric":
        _activate_abdominal_definition(body)
    var regions = REGION_SCRIPT.new()
    if not regions.configure(body, body, [], model_path):
        push_error("Surface region system failed: " + regions.get_configuration_error())
        quit(1)
        return
    var available: PackedStringArray = regions.available_regions(0.25)
    var region_report := {}
    for region_id in available:
        var samples: Array[Dictionary] = regions.get_region_surface_samples(region_id, 0.25, 450)
        region_report[region_id] = samples.size()
        _draw_samples(samples, Color(REGION_COLOURS.get(region_id, Color.WHITE)))
    _add_legend(available)
    var output_abs := ProjectSettings.globalize_path(output)
    DirAccess.make_dir_recursive_absolute(output_abs)
    var views := {
        "front": [Vector3(0, 0.88, 4.4), Vector3(0, 0.88, 0), 2.05],
        "side": [Vector3(4.4, 0.88, 0), Vector3(0, 0.88, 0), 2.05],
        "rear": [Vector3(0, 0.88, -4.4), Vector3(0, 0.88, 0), 2.05]
    }
    for view in views:
        var v: Array = views[view]
        camera.position = v[0]
        camera.look_at(v[1], Vector3.UP)
        camera.size = v[2]
        await process_frame
        await process_frame
        await RenderingServer.frame_post_draw
        var image := root.get_texture().get_image()
        if image.save_png(output_abs.path_join(view + ".png")) != OK:
            push_error("Could not save " + view + " view")
            quit(1)
            return
    var file := FileAccess.open(output_abs.path_join("region-report.json"), FileAccess.WRITE)
    file.store_string(JSON.stringify({"character": character_name, "model": model_path, "regions": region_report, "interpretation": "Bone-influence regions; not authored fine anatomical boundaries."}, "\t"))
    file.close()
    print("ANATOMY_REVIEW_OK character=%s regions=%d" % [character_name, available.size()])
    quit(0)

func _draw_samples(samples: Array[Dictionary], colour: Color) -> void:
    var mesh := SphereMesh.new()
    mesh.radius = 0.006
    mesh.height = 0.012
    mesh.radial_segments = 5
    mesh.rings = 3
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.albedo_color = colour
    material.no_depth_test = true
    mesh.material = material
    var multi := MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.mesh = mesh
    multi.instance_count = samples.size()
    for i in samples.size():
        var p: Vector3 = samples[i]["position"]
        multi.set_instance_transform(i, Transform3D(Basis.IDENTITY, p))
    var instance := MultiMeshInstance3D.new()
    instance.multimesh = multi
    stage.add_child(instance)

func _add_legend(regions: PackedStringArray) -> void:
    var layer := CanvasLayer.new()
    stage.add_child(layer)
    var panel := PanelContainer.new()
    panel.position = Vector2(12, 12)
    panel.add_theme_stylebox_override("panel", StyleBoxFlat.new())
    layer.add_child(panel)
    var column := VBoxContainer.new()
    panel.add_child(column)
    var title := Label.new()
    title.text = "Rig-derived surface regions • coloured dots"
    column.add_child(title)
    for region in regions:
        var label := Label.new()
        label.text = "●  " + region.replace("_", " ")
        label.add_theme_color_override("font_color", Color(REGION_COLOURS.get(region, Color.WHITE)))
        column.add_child(label)
    var note := Label.new()
    note.text = "Not fine anatomical boundaries"
    column.add_child(note)

func _activate_abdominal_definition(body: Node) -> void:
    var meshes: Array[MeshInstance3D] = []
    _collect_meshes(body, meshes)
    for instance in meshes:
        for i in instance.mesh.get_blend_shape_count():
            if String(instance.mesh.get_blend_shape_name(i)) == "AbdominalDefinition":
                instance.set_blend_shape_value(i, 1.0)

func _collect_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
    if node is MeshInstance3D and node.mesh != null:
        out.append(node)
    for child in node.get_children():
        _collect_meshes(child, out)

func _lighting() -> void:
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("#252a30")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("#c5cbd2")
    env.ambient_light_energy = 0.65
    var world := WorldEnvironment.new()
    world.environment = env
    stage.add_child(world)
    var light := DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-25, -25, 0)
    light.light_energy = 1.3
    stage.add_child(light)
