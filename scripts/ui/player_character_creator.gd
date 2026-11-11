extends CanvasLayer
## First-run player identity and appearance setup.
## Ara geometry is generated at build time; this screen stores a profile and
## applies supported runtime material/name changes without claiming live mesh regeneration.

signal completed(profile: Dictionary)

const RULES = preload("res://scripts/simulation/character_creation_rules.gd")
const ITEM_CATALOG = preload("res://scripts/simulation/item_catalog.gd")

const SAVE_PATH := "user://player_appearance.json"
const SKIN_TONES := ["Porcelain", "Fair", "Light", "Medium", "Olive", "Brown", "Deep brown"]
const SKIN_COLOURS := ["#f2d8c4", "#e8c2a2", "#d6a47e", "#b9825f", "#9a6849", "#70452f", "#45291f"]
const EYE_COLOURS := ["Brown", "Light brown", "Dark brown", "Green", "Blue", "Grey", "Ice blue"]
const HAIR_COLOURS := ["Black", "Dark brown", "Chestnut", "Blonde", "Red", "Silver", "White", "Blue", "Green"]
const HAIR_STYLES := ["Short 1", "Short 2", "Short 3", "Short 4", "Afro", "Bob 1", "Bob 2", "Braid", "Long", "Ponytail", "Buzz cut", "Mohawk", "Cornrows", "Box braids", "None"]
const HAIR_STYLE_IDS := {
    "Short 1": "short01", "Short 2": "short02", "Short 3": "short03", "Short 4": "short04",
    "Afro": "afro01", "Bob 1": "bob01", "Bob 2": "bob02", "Braid": "braid01",
    "Long": "long01", "Ponytail": "ponytail01", "Buzz cut": "buzz",
    "Mohawk": "mohawk", "Cornrows": "cornrows", "Box braids": "box_braids", "None": "none"
}
const BODY_BUILDS := ["Lean", "Average", "Broad", "Muscular", "Soft", "Androgynous"]
const PRESENTATIONS := ["Masculine", "Feminine", "Androgynous", "Mixed", "Custom"]
const PRONOUN_SETS := ["He / him", "She / her", "They / them", "Use my name", "Custom"]
const FEMALE_PREVIEW_ASSET := "res://art/characters/ara_runtime/ara_person_body.glb"
const MALE_PREVIEW_ASSET := "res://art/characters/ara_runtime/ara_person_male_body.glb"
const ARA_ACTOR = preload("res://scripts/presentation/ara_character_actor.gd")

var name_edit: LineEdit
var game_mode_select: OptionButton
var campaign_select: OptionButton
var difficulty_select: OptionButton
var ironman_check: CheckBox
var arena_rewards_check: CheckBox
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
var body_variant_select: OptionButton
var height_slider: HSlider
var preview_status: Label
var preview_actor: AraCharacterActor
var preview_variant_loaded: String = ""

func _ready() -> void:
    layer = 100
    _build_screen()
    _load_saved_profile()
    call_deferred("_refresh_appearance_preview", 0)

