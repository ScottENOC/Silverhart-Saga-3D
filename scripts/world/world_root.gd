extends Node3D

const HOLLOWMERE_VILLAGE_SCRIPT = preload("res://scripts/world/hollowmere_village.gd")
const HOLLOW_TANKARD_SCRIPT = preload("res://scripts/world/hollow_tankard.gd")
const CHARACTER_CREATOR_SCRIPT = preload("res://scripts/ui/player_character_creator.gd")

var village: Node3D
var tavern: Node3D
var loading_layer: CanvasLayer
var loading_label: Label
var loading_bar: ProgressBar
var loading_detail: Label
var pending_save_data: Dictionary = {}

func _ready() -> void:
    _create_loading_overlay()
    if SaveManager.has_pending_load():
        pending_save_data = SaveManager.consume_pending_load()
        loading_layer.visible = true
        _set_loading_stage("Restoring campaign…", "Rebuilding the base world before applying your saved changes.", 5.0)
        await get_tree().process_frame
        _on_character_created(pending_save_data.get("player_profile", {}).duplicate(true))
        return
    loading_layer.visible = true
    _set_loading_stage(
        "Preparing the campaign…",
        "Loading the character creator and its Ara model preview. This can take a little while on first launch.",
        5.0
    )
    # Give Godot a frame to actually draw the loading screen before the
    # character creator performs synchronous model/resource setup.
    await get_tree().process_frame

    _set_loading_stage(
        "Loading character creation…",
        "Preparing the character preview and appearance options.",
        15.0
    )
    await get_tree().process_frame

    var creator := CHARACTER_CREATOR_SCRIPT.new()
    creator.name = "PlayerCharacterCreator"
    creator.completed.connect(_on_character_created)
    add_child(creator)

    # The creator is now ready and visible on its own CanvasLayer.
    loading_layer.visible = false

func _create_loading_overlay() -> void:
    loading_layer = CanvasLayer.new()
    loading_layer.name = "WorldLoadingOverlay"
    loading_layer.layer = 200
    loading_layer.visible = false
    add_child(loading_layer)

    var backdrop := ColorRect.new()
    backdrop.color = Color(0.035, 0.045, 0.06, 0.96)
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    loading_layer.add_child(backdrop)

    var centre := CenterContainer.new()
    centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    loading_layer.add_child(centre)

    var stack := VBoxContainer.new()
    stack.custom_minimum_size = Vector2(420.0, 0.0)
    stack.add_theme_constant_override("separation", 14)
    centre.add_child(stack)

    var heading := Label.new()
    heading.text = "SILVERHART SAGA — MAIN CAMPAIGN"
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    heading.add_theme_font_size_override("font_size", 22)
    stack.add_child(heading)

    loading_label = Label.new()
    loading_label.text = "Preparing your character…"
    loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    loading_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    stack.add_child(loading_label)

    loading_bar = ProgressBar.new()
    loading_bar.min_value = 0.0
    loading_bar.max_value = 100.0
    loading_bar.value = 0.0
    loading_bar.show_percentage = false
    loading_bar.custom_minimum_size = Vector2(420.0, 16.0)
    stack.add_child(loading_bar)

    loading_detail = Label.new()
    loading_detail.text = "Please wait…"
    loading_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    loading_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    loading_detail.add_theme_font_size_override("font_size", 13)
    loading_detail.add_theme_color_override("font_color", Color(0.72, 0.76, 0.79))
    stack.add_child(loading_detail)

func _set_loading_stage(message: String, detail: String, progress: float) -> void:
    loading_label.text = message
    loading_detail.text = detail
    loading_bar.value = progress

func _on_character_created(profile: Dictionary) -> void:
    loading_layer.visible = true

    # Construct each large procedural scene only when needed. These are
    # synchronous stages, so the displayed message identifies the operation
    # currently occupying the main thread; the bar advances at stage boundaries.
    _set_loading_stage(
        "Generating Hollowmere village…",
        "Creating terrain, roads, stream, buildings, bridge and surrounding forest.",
        25.0
    )
    await get_tree().process_frame
    village = HOLLOWMERE_VILLAGE_SCRIPT.new()
    village.name = "HollowmereVillage"
    add_child(village)

    _set_loading_stage(
        "Building the Hollow Tankard…",
        "Creating the hex map, tavern interior, furniture, simulation and starting area.",
        50.0
    )
    await get_tree().process_frame
    tavern = HOLLOW_TANKARD_SCRIPT.new()
    tavern.name = "HollowTankard"
    tavern.set("player_profile", profile.duplicate(true))
    tavern.set("pending_save_data", pending_save_data.duplicate(true))
    add_child(tavern)

    _set_loading_stage(
        "Loading villagers and character models…",
        "Setting up NPCs, equipment, the player appearance and the opening scene.",
        85.0
    )
    await get_tree().process_frame
    if tavern.has_method("apply_player_profile"):
        tavern.apply_player_profile(profile)

    _set_loading_stage(
        "Hollowmere is ready",
        "Entering the Main Campaign…",
        100.0
    )
    await get_tree().process_frame
    loading_layer.visible = false
