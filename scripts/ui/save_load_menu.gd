extends CanvasLayer
## Shared manual save/load slot picker for the campaign.
signal closed
var mode := "save"
var snapshot: Dictionary = {}
var panel: PanelContainer
var status_label: Label
var slot_list: VBoxContainer

func _ready() -> void:
    layer = 150
    _build_ui()
    visible = false

func open_for_save(data: Dictionary) -> void:
    mode = "save"
    snapshot = data.duplicate(true)
    _refresh_slots()
    visible = true

func open_for_load() -> void:
    mode = "load"
    snapshot.clear()
    _refresh_slots()
    visible = true

func _build_ui() -> void:
    var backdrop := ColorRect.new()
    backdrop.color = Color(0.015, 0.02, 0.03, 0.78)
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(backdrop)
    var centre := CenterContainer.new()
    centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(centre)
    panel = PanelContainer.new()
    panel.custom_minimum_size = Vector2(560, 0)
    centre.add_child(panel)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 10)
    panel.add_child(column)
    var heading := Label.new()
    heading.name = "Heading"
    heading.text = "CAMPAIGN SAVES"
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    heading.add_theme_font_size_override("font_size", 24)
    column.add_child(heading)
    status_label = Label.new()
    status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(status_label)
    var scroll := ScrollContainer.new()
    scroll.custom_minimum_size = Vector2(520, 430)
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    column.add_child(scroll)
    slot_list = VBoxContainer.new()
    slot_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(slot_list)
    var close_button := Button.new()
    close_button.text = "Close  [Esc]"
    close_button.pressed.connect(_close)
    column.add_child(close_button)

func _refresh_slots() -> void:
    for child in slot_list.get_children():
        child.queue_free()
    var heading := panel.find_child("Heading", true, false) as Label
    heading.text = "SAVE CAMPAIGN" if mode == "save" else "LOAD CAMPAIGN"
    status_label.text = "Choose a slot. Existing manual saves are only replaced when selected." if mode == "save" else "Choose a saved campaign to continue."
    for entry in SaveManager.list_slots():
        var slot_id := String(entry.get("slot_id", ""))
        var metadata: Dictionary = entry.get("metadata", {})
        var occupied := bool(entry.get("occupied", false))
        var button := Button.new()
        button.custom_minimum_size = Vector2(0, 54)
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        var slot_name := slot_id.replace("_", " ").capitalize()
        if occupied:
            var saved_at := Time.get_datetime_string_from_unix_time(int(metadata.get("saved_at_unix", 0)), true)
            button.text = "%s   ·   %s   ·   %s" % [slot_name, String(metadata.get("character_name", "Adventurer")), saved_at]
        else:
            button.text = "%s   ·   Empty" % slot_name
        button.disabled = mode == "load" and not occupied
        button.pressed.connect(_on_slot_pressed.bind(slot_id, occupied))
        slot_list.add_child(button)

func _on_slot_pressed(slot_id: String, occupied: bool) -> void:
    if mode == "save":
        if occupied:
            status_label.text = "Saving will replace this slot. Select it again to confirm."
            var confirm := ConfirmationDialog.new()
            confirm.dialog_text = "Replace the existing save in %s?" % slot_id.replace("_", " ")
            add_child(confirm)
            confirm.confirmed.connect(func():
                _write_slot(slot_id)
                confirm.queue_free()
            )
            confirm.canceled.connect(confirm.queue_free)
            confirm.popup_centered()
            return
        _write_slot(slot_id)
        return
    var result := SaveManager.load_snapshot(slot_id)
    if not bool(result.get("ok", false)):
        status_label.text = "Could not load save: %s" % String(result.get("reason", "unknown error"))
        return
    SaveManager.set_pending_load(result["snapshot"])
    get_tree().change_scene_to_file("res://scenes/main.tscn")
    _close()

func _write_slot(slot_id: String) -> void:
    var result := SaveManager.save_snapshot(slot_id, snapshot)
    status_label.text = "Saved successfully." if bool(result.get("ok", false)) else "Save failed: %s" % String(result.get("reason", "unknown error"))
    if bool(result.get("ok", false)):
        _refresh_slots()

func _close() -> void:
    visible = false
    closed.emit()

func _unhandled_input(event: InputEvent) -> void:
    if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        _close()
        get_viewport().set_input_as_handled()
