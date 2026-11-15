class_name CampaignDialoguePanel
extends PanelContainer
## Renders campaign dialogue and forwards selected choice data without applying campaign rules.

signal choice_selected(choice: Dictionary)

var speaker_text: String = ""
var speaker_label: Label
var body_label: Label
var choices_box: VBoxContainer


func _ready() -> void:
    anchor_left = 0.5
    anchor_right = 0.5
    anchor_top = 1.0
    anchor_bottom = 1.0
    offset_left = -310.0
    offset_right = 310.0
    offset_top = -300.0
    offset_bottom = -22.0
    visible = false

    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 10)
    add_child(column)

    speaker_label = Label.new()
    speaker_label.add_theme_font_size_override("font_size", 22)
    speaker_label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.55))
    column.add_child(speaker_label)

    body_label = Label.new()
    body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    body_label.custom_minimum_size = Vector2(580.0, 76.0)
    body_label.add_theme_font_size_override("font_size", 18)
    column.add_child(body_label)

    choices_box = VBoxContainer.new()
    choices_box.add_theme_constant_override("separation", 6)
    column.add_child(choices_box)


func present(speaker: String, body: String, choices: Array[Dictionary]) -> void:
    speaker_text = speaker
    speaker_label.text = speaker
    body_label.text = body
    for child in choices_box.get_children():
        child.queue_free()
    for choice_value in choices:
        var choice: Dictionary = choice_value
        var button := Button.new()
        button.text = String(choice.get("label", "Continue"))
        button.custom_minimum_size = Vector2(0.0, 38.0)
        button.disabled = not bool(choice.get("available", true))
        if button.disabled:
            button.tooltip_text = String(choice.get("unavailable_reason", "Not available yet."))
        else:
            button.pressed.connect(_emit_choice.bind(choice.duplicate(true)))
        choices_box.add_child(button)
    visible = true


func dismiss() -> void:
    visible = false


func _emit_choice(choice: Dictionary) -> void:
    choice_selected.emit(choice.duplicate(true))
