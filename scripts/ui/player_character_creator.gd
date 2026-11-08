extends CanvasLayer
## First-run player identity and appearance setup.
## Ara geometry is generated at build time; this screen stores a profile and
## applies supported runtime material/name changes without claiming live mesh regeneration.

signal completed(profile: Dictionary)

const RULES = preload("res://scripts/simulation/character_creation_rules.gd")

const SAVE_PATH := "user://player_appearance.json"
const SKIN_TONES := ["Porcelain", "Fair", "Light", "Medium", "Olive", "Brown", "Deep brown"]
const SKIN_COLOURS := ["#f2d8c4", "#e8c2a2", "#d6a47e", "#b9825f", "#9a6849", "#70452f", "#45291f"]
const EYE_COLOURS := ["Brown", "Light brown", "Dark brown", "Green", "Blue", "Grey", "Ice blue"]
const HAIR_COLOURS := ["Black", "Dark brown", "Chestnut", "Blonde", "Red", "Silver", "White", "Blue", "Green"]
const HAIR_STYLES := ["Short", "Long", "Braid", "Curly", "Wavy", "Shaved", "Ponytail"]
const BODY_BUILDS := ["Lean", "Average", "Broad", "Muscular", "Soft", "Androgynous"]
const PRESENTATIONS := ["Masculine", "Feminine", "Androgynous", "Mixed", "Custom"]
const PRONOUN_SETS := ["He / him", "She / her", "They / them", "Use my name", "Custom"]

var name_edit: LineEdit
var game_mode_select: OptionButton
var difficulty_select: OptionButton
var ironman_check: CheckBox
var race_select: OptionButton
var class_select: OptionButton
var rules_preview: Label
var mode_note: Label
var start_button: Button
var presentation_select: OptionButton
var pronoun_select: OptionButton
var custom_pronouns: LineEdit
var skin_select: OptionButton
var eye_select: OptionButton
var hair_colour_select: OptionButton
var hair_style_select: OptionButton
var body_select: OptionButton
var shirt_select: OptionButton
var trousers_select: OptionButton

func _ready() -> void:
    layer = 100
    _build_screen()
    _load_saved_profile()

