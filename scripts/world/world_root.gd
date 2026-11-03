extends Node3D

const HOLLOW_TANKARD_SCRIPT = preload("res://scripts/world/hollow_tankard.gd")

func _ready() -> void:
    var tavern := HOLLOW_TANKARD_SCRIPT.new()
    tavern.name = "HollowTankard"
    add_child(tavern)
