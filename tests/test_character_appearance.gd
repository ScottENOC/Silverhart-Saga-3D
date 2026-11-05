extends SceneTree

func _initialize() -> void:
    var appearance := CharacterAppearance.new()
    appearance.body_variant = "ara_female_athletic"
    appearance.hair_id = "ponytail01"
    appearance.hair_tint = Color("#6f3428")
    appearance.tattoos.append("forearm_l")
    appearance.accessories = {"ear.left": "silver_hoop", "nose.ring": "small_silver"}
    appearance.equipment["shirt"] = "fatigue_shirt"
    appearance.equipment["main_hand"] = "sword"
    appearance.materials["shirt"] = {
        "colour": "#9c2632",
        "secondary": "#d9b7a4",
        "fabric": "linen",
        "opacity": 1.0
    }
    var assembler := ModularCharacterAssembler.new()
    root.add_child(assembler)
    var shirt_mount := Node3D.new()
    assembler.slot_mounts["shirt"] = shirt_mount
    assembler.add_child(shirt_mount)
    var shirt_mesh := MeshInstance3D.new()
    shirt_mesh.mesh = BoxMesh.new()
    var shirt_material := StandardMaterial3D.new()
    shirt_material.albedo_color = Color.WHITE
    shirt_mesh.material_override = shirt_material
    shirt_mount.add_child(shirt_mesh)
    assert(assembler.set_garment_material("shirt", appearance.materials["shirt"]), "Runtime fabric material update failed")
    var runtime_material := shirt_mesh.get_surface_override_material(0) as ShaderMaterial
    assert(runtime_material != null, "Fabric shader override was not applied")
    assert(int(runtime_material.get_shader_parameter("fabric_mode")) == 1, "Linen fabric mode was not selected")
    assert(Color(runtime_material.get_shader_parameter("tint")).is_equal_approx(Color("#9c2632")), "Shirt dye was not applied")

    var skeleton := Skeleton3D.new()
    for bone_name in ["Hips", "Spine2", "Head", "RightHand", "LeftHand"]:
        skeleton.add_bone(bone_name)
    root.add_child(skeleton)
    var calibration := {"sockets": {}}
    for socket_id in CharacterAttachmentRig.SOCKETS:
        calibration.sockets[socket_id] = {"calibrated": true}
    var attachment_rig := CharacterAttachmentRig.new()
    root.add_child(attachment_rig)
    assert(attachment_rig.configure(skeleton, calibration), "Attachment rig failed to configure")
    assert(attachment_rig.attach("ear.left", CharacterAccessoryFactory.make_earring("silver_hoop")), "Left earring socket failed")
    assert(attachment_rig.attach("ear.right", CharacterAccessoryFactory.make_earring("silver_hoop_right")), "Right earring socket failed")
    assert(attachment_rig.attach("nose.ring", CharacterAccessoryFactory.make_ring("nose_ring")), "Nose ring socket failed")
    assert(attachment_rig.attach("necklace", CharacterAccessoryFactory.make_necklace("silver_chain")), "Necklace socket failed")
    assert(attachment_rig.attach("nipple.left", CharacterAccessoryFactory.make_ring("nipple_ring")), "Nipple socket failed")
    assert(attachment_rig.attach("clitoral_hood", CharacterAccessoryFactory.make_ring("hood_ring")), "Pelvic socket failed")

    assembler.current_body_variant = "ara_female_slim"
    assert(assembler._component_path("shirt", "tank_top").ends_with("shirt_alt.glb"), "Alternate shirt did not resolve")
    assert(assembler._component_path("trousers", "cargo_shorts").ends_with("trousers_alt.glb"), "Alternate trousers did not resolve")
    assert(assembler._component_path("boots", "combat_boots").ends_with("boots.glb"), "Boot component did not resolve")
    assert(assembler._component_path("main_hand", "sword").ends_with("weapon_sword.glb"), "Sword component did not resolve")

    var save_error := CharacterAppearanceStore.save_appearance("npc_test_01", appearance)
    assert(save_error == OK, "Appearance save failed: %s" % error_string(save_error))
    var loaded := CharacterAppearanceStore.load_appearance("npc_test_01")
    assert(loaded.body_variant == appearance.body_variant)
    assert(loaded.hair_id == appearance.hair_id)
    assert(loaded.hair_tint.is_equal_approx(appearance.hair_tint))
    assert(loaded.equipment["shirt"] == "fatigue_shirt")
    assert(loaded.materials["shirt"]["colour"] == "#9c2632")
    assert(loaded.materials["shirt"]["fabric"] == "linen")
    assert(assembler.set_garment_material("shirt", loaded.materials["shirt"]), "Reloaded material could not be reapplied")
    runtime_material = shirt_mesh.get_surface_override_material(0) as ShaderMaterial
    assert(runtime_material != null and int(runtime_material.get_shader_parameter("fabric_mode")) == 1)
    assert(loaded.accessories["nose.ring"] == "small_silver")
    print("Character appearance save/reload test passed.")
    quit(0)
