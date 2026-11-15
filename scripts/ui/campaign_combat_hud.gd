class_name CampaignCombatHud
extends Control
## Presentation-only combat controls. Combat eligibility and turn rules stay in WorldSimulation/HollowTankard.

signal attack_requested
signal end_turn_requested

var attack_button: Button
var end_turn_button: Button
var status_label: Label


func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    _create_controls()


func _create_controls() -> void:
    attack_button = Button.new()
    attack_button.name = "AttackButton"
    attack_button.text = "Attack [Space]"
    attack_button.position = Vector2(840.0, 70.0)
    attack_button.custom_minimum_size = Vector2(145.0, 42.0)
    attack_button.pressed.connect(func(): attack_requested.emit())
    add_child(attack_button)

    end_turn_button = Button.new()
    end_turn_button.name = "EndTurnButton"
    end_turn_button.text = "End Turn [Enter]"
    end_turn_button.position = Vector2(995.0, 70.0)
    end_turn_button.custom_minimum_size = Vector2(160.0, 42.0)
    end_turn_button.pressed.connect(func(): end_turn_requested.emit())
    add_child(end_turn_button)

    status_label = Label.new()
    status_label.name = "CombatStatusLabel"
    status_label.position = Vector2(610.0, 120.0)
    status_label.custom_minimum_size = Vector2(360.0, 54.0)
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    add_child(status_label)
    visible = false


func present(combat_visible: bool, can_end_turn: bool, can_attack: bool, status_text: String) -> void:
    visible = combat_visible
    if not combat_visible:
        return
    end_turn_button.disabled = not can_end_turn
    attack_button.disabled = not can_attack
    status_label.text = status_text


func set_status_text(status_text: String) -> void:
    status_label.text = status_text