func _build_screen() -> void:
    var backdrop := ColorRect.new()
    backdrop.color = Color(0.055, 0.065, 0.075, 0.97)
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(backdrop)

    var scroll := ScrollContainer.new()
    scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    scroll.offset_left = 12
    scroll.offset_top = 12
    scroll.offset_right = -12
    scroll.offset_bottom = -12
    add_child(scroll)

    var centre := CenterContainer.new()
    centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(centre)

    var panel := VBoxContainer.new()
    panel.custom_minimum_size = Vector2(0, 0)
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    panel.add_theme_constant_override("separation", 10)
    centre.add_child(panel)

    var title := Label.new()
    title.text = "CREATE YOUR CHARACTER"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 30)
    panel.add_child(title)

    var intro := Label.new()
    intro.text = "Choose who arrives in Hollowmere, the opening village of the Main Campaign. Identity, presentation and appearance are independent."
    intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    intro.add_theme_color_override("font_color", Color(0.78, 0.79, 0.78))
    panel.add_child(intro)

    _section(panel, "LIVE CHARACTER PREVIEW")
    var preview_container := SubViewportContainer.new()
    preview_container.custom_minimum_size = Vector2(0, 280)
    preview_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    preview_container.stretch = true
    var preview_viewport := SubViewport.new()
    preview_viewport.name = "CharacterPreviewViewport"
    preview_viewport.size = Vector2i(720, 420)
    preview_viewport.own_world_3d = true
    preview_container.add_child(preview_viewport)
    panel.add_child(preview_container)
    var preview_rotation_row := HBoxContainer.new()
    preview_rotation_row.alignment = BoxContainer.ALIGNMENT_CENTER
    var rotate_left := Button.new()
    rotate_left.text = "Rotate left"
    rotate_left.pressed.connect(func(): _rotate_preview(-30.0))
    preview_rotation_row.add_child(rotate_left)
    var rotate_right := Button.new()
    rotate_right.text = "Rotate right"
    rotate_right.pressed.connect(func(): _rotate_preview(30.0))
    preview_rotation_row.add_child(rotate_right)
    panel.add_child(preview_rotation_row)
    var preview_world := Node3D.new()
    preview_world.name = "PreviewWorld"
    preview_viewport.add_child(preview_world)
    var preview_environment := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color(0.12, 0.14, 0.16)
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.72, 0.70, 0.66)
    environment.ambient_light_energy = 0.8
    preview_environment.environment = environment
    preview_world.add_child(preview_environment)
    var preview_light := DirectionalLight3D.new()
    preview_light.rotation_degrees = Vector3(-28, -25, 0)
    preview_light.light_energy = 1.4
    preview_world.add_child(preview_light)
    var preview_camera := Camera3D.new()
    preview_camera.position = Vector3(0, 1.05, 3.4)
    preview_camera.fov = 35
    preview_camera.look_at_from_position(preview_camera.position, Vector3(0, 0.95, 0), Vector3.UP)
    preview_world.add_child(preview_camera)
    preview_camera.current = true
    preview_actor = ARA_ACTOR.new() as AraCharacterActor
    preview_actor.name = "PreviewCharacter"
    preview_world.add_child(preview_actor)
    preview_status = Label.new()
    preview_status.text = "Loading character preview…"
    preview_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    preview_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    preview_status.add_theme_color_override("font_color", Color(0.9, 0.75, 0.48))
    panel.add_child(preview_status)

    _section(panel, "GAME MODE")
    game_mode_select = _option_row(panel, "Mode", ["Campaign", "Arena"])
    campaign_select = _option_row(panel, "Campaign", ["Main Campaign — Hollowmere"])
    campaign_select.set_item_metadata(0, "2")
    difficulty_select = _option_row(panel, "Difficulty", ["Easy", "Normal", "Hard"])
    for i in range(3):
        difficulty_select.set_item_metadata(i, ["easy", "normal", "hard"][i])
    ironman_check = CheckBox.new()
    ironman_check.text = "Ironman run (save enforcement not yet ported)"
    panel.add_child(ironman_check)
    arena_rewards_check = CheckBox.new()
    arena_rewards_check.text = "Arena roguelike rewards"
    arena_rewards_check.button_pressed = true
    panel.add_child(arena_rewards_check)
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
    _select_metadata(race_select, "human")
    var race_note := Label.new()
    race_note.text = "Race changes your starting attribute pools and available racial skill trees. All races currently share the existing character models; appearance is chosen separately."
    race_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    race_note.add_theme_color_override("font_color", Color(0.78, 0.82, 0.76))
    panel.add_child(race_note)
    _select_metadata(class_select, "fighter")
    _select_metadata(difficulty_select, "normal")
    race_select.item_selected.connect(_refresh_character_preview)
    class_select.item_selected.connect(_refresh_character_preview)
    class_select.item_selected.connect(_refresh_appearance_preview)
    difficulty_select.item_selected.connect(_refresh_character_preview)
    rules_preview = Label.new()
    rules_preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    rules_preview.add_theme_font_size_override("font_size", 13)
    rules_preview.add_theme_color_override("font_color", Color(0.82, 0.82, 0.78))
    panel.add_child(rules_preview)
    _refresh_character_preview(0)
    body_variant_select = _option_row(panel, "Body model", ["Female", "Male"])
    body_variant_select.item_selected.connect(_refresh_appearance_preview)
    presentation_select = _option_row(panel, "Gender presentation", PRESENTATIONS)
    pronoun_select = _option_row(panel, "Pronouns", PRONOUN_SETS)
    custom_pronouns = _line_edit(panel, "Custom pronouns (optional)", "e.g. xe / xem / xyr")

    _section(panel, "APPEARANCE")
    skin_select = _option_row(panel, "Skin tone", SKIN_TONES)
    eye_select = _option_row(panel, "Eye colour", EYE_COLOURS)
    hair_colour_select = _option_row(panel, "Hair colour", HAIR_COLOURS)
    hair_style_select = _option_row(panel, "Hair style", HAIR_STYLES)
    body_select = _option_row(panel, "Body build", BODY_BUILDS)
    height_slider = HSlider.new()
    height_slider.min_value = 0.90
    height_slider.max_value = 1.10
    height_slider.step = 0.01
    height_slider.value = 1.0
    height_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var height_row := HBoxContainer.new()
    var height_label := Label.new()
    height_label.text = "Height"
    height_label.custom_minimum_size.x = 135
    height_row.add_child(height_label)
    height_row.add_child(height_slider)
    panel.add_child(height_row)
    for selector in [skin_select, eye_select, hair_colour_select, hair_style_select, body_select, presentation_select]:
        selector.item_selected.connect(_refresh_appearance_preview)
    height_slider.value_changed.connect(_refresh_appearance_preview_value)

    _section(panel, "STARTING EQUIPMENT")
    var equipment_note := Label.new()
    equipment_note.text = "Your selected class determines its starting inventory. Equipped armour, weapons and shields appear on the preview when their Workshop and prop assets are installed. You can change equipment later from the in-game Inventory screen."
    equipment_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    equipment_note.add_theme_color_override("font_color", Color(0.78, 0.82, 0.76))
    panel.add_child(equipment_note)

    var note := Label.new()
    note.text = "Appearance choices use the shared Ara character rig. Hairstyles are separate skinned exports; body proportions use only morph targets present in the exported model."
    note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    note.add_theme_color_override("font_color", Color(0.9, 0.75, 0.48))
    panel.add_child(note)

    start_button = Button.new()
    start_button.text = "BEGIN MAIN CAMPAIGN"
    start_button.custom_minimum_size = Vector2(0, 52)
    start_button.pressed.connect(_finish)
    panel.add_child(start_button)
    _update_mode_controls(game_mode_select.selected)

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
    label.custom_minimum_size.x = 120
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
    label.custom_minimum_size.x = 135
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
    _select_metadata(campaign_select, str(data.get("campaign_id", "2")))
    arena_rewards_check.button_pressed = bool(data.get("arena_roguelike_rewards", true))
    _select_text(body_variant_select, "Male" if str(data.get("body_variant", "female")) == "male" else "Female")
    _select_text(presentation_select, str(data.get("gender_presentation", "Masculine")))
    _select_text(pronoun_select, str(data.get("pronoun_preset", "They / them")))
    custom_pronouns.text = str(data.get("custom_pronouns", ""))
    _select_text(skin_select, str(data.get("skin_tone", "Medium")))
    _select_text(eye_select, str(data.get("eye_colour", "Brown")))
    _select_text(hair_colour_select, str(data.get("hair_colour", "Dark brown")))
    _select_text(hair_style_select, str(data.get("hair_style", "Short 2")))
    _select_text(body_select, str(data.get("body_build", "Average")))
    height_slider.value = clampf(float(data.get("height_scale", 1.0)), 0.90, 1.10)
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

