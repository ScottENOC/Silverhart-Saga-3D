class_name CharacterPanel
extends Control

signal equipment_changed(character_id: String)

const ITEM_CATALOG = preload("res://scripts/simulation/item_catalog.gd")
const SKILL_PROGRESSION = preload("res://scripts/simulation/skill_progression.gd")
const SKILL_CATALOG = preload("res://scripts/simulation/skill_catalog.gd")
## Data-backed character sheet and inventory/equipment panel.
## It reads CharacterState directly; it does not maintain a parallel UI model.

var simulation: WorldSimulation
var character_id: String = "player"
var active_tab: String = "character"
var selected_skill_tree: String = ""
var skill_feedback_message: String = ""
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
    if tab_id != "character" and tab_id != "skills" and tab_id != "inventory":
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
    var skills_tab := Button.new()
    skills_tab.text = "Skills"
    skills_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    skills_tab.disabled = active_tab == "skills"
    skills_tab.pressed.connect(set_tab.bind("skills"))
    tabs.add_child(skills_tab)
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
    elif active_tab == "skills":
        _build_skills_tab(content, state)
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



func _build_skills_tab(parent: VBoxContainer, state: CharacterState) -> void:
    _add_section(parent, "SKILL DEVELOPMENT")
    _add_label_to(parent, "Spend one point from an eligible attribute pool to raise a skill by one rank. Some legacy skill effects are still being ported; a purchased rank does not yet guarantee its gameplay effect is active.")

    var party_ids: Array[String] = []
    if simulation != null:
        party_ids = simulation.get_party_member_ids()
    if party_ids.size() > 1:
        var character_row := HBoxContainer.new()
        parent.add_child(character_row)
        var character_label := Label.new()
        character_label.text = "Character"
        character_label.custom_minimum_size.x = 92.0
        character_row.add_child(character_label)
        var character_selector := OptionButton.new()
        character_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        var selected_character_index := 0
        for index in range(party_ids.size()):
            var party_id := String(party_ids[index])
            var party_state := simulation.get_character(party_id)
            if party_state == null:
                continue
            character_selector.add_item("You" if party_id == "player" else party_state.display_name)
            character_selector.set_item_metadata(character_selector.item_count - 1, party_id)
            if party_id == character_id:
                selected_character_index = character_selector.item_count - 1
        character_selector.select(selected_character_index)
        character_selector.item_selected.connect(_on_skill_character_selected.bind(character_selector))
        character_row.add_child(character_selector)

    if state.progression_mode != "player" and state.progression_mode != "companion":
        _add_label_to(parent, "Skill spending is available for the player and recruited companions. This character is still managed by NPC progression.")
        return

    var accounting := SKILL_PROGRESSION.accounting_report(state)
    _add_section(parent, "POINTS")
    _add_stat(parent, "Unspent skill points", str(int(accounting.get("available_points", 0))))
    var pools: Dictionary = accounting.get("pools", {})
    var pool_names: Array = pools.keys()
    pool_names.sort()
    for pool_name in pool_names:
        var pool_data: Dictionary = pools[pool_name]
        var budget := int(pool_data.get("budget", 0))
        var spent := int(pool_data.get("spent", 0))
        var remaining := int(pool_data.get("remaining", 0))
        if budget <= 0 and spent <= 0 and remaining <= 0:
            continue
        _add_stat(parent, String(pool_name).capitalize(), "%d left  ·  %d / %d spent" % [remaining, spent, budget])

    _add_section(parent, "SKILL TREES")
    var tree_selector := OptionButton.new()
    tree_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var tree_names: Array[String] = []
    for skill_id in SKILL_CATALOG.all_skill_ids():
        var definition := SKILL_CATALOG.get_skill(skill_id)
        var tree_name := String(definition.get("tree", ""))
        if tree_name.is_empty() or SKILL_PROGRESSION.NON_PURCHASABLE_TREES.has(tree_name):
            continue
        if not tree_names.has(tree_name):
            tree_names.append(tree_name)
    tree_names.sort()
    if tree_names.is_empty():
        _add_label_to(parent, "No purchasable skill trees were found in the catalogue.")
        return
    if not tree_names.has(selected_skill_tree):
        selected_skill_tree = tree_names[0]
    var selected_tree_index := 0
    for index in range(tree_names.size()):
        tree_selector.add_item(tree_names[index].capitalize())
        tree_selector.set_item_metadata(index, tree_names[index])
        if tree_names[index] == selected_skill_tree:
            selected_tree_index = index
    tree_selector.select(selected_tree_index)
    tree_selector.item_selected.connect(_on_skill_tree_selected.bind(tree_selector))
    parent.add_child(tree_selector)

    if not skill_feedback_message.is_empty():
        _add_label_to(parent, skill_feedback_message)

    var found_skill := false
    for skill_id in SKILL_CATALOG.all_skill_ids():
        var skill := SKILL_CATALOG.get_skill(skill_id)
        if String(skill.get("tree", "")) != selected_skill_tree:
            continue
        found_skill = true
        _add_skill_card(parent, state, skill_id, skill)
    if not found_skill:
        _add_label_to(parent, "This tree currently has no skill definitions.")


