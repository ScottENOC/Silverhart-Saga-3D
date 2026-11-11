extends Control
const CAMPAIGN_SCENE := "res://scenes/main.tscn"
const ARENA_SCENE := "res://scenes/arena/arena_placeholder.tscn"
const WORLD_PREVIEW_SCENE := "res://scenes/prototypes/campaign2_macro_world_preview.tscn"

func _ready() -> void:
	_build_interface()
	AudioManager.enter_mode("menu")

func _build_interface() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("#111923")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#1c2833")
	style.border_color = Color("#9a8054")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 28
	style.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", style)
	centre.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 15)
	panel.add_child(column)
	var title := Label.new()
	title.text = "SILVERHART SAGA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color("#e8d8b6"))
	column.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Choose your adventure"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color("#aebbc4"))
	column.add_child(subtitle)
	column.add_child(HSeparator.new())
	_add_mode_button(column, "CAMPAIGN", "A persistent world, stories and choices", _start_campaign)
	_add_mode_button(column, "ARENA", "Standalone battles and arena progression", _start_arena)
	_add_mode_button(column, "WORLD PREVIEW", "Browse the full Campaign 2 realm in 3D", _open_world_preview)
	var status := Label.new()
	status.text = "The world preview is a map-development view, not a playable travel system."
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size", 12)
	status.add_theme_color_override("font_color", Color("#93a2ad"))
	column.add_child(status)

func _add_mode_button(parent: VBoxContainer, heading: String, detail: String, callback: Callable) -> void:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 76)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#293846")
	normal.border_color = Color("#667887")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(5)
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#394c5a")
	hover.border_color = Color("#c2a16a")
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_color_override("font_color", Color("#f0e7d5"))
	button.add_theme_font_size_override("font_size", 17)
	button.text = heading + "\n" + detail
	button.pressed.connect(callback)
	parent.add_child(button)

func _start_campaign() -> void:
	AudioManager.enter_mode("campaign")
	get_tree().change_scene_to_file(CAMPAIGN_SCENE)

func _start_arena() -> void:
	AudioManager.enter_mode("arena")
	get_tree().change_scene_to_file(ARENA_SCENE)

func _open_world_preview() -> void:
	get_tree().change_scene_to_file(WORLD_PREVIEW_SCENE)
