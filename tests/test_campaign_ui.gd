extends SceneTree


func _initialize() -> void:
    _test_combat_hud_presentation_and_actions()
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

    hud.present(false, false, false, "")
    assert(not hud.visible)
    hud.free()
