extends SceneTree

const ARA_ACTOR = preload("res://scripts/presentation/ara_character_actor.gd")
const FEMALE_BODY := "res://art/characters/ara_runtime/ara_person_body.glb"
const MALE_BODY := "res://art/characters/ara_runtime/ara_person_male_body.glb"
const GARMENT_LIBRARY := "res://art/characters/ara_runtime/ara_person_garments.glb"
const REQUIRED_VISUALS := [
    "bra", "briefs", "fatigue_shirt", "fatigue_pants", "long_tunic",
    "trousers", "tunic", "wrapper_long", "wrapper_knee", "uniform_shirt",
    "tattered_shirt", "sandals", "combat_boots", "leather_armor", "tank_top", "backless_slit_dress"
]

func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var all_available: Array[String] = []
    if not ResourceLoader.exists(GARMENT_LIBRARY):
        _fail("Garment library is missing. Run tools/build_ara_runtime_local.py first.")
        return
    for body_path in [FEMALE_BODY, MALE_BODY]:
        var actor := ARA_ACTOR.new() as AraCharacterActor
        root.add_child(actor)
        if not actor.configure(body_path):
            _fail("Could not load base body: " + body_path)
            return
        actor.set_meta("body_variant", "male" if body_path == MALE_BODY else "female")
        if not actor.configure_modular_garments():
            _fail("Could not attach independent garment library to: " + body_path)
            return

        var available: Array[String] = []
        for garment in actor.modular_garment_meshes:
            var visual := String(garment.get_meta("garment_visual", ""))
            if not available.has(visual):
                available.append(visual)
            if garment.visible:
                _fail("Garment should start unequipped: " + visual)
                return
        for visual in available:
            if not all_available.has(visual):
                all_available.append(visual)

        var body_visibility: Dictionary = {}
        var body_meshes: Array[MeshInstance3D] = []
        _collect_meshes(actor.model_root, body_meshes)
        for mesh in body_meshes:
            if not actor.modular_garment_meshes.has(mesh):
                body_visibility[mesh.get_instance_id()] = mesh.visible

        var test_visual := "bra" if body_path == FEMALE_BODY else "trousers"
        var test_slot := "underTop" if test_visual == "bra" else "pants"
        actor.apply_equipment_visuals({
            test_slot: {"id": test_visual, "garment_visual": test_visual}
        })
        var equipped_visible := false
        for garment in actor.modular_garment_meshes:
            if String(garment.get_meta("garment_visual", "")) == test_visual and garment.visible:
                equipped_visible = true
        if not equipped_visible:
            _fail("Equipping %s did not show an independent garment object for %s." % [test_visual, body_path])
            return

        actor.apply_equipment_visuals({})
        for garment in actor.modular_garment_meshes:
            if garment.visible:
                _fail("Unequipping left a garment visible: " + String(garment.get_meta("garment_visual", "")))
                return
        for mesh in body_meshes:
            if body_visibility.has(mesh.get_instance_id()) and mesh.visible != body_visibility[mesh.get_instance_id()]:
                _fail("Equipment changed base-body mesh visibility: " + mesh.name)
                return

        print("[Character assembly test] PASS body=", body_path, " garments=", available.size())
        actor.queue_free()
        await process_frame
    for required in REQUIRED_VISUALS:
        if not all_available.has(required):
            _fail("Garment library is missing required inventory visual: " + required)
            return
    print("[Character assembly test] PASS: female and male bases use inventory-driven garment objects.")
    quit(0)


func _collect_meshes(node: Node, output: Array[MeshInstance3D]) -> void:
    if node is MeshInstance3D:
        output.append(node as MeshInstance3D)
    for child in node.get_children():
        _collect_meshes(child, output)


func _fail(message: String) -> void:
    push_error("[Character assembly test] " + message)
    quit(1)
