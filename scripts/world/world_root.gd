extends Node3D

const HOLLOWMERE_VILLAGE_SCRIPT = preload("res://scripts/world/hollowmere_village.gd")
const HOLLOW_TANKARD_SCRIPT = preload("res://scripts/world/hollow_tankard.gd")

func _ready() -> void:
    var village := HOLLOWMERE_VILLAGE_SCRIPT.new()
    village.name = "HollowmereVillage"
    add_child(village)

    var tavern := HOLLOW_TANKARD_SCRIPT.new()
    tavern.name = "HollowTankard"
    add_child(tavern)
