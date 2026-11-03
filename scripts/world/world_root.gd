extends Node3D

func _ready() -> void:
    var tavern := HollowTankard.new()
    tavern.name = "HollowTankard"
    add_child(tavern)