func _build_screen() -> void:
    var backdrop := ColorRect.new()
    backdrop.color = Color(0.055, 0.065, 0.075, 0.97)
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(backdrop)

    var scroll := ScrollContainer.new()
    scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    scroll.offset_left = 24
    scroll.offset_top = 18
    scroll.offset_right = -24
    scroll.offset_bottom = -18
    add_child(scroll)

    var centre := CenterContainer.new()
    centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(centre)

    var panel := VBoxContainer.new()
    panel.custom_minimum_size = Vector2(560, 0)
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    panel.add_theme_constant_override("separation", 10)
    centre.add_child(panel)

    var title := Label.new()
    title.text = "CREATE YOUR CHARACTER"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 30)
    panel.add_child(title)

    var intro := Label.new()
    intro.text = "Choose who arrives in Hollowmere. Identity, presentation and appearance are independent."
    intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    intro.add_theme_color_override("font_color", Color(0.78, 0.79, 0.78))
    panel.add_child(intro)

    _section(panel, "GAME MODE")
    game_mode_select = _option_row(panel, "Mode", ["Campaign", "Arena"])
    difficulty_select = _option_row(panel, "Difficulty", ["Easy", "Normal", "Hard"])
    for i in range(3):
        difficulty_select.set_item_metadata(i, ["easy", "normal", "hard"][i])
    ironman_check = CheckBox.new()
    ironman_check.text = "Ironman run (save enforcement not yet ported)"
    panel.add_child(ironman_check)
    mode_note = Label.new()
    mode_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    mode_note.add_theme_color_override("font_color", Color(0.9, 0.75, 0.48))
    panel.add_child(mode_note)
    game_mode_select.item_selected.connect(_update_mode_controls)
    _update_mode_controls(0)

    _section(panel, "IDENTITY & CHARACTER")
    name_edit = _line_edit(panel, "Character name", "Your name")
    race_select = _option_row(panel, "Race", [])
    for race_id in RULES.race_ids():
        race_select.add_item(String(RULES.race_definition(race_id).get("label", race_id)))
        race_select.set_item_metadata(race_select.item_count - 1, race_id)
    class_select = _option_row(panel, "Class", [])
    for class_id in RULES.class_ids():
        class_select.add_item(String(RULES.class_definition(class_id).get("label", class_id)))
        class_select.set_item_metadata(class_select.item_count - 1, class_id)
    race_select.item_selected.connect(_refresh_character_preview)
    class_select.item_selected.connect(_refresh_character_preview)
    difficulty_select.item_selected.connect(_refresh_character_preview)
    rules_preview = Label.new()
    rules_preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    rules_preview.add_theme_font_size_override("font_size", 13)
    rules_preview.add_theme_color_override("font_color", Color(0.82, 0.82, 0.78))
    panel.add_child(rules_preview)
    _refresh_character_preview(0)
    presentation_select = _option_row(panel, "Gender presentation", PRESENTATIONS)
    pronoun_select = _option_row(panel, "Pronouns", PRONOUN_SETS)
    custom_pronouns = _line_edit(panel, "Custom pronouns (optional)", "e.g. xe / xem / xyr")

    _section(panel, "APPEARANCE")
    skin_select = _option_row(panel, "Skin tone", SKIN_TONES)
    eye_select = _option_row(panel, "Eye colour", EYE_COLOURS)
    hair_colour_select = _option_row(panel, "Hair colour", HAIR_COLOURS)
    hair_style_select = _option_row(panel, "Hair style", HAIR_STYLES)
    body_select = _option_row(panel, "Body build", BODY_BUILDS)

    _section(panel, "STARTING CLOTHING")
    shirt_select = _option_row(panel, "Shirt", ["Simple tunic", "Linen shirt", "Blouse", "Vest", "No shirt"])
    trousers_select = _option_row(panel, "Legwear", ["Trousers", "Skirt", "Long skirt", "Shorts"])

    var note := Label.new()
    note.text = "Appearance choices are saved to your character profile. The current player model is still a placeholder; detailed Ara face, hair and body variants will appear once the generic player model and modular assets are built."
    note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    note.add_theme_color_override("font_color", Color(0.9, 0.75, 0.48))
    panel.add_child(note)

    start_button = Button.new()
    start_button.text = "BEGIN IN HOLLOWMERE"
    start_button.custom_minimum_size = Vector2(0, 52)
    start_button.pressed.connect(_finish)
    panel.add_child(start_button)

func _section(parent: VBoxContainer, text_value: String) -> void:
    var label := Label.new()
    label.text = text_value
    label.add_theme_font_size_override("font_size", 19)
    label.add_theme_color_override("font_color", Color(0.83, 0.72, 0.49))
    parent.add_child(label)

func _line_edit(parent: VBoxContainer, label_text: String, placeholder: String) -> LineEdit:
    var row := HBoxContainer.new()
    parent.add_child(row)
    var label := Label.new()
    label.text = label_text
    label.custom_minimum_size.x = 145
    row.add_child(label)
    var field := LineEdit.new()
    field.placeholder_text = placeholder
    field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(field)
    return field

func _option_row(parent: VBoxContainer, label_text: String, values: Array) -> OptionButton:
    var row := HBoxContainer.new()
    parent.add_child(row)
    var label := Label.new()
    label.text = label_text
    label.custom_minimum_size.x = 205
    row.add_child(label)
    var select := OptionButton.new()
    select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    for value in values:
        select.add_item(str(value))
    row.add_child(select)
    return select

func _load_saved_profile() -> void:
    if not FileAccess.file_exists(SAVE_PATH):
        return
    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if file == null:
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not parsed is Dictionary:
        return
    var data: Dictionary = parsed
    name_edit.text = str(data.get("name", ""))
    _select_metadata(race_select, str(data.get("race", "human")))
    _select_metadata(class_select, str(data.get("character_class", "fighter")))
    _select_text(game_mode_select, "Campaign" if str(data.get("game_mode", "campaign")) == "campaign" else "Arena")
    _select_metadata(difficulty_select, str(data.get("difficulty_mode", "normal")))
    ironman_check.button_pressed = bool(data.get("ironman_mode", false))
    _select_text(presentation_select, str(data.get("gender_presentation", "Masculine")))
    _select_text(pronoun_select, str(data.get("pronoun_preset", "They / them")))
    custom_pronouns.text = str(data.get("custom_pronouns", ""))
    _select_text(skin_select, str(data.get("skin_tone", "Medium")))
    _select_text(eye_select, str(data.get("eye_colour", "Brown")))
    _select_text(hair_colour_select, str(data.get("hair_colour", "Dark brown")))
    _select_text(hair_style_select, str(data.get("hair_style", "Short")))
    _select_text(body_select, str(data.get("body_build", "Average")))
    _select_text(shirt_select, str(data.get("shirt", "Simple tunic")))
    _select_text(trousers_select, str(data.get("legwear", "Trousers")))
    _refresh_character_preview(0)
    _update_mode_controls(game_mode_select.selected)

