extends SceneTree

func _initialize() -> void:
	await _test_player_male_anatomy_creation_save_restore()
	await _test_creator_preview_faces_camera()
	_test_appearance_save_reload_and_material_application()
	_test_materials_are_not_shared_between_characters()
	_test_accessory_socket_attach_and_remove()
	_test_campaign_character_actor_factory()
	_test_shared_ara_npc_models_and_wren_appearance()
	print("Character appearance, player anatomy customisation and accessory tests passed.")
	quit()


func _test_player_male_anatomy_creation_save_restore() -> void:
	const SAVE_PATH := "user://player_appearance.json"
	var previous_save_exists := FileAccess.file_exists(SAVE_PATH)
	var previous_save := FileAccess.get_file_as_string(SAVE_PATH) if previous_save_exists else ""
	if previous_save_exists:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

	var creator_script := load("res://scripts/ui/player_character_creator.gd") as Script
	assert(creator_script != null, "Player character creator script must load")
	var creator: Variant = creator_script.new()
	creator.preview_enabled = false
	root.add_child(creator)
	assert(creator.male_anatomy_length_slider != null)
	assert(creator.male_anatomy_girth_slider != null)
	creator.body_variant_select.select(1)
	creator.male_anatomy_length_slider.value = 0.25
	creator.male_anatomy_girth_slider.value = 0.75

	var emitted_profiles: Array[Dictionary] = []
	creator.completed.connect(func(profile: Dictionary) -> void:
		emitted_profiles.append(profile)
	)
	creator._finish()
	await process_frame
	assert(emitted_profiles.size() == 1, "Character creation must emit the completed player profile")
	assert(FileAccess.file_exists(SAVE_PATH), "Character creation must persist the player profile")

	var saved_profile: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	assert(saved_profile is Dictionary, "Saved player appearance must be valid JSON")
	var profile: Dictionary = saved_profile
	assert(profile.get("body_variant") == "male")
	assert(is_equal_approx(float(profile.get("male_anatomy_length_percentile", -1.0)), 0.25))
	assert(is_equal_approx(float(profile.get("male_anatomy_girth_percentile", -1.0)), 0.75))

	var expected_length := (13.12 + lerpf(-1.644854, 1.644854, 0.25) * 1.66) / 13.12
	var expected_girth := (11.66 + lerpf(-1.644854, 1.644854, 0.75) * 1.10) / 11.66
	assert(is_equal_approx(float(profile.get("male_anatomy_length_scale", 0.0)), expected_length))
	assert(is_equal_approx(float(profile.get("male_anatomy_girth_scale", 0.0)), expected_girth))

	var restored: Variant = creator_script.new()
	restored.preview_enabled = false
	root.add_child(restored)
	assert(restored.body_variant_select.get_item_text(restored.body_variant_select.selected) == "Male")
	assert(restored.male_anatomy_section.visible, "Male anatomy controls must be visible after restoring a male profile")
	assert(is_equal_approx(restored.male_anatomy_length_slider.value, 0.25))
	assert(is_equal_approx(restored.male_anatomy_girth_slider.value, 0.75))

	if ResourceLoader.exists("res://art/characters/ara_runtime/ara_player_male_body.glb"):
		var actor := AraCharacterActor.new()
		root.add_child(actor)
		assert(actor.configure("res://art/characters/ara_runtime/ara_player_male_body.glb"))
		actor.apply_player_profile(profile)
		var applied: Dictionary = actor.get_meta("male_anatomy_size_scales", {})
		assert(is_equal_approx(float(applied.get("length", 0.0)), expected_length), "Saved length choice must reach the male anatomy rig")
		assert(is_equal_approx(float(applied.get("girth", 0.0)), expected_girth), "Saved circumference choice must reach the male anatomy rig")
		actor.queue_free()

	restored.queue_free()
	await process_frame
	if previous_save_exists:
		var restore_file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		assert(restore_file != null)
		restore_file.store_string(previous_save)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

