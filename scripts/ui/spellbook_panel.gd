class_name SpellbookPanel
extends CanvasLayer

## Player-facing spellbook. The simulation remains authoritative for cast
## legality, target validation, resource payment and effects.

const SPELL_RULES = preload("res://scripts/simulation/spell_rules.gd")
const ACTION_REQUEST = preload("res://scripts/simulation/simulation_action_request.gd")

const HEX_DIRECTIONS: Array[Vector2i] = [
    Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
    Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)
]

var simulation: WorldSimulation
var character_id: String = "player"
var selected_spell_id: String = ""
var selected_modifiers: Dictionary = {}
var feedback_message: String = ""
var _panel: PanelContainer
var _body: VBoxContainer
var _content: VBoxContainer
var pending_target_spell: PreparedSpell
var pending_target_mode: String = ""


func _ready() -> void:
    layer = 70
    _build_shell()
    get_viewport().size_changed.connect(_layout_shell)
    visible = false


func configure(world_simulation: WorldSimulation, initial_character_id: String = "player") -> void:
    simulation = world_simulation
    character_id = initial_character_id
    if simulation != null and not simulation.action_committed.is_connected(_on_action_committed):
        simulation.action_committed.connect(_on_action_committed)
    refresh()


func set_character(next_character_id: String) -> void:
    if character_id != next_character_id and is_awaiting_hex_target():
        cancel_hex_targeting()
    character_id = next_character_id
    selected_spell_id = ""
    feedback_message = ""
    refresh()


func open_for_character(next_character_id: String = "player") -> void:
    character_id = next_character_id
    visible = true
    refresh()


func toggle_for_character(next_character_id: String = "player") -> void:
    if visible:
        if is_awaiting_hex_target():
            cancel_hex_targeting()
        visible = false
    else:
        open_for_character(next_character_id)


func refresh() -> void:
    if _content == null:
        return
    for child in _content.get_children():
        _content.remove_child(child)
        child.queue_free()

    var state := simulation.get_character(character_id) if simulation != null else null
    if state == null:
        _add_label(_content, "Character data unavailable.")
        return

    var header := HBoxContainer.new()
    _content.add_child(header)
    var heading := Label.new()
    heading.text = "SPELLBOOK  ·  " + state.display_name
    heading.add_theme_font_size_override("font_size", 20)
    heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(heading)
    var close := Button.new()
    close.text = "×"
    close.pressed.connect(func():
        if is_awaiting_hex_target():
            cancel_hex_targeting()
        visible = false
    )
    header.add_child(close)

    _add_label(_content, "Mana  %d / %d     Time Points  %.0f / %.0f" % [
        state.current_mana, state.max_mana, state.time_points, state.max_time_points
    ])
    _add_section(_content, "KNOWN SPELLS")
    var catalogue := SPELL_RULES.base_spells()
    var spell_ids: Array = catalogue.keys()
    spell_ids.sort()
    var known_count := 0
    for spell_id_value in spell_ids:
        var spell_id := String(spell_id_value)
        if not _knows_spell(state, spell_id):
            continue
        known_count += 1
        var definition: Dictionary = catalogue[spell_id]
        var spell_button := Button.new()
        spell_button.text = "%s  ·  %s" % [
            String(definition.get("name", spell_id)),
            String(definition.get("school", "")).capitalize()
        ]
        spell_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
        spell_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        spell_button.disabled = selected_spell_id == spell_id
        spell_button.pressed.connect(_select_spell.bind(spell_id))
        _content.add_child(spell_button)
    if known_count == 0:
        _add_label(_content, "No base spells learned yet. Learn a spell through its Learn skill in the Skills tab.")

    if not selected_spell_id.is_empty() and _knows_spell(state, selected_spell_id):
        _build_spell_builder(state)

    _add_section(_content, "PREPARED SPELLS  ·  %d / %d" % [
        state.prepared_spells.size(), _prepared_slot_limit(state)
    ])
    if state.prepared_spells.is_empty():
        _add_label(_content, "Prepare a known spell above before it can be cast.")
    else:
        for index in range(state.prepared_spells.size()):
            var prepared := PreparedSpell.from_dict(state.prepared_spells[index])
            if prepared == null:
                continue
            _build_prepared_row(state, prepared, index)

    if not feedback_message.is_empty():
        _add_label(_content, feedback_message)