func _refresh_appearance_preview(_index: int) -> void:
    if preview_actor == null or not is_instance_valid(preview_actor):
        return
    var variant := "male" if body_variant_select.get_item_text(body_variant_select.selected) == "Male" else "female"
    var asset_path := MALE_PREVIEW_ASSET if variant == "male" else FEMALE_PREVIEW_ASSET
    if not ResourceLoader.exists(asset_path):
        preview_status.text = "Preview asset not found: %s. Your appearance choices can still be saved." % asset_path
        return
    if preview_variant_loaded != variant:
        var body_resource := await _load_preview_asset(asset_path, "%s Ara body model" % variant.capitalize(), 0, 2)
        if body_resource == null or not preview_actor.configure(asset_path):
            preview_status.text = "Preview asset unavailable or failed to instantiate: %s. Your appearance choices can still be saved." % asset_path
            preview_variant_loaded = ""
            return
        preview_variant_loaded = variant
    var build_factors := {"Lean": 0.96, "Average": 1.0, "Broad": 1.045, "Muscular": 1.055, "Soft": 1.04, "Androgynous": 1.0}
    var profile := {
        "skin_colour": SKIN_COLOURS[skin_select.selected],
        "eye_colour": eye_select.get_item_text(eye_select.selected),
        "hair_colour": hair_colour_select.get_item_text(hair_colour_select.selected),
        "height_scale": height_slider.value,
        "build_scale": float(build_factors.get(body_select.get_item_text(body_select.selected), 1.0)),
        "body_variant": variant,
        "gender_presentation": presentation_select.get_item_text(presentation_select.selected),
        "pronouns": "they/them"
    }
    profile["height"] = inverse_lerp(0.90, 1.10, height_slider.value)
    profile["muscle"] = inverse_lerp(0.96, 1.055, float(build_factors.get(body_select.get_item_text(body_select.selected), 1.0)))
    preview_actor.apply_player_profile(profile)
    preview_actor.apply_equipment_visuals(_preview_equipment_for_class())
    var hair_id := String(HAIR_STYLE_IDS.get(hair_style_select.get_item_text(hair_style_select.selected), "short02"))
    var hair_path := "res://art/characters/ara_runtime/hair/%s_%s.glb" % [variant, hair_id]
    var using_ara_base := preview_actor.loaded_asset_path.contains("/ara_runtime/")
    var hair_loaded := false
    if using_ara_base:
        if hair_id == "none":
            preview_actor.clear_hairstyle()
            hair_loaded = true
            preview_status.text = "Loaded 2 of 2 assets · %s body ready · no separate hairstyle required." % variant.capitalize()
        elif ResourceLoader.exists(hair_path):
            var hair_resource := await _load_preview_asset(hair_path, "%s hairstyle (%s)" % [hair_style_select.get_item_text(hair_style_select.selected), hair_id], 1, 2)
            hair_loaded = hair_resource != null and preview_actor.set_hairstyle(hair_path)
    if using_ara_base and hair_loaded:
        preview_status.text = "Loaded 2 of 2 assets · %s body and %s hairstyle ready. Hair colour is independently tintable." % [variant.capitalize(), hair_style_select.get_item_text(hair_style_select.selected)]
    elif using_ara_base:
        preview_status.text = "Loaded 1 of 2 assets · %s body ready. FAILED: hairstyle asset %s is missing or incompatible with the body skeleton." % [variant.capitalize(), hair_id]
    else:
        preview_status.text = "Loaded 1 of 1 assets · Legacy preview model ready. Install the Ara hair bundle to enable separate hairstyles."

