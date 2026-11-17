extends SceneTree


func _initialize() -> void:
    await process_frame
    _test_combat_hud_presentation_and_actions()
    _test_dialogue_panel_presentation_and_choice_signal()
    _test_nearby_interaction_panel_presentation_and_selection()
    print("Campaign UI tests passed.")
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
    panel.present("Mara", "There is work to be done.", choices)
    assert(panel.visible)
    assert(panel.speaker_text == "Mara")
    assert(panel.speaker_label.text == "Mara")
    assert(panel.body_label.text == "There is work to be done.")
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
    panel.free()

func _test_nearby_interaction_panel_presentation_and_selection() -> void:
    var panel := NearbyInteractionPanel.new()
    root.add_child(panel)
    assert(not panel.visible)

    var empty_entries: Array[Dictionary] = []
    panel.present(empty_entries)
    assert(not panel.visible)

    var entries: Array[Dictionary] = []
    for index in range(7):
        entries.append({
            "id": "character_%d" % index,
            "name": "Character %d" % index,
            "distance": index,
            "hostile": index == 1
        })

    var selected_id := ""
    panel.character_selected.connect(func(character_id: String): selected_id = character_id)
    panel.present(entries)
    assert(panel.visible)
    var column := panel.get_child(0) as VBoxContainer
    assert(column.get_child_count() == 7)
    assert((column.get_child(0) as Label).text == "NEARBY PEOPLE")
    assert((column.get_child(1) as Button).text == "Talk · Character 0")
    assert((column.get_child(2) as Button).text == "Engage · Character 1")
    assert((column.get_child(6) as Button).text == "Talk · Character 5")

    (column.get_child(2) as Button).emit_signal("pressed")
    assert(selected_id == "character_1")

    panel.present(empty_entries)
    assert(not panel.visible)
    assert(panel.get_child_count() == 0)
    panel.free()
