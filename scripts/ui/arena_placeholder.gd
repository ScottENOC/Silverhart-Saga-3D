extends Control
func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var bg := ColorRect.new()
    bg.color = Color("#111923")
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(bg)
    var centre := CenterContainer.new()
    centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(centre)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 14)
    centre.add_child(column)
    var title := Label.new()
    title.text = "ARENA"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 32)
    title.add_theme_color_override("font_color", Color("#e8d8b6"))
    column.add_child(title)
    var note := Label.new()
    note.text = "Arena mode selected. Its battle, lobby and progression systems are next to be ported."
    note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    note.custom_minimum_size = Vector2(320, 0)
    note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    note.add_theme_color_override("font_color", Color("#c0cbd1"))
    column.add_child(note)
    var back := Button.new()
    back.text = "Back to game selection"
    back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
    column.add_child(back)
