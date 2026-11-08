extends SceneTree

func _initialize() -> void:
    _test_material_profiles_and_surface_isolation()
    print("Equipment appearance tests passed.")
    quit()

func _test_material_profiles_and_surface_isolation() -> void:
    var shared := StandardMaterial3D.new()
    shared.resource_name = "Steel"
    shared.albedo_color = Color(0.4, 0.4, 0.4)
    shared.metallic = 0.8
    var mesh := BoxMesh.new()
    mesh.material = shared
    var prop_a := MeshInstance3D.new()
    prop_a.name = "Sword"
    prop_a.mesh = mesh
    var prop_b := MeshInstance3D.new()
    prop_b.name = "Sword"
    prop_b.mesh = mesh
    var root_a := Node3D.new()
    var root_b := Node3D.new()
    root_a.add_child(prop_a)
    root_b.add_child(prop_b)

    assert(EquipmentAppearance.apply_to(root_a, {"steel":{"profile":"gold"}}) == 1)
    var gold := prop_a.get_active_material(0) as StandardMaterial3D
    assert(gold != null)
    assert(gold.metallic > 0.9)
    assert(gold.albedo_color.is_equal_approx(Color("#d6ad45")))
    assert((prop_b.get_active_material(0) as StandardMaterial3D).albedo_color.is_equal_approx(shared.albedo_color))

    var wood_material := StandardMaterial3D.new()
    wood_material.resource_name = "Oak"
    var wood_mesh := BoxMesh.new()
    wood_mesh.material = wood_material
    var shield := MeshInstance3D.new()
    shield.name = "Shield"
    shield.mesh = wood_mesh
    var shield_root := Node3D.new()
    shield_root.add_child(shield)
    EquipmentAppearance.apply_to(shield_root, {"oak":{"profile":"gold"}})
    var wood := shield.get_active_material(0) as StandardMaterial3D
    assert(wood.metallic == 0.0)
    assert(wood.roughness > 0.7)

    var unknown_material := StandardMaterial3D.new()
    unknown_material.resource_name = "Material.001"
    unknown_material.metallic = 0.15
    unknown_material.roughness = 0.55
    var unknown_mesh := BoxMesh.new()
    unknown_mesh.material = unknown_material
    var unknown_surface := MeshInstance3D.new()
    unknown_surface.name = "UnknownSurface"
    unknown_surface.mesh = unknown_mesh
    var unknown_root := Node3D.new()
    unknown_root.add_child(unknown_surface)
    assert(EquipmentAppearance.apply_to(unknown_root, {"unknown_surface":{"profile":"gold"}}) == 0)
    var preserved := unknown_surface.get_active_material(0) as StandardMaterial3D
    assert(is_equal_approx(preserved.metallic, 0.15))
    assert(is_equal_approx(preserved.roughness, 0.55))
    var heraldry_source := StandardMaterial3D.new()
    heraldry_source.resource_name = "HeraldryFace"
    var heraldry_mesh := BoxMesh.new()
    heraldry_mesh.material = heraldry_source
    var shield_face := MeshInstance3D.new()
    shield_face.mesh = heraldry_mesh
    var heraldry_root := Node3D.new()
    heraldry_root.add_child(shield_face)
    assert(EquipmentAppearance.apply_shield_heraldry(heraldry_root, {
        "field_colour": "#8b2028",
        "secondary_colour": "#e8dfc8",
        "pattern": "halves_vertical",
        "emblem": "tree"
    }) == 1)
    assert(shield_face.get_active_material(0) is ShaderMaterial)
    EquipmentAppearance.apply_to(heraldry_root)
    assert(shield_face.get_active_material(0) is ShaderMaterial)

    root_a.free()
    root_b.free()
    shield_root.free()
    heraldry_root.free()
    unknown_root.free()
