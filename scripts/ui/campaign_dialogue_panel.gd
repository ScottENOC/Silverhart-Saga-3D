class_name CampaignDialoguePanel
extends PanelContainer
## Renders campaign dialogue and forwards selected choice data without applying campaign rules.

signal choice_selected(choice: Dictionary)

var speaker_text: String = ""
var speaker_label: Label
var body_label: Label
var choices_box: VBoxContainer
var portrait_frame: PanelContainer
var portrait_texture_rect: TextureRect
var portrait_actor: AraCharacterActor


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

	var content_row := HBoxContainer.new()
	content_row.add_theme_constant_override("separation", 12)
	content_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(content_row)

	portrait_frame = PanelContainer.new()
	portrait_frame.custom_minimum_size = Vector2(112.0, 166.0)
	portrait_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	portrait_frame.visible = false
	var portrait_style := StyleBoxFlat.new()
	portrait_style.bg_color = Color(0.08, 0.10, 0.13, 1.0)
	portrait_style.border_color = Color("#b69b67")
	portrait_style.set_border_width_all(1)
	portrait_style.set_corner_radius_all(5)
	portrait_frame.add_theme_stylebox_override("panel", portrait_style)
	content_row.add_child(portrait_frame)

	portrait_texture_rect = TextureRect.new()
	portrait_texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_frame.add_child(portrait_texture_rect)

	var dialogue_column := VBoxContainer.new()
	dialogue_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialogue_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dialogue_column.add_theme_constant_override("separation", 8)
	content_row.add_child(dialogue_column)

	body_label = Label.new()
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.custom_minimum_size = Vector2(580.0, 76.0)
	body_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_label.add_theme_font_size_override("font_size", 18)
	dialogue_column.add_child(body_label)

	choices_box = VBoxContainer.new()
	choices_box.add_theme_constant_override("separation", 6)
	dialogue_column.add_child(choices_box)


func present(
	speaker: String,
	body: String,
	choices: Array[Dictionary],
	portrait_texture: Texture2D = null,
	speaker_actor: AraCharacterActor = null,
	expression: String = "neutral"
) -> void:
	if portrait_actor != null and portrait_actor != speaker_actor and is_instance_valid(portrait_actor):
		portrait_actor.set_portrait_live(false)
	portrait_actor = speaker_actor
	if portrait_actor != null and is_instance_valid(portrait_actor):
		portrait_actor.set_portrait_expression(expression)
		portrait_actor.set_portrait_live(true)
		portrait_texture = portrait_actor.get_portrait_texture()

	speaker_text = speaker
	speaker_label.text = speaker
	body_label.text = body
	body_label.custom_minimum_size.x = 430.0 if portrait_texture != null else 580.0
	portrait_texture_rect.texture = portrait_texture
	portrait_frame.visible = portrait_texture != null
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


func present_character(
	speaker: String,
	body: String,
	choices: Array[Dictionary],
	speaker_actor: AraCharacterActor,
	expression: String = "neutral"
) -> void:
	present(speaker, body, choices, null, speaker_actor, expression)


func dismiss() -> void:
	if portrait_actor != null and is_instance_valid(portrait_actor):
		portrait_actor.set_portrait_live(false)
	portrait_actor = null
	visible = false


func _emit_choice(choice: Dictionary) -> void:
	choice_selected.emit(choice.duplicate(true))
