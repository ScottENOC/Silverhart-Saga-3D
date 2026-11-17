extends SceneTree
## Loads the isolated Ara muscle-morph candidate in Godot, applies each imported
## blend shape at runtime, and compares it with the existing production body.

const MODEL_PATH := "res://build/ara_person_body_anatomy_morphs.glb"
const PRODUCTION_PATH := "res://art/characters/ara_runtime/ara_person_body_anatomy.glb"
const OUTPUT_DIR := "res://build/ara-morph-renders"
const VIEW_SIZE := Vector2i(640, 800)
const MORPH_NAMES := ["body_muscle_low", "body_muscle_high"]

var mesh_instances: Array[MeshInstance3D] = []
var morph_indices: Dictionary = {}
var camera: Camera3D

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    root.size = VIEW_SIZE
    var packed := load(MODEL_PATH) as PackedScene
    var production_packed := load(PRODUCTION_PATH) as PackedScene
    if packed == null or production_packed == null:
        push_error("Could not load candidate or production Ara body GLB")
        quit(1)
        return

    var stage := Node3D.new()
    stage.name = "MorphPreviewStage"
    root.add_child(stage)

    var candidate := packed.instantiate() as Node3D
    var production := production_packed.instantiate() as Node3D
    if candidate == null or production == null:
        push_error("Candidate or production Ara GLB did not instantiate as Node3D")
        quit(1)
        return
    candidate.name = "AraMorphCandidate"
    production.name = "AraProductionBaseline"
    stage.add_child(candidate)
    stage.add_child(production)
    production.visible = false

    _collect_meshes(candidate)
    for mesh_instance in mesh_instances:
        var mesh := mesh_instance.mesh
        for index in range(mesh.get_blend_shape_count()):
            var shape_name := String(mesh.get_blend_shape_name(index))
            if not morph_indices.has(shape_name):
                morph_indices[shape_name] = []
            morph_indices[shape_name].append({"mesh": mesh_instance, "index": index})
            print("GODOT_MORPH_FOUND mesh=%s name=%s initial_value=%.3f" % [
                mesh_instance.name, shape_name, mesh_instance.get_blend_shape_value(index)
            ])

    for required_name in MORPH_NAMES:
        if not morph_indices.has(required_name):
            push_error("Godot did not import expected blend shape: " + required_name)
            quit(1)
            return

    _set_all_morphs(0.0)
    _create_lighting(stage)
    _create_camera(stage)

    var output_absolute := ProjectSettings.globalize_path(OUTPUT_DIR)
    DirAccess.make_dir_recursive_absolute(output_absolute)

    for state in ["production", "neutral", "low", "high"]:
        production.visible = state == "production"
        candidate.visible = state != "production"
        _set_all_morphs(0.0)
        if state == "low":
            _set_morph("body_muscle_low", 1.0)
        elif state == "high":
            _set_morph("body_muscle_high", 1.0)

        for view in ["front", "side"]:
            _position_camera(view)
            await process_frame
            await process_frame
            await process_frame
            var image := root.get_texture().get_image()
            if image == null or image.is_empty():
                push_error("Godot returned an empty viewport image for %s-%s" % [view, state])
                quit(1)
                return
            var output_path := output_absolute.path_join("%s-%s.png" % [view, state])
            var save_error := image.save_png(output_path)
            if save_error != OK:
                push_error("Could not save render %s (error %d)" % [output_path, save_error])
                quit(1)
                return
            print("GODOT_RENDER_OK state=%s view=%s path=%s" % [state, view, output_path])

    print("GODOT_MORPH_TEST_OK imported=%s renders=8" % [str(morph_indices.keys())])
    quit(0)

func _collect_meshes(node: Node) -> void:
    if node is MeshInstance3D and node.mesh != null:
        mesh_instances.append(node as MeshInstance3D)
    for child in node.get_children():
        _collect_meshes(child)

func _set_all_morphs(value: float) -> void:
    for shape_name in morph_indices:
        _set_morph(String(shape_name), value)

func _set_morph(shape_name: String, value: float) -> void:
    for entry in morph_indices.get(shape_name, []):
        var mesh_instance: MeshInstance3D = entry["mesh"]
        mesh_instance.set_blend_shape_value(int(entry["index"]), value)

func _create_lighting(stage: Node3D) -> void:
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color("#252a30")
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color("#b8c0c9")
    environment.ambient_light_energy = 0.32
    environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    environment.tonemap_exposure = 0.82
    var world := WorldEnvironment.new()
    world.environment = environment
    stage.add_child(world)

    var light := DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-24.0, -28.0, 0.0)
    light.light_energy = 0.95
    light.shadow_enabled = false
    stage.add_child(light)

func _create_camera(stage: Node3D) -> void:
    camera = Camera3D.new()
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = 1.95
    camera.current = true
    stage.add_child(camera)

func _position_camera(view: String) -> void:
    if view == "front":
        camera.position = Vector3(0.0, 0.82, 4.2)
    else:
        camera.position = Vector3(4.2, 0.82, 0.0)
    camera.look_at(Vector3(0.0, 0.82, 0.0), Vector3.UP)