func _preview_equipment_for_class() -> Dictionary:
    var definition := RULES.class_definition(_selected_id(class_select, "fighter"))
    var equipped: Dictionary = {}
    for item_id_variant in definition.get("equipped", []):
        var item_id := String(item_id_variant)
        var item := ITEM_CATALOG.get_definition(item_id)
        var slot := String(item.get("equipment_slot", ""))
        if not slot.is_empty():
            equipped[slot] = item
    return equipped


func _load_preview_asset(path: String, description: String, loaded_count: int, total_count: int) -> Resource:
    if ResourceLoader.has_cached(path):
        preview_status.text = "Loaded %d of %d assets · Currently loading: %s (cached)" % [loaded_count + 1, total_count, description]
        return load(path)
    var request_error := ResourceLoader.load_threaded_request(path)
    if request_error != OK and request_error != ERR_BUSY:
        preview_status.text = "FAILED to start loading %s (error %d)." % [description, request_error]
        return null
    var progress: Array = []
    var status := ResourceLoader.load_threaded_get_status(path, progress)
    while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
        var percent := int(round(float(progress[0]) * 100.0)) if not progress.is_empty() else 0
        preview_status.text = "Loaded %d of %d assets\nCurrently loading: %s (%d%%)" % [loaded_count, total_count, description, percent]
        await get_tree().process_frame
        progress.clear()
        status = ResourceLoader.load_threaded_get_status(path, progress)
    if status != ResourceLoader.THREAD_LOAD_LOADED:
        preview_status.text = "FAILED loading %s (status %d). Check the Godot Output panel for the resource error." % [description, status]
        return null
    var resource := ResourceLoader.load_threaded_get(path)
    if resource == null:
        preview_status.text = "FAILED loading %s: Godot returned an empty resource." % description
        return null
    preview_status.text = "Loaded %d of %d assets · Finished: %s" % [loaded_count + 1, total_count, description]
    return resource

