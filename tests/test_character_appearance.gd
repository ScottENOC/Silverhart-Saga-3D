extends SceneTree

func _initialize() -> void:
	_test_appearance_save_reload_and_material_application()
	_test_materials_are_not_shared_between_characters()
	_test_accessory_socket_attach_and_remove()
	print("Character appearance and accessory tests passed.")
	quit()

func _test_appearance_save_reload_and_material_application() -> void:
	var appearance := CharacterAppearance.new()
	appearance.shirt_tint = Color("#9b263d")
	appearance.shirt_fabric = "linen"
	appearance.accessory_ids = PackedStringArray(["earring_hoop_gold", "necklace_silver", "nipple_piercing_left", "nipple_piercing_right", "clitoral_hood_piercing"])
	appearance.tattoo_ids = PackedStringArray(["forearm_bands"])

	var source_material := StandardMaterial3D.new()
	source_material.albedo_color = Color.WHITE
	source_material.roughness = 0.5
	var mesh := BoxMesh.new()
	mesh.material = source_material
	var shirt := MeshInstance3D.new()
	shirt.name = "Shirt"
	shirt.mesh = mesh
	shirt.set_meta("appearance_slot", "shirt")
	var body := Node3D.new()
	body.add_child(shirt)

	appearance.apply_to(body)
	appearance.apply_to(body) # Applying twice must not multiply the tint twice.
	var dyed := shirt.get_surface_override_material(0) as StandardMaterial3D
	assert(dyed != null)
	assert(dyed.albedo_color.is_equal_approx(Color("#9b263d")))
	assert(is_equal_approx(dyed.roughness, 0.96))
	assert(is_equal_approx(source_material.albedo_color.r, 1.0))
	assert(is_equal_approx(source_material.roughness, 0.5))
	appearance.shirt_tint = Color("#315f9b")
	appearance.apply_to(body)
	var redyed := shirt.get_surface_override_material(0) as StandardMaterial3D
	assert(redyed.albedo_color.is_equal_approx(Color("#315f9b")))
	appearance.shirt_opacity = 0.35
	appearance.shirt_visible = false
	appearance.apply_to(body)
	var translucent := shirt.get_surface_override_material(0) as StandardMaterial3D
	assert(is_equal_approx(translucent.albedo_color.a, 0.35))
	assert(translucent.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA)
	assert(not shirt.visible)

	appearance.bra_tint = Color("#9a3650")
	appearance.bra_opacity = 0.6
	appearance.bra_visible = false
	appearance.briefs_tint = Color("#315f9b")
	appearance.briefs_opacity = 0.8
	var bra_material := StandardMaterial3D.new()
	bra_material.resource_name = "Bra"
	var bra_mesh := BoxMesh.new()
	bra_mesh.material = bra_material
	var bra := MeshInstance3D.new()
	bra.name = "AraGeneratedMeshBra"
	bra.mesh = bra_mesh
	body.add_child(bra)
	var briefs_material := StandardMaterial3D.new()
	briefs_material.resource_name = "Briefs"
	var briefs_mesh := BoxMesh.new()
	briefs_mesh.material = briefs_material
	var briefs := MeshInstance3D.new()
	briefs.name = "AraGeneratedMeshBriefs"
	briefs.mesh = briefs_mesh
	body.add_child(briefs)
	appearance.apply_to(body)
	var dyed_bra := bra.get_surface_override_material(0) as StandardMaterial3D
	var dyed_briefs := briefs.get_surface_override_material(0) as StandardMaterial3D
	assert(dyed_bra.albedo_color.is_equal_approx(appearance.bra_tint))
	assert(is_equal_approx(dyed_bra.albedo_color.a, 0.6))
	assert(not bra.visible)
	assert(dyed_briefs.albedo_color.is_equal_approx(appearance.briefs_tint))
	assert(is_equal_approx(dyed_briefs.albedo_color.a, 0.8))

	var path := "user://character_appearance_test.json"
	assert(appearance.save_json(path) == OK)
	var restored := CharacterAppearance.load_json(path)
	assert(restored.shirt_tint.is_equal_approx(appearance.shirt_tint))
	assert(restored.shirt_fabric == "linen")
	assert(is_equal_approx(restored.shirt_opacity, 0.35))
	assert(not restored.shirt_visible)
	assert(restored.bra_tint.is_equal_approx(appearance.bra_tint))
	assert(is_equal_approx(restored.bra_opacity, 0.6))
	assert(not restored.bra_visible)
	assert(restored.briefs_tint.is_equal_approx(appearance.briefs_tint))
	assert(is_equal_approx(restored.briefs_opacity, 0.8))
	assert(restored.accessory_ids == appearance.accessory_ids)
	assert(restored.tattoo_ids == appearance.tattoo_ids)
	restored.apply_to(body)
	assert(not bra.visible)
	assert((bra.get_surface_override_material(0) as StandardMaterial3D).albedo_color.is_equal_approx(appearance.bra_tint))
	assert((briefs.get_surface_override_material(0) as StandardMaterial3D).albedo_color.is_equal_approx(appearance.briefs_tint))
	var after_reload := shirt.get_surface_override_material(0) as StandardMaterial3D
	assert(after_reload.albedo_color.r == appearance.shirt_tint.r)
	assert(is_equal_approx(after_reload.albedo_color.a, 0.35))
	assert(not shirt.visible)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	body.free()

