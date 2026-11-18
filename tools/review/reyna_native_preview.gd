extends SceneTree
## Isolated Godot preview of the final native-Ara Reyna GLB.
## This project does not load the game scenes or modify gameplay.

const MODEL_PATH := "res://build/reyna-native/Reyna.glb"
const OUTPUT_DIR := "res://build/reyna-native/preview"
const VIEW_SIZE := Vector2i(720, 960)

var camera: Camera3D
var mesh_instances: Array[MeshInstance3D] = []


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    root.size = VIEW_SIZE
    var packed := load(MODEL_PATH) as PackedScene
    if packed == null:
        push_error("Could not import final Reyna GLB as a PackedScene")
        quit(1)
        return

    var stage := Node3D.new()
    stage.name = "ReynaPreviewStage"
    root.add_child(stage)

    var character := packed.instantiate() as Node3D
    if character == null:
        push_error("Reyna GLB did not instantiate as Node3D")
        quit(1)
        return
    character.name = "Reyna"
    stage.add_child(character)

    _collect_meshes(character)
    _activate_abdominal_definition()
    if mesh_instances.is_empty():
        push_error("Reyna GLB contains no MeshInstance3D nodes")
        quit(1)
        return

    var report := _build_mesh_report()
    print("ALDRIC_GODOT_MESH_REPORT " + JSON.stringify(report))

    if int(report.get("max_blend_shape_count", 0)) < 34:
        push_error("Expected Ara's 34 facial expression / speech blend shapes; found %d" % int(report.get("max_blend_shape_count", 0)))
        quit(1)
        return

    _create_lighting(stage)
    _create_camera(stage)

    var output_absolute := ProjectSettings.globalize_path(OUTPUT_DIR)
    DirAccess.make_dir_recursive_absolute(output_absolute)

    var views := {
        "front": {"target": Vector3(0.0, 0.84, 0.0), "offset": Vector3(0.0, 0.0, 4.2), "size": 1.95},
        "side": {"target": Vector3(0.0, 0.84, 0.0), "offset": Vector3(4.2, 0.0, 0.0), "size": 1.95},
        "threequarter": {"target": Vector3(0.0, 0.84, 0.0), "offset": Vector3(3.2, 0.0, 3.2), "size": 1.95},
        "face": {"target": Vector3(0.0, 1.54, 0.0), "offset": Vector3(0.0, 0.0, 2.1), "size": 0.62},
        "pelvis": {"target": Vector3(0.0, 0.80, 0.0), "offset": Vector3(0.0, 0.0, 1.45), "size": 0.54},
        "abdomen": {"target": Vector3(0.0, 1.05, 0.0), "offset": Vector3(0.0, 0.0, 1.55), "size": 0.82}
    }

    for view_name in views:
        var settings: Dictionary = views[view_name]
        camera.size = float(settings["size"])
        camera.position = settings["target"] + settings["offset"]
        camera.look_at(settings["target"], Vector3.UP)
        await process_frame
        await process_frame
        await process_frame
        var image := root.get_texture().get_image()
        if image == null or image.is_empty():
            push_error("Godot returned an empty viewport image for " + view_name)
            quit(1)
            return
        var output_path := output_absolute.path_join(view_name + ".png")
        var save_error := image.save_png(output_path)
        if save_error != OK:
            push_error("Could not save %s (error %d)" % [output_path, save_error])
            quit(1)
            return
        print("ALDRIC_GODOT_RENDER_OK view=%s path=%s" % [view_name, output_path])

    var report_file := FileAccess.open(output_absolute.path_join("render-report.json"), FileAccess.WRITE)
    if report_file == null:
        push_error("Could not write Reyna render report")
        quit(1)
        return
    report["views"] = ["front", "side", "threequarter", "face", "pelvis", "abdomen"]
    report_file.store_string(JSON.stringify(report, "\t") + "\n")
    report_file.close()

    print("ALDRIC_GODOT_PREVIEW_OK meshes=%d blend_shapes=%d renders=4" % [
        mesh_instances.size(), int(report.get("max_blend_shape_count", 0))
    ])
    quit(0)


func _activate_abdominal_definition() -> void:
    var activated := 0
    for instance in mesh_instances:
        var mesh := instance.mesh
        for index in range(mesh.get_blend_shape_count()):
            if String(mesh.get_blend_shape_name(index)) == "AbdominalDefinition":
                instance.set_blend_shape_value(index, 1.0)
                activated += 1
    print("ABDOMINAL_DEFINITION_ACTIVATED meshes=%d" % activated)

func _collect_meshes(node: Node) -> void:
    if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
        mesh_instances.append(node as MeshInstance3D)
    for child in node.get_children():
        _collect_meshes(child)


func _build_mesh_report() -> Dictionary:
    var result := {
        "mesh_count": mesh_instances.size(),
        "max_blend_shape_count": 0,
        "meshes": []
    }
    var rows: Array[Dictionary] = []
    for instance in mesh_instances:
        var mesh := instance.mesh
        var names: Array[String] = []
        for index in range(mesh.get_blend_shape_count()):
            names.append(String(mesh.get_blend_shape_name(index)))
        result["max_blend_shape_count"] = max(int(result["max_blend_shape_count"]), names.size())
        var surfaces: Array[Dictionary] = []
        for surface in range(mesh.get_surface_count()):
            var material := mesh.surface_get_material(surface)
            surfaces.append({
                "surface": String(mesh.surface_get_name(surface)),
                "material": material.resource_name if material != null else ""
            })
        rows.append({
            "node": str(instance.get_path()),
            "mesh": mesh.resource_name,
            "blend_shape_count": names.size(),
            "blend_shapes": names,
            "surfaces": surfaces
        })
    result["meshes"] = rows
    return result


func _create_lighting(stage: Node3D) -> void:
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color("#252a30")
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color("#b8c0c9")
    environment.ambient_light_energy = 0.42
    environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    environment.tonemap_exposure = 0.9

    var world := WorldEnvironment.new()
    world.environment = environment
    stage.add_child(world)

    var key := DirectionalLight3D.new()
    key.rotation_degrees = Vector3(-28.0, -28.0, 0.0)
    key.light_energy = 1.15
    key.shadow_enabled = false
    stage.add_child(key)

    var fill := OmniLight3D.new()
    fill.position = Vector3(2.0, 2.0, 2.4)
    fill.light_energy = 1.1
    fill.omni_range = 5.0
    fill.shadow_enabled = false
    stage.add_child(fill)


func _create_camera(stage: Node3D) -> void:
    camera = Camera3D.new()
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = 1.95
    camera.current = true
    stage.add_child(camera)
