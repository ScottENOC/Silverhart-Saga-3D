extends SceneTree


func _initialize() -> void:
	await process_frame
	_test_combat_hud_presentation_and_actions()
	_test_dialogue_panel_presentation_and_choice_signal()
	_test_character_portrait_renderer()
	await _test_ambient_dialogue_presenter()
	print("Campaign UI and character portrait tests passed.")
	quit()


func _test_combat_hud_presentation_and_actions() -> void:
	var hud := CampaignCombatHud.new()
	root.add_child(hud)
	assert(not hud.visible)
	assert(hud.attack_button != null)
	assert(hud.end_turn_button != null)
	assert(hud.status_label != null)

	var attack_requested := false
	var end_turn_requested := false
	hud.attack_requested.connect(func(): attack_requested = true)
	hud.end_turn_requested.connect(func(): end_turn_requested = true)
	hud.attack_button.emit_signal("pressed")
	hud.end_turn_button.emit_signal("pressed")
	assert(attack_requested)
	assert(end_turn_requested)

	hud.present(true, false, false, "Not your turn.")
	assert(hud.visible)
	assert(hud.end_turn_button.disabled)
	assert(hud.attack_button.disabled)
	assert(hud.status_label.text == "Not your turn.")

	hud.present(true, true, true, "Ready.")
	assert(not hud.end_turn_button.disabled)
	assert(not hud.attack_button.disabled)
	assert(hud.status_label.text == "Ready.")
	hud.set_status_text("Attack resolved.")
	assert(hud.status_label.text == "Attack resolved.")

	hud.present(false, false, false, "")
	assert(not hud.visible)
	hud.free()



func _test_dialogue_panel_presentation_and_choice_signal() -> void:
	var panel := CampaignDialoguePanel.new()
	root.add_child(panel)
	assert(not panel.visible)

	var selected_choice: Dictionary = {}
	panel.choice_selected.connect(func(choice: Dictionary): selected_choice = choice)
	var choices: Array[Dictionary] = [
		{"id": "start:quest_intro", "label": "Hear the offer", "available": true},
		{"id": "locked", "label": "Not yet", "available": false, "unavailable_reason": "Requires a key."}
	]
	var portrait_image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	portrait_image.fill(Color("#b69b67"))
	var portrait_texture := ImageTexture.create_from_image(portrait_image)
	panel.present("Mara", "There is work to be done.", choices, portrait_texture)
	assert(panel.visible)
	assert(panel.speaker_text == "Mara")
	assert(panel.speaker_label.text == "Mara")
	assert(panel.body_label.text == "There is work to be done.")
	assert(panel.portrait_frame.visible)
	assert(panel.portrait_texture_rect.texture == portrait_texture)
	assert(panel.choices_box.get_child_count() == 2)

	var available_button := panel.choices_box.get_child(0) as Button
	var unavailable_button := panel.choices_box.get_child(1) as Button
	assert(not available_button.disabled)
	assert(unavailable_button.disabled)
	assert(unavailable_button.tooltip_text == "Requires a key.")
	available_button.emit_signal("pressed")
	assert(selected_choice == choices[0])

	panel.dismiss()
	assert(not panel.visible)
	assert(not panel.portrait_frame.visible)
	panel.free()


func _test_character_portrait_renderer() -> void:
	var source := Node3D.new()
	source.name = "PortraitTestSource"
	var mesh := MeshInstance3D.new()
	mesh.mesh = SphereMesh.new()
	source.add_child(mesh)
	root.add_child(source)

	var renderer := CharacterPortraitRenderer.new()
	root.add_child(renderer)
	assert(renderer.configure(source), "Portrait renderer accepts a valid 3D model")
	assert(renderer.get_texture() != null, "Portrait renderer exposes its SubViewport texture")
	assert(renderer.get_facial_blend_shape_names().is_empty(), "Portrait renderer safely supports models without facial morphs")
	renderer.set_expression("smile")
	renderer.set_live(true)
	assert(renderer.is_live(), "Portrait renderer can enable live dialogue animation")
	renderer.set_live(false)
	assert(not renderer.is_live(), "Portrait renderer can pause outside dialogue")
	renderer.free()
	source.free()


func _test_ambient_dialogue_presenter() -> void:
	assert(is_equal_approx(CampaignAmbientDialoguePresenter.duration_for_text("Hi."), 2.0))
	assert(is_equal_approx(CampaignAmbientDialoguePresenter.duration_for_text("x".repeat(400)), 7.0))

	var presenter := CampaignAmbientDialoguePresenter.new()
	var actor := Node3D.new()
	root.add_child(presenter)
	root.add_child(actor)
	assert(not bool(presenter.present_line(null, "Hello").get("ok", true)))
	assert(not bool(presenter.present_line(actor, "   ").get("ok", true)))
	assert(not bool(presenter.present_line(actor, "Hello", 0.0).get("ok", true)))

	var result := presenter.present_line(actor, "The road is clear.", 0.15, 2.4)
	assert(bool(result.get("ok", false)))
	var bubble: Label3D = result.get("bubble") as Label3D
	assert(bubble != null and is_instance_valid(bubble))
	assert(bubble.get_parent() == actor, "Ambient speech must be attached to its speaker")
	assert(bubble.is_in_group("campaign_ambient_dialogue_bubble"))
	assert(bubble.billboard == BaseMaterial3D.BILLBOARD_ENABLED)
	assert(is_equal_approx(bubble.position.y, 2.4))
	var expiry := bubble.get_node_or_null("RealTimeExpiry") as Timer
	assert(expiry != null)
	assert(expiry.one_shot)
	assert(expiry.ignore_time_scale, "Ambient text must expire independently of game time scale")
	await create_timer(0.25).timeout
	await process_frame
	assert(not is_instance_valid(bubble), "Ambient bubble expires after its real-time timer")

	var second_actor := Node3D.new()
	root.add_child(second_actor)
	var exchange := await presenter.present_exchange(
		[
			{"speaker_id":"first","text":"The watch is quiet."},
			{"speaker_id":"second","text":"Then let us keep it that way."}
		],
		{"first":actor,"second":second_actor},
		0.08
	)
	assert(bool(exchange.get("ok", false)), "Multi-speaker banter remains a sequential ambient exchange")
	assert(exchange.get("lines_presented", []).size() == 2)
	var second_actor_has_bubble := false
	for child in second_actor.get_children():
		if child is Label3D and child.is_in_group("campaign_ambient_dialogue_bubble"):
			second_actor_has_bubble = true
	assert(second_actor_has_bubble)
	second_actor.queue_free()
	actor.queue_free()
	presenter.queue_free()
	await process_frame
