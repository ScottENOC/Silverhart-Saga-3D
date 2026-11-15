class_name NearbyInteractionPanel
extends PanelContainer
## Displays nearby character interaction options and forwards the selected character ID.

signal character_selected(character_id: String)


func _ready() -> void:
    position = Vector2(22.0, 244.0)
    custom_minimum_size = Vector2(250.0, 0.0)
    visible = false


func present(entries: Array[Dictionary]) -> void:
    for child in get_children():
        child.free()
    if entries.is_empty():
        visible = false
        return

    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 4)
    add_child(column)

    var heading := Label.new()
    heading.text = "NEARBY PEOPLE"
    heading.add_theme_color_override("font_color", Color(0.94, 0.84, 0.62))
    column.add_child(heading)

    for index in range(mini(entries.size(), 6)):
        var entry: Dictionary = entries[index]
        var character_id := String(entry.get("id", ""))
        var character_name := String(entry.get("name", character_id))
        var action_label := "Engage · " if bool(entry.get("hostile", false)) else "Talk · "
        var button := Button.new()
        button.text = action_label + character_name
        button.custom_minimum_size = Vector2(225.0, 34.0)
        button.pressed.connect(_emit_character_selected.bind(character_id))
        column.add_child(button)

    visible = true


func dismiss() -> void:
    visible = false


func _emit_character_selected(character_id: String) -> void:
    character_selected.emit(character_id)
