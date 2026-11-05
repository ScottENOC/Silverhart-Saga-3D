extends SceneTree

func _initialize() -> void:
	_test_appearance_save_reload_and_material_application()
	_test_materials_are_not_shared_between_characters()
	print("CharacterAppearance tests passed.")
	quit()

func _test_appearance_save_reload_and_material_application() -> void:
	var appearance := CharacterAppearance.new()
	appearance.shirt_tint = Color("#9b263d")
	appearance.shirt_fabric = "linen"
	appearance.accessory_ids = PackedStringArray(["earring_hoop_gold", "necklace_silver"])
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
	var dyed := shirt.get_active_material(0) as StandardMaterial3D
	assert(dyed != null)
	assert(dyed.albedo_color.is_equal_approx(Color("#9b263d")))
	assert(is_equal_approx(dyed.roughness, 0.96))
	assert(is_equal_approx(source_material.albedo_color.r, 1.0))
	assert(is_equal_approx(source_material.roughness, 0.5))

	var path := "user://character_appearance_test.json"
	assert(appearance.save_json(path) == OK)
	var restored := CharacterAppearance.load_json(path)
	assert(restored.shirt_tint.is_equal_approx(appearance.shirt_tint))
	assert(restored.shirt_fabric == "linen")
	assert(restored.accessory_ids == appearance.accessory_ids)
	assert(restored.tattoo_ids == appearance.tattoo_ids)
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
	assert((a.get_active_material(0) as StandardMaterial3D).albedo_color.is_equal_approx(Color.RED))
	assert((b.get_active_material(0) as StandardMaterial3D).albedo_color.is_equal_approx(Color.BLUE))
	assert(shared_material.albedo_color.is_equal_approx(Color.WHITE))
	root_a.free()
	root_b.free()
