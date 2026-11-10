extends SceneTree

const ARA_ACTOR = preload("res://scripts/presentation/ara_character_actor.gd")
const WREN_BODY := "res://art/characters/ara_runtime/bodies/wren_talbot.glb"
const GARMENT_LIBRARY := "res://art/characters/ara_runtime/ara_person_garments.glb"
const REQUIRED_VISUALS := ["bra", "fatigue_shirt", "fatigue_pants", "combat_boots"]

func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    if not ResourceLoader.exists(WREN_BODY):
        _fail("Wren's profile-generated bare body is missing. Run tools/build_ara_runtime_local.py first.")
        return
    if not ResourceLoader.exists(GARMENT_LIBRARY):
        _fail("Wren's profile-matched garment library is missing. Run tools/build_ara_runtime_local.py first.")
        return

    var actor := ARA_ACTOR.new() as AraCharacterActor
    root.add_child(actor)
    actor.set_meta("body_variant", "female")
    if not actor.configure(WREN_BODY):
        _fail("Could not load Wren's profile-generated Ara body.")
        return
    if String(actor.get_meta("body_profile_id", "")) != "wren_talbot":
        _fail("Wren body path did not resolve to the wren_talbot profile id.")
        return
    if String(actor.get_meta("body_variant", "")) != "female":
        _fail("Wren's profile body was not identified as the female Ara variant.")
        return
    if not bool(actor.get_meta("body_profile_baked", false)):
        _fail("Wren's profile-specific body was not marked as macro-morph baked.")
        return

    var body_meshes: Array[MeshInstance3D] = []
    _collect_meshes(actor.model_root, body_meshes)
    var facial_morph_count := 0
    for mesh in body_meshes:
        if mesh.mesh != null:
            facial_morph_count = maxi(facial_morph_count, mesh.mesh.get_blend_shape_count())
    if facial_morph_count < 20:
        _fail("Wren's Ara body is missing its expected facial blend shapes: %d" % facial_morph_count)
        return

    actor.apply_body_parameters({"muscle": 0.62, "weight": 0.42, "height": 0.55, "proportions": 0.58})
    if int(actor.get_meta("body_morph_targets_applied", -1)) != 0:
        _fail("Baked Ara body settings should not be applied a second time as runtime morphs.")
        return

    if not actor.configure_modular_garments():
        _fail("Could not attach Wren's matching independent garment library.")
        return

    var available: Array[String] = []
    for garment in actor.modular_garment_meshes:
        var visual := String(garment.get_meta("garment_visual", ""))
        if not available.has(visual):
            available.append(visual)
        if garment.visible:
            _fail("Garment should start unequipped: " + visual)
            return
        if garment.skin == null or garment.skeleton.is_empty():
            _fail("Garment is not independently skinned: " + garment.name)
            return
        var bound_skeleton := garment.get_node_or_null(garment.skeleton) as Skeleton3D
        var actor_skeleton := actor._find_skeleton(actor.model_root)
        if bound_skeleton == null or bound_skeleton != actor_skeleton:
            _fail("Garment is not bound to Wren's skeleton: " + garment.name)
            return

    for required in REQUIRED_VISUALS:
        if not available.has(required):
            _fail("Wren's garment library is missing required inventory visual: " + required)
            return

    var body_visibility: Dictionary = {}
    for mesh in body_meshes:
        body_visibility[mesh.get_instance_id()] = mesh.visible

    actor.apply_equipment_visuals({
        "underTop": {"id": "bra", "garment_visual": "bra"}
    })
    var equipped_visible := false
    for garment in actor.modular_garment_meshes:
        if String(garment.get_meta("garment_visual", "")) == "bra" and garment.visible:
            equipped_visible = true
    if not equipped_visible:
        _fail("Equipping Wren's bra did not show its independent garment mesh.")
        return

    actor.apply_equipment_visuals({})
    for garment in actor.modular_garment_meshes:
        if garment.visible:
            _fail("Unequipping left a garment visible: " + String(garment.get_meta("garment_visual", "")))
            return
    for mesh in body_meshes:
        if mesh.visible != body_visibility[mesh.get_instance_id()]:
            _fail("Equipment changed base-body mesh visibility: " + mesh.name)
            return

    print("[Character assembly test] PASS Wren bare Ara body, facial morphs, profile-matched garments and equip/unequip.")
    quit(0)


func _collect_meshes(node: Node, output: Array[MeshInstance3D]) -> void:
    if node is MeshInstance3D:
        output.append(node as MeshInstance3D)
    for child in node.get_children():
        _collect_meshes(child, output)


func _fail(message: String) -> void:
    push_error("[Character assembly test] " + message)
    quit(1)
