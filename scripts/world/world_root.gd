extends Node3D

const HOLLOWMERE_VILLAGE_SCRIPT = preload("res://scripts/world/hollowmere_village.gd")
const HOLLOW_TANKARD_SCRIPT = preload("res://scripts/world/hollow_tankard.gd")
const CHARACTER_CREATOR_SCRIPT = preload("res://scripts/ui/player_character_creator.gd")

var village: Node3D
var tavern: Node3D
var loading_layer: CanvasLayer
var loading_label: Label
var loading_bar: ProgressBar

func _ready() -> void:
    _create_loading_overlay()
    var creator := CHARACTER_CREATOR_SCRIPT.new()
    creator.name = "PlayerCharacterCreator"
    creator.completed.connect(_on_character_created)
    add_child(creator)

func _create_loading_overlay() -> void:
    loading_layer = CanvasLayer.new()
    loading_layer.name = "WorldLoadingOverlay"
    loading_layer.layer = 200
    loading_layer.visible = false
    add_child(loading_layer)

    var backdrop := ColorRect.new()
    backdrop.color = Color(0.035, 0.045, 0.06, 0.94)
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    loading_layer.add_child(backdrop)

    var centre := CenterContainer.new()
    centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    loading_layer.add_child(centre)

    var stack := VBoxContainer.new()
    stack.custom_minimum_size = Vector2(320.0, 0.0)
    stack.add_theme_constant_override("separation", 14)
    centre.add_child(stack)

    var heading := Label.new()
    heading.text = "ENTERING HOLLOWMERE"
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
    loading_bar.custom_minimum_size = Vector2(320.0, 12.0)
    stack.add_child(loading_bar)

func _set_loading_stage(message: String, progress: float) -> void:
    loading_label.text = message
    loading_bar.value = progress

func _on_character_created(profile: Dictionary) -> void:
    loading_layer.visible = true

    # Construct each large procedural scene only when needed. The previous
    # startup built both hidden scenes before the creator appeared, doing the
    # expensive work with no visible indication of what was happening.
    _set_loading_stage("Generating Hollowmere village terrain, roads and buildings…", 15.0)
    await get_tree().process_frame
    village = HOLLOWMERE_VILLAGE_SCRIPT.new()
    village.name = "HollowmereVillage"
    add_child(village)

    _set_loading_stage("Building the Hollow Tankard interior and hex movement map…", 55.0)
    await get_tree().process_frame
    tavern = HOLLOW_TANKARD_SCRIPT.new()
    tavern.name = "HollowTankard"
    add_child(tavern)

    _set_loading_stage("Loading Ara character models, NPCs and animations…", 85.0)
    await get_tree().process_frame
    if tavern.has_method("apply_player_profile"):
        tavern.apply_player_profile(profile)

    _set_loading_stage("Opening Hollowmere…", 100.0)
    await get_tree().process_frame
    loading_layer.visible = false
