class_name CharacterPanel
extends Control

signal equipment_changed(character_id: String)

const ITEM_CATALOG = preload("res://scripts/simulation/item_catalog.gd")
## Data-backed character sheet and inventory/equipment panel.
## It reads CharacterState directly; it does not maintain a parallel UI model.

var simulation: WorldSimulation
var character_id: String = "player"
var active_tab: String = "character"
var _body: VBoxContainer
var _heading: Label
var _panel: PanelContainer
var _scroll: ScrollContainer


func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
    offset_left = -500.0
    offset_right = -18.0
    offset_top = 82.0
    offset_bottom = 820.0
    custom_minimum_size = Vector2(482.0, 620.0)
    _build_shell()
    visible = false


func configure(world_simulation: WorldSimulation, initial_character_id: String = "player") -> void:
    simulation = world_simulation
    character_id = initial_character_id
    if simulation != null:
        if not simulation.action_committed.is_connected(_on_action_committed):
            simulation.action_committed.connect(_on_action_committed)
        if not simulation.world_tick.is_connected(_on_world_tick):
            simulation.world_tick.connect(_on_world_tick)
        if not simulation.combat_action_resolved.is_connected(_on_combat_action_resolved):
            simulation.combat_action_resolved.connect(_on_combat_action_resolved)
    refresh()


func set_character(next_character_id: String) -> void:
    character_id = next_character_id
    refresh()


func set_tab(tab_id: String) -> void:
    if tab_id != "character" and tab_id != "inventory":
        return
    if active_tab == tab_id:
        return
    active_tab = tab_id
    refresh(true)


func toggle_panel() -> void:
    visible = not visible
    if visible:
        refresh()


func refresh(reset_scroll: bool = false) -> void:
    if _body == null:
        return
    var previous_scroll := 0
    if not reset_scroll and is_instance_valid(_scroll):
        previous_scroll = _scroll.scroll_vertical
    for child in _body.get_children():
        _body.remove_child(child)
        child.queue_free()

    var state := simulation.get_character(character_id) if simulation != null else null
    if state == null:
        _add_label("Character data unavailable.")
        return

    _heading.text = state.display_name
    var tabs := HBoxContainer.new()
    tabs.add_theme_constant_override("separation", 8)
    _body.add_child(tabs)
    var character_tab := Button.new()
    character_tab.text = "Character"
    character_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    character_tab.disabled = active_tab == "character"
    character_tab.pressed.connect(set_tab.bind("character"))
    tabs.add_child(character_tab)
    var inventory_tab := Button.new()
    inventory_tab.text = "Inventory"
    inventory_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    inventory_tab.disabled = active_tab == "inventory"
    inventory_tab.pressed.connect(set_tab.bind("inventory"))
    tabs.add_child(inventory_tab)

    _scroll = ScrollContainer.new()
    _scroll.name = "CharacterContentScroll"
    _scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _body.add_child(_scroll)
    var content := VBoxContainer.new()
    content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content.add_theme_constant_override("separation", 8)
    _scroll.add_child(content)
    if previous_scroll > 0:
        call_deferred("_restore_scroll_position", previous_scroll)

    if active_tab == "character":
        _build_character_tab(content, state)
    else:
        _build_inventory_tab(content, state)


func _build_shell() -> void:
    _panel = PanelContainer.new()
    _panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(_panel)

    var stack := VBoxContainer.new()
    stack.add_theme_constant_override("separation", 10)
    _panel.add_child(stack)

    var header := HBoxContainer.new()
    stack.add_child(header)
    _heading = Label.new()
    _heading.text = "Character"
    _heading.add_theme_font_size_override("font_size", 22)
    _heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(_heading)
    var close := Button.new()
    close.text = "×"
    close.custom_minimum_size = Vector2(38.0, 34.0)
    close.pressed.connect(func(): visible = false)
    header.add_child(close)

    _body = VBoxContainer.new()
    _body.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _body.add_theme_constant_override("separation", 10)
    stack.add_child(_body)


func _build_character_tab(parent: VBoxContainer, state: CharacterState) -> void:
    var status := "Alive" if state.alive else "Dead"
    if state.unconscious:
        status = "Downed / unconscious"
    _add_section(parent, "IDENTITY & PROGRESSION")
    _add_stat(parent, "Race", state.race.capitalize())
    _add_stat(parent, "Class", state.character_class.capitalize())
    _add_stat(parent, "Level / XP", "%d / %d" % [state.level, state.experience])
    _add_stat(parent, "Gold", str(state.gold))
    _add_stat(parent, "Difficulty", state.difficulty_mode.capitalize())
    _add_section(parent, "ATTRIBUTE POOLS")
    var attribute_keys: Array = state.attributes.keys()
    attribute_keys.sort()
    for attribute_key in attribute_keys:
        var attribute_value := int(state.attributes[attribute_key])
        if attribute_value != 0:
            _add_stat(parent, String(attribute_key).capitalize(), "+%d" % attribute_value)
    _add_section(parent, "STATUS")
    _add_stat(parent, "Condition", status)
    _add_stat(parent, "Faction", state.side.capitalize())
    _add_stat(parent, "Health", "%d / %d" % [state.health, state.max_health])
    _add_stat(parent, "Time Points", "%.1f / %.0f" % [state.time_points, state.max_time_points])

    _add_section(parent, "COMBAT")
    _add_stat(parent, "Base damage", str(state.base_damage))
    _add_stat(parent, "Melee to-hit", "%.1f" % state.to_hit_melee)
    _add_stat(parent, "Ranged to-hit", "%.1f" % state.to_hit_ranged)
    _add_stat(parent, "Passive dodge", "%.1f" % state.passive_dodge)
    _add_stat(parent, "Damage reduction", str(CombatRules.damage_reduction(state)))
    _add_stat(parent, "Parries remaining", str(state.parries_remaining))
    _add_stat(parent, "Sidesteps remaining", str(state.sidesteps_remaining))