func _build_shell() -> void:
    _panel = PanelContainer.new()
    _panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
    add_child(_panel)
    _layout_shell()

    var stack := VBoxContainer.new()
    stack.add_theme_constant_override("separation", 8)
    _panel.add_child(stack)
    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    stack.add_child(scroll)
    _content = VBoxContainer.new()
    _content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _content.add_theme_constant_override("separation", 7)
    scroll.add_child(_content)


func _layout_shell() -> void:
    if _panel == null:
        return
    var viewport_size := get_viewport().get_visible_rect().size
    var panel_width := maxf(240.0, minf(490.0, viewport_size.x - 24.0))
    var panel_height := maxf(300.0, minf(780.0, viewport_size.y - 96.0))
    _panel.offset_left = -panel_width - 12.0
    _panel.offset_right = -12.0
    _panel.offset_top = 72.0
    _panel.offset_bottom = 72.0 + panel_height
    _panel.custom_minimum_size = Vector2(panel_width, panel_height)


func _build_spell_builder(state: CharacterState) -> void:
    var definition := SPELL_RULES.get_base_spell(selected_spell_id)
    var school := String(definition.get("school", ""))
    var school_prefix := school + "_"
    var modifiers := _default_modifiers(state, school)
    if selected_modifiers.get("base_spell_id", "") == selected_spell_id:
        modifiers = selected_modifiers.duplicate(true)
        modifiers.erase("base_spell_id")

    _add_section(_content, "BUILD  ·  " + String(definition.get("name", selected_spell_id)).to_upper())
    _add_label(_content, String(definition.get("description", "Choose a spell variant.")))

    var speed_options := ["default"]
    if int(state.skills.get(school_prefix + "quickened", 0)) > 0:
        speed_options.append("quickened")
    if int(state.skills.get(school_prefix + "slowed", 0)) > 0:
        speed_options.append("slowed")
    var speed_selector := _option_row(_content, "Casting speed", speed_options, String(modifiers.get("speed", "default")))
    speed_selector.item_selected.connect(func(index: int):
        modifiers["speed"] = String(speed_selector.get_item_metadata(index))
        _set_modifiers(modifiers)
    )

    _add_modifier_spin("Potency", "magnitude_bonus", int(state.skills.get(school_prefix + "magnitude", 0)), modifiers)
    _add_modifier_spin("Range", "range_bonus", int(state.skills.get(school_prefix + "range", 0)), modifiers, 5)
    if String(definition.get("type", "")) not in ["summon", "aoe_debuff"] and selected_spell_id not in ["disguise_self", "feather_fall", "calm_animal", "counterspell"]:
        _add_modifier_spin("Additional targets", "target_bonus", int(state.skills.get(school_prefix + "targets", 0)), modifiers)
    if selected_spell_id == "entangle" or (bool(modifiers.get("burst", false)) and int(state.skills.get(school_prefix + "burst", 0)) > 0):
        _add_modifier_spin("Area radius", "radius_bonus", int(state.skills.get(school_prefix + "expand", 0)), modifiers)

    if int(state.skills.get(school_prefix + "burst", 0)) > 0 and String(definition.get("type", "")) in ["damage", "heal"]:
        var burst := CheckBox.new()
        burst.text = "Burst (area cast)"
        burst.button_pressed = bool(modifiers.get("burst", false))
        burst.toggled.connect(func(value: bool):
            modifiers["burst"] = value
            _set_modifiers(modifiers)
        )
        _content.add_child(burst)
    if int(state.skills.get("subtle_spell", 0)) > 0 and String(definition.get("type", "")) != "damage":
        var subtle := CheckBox.new()
        subtle.text = "Subtle casting"
        subtle.button_pressed = bool(modifiers.get("subtle", false))
        subtle.toggled.connect(func(value: bool):
            modifiers["subtle"] = value
            _set_modifiers(modifiers)
        )
        _content.add_child(subtle)
    if int(state.skills.get(school_prefix + "touch", 0)) > 0:
        var touch := CheckBox.new()
        touch.text = "Touch range (adjacent only)"
        touch.button_pressed = bool(modifiers.get("touch", false))
        touch.toggled.connect(func(value: bool):
            modifiers["touch"] = value
            _set_modifiers(modifiers)
        )
        _content.add_child(touch)

    if selected_spell_id == "summon_animal":
        var summon_selector := _option_row(_content, "Summon", ["wolf", "boar", "tiger", "eagle", "unicorn", "horse"], String(modifiers.get("summon_id", "wolf")))
        summon_selector.item_selected.connect(func(index: int):
            modifiers["summon_id"] = String(summon_selector.get_item_metadata(index))
            _set_modifiers(modifiers)
        )
    elif selected_spell_id == "calm_animal":
        var calm_selector := _option_row(_content, "Animal behaviour", ["stay", "come", "chase"], String(modifiers.get("calm_mode", "stay")))
        calm_selector.item_selected.connect(func(index: int):
            modifiers["calm_mode"] = String(calm_selector.get_item_metadata(index))
            _set_modifiers(modifiers)
        )

    var variant := SPELL_RULES.compute_variant(selected_spell_id, modifiers, state.skills)
    var armour_penalty := SPELL_RULES.armour_mana_penalty(state, school)
    var total_cost := int(variant.get("mana_cost", 0)) + armour_penalty
    if bool(variant.get("ok", false)):
        _add_label(_content, "Preview: %d mana (+%d armour)  ·  %.0f TP  ·  range %d  ·  radius %d" % [
            total_cost, armour_penalty, float(variant.get("time_point_cost", 0)),
            int(variant.get("range", 0)), int(variant.get("radius", 0))
        ])
        var affordability := SPELL_RULES.cast_affordability(state, total_cost)
        if not bool(affordability.get("ok", false)):
            _add_label(_content, "Currently unaffordable: " + String(affordability.get("reason", "insufficient_mana")).replace("_", " "))
    else:
        _add_label(_content, "Invalid variant: " + String(variant.get("reason", "unknown")).replace("_", " "))

    var prepare := Button.new()
    prepare.text = "Prepare this variant"
    prepare.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    prepare.disabled = not bool(variant.get("ok", false)) or not SPELL_RULES.supports_initial_cast(selected_spell_id, variant)
    prepare.pressed.connect(_prepare_spell.bind(modifiers))
    _content.add_child(prepare)


