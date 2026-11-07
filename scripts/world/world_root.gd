extends Node3D

const HOLLOWMERE_VILLAGE_SCRIPT = preload("res://scripts/world/hollowmere_village.gd")
const HOLLOW_TANKARD_SCRIPT = preload("res://scripts/world/hollow_tankard.gd")
const CHARACTER_CREATOR_SCRIPT = preload("res://scripts/ui/player_character_creator.gd")

var village: Node3D
var tavern: Node3D

func _ready() -> void:
    village = HOLLOWMERE_VILLAGE_SCRIPT.new()
    village.name = "HollowmereVillage"
    add_child(village)

    tavern = HOLLOW_TANKARD_SCRIPT.new()
    tavern.name = "HollowTankard"
    add_child(tavern)

    # Keep the world behind the first-run creator; gameplay begins only after
    # the player confirms their identity and appearance.
    village.visible = false
    tavern.visible = false
    var creator := CHARACTER_CREATOR_SCRIPT.new()
    creator.name = "PlayerCharacterCreator"
    creator.completed.connect(_on_character_created)
    add_child(creator)

func _on_character_created(profile: Dictionary) -> void:
    if tavern.has_method("apply_player_profile"):
        tavern.apply_player_profile(profile)
    village.visible = true
    tavern.visible = true