func _build_inventory_tab(parent: VBoxContainer, state: CharacterState) -> void:
    _add_section(parent, "CARRIED ITEMS")
    if state.inventory.is_empty():
        _add_label_to(parent, "No items carried yet. Inventory is connected to character state; items will appear here as starting gear, loot and shops are ported.")
    else:
        for item in state.inventory:
            var row := HBoxContainer.new()
            row.add_theme_constant_override("separation", 8)
            parent.add_child(row)
            var item_name := String(item.get("name", item.get("id", "Unknown item")))
            var quantity := int(item.get("quantity", 1))
            _add_item_icon(row, item)
            var detail := Label.new()
            detail.text = "%s  ×%d" % [item_name, quantity]
            detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            detail.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
            detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
            row.add_child(detail)
            var slot := String(item.get("equipment_slot", ""))
            if not slot.is_empty() and quantity == 1:
                var equip := Button.new()
                equip.text = "Equip"
                equip.pressed.connect(_equip_item.bind(String(item.get("instance_id", ""))))
                row.add_child(equip)
            var description := String(item.get("description", ""))
            if not description.is_empty():
                _add_label_to(parent, description)

    _add_section(parent, "EQUIPMENT")
    var has_equipment := false
    for slot in state.equipped_item_data.keys():
        has_equipment = true
        var item: Dictionary = state.equipped_item_data[slot]
        var row := HBoxContainer.new()
        row.add_theme_constant_override("separation", 8)
        parent.add_child(row)
        _add_item_icon(row, item)
        var item_label := Label.new()
        item_label.text = "%s — %s" % [String(slot).capitalize(), String(item.get("name", item.get("id", "Unknown")))]
        item_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        item_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        item_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        row.add_child(item_label)
        var unequip := Button.new()
        unequip.text = "Unequip"
        unequip.pressed.connect(_unequip_slot.bind(String(slot)))
        row.add_child(unequip)
    if not has_equipment:
        _add_label_to(parent, "No item instances equipped. Legacy equipment IDs remain visible on the Character tab.")



func _add_item_icon(parent: Control, item: Dictionary) -> void:
    var texture := ITEM_CATALOG.get_icon_texture(item)
    if texture != null:
        var image := TextureRect.new()
        image.texture = texture
        image.custom_minimum_size = Vector2(44.0, 44.0)
        image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        image.tooltip_text = String(item.get("name", item.get("id", "Item")))
        parent.add_child(image)
        return
    var placeholder := Label.new()
    placeholder.text = "◇"
    placeholder.custom_minimum_size = Vector2(44.0, 44.0)
    placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    placeholder.tooltip_text = "Item artwork unavailable"
    parent.add_child(placeholder)


func _add_section(parent: VBoxContainer, text_value: String) -> void:
    var label := Label.new()
    label.text = text_value
    label.add_theme_font_size_override("font_size", 14)
    label.add_theme_color_override("font_color", Color(0.78, 0.72, 0.58))
    parent.add_child(label)


func _add_stat(parent: VBoxContainer, label_text: String, value_text: String) -> void:
    var row := HBoxContainer.new()
    row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.custom_minimum_size.y = 28.0
    row.add_theme_constant_override("separation", 10)
    parent.add_child(row)
    var label := Label.new()
    label.text = label_text
    label.custom_minimum_size.x = 150.0
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    label.add_theme_color_override("font_color", Color(0.78, 0.78, 0.78))
    row.add_child(label)
    var value := Label.new()
    value.text = value_text
    value.custom_minimum_size.x = 132.0
    value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    value.autowrap_mode = TextServer.AUTOWRAP_OFF
    row.add_child(value)


func _add_label(text_value: String) -> void:
    _add_label_to(_body, text_value)


func _add_label_to(parent: VBoxContainer, text_value: String) -> void:
    var label := Label.new()
    label.text = text_value
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    parent.add_child(label)


func _equip_item(instance_id: String) -> void:
    var state := simulation.get_character(character_id) if simulation != null else null
    if state != null and state.equip_inventory_item(instance_id):
        equipment_changed.emit(character_id)
        refresh()


func _unequip_slot(slot: String) -> void:
    var state := simulation.get_character(character_id) if simulation != null else null
    if state != null and state.unequip_equipment_slot(slot):
        equipment_changed.emit(character_id)
        refresh()


func _on_action_committed(_event: SimulationEvent) -> void:
    refresh()


func _on_world_tick(_tick_index: int, _world_seconds: float) -> void:
    # Rebuilding controls every simulation tick destroys active tab buttons and resets scrolling.
    pass


func _restore_scroll_position(value: int) -> void:
    if is_instance_valid(_scroll):
        _scroll.scroll_vertical = value


func _on_combat_action_resolved(_result: Dictionary) -> void:
    refresh()