func _add_modifier_spin(label_text: String, key: String, maximum: int, modifiers: Dictionary, multiplier: int = 1) -> void:
    if maximum <= 0:
        return
    var row := HBoxContainer.new()
    _content.add_child(row)
    var label := Label.new()
    label.text = label_text
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(label)
    var spin := SpinBox.new()
    spin.min_value = 0
    spin.max_value = maximum
    spin.step = 1
    spin.value = int(modifiers.get(key, 0)) / maxi(1, multiplier)
    spin.value_changed.connect(func(value: float):
        modifiers[key] = int(value) * maxi(1, multiplier)
        _set_modifiers(modifiers)
    )
    row.add_child(spin)


func _build_prepared_row(state: CharacterState, prepared: PreparedSpell, index: int) -> void:
    var variant := SPELL_RULES.compute_variant(prepared.base_spell_id, prepared.modifiers, state.skills)
    var name := String(SPELL_RULES.get_base_spell(prepared.base_spell_id).get("name", prepared.base_spell_id))
    var card := PanelContainer.new()
    card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _content.add_child(card)
    var stack := VBoxContainer.new()
    stack.add_theme_constant_override("separation", 4)
    card.add_child(stack)
    var title := Label.new()
    title.text = "%s  ·  %d mana  ·  %.0f TP" % [
        name,
        int(variant.get("mana_cost", 0)) + SPELL_RULES.armour_mana_penalty(state, String(variant.get("school", ""))),
        float(variant.get("time_point_cost", 0))
    ]
    title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    stack.add_child(title)

    var row := HBoxContainer.new()
    stack.add_child(row)
    var target_selector: OptionButton
    var selected_target_ids: Array[String] = []
    var needs_hex_target := prepared.base_spell_id in ["summon_animal", "entangle"]
    var multi_target := int(variant.get("extra_targets", 0)) > 0
    if multi_target:
        var target_list := VBoxContainer.new()
        target_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        stack.add_child(target_list)
        _add_label(target_list, "Select up to %d targets:" % (int(variant.get("extra_targets", 0)) + 1))
        for candidate in _target_candidates(state, prepared.base_spell_id):
            var check := CheckBox.new()
            check.text = candidate.display_name
            check.toggled.connect(_on_multi_target_toggled.bind(
                candidate.id, selected_target_ids, int(variant.get("extra_targets", 0)) + 1, check
            ))
            target_list.add_child(check)
    elif not needs_hex_target:
        target_selector = _make_target_selector(state, prepared.base_spell_id)
        target_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.add_child(target_selector)

    var cast := Button.new()
    cast.text = "Choose hex" if needs_hex_target else "Cast"
    cast.disabled = not bool(variant.get("ok", false)) or prepared.base_spell_id == "counterspell"
    cast.tooltip_text = "Counterspell is offered as a reaction to an enemy spell."
    if needs_hex_target:
        cast.pressed.connect(_begin_hex_targeting.bind(prepared))
    elif multi_target:
        cast.pressed.connect(_cast_prepared_multi.bind(prepared, selected_target_ids))
    else:
        cast.pressed.connect(_cast_prepared.bind(prepared, target_selector))
    row.add_child(cast)

    var remove := Button.new()
    remove.text = "Remove"
    remove.pressed.connect(_remove_prepared.bind(index))
    row.add_child(remove)


