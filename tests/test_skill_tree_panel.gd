extends SceneTree

const CHARACTER_STATE_SCRIPT = preload("res://scripts/simulation/character_state.gd")
const WORLD_SIMULATION_SCRIPT = preload("res://scripts/simulation/world_simulation.gd")
const CHARACTER_PANEL_SCRIPT = preload("res://scripts/ui/character_panel.gd")
const SKILL_PROGRESSION_SCRIPT = preload("res://scripts/simulation/skill_progression.gd")

var _failures := 0


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var simulation = WORLD_SIMULATION_SCRIPT.new()
    root.add_child(simulation)

    var player = CHARACTER_STATE_SCRIPT.new("player", "Player", Vector2i.ZERO)
    player.progression_mode = "player"
    player.attributes = {"strength": 1}
    SKILL_PROGRESSION_SCRIPT.initialise(player)
    simulation.register_character(player)

    var companion = CHARACTER_STATE_SCRIPT.new("companion_test", "Companion", Vector2i(1, 0))
    companion.progression_mode = "companion"
    companion.companion_recruitment_initialized = true
    companion.attributes = {"agility": 1}
    SKILL_PROGRESSION_SCRIPT.initialise(companion)
    simulation.register_character(companion)
    simulation.restore_party_members(["player", "companion_test"])

    var panel = CHARACTER_PANEL_SCRIPT.new()
    root.add_child(panel)
    panel.configure(simulation, "player")
    panel.selected_skill_tree = "strength"
    panel.set_tab("skills")
    _check(panel.active_tab == "skills", "Character panel should expose a Skills tab")

    var player_purchase := _find_button_with_prefix(panel, "Learn · 1 Strength point")
    _check(player_purchase != null, "The skill tree should render eligible purchase controls")
    if player_purchase != null:
        player_purchase.pressed.emit()
    _check(int(player.skills.get("iron_grip", 0)) == 1 or int(player.skills.get("shove", 0)) == 1, "The Skills tab should call the shared purchase function")
    _check(int(player.attributes.get("strength", 0)) == 0, "The Skills tab should spend the character's actual point pool")

    panel.set_character("companion_test")
    panel.selected_skill_tree = "agility"
    panel.refresh(true)
    var companion_purchase := _find_button_with_prefix(panel, "Learn · 1 Agility point")
    _check(companion_purchase != null, "The Skills tab should allow selecting a recruited companion")
    if companion_purchase != null:
        companion_purchase.pressed.emit()
    _check(not companion.skills.is_empty(), "A recruited companion should be able to spend its own unspent points")
    _check(int(companion.attributes.get("agility", 0)) == 0, "Companion skill spending should deduct from the companion's pool")

    panel.queue_free()
    simulation.queue_free()
    await process_frame
    if _failures > 0:
        push_error("%d skill tree UI test assertion(s) failed." % _failures)
        quit(1)
        return
    print("Skill tree UI tests passed.")
    quit(0)


func _find_button_with_prefix(node: Node, prefix: String) -> Button:
    if node is Button and (node as Button).text.begins_with(prefix):
        return node as Button
    for child in node.get_children():
        var found := _find_button_with_prefix(child, prefix)
        if found != null:
            return found
    return null


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    _failures += 1
    push_error("FAIL: " + message)