func _test_materials_are_not_shared_between_characters() -> void:
	var shared_material := StandardMaterial3D.new()
	var shared_mesh := BoxMesh.new()
	shared_mesh.material = shared_material
	var a := MeshInstance3D.new()
	a.name = "Shirt"
	a.mesh = shared_mesh
	var b := MeshInstance3D.new()
	b.name = "Shirt"
	b.mesh = shared_mesh
	var root_a := Node3D.new()
	var root_b := Node3D.new()
	root_a.add_child(a)
	root_b.add_child(b)

	var red := CharacterAppearance.new()
	red.shirt_tint = Color.RED
	red.apply_to(root_a)
	var blue := CharacterAppearance.new()
	blue.shirt_tint = Color.BLUE
	blue.apply_to(root_b)
	assert((a.get_surface_override_material(0) as StandardMaterial3D).albedo_color.is_equal_approx(Color.RED))
	assert((b.get_surface_override_material(0) as StandardMaterial3D).albedo_color.is_equal_approx(Color.BLUE))
	assert(shared_material.albedo_color.is_equal_approx(Color.WHITE))
	root_a.free()
	root_b.free()

func _test_accessory_socket_attach_and_remove() -> void:
	var character := Node3D.new()
	var socket := Node3D.new()
	socket.name = "SOCKET_Earring_L"
	character.add_child(socket)
	for socket_name in ["SOCKET_Nipple_L", "SOCKET_Nipple_R", "SOCKET_ClitoralHood"]:
		var piercing_socket := Node3D.new()
		piercing_socket.name = socket_name
		character.add_child(piercing_socket)

	var accessory_root := Node3D.new()
	accessory_root.name = "GoldHoop"
	var packed := PackedScene.new()
	assert(packed.pack(accessory_root) == OK)
	accessory_root.free()

	var attached := AccessoryAttachment.attach(character, "SOCKET_Earring_L", packed, "earring_hoop_gold")
	assert(attached != null)
	assert(attached.get_parent() == socket)
	assert(str(attached.get_meta("accessory_id")) == "earring_hoop_gold")
	assert(AccessoryAttachment.remove_by_id(character, "earring_hoop_gold"))
	assert(not AccessoryAttachment.remove_by_id(character, "earring_hoop_gold"))
	for piercing_id in ["nipple_piercing_left", "nipple_piercing_right", "clitoral_hood_piercing"]:
		var piercing := AccessoryAttachment.attach_piercing(character, piercing_id)
		assert(piercing != null)
		if piercing_id == "clitoral_hood_piercing":
			assert(piercing.mesh is ArrayMesh)
			assert(piercing.get_child_count() == 2)
		else:
			assert(piercing.mesh is TorusMesh)
		assert(str(piercing.get_meta("accessory_id")) == piercing_id)
		assert(AccessoryAttachment.remove_by_id(character, piercing_id))
	character.free()
