class_name CombatInitiativeTimeline
extends Control

signal character_selected(character_id: String)

const MODEL_SCRIPT = preload("res://scripts/ui/combat_initiative_model.gd")

var simulation: WorldSimulation
var _last_signature: String = ""
var _cards: HBoxContainer
var _header_status: Label

func _ready() -> void:
    name = "CombatInitiativeTimeline"
    anchor_left = 0.5
    anchor_right = 0.5
    anchor_top = 1.0
    anchor_bottom = 1.0
    offset_left = -560.0
    offset_right = 560.0
    offset_top = -142.0
    offset_bottom = -14.0
    mouse_filter = Control.MOUSE_FILTER_STOP
    _build_layout()
    visible = false

func configure(world_simulation: WorldSimulation) -> void:
    simulation = world_simulation
    _last_signature = ""
    refresh()

func _process(_delta: float) -> void:
    refresh()

func refresh() -> void:
    if simulation == null or not simulation.is_in_combat:
        if visible:
            visible = false
            _last_signature = ""
        return

    var current := simulation.get_current_turn_character()
    var current_id := current.id if current != null else ""
    var entries := MODEL_SCRIPT.build_entries(simulation.characters, current_id)
    var signature_parts: Array[String] = [current_id]
    for entry in entries:
        signature_parts.append("%s:%.2f:%s:%s" % [
            String(entry["id"]),
            float(entry["time_points"]),
            str(bool(entry["is_unconscious"])),
            str(bool(entry["is_active"]))
        ])
    var signature := "|".join(signature_parts)
    visible = true
    if signature == _last_signature:
        return
    _last_signature = signature
    _render_entries(entries, current)

func _build_layout() -> void:
    var panel := PanelContainer.new()
    panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var panel_style := StyleBoxFlat.new()
    panel_style.bg_color = Color(0.035, 0.045, 0.06, 0.94)
    panel_style.border_color = Color(0.48, 0.40, 0.25, 0.9)
    panel_style.set_border_width_all(1)
    panel_style.set_corner_radius_all(10)
    panel_style.content_margin_left = 10.0
    panel_style.content_margin_right = 10.0
    panel_style.content_margin_top = 7.0
    panel_style.content_margin_bottom = 7.0
    panel.add_theme_stylebox_override("panel", panel_style)
    add_child(panel)

    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 5)
    panel.add_child(column)

    var header := HBoxContainer.new()
    column.add_child(header)
    var title := Label.new()
    title.text = "COMBAT ORDER"
    title.add_theme_font_size_override("font_size", 12)
    title.add_theme_color_override("font_color", Color("#d9c18d"))
    header.add_child(title)

    _header_status = Label.new()
    _header_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _header_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    _header_status.add_theme_font_size_override("font_size", 11)
    _header_status.add_theme_color_override("font_color", Color("#c5cbd0"))
    header.add_child(_header_status)

    var scroll := ScrollContainer.new()
    scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    column.add_child(scroll)

    _cards = HBoxContainer.new()
    _cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _cards.add_theme_constant_override("separation", 6)
    scroll.add_child(_cards)

func _render_entries(entries: Array[Dictionary], current: CharacterState) -> void:
    for child in _cards.get_children():
        child.queue_free()

    if current == null:
        _header_status.text = "Waiting for a combatant to reach 100 TP"
    else:
        _header_status.text = "%s is acting" % current.display_name

    for entry in entries:
        var character_id := String(entry["id"])
        var is_active := bool(entry["is_active"])
        var side := String(entry["side"])
        var card := Button.new()
        card.custom_minimum_size = Vector2(142.0, 91.0)
        card.size_flags_vertical = Control.SIZE_EXPAND_FILL
        card.tooltip_text = "%s — %.1f / %.0f TP. Select to inspect." % [
            String(entry["display_name"]),
            float(entry["time_points"]),
            float(entry["max_time_points"])
        ]
        var style := StyleBoxFlat.new()
        style.bg_color = Color(0.16, 0.18, 0.20, 0.98) if side == "player" else Color(0.20, 0.14, 0.14, 0.98)
        style.border_color = Color("#d7b65e") if is_active else (Color("#557e70") if side == "player" else Color("#89534d"))
        style.set_border_width_all(2 if is_active else 1)
        style.set_corner_radius_all(7)
        style.content_margin_left = 6.0
        style.content_margin_right = 6.0
        style.content_margin_top = 5.0
        style.content_margin_bottom = 5.0
        card.add_theme_stylebox_override("normal", style)
        card.add_theme_stylebox_override("hover", style)
        card.add_theme_stylebox_override("pressed", style)
        card.add_theme_stylebox_override("focus", style)
        card.pressed.connect(_on_card_pressed.bind(character_id))

        var content := VBoxContainer.new()
        content.add_theme_constant_override("separation", 2)
        card.add_child(content)
        content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        content.mouse_filter = Control.MOUSE_FILTER_IGNORE

        var name_label := Label.new()
        name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        name_label.text = String(entry["display_name"])
        name_label.clip_text = true
        name_label.add_theme_font_size_override("font_size", 12)
        name_label.add_theme_color_override("font_color", Color("#f1e8d5"))
        content.add_child(name_label)

        var status_label := Label.new()
        status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        if bool(entry["is_unconscious"]):
            status_label.text = "DOWNED"
        elif is_active:
            status_label.text = "ACTIVE"
        elif bool(entry["can_start_turn"]):
            status_label.text = "READY"
        else:
            status_label.text = "RECOVERING"
        status_label.add_theme_font_size_override("font_size", 9)
        status_label.add_theme_color_override("font_color", Color("#d9c18d") if is_active else Color("#c0c7cc"))
        content.add_child(status_label)

        var tp_label := Label.new()
        tp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        tp_label.text = "TP  %.0f / %.0f" % [float(entry["time_points"]), float(entry["max_time_points"])]
        tp_label.add_theme_font_size_override("font_size", 10)
        content.add_child(tp_label)

        var tp_bar := ProgressBar.new()
        tp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
        tp_bar.min_value = 0.0
        tp_bar.max_value = 1.0
        tp_bar.value = float(entry["time_points_ratio"])
        tp_bar.show_percentage = false
        tp_bar.custom_minimum_size = Vector2(0.0, 7.0)
        content.add_child(tp_bar)
        _cards.add_child(card)

func _on_card_pressed(character_id: String) -> void:
    character_selected.emit(character_id)
