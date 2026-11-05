extends SceneTree

func _initialize() -> void:
	_test_appearance_save_reload_and_material_application()
	print("CharacterAppearance tests passed.")
	quit()

func _test_appearance_save_reload_and_material_application() -> void:
	var appearance := CharacterAppearance.new()
	appearance.shirt_tint = Color("#9b263d")
	appearance.shirt_fabric = "linen"
	appearance.accessory_ids = PackedStringArray(["earring_hoop_gold", "necklace_silver"])
	appearance.tattoo_ids = PackedStringArray(["forearm_bands"])

	var shirt := MeshInstance3D.new()
	shirt.name = "Shirt"
	shirt.set_meta("appearance_slot", "shirt")
	shirt.material_override = StandardMaterial3D.new()
	var body := Node3D.new()
	body.add_child(shirt)
	appearance.apply_to(body)
	assert(shirt.material_override.albedo_color.is_equal_approx(Color("#9b263d")))
	assert(is_equal_approx(shirt.material_override.roughness, 0.96))

	var path := "user://character_appearance_test.json"
	assert(appearance.save_json(path) == OK)
	var restored := CharacterAppearance.load_json(path)
	assert(restored.shirt_tint.is_equal_approx(appearance.shirt_tint))
	assert(restored.shirt_fabric == "linen")
	assert(restored.accessory_ids == appearance.accessory_ids)
	assert(restored.tattoo_ids == appearance.tattoo_ids)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	body.free()