func _add_skill_card(parent: VBoxContainer, state: CharacterState, skill_id: String, skill: Dictionary) -> void:
    var card := PanelContainer.new()
    card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    parent.add_child(card)
    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 5)
    card.add_child(content)

    var title_row := HBoxContainer.new()
    content.add_child(title_row)
    var title := Label.new()
    title.text = String(skill.get("name", skill_id))
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    title.add_theme_color_override("font_color", Color(0.94, 0.84, 0.62))
    title_row.add_child(title)

    var rank := int(state.skills.get(skill_id, 0))
    var maximum := int(skill.get("max_ranks", 0))
    var rank_label := Label.new()
    rank_label.text = "Rank %d / %s" % [rank, str(maximum) if maximum > 0 else "∞"]
    rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    title_row.add_child(rank_label)

    var description := Label.new()
    description.text = String(skill.get("description", "No description supplied."))
    description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content.add_child(description)

    var prerequisite_value: Variant = skill.get("prerequisite", null)
    if prerequisite_value != null and not String(prerequisite_value).is_empty():
        var prerequisite := SKILL_CATALOG.get_skill(String(prerequisite_value))
        var prerequisite_name := String(prerequisite.get("name", prerequisite_value))
        var prerequisite_label := Label.new()
        prerequisite_label.text = "Requires: " + prerequisite_name
        prerequisite_label.add_theme_color_override("font_color", Color(0.72, 0.76, 0.82))
        prerequisite_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        content.add_child(prerequisite_label)

    var eligibility := SKILL_PROGRESSION.can_purchase(state, skill_id)
    if String(eligibility.get("reason", "")) == "funding_pool_choice_required":
        var funding_row := HBoxContainer.new()
        content.add_child(funding_row)
        var funding_selector := OptionButton.new()
        funding_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        var funding_pools: Array = eligibility.get("available_pools", [])
        for pool in funding_pools:
            funding_selector.add_item(String(pool).capitalize())
            funding_selector.set_item_metadata(funding_selector.item_count - 1, String(pool))
        funding_row.add_child(funding_selector)
        var pool_purchase_button := Button.new()
        pool_purchase_button.text = "Learn · 1 point"
        pool_purchase_button.disabled = funding_pools.is_empty()
        pool_purchase_button.pressed.connect(_purchase_skill_from_selector.bind(skill_id, funding_selector))
        funding_row.add_child(pool_purchase_button)
    elif bool(eligibility.get("ok", false)):
        var direct_purchase_button := Button.new()
        direct_purchase_button.text = "Learn · 1 %s point" % String(eligibility.get("funding_pool", "")).capitalize()
        direct_purchase_button.pressed.connect(_purchase_skill.bind(skill_id, String(eligibility.get("funding_pool", ""))))
        content.add_child(direct_purchase_button)
    else:
        var lock_label := Label.new()
        lock_label.text = "Unavailable: " + _skill_lock_description(eligibility)
        lock_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        lock_label.add_theme_color_override("font_color", Color(0.82, 0.64, 0.58))
        content.add_child(lock_label)


func _skill_lock_description(result: Dictionary) -> String:
    var reason := String(result.get("reason", "unknown"))
    match reason:
        "maximum_rank_reached":
            return "Maximum rank reached."
        "prerequisite_missing":
            var prerequisite_id := String(result.get("prerequisite", ""))
            var prerequisite := SKILL_CATALOG.get_skill(prerequisite_id)
            return "Requires %s." % String(prerequisite.get("name", prerequisite_id))
        "incompatible_skill_learned":
            var incompatible_id := String(result.get("incompatible_skill", ""))
            var incompatible := SKILL_CATALOG.get_skill(incompatible_id)
            return "Incompatible with %s." % String(incompatible.get("name", incompatible_id))
        "dynamic_prerequisite_missing":
            return "A special prerequisite has not been met."
        "insufficient_skill_points":
            return "No points remain in an eligible pool."
        "quest_granted_only":
            return "Granted through a quest, not purchased."
        "already_knows_riding":
            return "Another riding skill is already known."
        "skill_tree_not_player_purchasable":
            return "This tree is reserved for NPC or special use."
        "missing_character":
            return "Character data is unavailable."
        _:
            return reason.replace("_", " ").capitalize() + "."


func _on_skill_character_selected(index: int, selector: OptionButton) -> void:
    if index < 0 or index >= selector.item_count:
        return
    var selected_id := String(selector.get_item_metadata(index))
    if not selected_id.is_empty() and selected_id != character_id:
        character_id = selected_id
        skill_feedback_message = ""
        refresh(true)


func _on_skill_tree_selected(index: int, selector: OptionButton) -> void:
    if index < 0 or index >= selector.item_count:
        return
    selected_skill_tree = String(selector.get_item_metadata(index))
    skill_feedback_message = ""
    refresh(true)


func _purchase_skill_from_selector(skill_id: String, selector: OptionButton) -> void:
    if selector == null or selector.item_count == 0 or selector.selected < 0:
        return
    _purchase_skill(skill_id, String(selector.get_item_metadata(selector.selected)))


func _purchase_skill(skill_id: String, funding_pool: String = "") -> void:
    var state := simulation.get_character(character_id) if simulation != null else null
    if state == null:
        skill_feedback_message = "Character data is unavailable; no points were spent."
        refresh()
        return
    if state.progression_mode != "player" and state.progression_mode != "companion":
        skill_feedback_message = "This character is not eligible for player-controlled skill spending."
        refresh()
        return
    var result := SKILL_PROGRESSION.purchase(state, skill_id, funding_pool)
    if bool(result.get("ok", false)):
        var skill := SKILL_CATALOG.get_skill(skill_id)
        skill_feedback_message = "Learned %s at rank %d using %s points." % [
            String(skill.get("name", skill_id)),
            int(result.get("rank", 0)),
            String(result.get("funding_pool", funding_pool)).capitalize()
        ]
    else:
        skill_feedback_message = "Purchase failed: " + _skill_lock_description(result)
    refresh()




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