func _make_target_selector(state: CharacterState, spell_id: String) -> OptionButton:
    var selector := OptionButton.new()
    var candidates := _target_candidates(state, spell_id)
    if candidates.is_empty():
        selector.add_item("No character target")
        selector.set_item_metadata(0, "")
    else:
        for candidate in candidates:
            selector.add_item(candidate.display_name)
            selector.set_item_metadata(selector.item_count - 1, candidate.id)
    return selector


func _target_candidates(caster: CharacterState, spell_id: String) -> Array[CharacterState]:
    var result: Array[CharacterState] = []
    if spell_id == "summon_animal" or simulation == null:
        return result
    for value in simulation.characters.values():
        var candidate := value as CharacterState
        if candidate == null or not candidate.can_be_targeted():
            continue
        var valid := true
        if spell_id in ["disguise_self", "feather_fall"]:
            valid = candidate.id == caster.id
        elif spell_id in ["firebolt", "curse", "counterspell"]:
            valid = candidate.side != caster.side
        elif spell_id in ["heal", "divine_protection", "divine_strength"]:
            valid = candidate.side == caster.side
        if spell_id == "wild_fury":
            valid = candidate == caster or (candidate.side == caster.side and candidate.summoned_by_id == caster.id)
        elif spell_id == "calm_animal":
            valid = valid and candidate.tags.has("animal") and not candidate.tags.has("fey") and not candidate.tags.has("dragon")
        if valid:
            result.append(candidate)
    result.sort_custom(func(a: CharacterState, b: CharacterState): return a.display_name < b.display_name)
    return result


