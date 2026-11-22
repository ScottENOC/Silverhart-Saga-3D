extends SceneTree
## Actual Wren + generated Ara bra attachment/render test.
const ACTOR_SCRIPT = preload("res://scripts/presentation/ara_character_actor.gd")
const WREN_PATH := "res://build/wren-native/Wren.glb"
const BRA_ID := "bra"
const OUTPUT_DIR := "res://build/wren-bra-attachment-review"
const SIZE := Vector2i(1280, 1200)

var actor: AraCharacterActor
var camera: Camera3D

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    root.size = SIZE
    actor = ACTOR_SCRIPT.new() as AraCharacterActor
    root.add_child(actor)
    if not ResourceLoader.exists(WREN_PATH):
        push_error("WREN_BRA_TEST_FAIL: native Wren model is missing")
        quit(1)
        return
    if not actor.configure(WREN_PATH):
        push_error("WREN_BRA_TEST_FAIL: AraCharacterActor could not configure native Wren")
        quit(1)
        return
    var bra_path := "res://art/characters/ara_runtime/garments/female_bra.glb"
    if not ResourceLoader.exists(bra_path):
        push_error("WREN_BRA_TEST_FAIL: generated standalone bra is missing")
        quit(1)
        return
    if not actor._load_garment_attachment(BRA_ID):
        push_error("WREN_BRA_TEST_FAIL: bra attachment rejected; inspect skeleton compatibility and import logs")
        quit(1)
        return
    var attachments: Dictionary = actor.get("garment_attachments")
    var meshes: Array = attachments.get(BRA_ID, [])
    if meshes.is_empty():
        push_error("WREN_BRA_TEST_FAIL: attachment produced no mesh instances")
        quit(1)
        return
    for mesh in meshes:
        mesh.visible = true
    _build_stage()
    await process_frame
    var out := ProjectSettings.globalize_path(OUTPUT_DIR)
    DirAccess.make_dir_recursive_absolute(out)
    var views := {
        "front": [Vector3(0.0, 1.2, 4.2), Vector3(0.0, 1.2, 0.0)],
        "side": [Vector3(4.2, 1.2, 0.0), Vector3(0.0, 1.2, 0.0)],
        "rear": [Vector3(0.0, 1.2, -4.2), Vector3(0.0, 1.2, 0.0)]
    }
    for view_name in views:
        camera.position = views[view_name][0]
        camera.look_at(views[view_name][1], Vector3.UP)
        await process_frame
        await process_frame
        await RenderingServer.frame_post_draw
        var image := root.get_texture().get_image()
        var error := image.save_png(out.path_join(view_name + ".png"))
        if error != OK:
            push_error("WREN_BRA_TEST_FAIL: could not save " + view_name + " render")
            quit(1)
            return
    camera.size = 0.92
    var close_views := {
        "front-closeup": [Vector3(0.0, 1.24, 2.6), Vector3(0.0, 1.24, 0.0)],
        "side-closeup": [Vector3(2.6, 1.24, 0.0), Vector3(0.0, 1.24, 0.0)],
        "rear-closeup": [Vector3(0.0, 1.24, -2.6), Vector3(0.0, 1.24, 0.0)]
    }
    for view_name in close_views:
        camera.position = close_views[view_name][0]
        camera.look_at(close_views[view_name][1], Vector3.UP)
        await process_frame
        await process_frame
        await RenderingServer.frame_post_draw
        var close_image := root.get_texture().get_image()
        var close_error := close_image.save_png(out.path_join(view_name + ".png"))
        if close_error != OK:
            push_error("WREN_BRA_TEST_FAIL: could not save " + view_name + " render")
            quit(1)
            return
    camera.size = 2.15
    var report := {
        "status": "RENDERED_REQUIRES_VISUAL_REVIEW",
        "character_asset": WREN_PATH,
        "garment_asset": bra_path,
        "garment_id": BRA_ID,
        "attachment_mesh_count": meshes.size(),
        "skeleton_bone_count": _find_skeleton(actor.model_root).get_bone_count(),
        "views": ["front", "side", "rear"],\n        "close_up_views": ["front-closeup", "side-closeup", "rear-closeup"],
        "note": "Successful attachment proves skeleton acceptance and produces native Wren renders; it does not by itself prove anatomical fit."
    }
    var file := FileAccess.open(out.path_join("report.json"), FileAccess.WRITE)
    file.store_string(JSON.stringify(report, "\t"))
    file.close()
    print("WREN_BRA_ATTACHMENT_REVIEW_OK meshes=%d" % meshes.size())
    quit(0)

func _build_stage() -> void:
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color("#252a30")
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color("#c5cbd2")
    environment.ambient_light_energy = 0.8
    var world := WorldEnvironment.new()
    world.environment = environment
    root.add_child(world)
    var light := DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-25.0, -25.0, 0.0)
    light.light_energy = 1.4
    root.add_child(light)
    camera = Camera3D.new()
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = 2.15
    camera.current = true
    root.add_child(camera)

func _find_skeleton(node: Node) -> Skeleton3D:
    if node is Skeleton3D:
        return node as Skeleton3D
    for child in node.get_children():
        var found := _find_skeleton(child)
        if found != null:
            return found
    return null