func _select_metadata(select: OptionButton, value: String) -> void:
    for index in range(select.item_count):
        if String(select.get_item_metadata(index)) == value:
            select.select(index)
            return

func _selected_id(select: OptionButton, fallback: String) -> String:
    if select == null or select.selected < 0:
        return fallback
    var value: Variant = select.get_item_metadata(select.selected)
    return String(value) if value != null else fallback

func _refresh_character_preview(_index: int) -> void:
    if rules_preview != null:
        rules_preview.text = RULES.preview_text(_selected_id(race_select, "human"), _selected_id(class_select, "fighter"), _selected_id(difficulty_select, "normal"))

func _update_mode_controls(_index: int) -> void:
    if game_mode_select == null:
        return
    var arena := game_mode_select.get_item_text(game_mode_select.selected) == "Arena"
    mode_note.text = "Arena is selected, but its lobby and combat loop have not yet been ported. Select Campaign to begin the playable Hollowmere opening." if arena else "Campaign 2 — Small World opens in Hollowmere. Main Campaign content is not yet ported. Ironman save enforcement is also pending."
    start_button.disabled = arena
    start_button.text = "ARENA MODE NOT YET AVAILABLE" if arena else "BEGIN IN HOLLOWMERE"

func _select_text(select: OptionButton, value: String) -> void:
    for index in range(select.item_count):
        if select.get_item_text(index) == value:
            select.select(index)
            return

func _finish() -> void:
    if game_mode_select.get_item_text(game_mode_select.selected) == "Arena":
        mode_note.text = "Arena is not yet playable. Choose Campaign to start."
        return
    var pronoun_value := pronoun_select.get_item_text(pronoun_select.selected)
    var custom_value := custom_pronouns.text.strip_edges()
    if pronoun_value == "Custom" and custom_value.is_empty():
        custom_pronouns.grab_focus()
        custom_pronouns.placeholder_text = "Please enter your pronouns"
        return
    var profile := {
        "schema_version": 2,
        "name": name_edit.text.strip_edges() if not name_edit.text.strip_edges().is_empty() else "Adventurer",
        "race": _selected_id(race_select, "human"),
        "character_class": _selected_id(class_select, "fighter"),
        "game_mode": "campaign",
        "campaign_id": "2",
        "difficulty_mode": _selected_id(difficulty_select, "normal"),
        "ironman_mode": ironman_check.button_pressed,
        "gender_presentation": presentation_select.get_item_text(presentation_select.selected),
        "pronoun_preset": pronoun_value,
        "pronouns": custom_value if pronoun_value == "Custom" else _pronouns_for(pronoun_value),
        "custom_pronouns": custom_value,
        "skin_tone": skin_select.get_item_text(skin_select.selected),
        "skin_colour": SKIN_COLOURS[skin_select.selected],
        "eye_colour": eye_select.get_item_text(eye_select.selected),
        "hair_colour": hair_colour_select.get_item_text(hair_colour_select.selected),
        "hair_style": hair_style_select.get_item_text(hair_style_select.selected),
        "body_build": body_select.get_item_text(body_select.selected),
        "shirt": shirt_select.get_item_text(shirt_select.selected),
        "legwear": trousers_select.get_item_text(trousers_select.selected)
    }
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify(profile, "\t"))
    completed.emit(profile)
    queue_free()

func _pronouns_for(preset: String) -> String:
    match preset:
        "He / him": return "he/him"
        "She / her": return "she/her"
        "They / them": return "they/them"
        "Use my name": return "name"
        _: return ""