func _cast_prepared(prepared: PreparedSpell, selector: OptionButton) -> void:
    var caster := simulation.get_character(character_id) if simulation != null else null
    if caster == null:
        feedback_message = "Caster unavailable."
        refresh()
        return
    var target_id := ""
    if selector != null and selector.item_count > 0 and selector.selected >= 0:
        target_id = String(selector.get_item_metadata(selector.selected))
    if prepared.base_spell_id in ["disguise_self", "feather_fall"]:
        target_id = caster.id

    if prepared.base_spell_id in ["summon_animal", "entangle"]:
        _begin_hex_targeting(prepared)
        return
    var request := ACTION_REQUEST.cast_spell(caster.id, target_id, prepared)
    var result := simulation.submit_action(request)
    if bool(result.get("ok", false)):
        feedback_message = "Cast submitted: " + String(SPELL_RULES.get_base_spell(prepared.base_spell_id).get("name", prepared.base_spell_id))
    else:
        feedback_message = "Cast failed: " + String(result.get("reason", "unknown")).replace("_", " ")
    refresh()


func _begin_hex_targeting(prepared: PreparedSpell) -> void:
    if simulation == null or prepared == null:
        return
    pending_target_spell = prepared
    pending_target_mode = "summon" if prepared.base_spell_id == "summon_animal" else "area"
    feedback_message = "Click an unoccupied walkable hex to summon." if pending_target_mode == "summon" else "Click the centre hex for Entangle. Press Escape to cancel."
    refresh()


func is_awaiting_hex_target() -> bool:
    return pending_target_spell != null


func cancel_hex_targeting() -> void:
    pending_target_spell = null
    pending_target_mode = ""
    feedback_message = "Spell targeting cancelled; no resources spent."
    refresh()


func handle_hex_click(target_hex: Vector2i) -> bool:
    if pending_target_spell == null or simulation == null:
        return false
    var caster := simulation.get_character(character_id)
    if caster == null:
        cancel_hex_targeting()
        return true
    if not simulation.map_data.is_walkable(target_hex):
        feedback_message = "That hex is not a valid target."
        refresh()
        return true
    if pending_target_mode == "summon" and simulation.is_hex_occupied(target_hex):
        feedback_message = "That hex is occupied. Choose another hex."
        refresh()
        return true
    var prepared := pending_target_spell
    pending_target_spell = null
    pending_target_mode = ""
    var request := ACTION_REQUEST.cast_spell_at_hex(caster.id, target_hex, prepared)
    var result := simulation.submit_action(request)
    if bool(result.get("ok", false)):
        feedback_message = "Cast submitted at hex %s, %s." % [target_hex.x, target_hex.y]
    else:
        feedback_message = "Cast failed: " + String(result.get("reason", "unknown")).replace("_", " ")
    refresh()
    return true


func _on_multi_target_toggled(checked: bool, candidate_id: String, selected_target_ids: Array[String], maximum: int, checkbox: CheckBox) -> void:
    if checked:
        if selected_target_ids.size() >= maximum:
            checkbox.set_pressed_no_signal(false)
            feedback_message = "This variant allows %d targets." % maximum
            return
        if not selected_target_ids.has(candidate_id):
            selected_target_ids.append(candidate_id)
    else:
        selected_target_ids.erase(candidate_id)


func _cast_prepared_multi(prepared: PreparedSpell, selected_target_ids: Array[String]) -> void:
    var caster := simulation.get_character(character_id) if simulation != null else null
    if caster == null:
        feedback_message = "Caster unavailable."
        refresh()
        return
    if selected_target_ids.is_empty():
        feedback_message = "Select at least one target."
        refresh()
        return
    var request := ACTION_REQUEST.cast_spell(caster.id, selected_target_ids[0], prepared)
    request.options["target_ids"] = selected_target_ids.duplicate()
    var result := simulation.submit_action(request)
    if bool(result.get("ok", false)):
        feedback_message = "Cast submitted against %d targets." % selected_target_ids.size()
    else:
        feedback_message = "Cast failed: " + String(result.get("reason", "unknown")).replace("_", " ")
    refresh()