func _rotate_preview(degrees: float) -> void:
    if preview_actor != null and is_instance_valid(preview_actor):
        preview_actor.rotate_y(deg_to_rad(degrees))

func _refresh_appearance_preview_value(_value: float) -> void:
    _refresh_appearance_preview(0)

func _update_mode_controls(_index: int) -> void:
    if game_mode_select == null:
        return
    var arena := game_mode_select.get_item_text(game_mode_select.selected) == "Arena"
    campaign_select.visible = not arena
    arena_rewards_check.visible = arena
    mode_note.text = "Arena is selected, but its lobby and combat loop have not yet been ported. Select Campaign to begin the playable Hollowmere opening." if arena else "The Main Campaign opens in Hollowmere using the original Campaign 2 village and regional map. The wider campaign is being migrated in stages. Ironman save enforcement is still pending."
    if start_button != null:
        start_button.disabled = arena
        start_button.text = "ARENA MODE NOT YET AVAILABLE" if arena else "BEGIN MAIN CAMPAIGN"

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
        "schema_version": 3,
        "name": name_edit.text.strip_edges() if not name_edit.text.strip_edges().is_empty() else "Adventurer",
        "race": _selected_id(race_select, "human"),
        "character_class": _selected_id(class_select, "fighter"),
        "game_mode": "campaign",
        "campaign_id": _selected_id(campaign_select, "2"),
        "arena_roguelike_rewards": arena_rewards_check.button_pressed,
        "difficulty_mode": _selected_id(difficulty_select, "normal"),
        "ironman_mode": ironman_check.button_pressed,
        "body_variant": "male" if body_variant_select.get_item_text(body_variant_select.selected) == "Male" else "female",
        "height_scale": height_slider.value,
        "height": inverse_lerp(0.90, 1.10, height_slider.value),
        "build_scale": float({"Lean": 0.96, "Average": 1.0, "Broad": 1.045, "Muscular": 1.055, "Soft": 1.04, "Androgynous": 1.0}.get(body_select.get_item_text(body_select.selected), 1.0)),
        "muscle": float({"Lean": 0.42, "Average": 0.5, "Broad": 0.62, "Muscular": 0.88, "Soft": 0.3, "Androgynous": 0.5}.get(body_select.get_item_text(body_select.selected), 0.5)),
        "weight": float({"Lean": 0.28, "Average": 0.5, "Broad": 0.72, "Muscular": 0.38, "Soft": 0.82, "Androgynous": 0.5}.get(body_select.get_item_text(body_select.selected), 0.5)),
        "proportions": 0.5,
        "gender_presentation": presentation_select.get_item_text(presentation_select.selected),
        "pronoun_preset": pronoun_value,
        "pronouns": custom_value if pronoun_value == "Custom" else _pronouns_for(pronoun_value),
        "custom_pronouns": custom_value,
        "skin_tone": skin_select.get_item_text(skin_select.selected),
        "skin_colour": SKIN_COLOURS[skin_select.selected],
        "eye_colour": eye_select.get_item_text(eye_select.selected),
        "hair_colour": hair_colour_select.get_item_text(hair_colour_select.selected),
        "hair_style": hair_style_select.get_item_text(hair_style_select.selected),
        "hair_style_id": String(HAIR_STYLE_IDS.get(hair_style_select.get_item_text(hair_style_select.selected), "short02")),
        "body_build": body_select.get_item_text(body_select.selected)
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

