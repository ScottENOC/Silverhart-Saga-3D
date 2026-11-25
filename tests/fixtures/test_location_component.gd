extends Node

var received_simulation: WorldSimulation
var received_profile: Dictionary = {}
var received_save_data: Dictionary = {}
var received_location_data: Dictionary = {}

func configure_location(location_data: Dictionary) -> void:
	received_location_data = location_data.duplicate(true)

func configure_campaign(simulation: WorldSimulation, profile: Dictionary, save_data: Dictionary) -> void:
	received_simulation = simulation
	received_profile = profile.duplicate(true)
	received_save_data = save_data.duplicate(true)