func _prepare_spell(modifiers: Dictionary) -> void:
    var state := simulation.get_character(character_id) if simulation != null else null
    if state == null or selected_spell_id.is_empty():
        return
    var variant := SPELL_RULES.compute_variant(selected_spell_id, modifiers, state.skills)
    if not bool(variant.get("ok", false)) or not SPELL_RULES.supports_initial_cast(selected_spell_id, variant):
        feedback_message = "This spell variant is not currently supported."
        refresh()
        return
    if state.prepared_spells.size() >= _prepared_slot_limit(state):
        feedback_message = "All prepared spell slots are full. Remove a prepared spell or learn Spell Mastery."
        refresh()
        return
    var school := String(variant.get("school", ""))
    var cap := int(state.mana_caps.get(school, 10)) + 5 * int(state.skills.get(school + "_cap", 0))
    if int(variant.get("core_mana_cost", variant.get("mana_cost", 0))) > cap:
        feedback_message = "This variant exceeds your %s mana cap (%d)." % [school, cap]
        refresh()
        return
    var prepared := PreparedSpell.create(selected_spell_id, modifiers)
    for saved in state.prepared_spells:
        var existing := PreparedSpell.from_dict(saved)
        if existing != null and existing.base_spell_id == prepared.base_spell_id and existing.modifiers == prepared.modifiers:
            feedback_message = "That exact variant is already prepared."
            refresh()
            return
    state.prepared_spells.append(prepared.to_dict())
    feedback_message = "Prepared " + String(variant.get("name", selected_spell_id)) + "."
    refresh()


func _remove_prepared(index: int) -> void:
    var state := simulation.get_character(character_id) if simulation != null else null
    if state == null or index < 0 or index >= state.prepared_spells.size():
        return
    state.prepared_spells.remove_at(index)
    feedback_message = "Prepared spell removed."
    refresh()


func _select_spell(spell_id: String) -> void:
    selected_spell_id = spell_id
    selected_modifiers = { "base_spell_id": spell_id }
    feedback_message = ""
    refresh()


func _set_modifiers(modifiers: Dictionary) -> void:
    selected_modifiers = modifiers.duplicate(true)
    selected_modifiers["base_spell_id"] = selected_spell_id
    refresh()


func _default_modifiers(state: CharacterState, school: String) -> Dictionary:
    return {
        "speed": "default",
        "magnitude_bonus": 0,
        "range_bonus": 0,
        "radius_bonus": 0,
        "target_bonus": 0,
        "burst": false,
        "subtle": false,
        "touch": false,
        "summon_id": "wolf",
        "calm_mode": "stay"
    }


func _prepared_slot_limit(state: CharacterState) -> int:
    return state.max_spell_slots + 2 * (
        int(state.skills.get("arcane_spell_slots", 0))
        + int(state.skills.get("divine_spell_slots", 0))
        + int(state.skills.get("nature_spell_slots", 0))
    )


func _knows_spell(state: CharacterState, spell_id: String) -> bool:
    return state.unlocked_base_spells.has(spell_id) or int(state.skills.get("learn_%s" % spell_id, 0)) > 0


func _option_row(parent: VBoxContainer, label_text: String, options: Array, selected_value: String) -> OptionButton:
    var row := HBoxContainer.new()
    parent.add_child(row)
    var label := Label.new()
    label.text = label_text
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(label)
    var selector := OptionButton.new()
    for option in options:
        selector.add_item(String(option).capitalize())
        selector.set_item_metadata(selector.item_count - 1, String(option))
    var selected_index := options.find(selected_value)
    selector.select(maxi(0, selected_index))
    row.add_child(selector)
    return selector


func _add_section(parent: VBoxContainer, title: String) -> void:
    var label := Label.new()
    label.text = title
    label.add_theme_color_override("font_color", Color(0.94, 0.82, 0.58))
    label.add_theme_font_size_override("font_size", 14)
    parent.add_child(label)


func _add_label(parent: VBoxContainer, message: String) -> void:
    var label := Label.new()
    label.text = message
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    parent.add_child(label)


func _on_action_committed(event: SimulationEvent) -> void:
    if event == null:
        return
    if visible and event.event_type in ["spell_cast", "spell_countered", "character_moved", "character_damaged", "animal_mounted", "animal_dismounted", "summon_expired"]:
        refresh()