func _test_creator_preview_faces_camera() -> void:
	var creator_script := load("res://scripts/ui/player_character_creator.gd") as Script
	assert(creator_script != null, "Player character creator script must load")
	var creator: Variant = creator_script.new()
	creator.preview_enabled = false
	root.add_child(creator)
	assert(creator.preview_actor != null, "Character creator must construct its preview actor")
	assert(absf(absf(creator.preview_actor.rotation.y) - PI) < 0.001,
		"Character creator preview must cancel the gameplay model's 180-degree yaw correction")
	creator._rotate_preview(30.0)
	assert(is_equal_approx(creator.preview_actor.rotation.y, PI + deg_to_rad(30.0)),
		"Preview rotation controls must rotate relative to the camera-facing starting pose")
	creator.queue_free()
	await process_frame


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
	var dyed := shirt.get_active_material(0) as StandardMaterial3D
	assert(dyed != null)
	assert(dyed.albedo_color.is_equal_approx(Color("#9b263d")))
	assert(is_equal_approx(dyed.roughness, 0.96))
	assert(is_equal_approx(source_material.albedo_color.r, 1.0))
	assert(is_equal_approx(source_material.roughness, 0.5))
	appearance.shirt_tint = Color("#315f9b")
	appearance.apply_to(body)
	var redyed := shirt.get_active_material(0) as StandardMaterial3D
	assert(redyed.albedo_color.is_equal_approx(Color("#315f9b")))
	appearance.shirt_opacity = 0.35
	appearance.shirt_visible = false
	appearance.apply_to(body)
	var translucent := shirt.get_active_material(0) as StandardMaterial3D
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
	var dyed_bra := bra.get_active_material(0) as StandardMaterial3D
	var dyed_briefs := briefs.get_active_material(0) as StandardMaterial3D
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
	assert((bra.get_active_material(0) as StandardMaterial3D).albedo_color.is_equal_approx(appearance.bra_tint))
	assert((briefs.get_active_material(0) as StandardMaterial3D).albedo_color.is_equal_approx(appearance.briefs_tint))
	var after_reload := shirt.get_active_material(0) as StandardMaterial3D
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
	assert((a.get_active_material(0) as StandardMaterial3D).albedo_color.is_equal_approx(Color.RED))
	assert((b.get_active_material(0) as StandardMaterial3D).albedo_color.is_equal_approx(Color.BLUE))
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


func _test_campaign_character_actor_factory() -> void:
	if not ResourceLoader.exists("res://art/characters/ara_runtime/ara_player_female_body.glb"):
		print("CAMPAIGN_CHARACTER_ACTOR_FACTORY_TEST: SKIPPED (generated player body is not installed yet)")
		return
	var state := CharacterState.new("factory_player", "Factory Player", Vector2i(-1, 2))
	var profile := {"name": "Factory Player", "body_variant": "female", "hair_style_id": "short02"}
	var actor := CampaignCharacterActorFactory.create_actor(
		state,
		Vector3(1.5, 0.0, -2.0),
		true,
		profile,
		{},
		"",
		"civilian"
	)
	assert(actor != null)
	assert(actor.name == "factory_player")
	assert(actor.position.is_equal_approx(Vector3(1.5, 0.0, -2.0)))
	assert(actor.get_meta("character_id") == "factory_player")
	assert(not actor.get_meta("ambient_enabled"))
	assert(actor.get_meta("ambient_role") == "civilian")
	var name_label := actor.get_node_or_null("PlayerNameLabel") as Label3D
	assert(name_label != null and name_label.text == "You")
	var model := actor.get_node_or_null("CharacterModel") as AraCharacterActor
	assert(model != null)
	assert(model.loaded_asset_path != "")
	assert(not model.hair_instances.is_empty(), "The standalone player hairstyle must bind to the generated body skeleton")
	var original_hair_count := model.hair_instances.size()
	assert(model.set_hairstyle("res://art/characters/ara_runtime/hair/female_short02.glb"))
	assert(model.hair_instances.size() == original_hair_count, "Replacing a hairstyle must not stack duplicate meshes")
	actor.free()


