class_name CombatInitiativeTimeline
extends Control

signal character_selected(character_id: String)

const MODEL_SCRIPT = preload("res://scripts/ui/combat_initiative_model.gd")
const TP_REGENERATION_GATE: float = 150.0

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
    offset_left = -600.0
    offset_right = 600.0
    offset_top = -176.0
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
    var signature := current_id
    for entry in entries:
        var portrait := entry.get("portrait_texture") as Texture2D
        signature += "|%s:%.2f:%d/%d:%d/%d:%s:%s:%s:%s" % [
            String(entry["id"]),
            float(entry["time_points"]),
            int(entry["health"]), int(entry["max_health"]),
            int(entry["mana"]), int(entry["max_mana"]),
            String(entry["display_name"]),
            String(entry["side"]),
            str(bool(entry["is_unconscious"])),
            str(bool(entry["is_active"])) + (portrait.resource_path if portrait != null else "")
        ]
    visible = true
    if signature == _last_signature:
        return
    _last_signature = signature
    _render_entries(entries, current)

func _build_layout() -> void:
    var panel := PanelContainer.new()
    panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var panel_style := StyleBoxFlat.new()
    panel_style.bg_color = Color(0.035, 0.045, 0.06, 0.96)
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
    _cards.add_theme_constant_override("separation", 7)
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
        card.custom_minimum_size = Vector2(224.0, 132.0)
        card.size_flags_vertical = Control.SIZE_EXPAND_FILL
        card.tooltip_text = "%s — %.1f TP (100 to act; regeneration pauses at 150)" % [
            String(entry["display_name"]), float(entry["time_points"])
        ]
        var style := StyleBoxFlat.new()
        style.bg_color = Color(0.16, 0.18, 0.20, 0.98) if side == "player" else Color(0.20, 0.14, 0.14, 0.98)
        style.border_color = Color("#d7b65e") if is_active else (Color("#557e70") if side == "player" else Color("#89534d"))
        style.set_border_width_all(2 if is_active else 1)
        style.set_corner_radius_all(7)
        style.content_margin_left = 7.0
        style.content_margin_right = 7.0
        style.content_margin_top = 6.0
        style.content_margin_bottom = 6.0
        card.add_theme_stylebox_override("normal", style)
        card.add_theme_stylebox_override("hover", style)
        card.add_theme_stylebox_override("pressed", style)
        card.add_theme_stylebox_override("focus", style)
        card.pressed.connect(_on_card_pressed.bind(character_id))

        var row := HBoxContainer.new()
        row.add_theme_constant_override("separation", 8)
        row.mouse_filter = Control.MOUSE_FILTER_IGNORE
        card.add_child(row)
        row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

        var portrait_frame := PanelContainer.new()
        portrait_frame.custom_minimum_size = Vector2(70.0, 100.0)
        portrait_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        var portrait_style := StyleBoxFlat.new()
        portrait_style.bg_color = Color(0.09, 0.11, 0.13, 1.0)
        portrait_style.border_color = Color("#b69b67")
        portrait_style.set_border_width_all(1)
        portrait_style.set_corner_radius_all(5)
        portrait_frame.add_theme_stylebox_override("panel", portrait_style)
        row.add_child(portrait_frame)

        var portrait := TextureRect.new()
        portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
        portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
        var portrait_texture := entry.get("portrait_texture") as Texture2D
        if portrait_texture != null:
            portrait.texture = portrait_texture
            portrait_frame.add_child(portrait)
        else:
            var initials := Label.new()
            var display_name := String(entry["display_name"]).strip_edges()
            var parts := display_name.split(" ", false)
            var fallback := ""
            for part in parts:
                if not part.is_empty() and fallback.length() < 2:
                    fallback += part.left(1).to_upper()
            initials.text = fallback if not fallback.is_empty() else "?"
            initials.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
            initials.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
            initials.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
            initials.add_theme_font_size_override("font_size", 23)
            initials.add_theme_color_override("font_color", Color("#d9c18d"))
            initials.mouse_filter = Control.MOUSE_FILTER_IGNORE
            portrait_frame.add_child(initials)

        var content := VBoxContainer.new()
        content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        content.add_theme_constant_override("separation", 2)
        row.add_child(content)

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

        _add_stat_bar(content, "HP", int(entry["health"]), int(entry["max_health"]), Color("#a94f4b"))
        if int(entry["max_mana"]) > 0:
            _add_stat_bar(content, "MP", int(entry["mana"]), int(entry["max_mana"]), Color("#477eb5"))
        _add_tp_bar(content, float(entry["time_points"]))

        _cards.add_child(card)

func _add_stat_bar(parent: VBoxContainer, prefix: String, value: int, maximum: int, fill: Color) -> void:
    var safe_maximum := maxi(1, maximum)
    var line := HBoxContainer.new()
    line.mouse_filter = Control.MOUSE_FILTER_IGNORE
    line.add_theme_constant_override("separation", 4)
    parent.add_child(line)

    var label := Label.new()
    label.text = "%s %d/%d" % [prefix, value, safe_maximum]
    label.custom_minimum_size = Vector2(67.0, 0.0)
    label.add_theme_font_size_override("font_size", 9)
    label.add_theme_color_override("font_color", Color("#d7dce0"))
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    line.add_child(label)

    var bar := ProgressBar.new()
    bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    bar.min_value = 0.0
    bar.max_value = safe_maximum
    bar.value = clampi(value, 0, safe_maximum)
    bar.show_percentage = false
    bar.custom_minimum_size = Vector2(0.0, 6.0)
    bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    line.add_child(bar)

func _add_tp_bar(parent: VBoxContainer, value: float) -> void:
    var line := HBoxContainer.new()
    line.mouse_filter = Control.MOUSE_FILTER_IGNORE
    line.add_theme_constant_override("separation", 4)
    parent.add_child(line)

    var label := Label.new()
    label.text = "TP %.0f" % value
    label.custom_minimum_size = Vector2(67.0, 0.0)
    label.add_theme_font_size_override("font_size", 9)
    label.add_theme_color_override("font_color", Color("#d9c18d"))
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    line.add_child(label)

    var bar := ProgressBar.new()
    bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    bar.min_value = 0.0
    bar.max_value = TP_REGENERATION_GATE
    bar.value = clampf(value, 0.0, TP_REGENERATION_GATE)
    bar.show_percentage = false
    bar.custom_minimum_size = Vector2(0.0, 6.0)
    bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    line.add_child(bar)

func _on_card_pressed(character_id: String) -> void:
    character_selected.emit(character_id)