func _test_shared_ara_npc_models_and_wren_appearance() -> void:
	if ResourceLoader.exists("res://art/characters/ara_runtime/ara_player_male_body.glb"):
		var male_state := CharacterState.new("garrick_test", "Garrick", Vector2i.ZERO)
		var male_profile := {
			"params": {
				"gender": 1,
				"age": 0.7,
				"height": 0.52,
				"muscle": 0.58,
				"weight": 0.7,
				"eyes": "brown",
				"hair": "short02",
				"hairTint": "#776e61"
			}
		}
		var male_actor := CampaignCharacterActorFactory.create_actor(
			male_state, Vector3.ZERO, false, {}, male_profile, "garrick_holt.glb", "civilian"
		)
		assert(male_actor != null)
		var male_model := male_actor.get_node_or_null("CharacterModel") as AraCharacterActor
		assert(male_model != null)
		assert(male_model.loaded_asset_path == "res://art/characters/ara_runtime/ara_player_male_body.glb")
		assert(male_model.apply_male_anatomy_size(1.10, 1.10), "Male anatomy size controls must bind to AnatomyRoot")
		var applied_size: Dictionary = male_model.get_meta("male_anatomy_size_scales", {})
		assert(is_equal_approx(float(applied_size.get("length", 0.0)), 1.10))
		assert(is_equal_approx(float(applied_size.get("girth", 0.0)), 1.10))
		male_actor.free()

		var aldric_state := CharacterState.new("companion_ser_aldric_thorne", "Ser Aldric Thorne", Vector2i.ZERO)
		var aldric_profile := {
			"params": {"gender": 1, "age": 0.62, "height": 0.68, "muscle": 0.72, "weight": 0.58},
			"anatomy_size": {"length_scale": 1.10, "girth_scale": 1.10}
		}
		var aldric_actor := CampaignCharacterActorFactory.create_actor(
			aldric_state, Vector3.ZERO, false, {}, aldric_profile, "aldric.glb", "companion"
		)
		assert(aldric_actor != null)
		var aldric_model := aldric_actor.get_node_or_null("CharacterModel") as AraCharacterActor
		assert(aldric_model != null)
		assert(aldric_model.apply_male_anatomy_size(1.0, 1.0), "Aldric's accepted model must expose the anatomy rig")
		var aldric_size: Dictionary = aldric_model.get_meta("male_anatomy_size_requested", {})
		assert(is_equal_approx(float(aldric_size.get("length_scale", 0.0)), 1.10))
		assert(is_equal_approx(float(aldric_size.get("girth_scale", 0.0)), 1.10))
		aldric_actor.free()

		var settlement_actor := CampaignCharacterActorFactory.create_settlement_actor({
			"id": "rurik_test",
			"name": "Rurik",
			"appearance": {
				"gender_presentation": "Masculine",
				"height_scale": 1.03,
				"build_scale": 1.045,
				"hair_style": "short02"
			}
		}, Vector3.ZERO)
		assert(settlement_actor != null)
		var settlement_model := settlement_actor.get_node_or_null("CharacterModel") as AraCharacterActor
		assert(settlement_model != null)
		assert(settlement_model.loaded_asset_path == "res://art/characters/ara_runtime/ara_player_male_body.glb")
		settlement_actor.free()
	
	else:
		print("CAMPAIGN_MALE_CHARACTER_TEST: SKIPPED (generated male player body is not installed yet)")

	var wren_state := CharacterState.new("companion_wren_talbot", "Wren", Vector2i.ZERO)
	var wren_profile := {
		"params": {
			"gender": 0,
			"age": 0.5,
			"height": 0.55,
			"muscle": 0.62,
			"weight": 0.42,
			"proportions": 0.58,
			"breasts": 0.76,
			"legs": 0.62,
			"eyes": "green",
			"skinTint": "#a1845b",
			"hair": "braid01",
			"hairTint": "#252b62"
		}
	}
	var wren_actor := CampaignCharacterActorFactory.create_actor(
		wren_state, Vector3.ZERO, false, {}, wren_profile, "wren_talbot.glb", "companion"
	)
	assert(wren_actor != null)
	var wren_model := wren_actor.get_node_or_null("CharacterModel") as AraCharacterActor
	assert(wren_model != null)
	assert(wren_model.loaded_asset_path == "res://art/characters/companions/wren.glb")
	assert(wren_model.body_variant == "female")
	assert(wren_model.hair_instances.is_empty(), "Approved Wren build should retain its baked braid, not attach a duplicate")
	assert(not wren_model.has_meta("body_parameters"), "Approved Wren appearance must not be overwritten by generic NPC morphs")
	assert(not wren_model.has_meta("skin_surfaces_tinted"), "Approved Wren complexion must remain baked into her accepted model")
	CampaignCharacterActorFactory.apply_npc_parameters(wren_model, {"gender": 0, "skinTint": "#ffffff", "hairTint": "#ffffff"})
	assert(not wren_model.has_meta("body_parameters"), "Generic NPC updates must not overwrite the approved Wren build")
	wren_actor.free()


func _collect_blend_shape_names(node: Node, output: Array[String]) -> void:
	if node is MeshInstance3D and node.mesh != null:
		for index in range(node.mesh.get_blend_shape_count()):
			var shape_name := String(node.mesh.get_blend_shape_name(index))
			if not output.has(shape_name):
				output.append(shape_name)
	for child in node.get_children():
		_collect_blend_shape_names(child, output)
