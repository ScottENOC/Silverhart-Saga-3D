extends SceneTree

const TERRAIN_STREAM = preload("res://scripts/world/campaign2_campaign_terrain_stream.gd")


func _initialize() -> void:
	var simulation := WorldSimulation.new()
	simulation.player_character_id = "player"

	var stream := TERRAIN_STREAM.new() as Campaign2CampaignTerrainStream
	stream.configure_campaign(simulation)
	assert(stream.campaign_simulation == simulation, "Terrain stream must retain the authoritative campaign simulation.")
	assert(stream.ecology_simulation == null, "Configuring the stream must not create or assign a second simulation.")

	simulation.building_registry.definitions["test_virtual_interior"] = {
		"virtual_floor_bounds": [96, 104, 96, 104]
	}
	assert(
		stream._is_virtual_interior_hex(Vector2i(100, 100)),
		"Virtual multi-storey floor coordinates must not move the exterior terrain stream."
	)
	assert(
		not stream._is_virtual_interior_hex(Vector2i(100, 105)),
		"Exterior coordinates beyond the virtual floor bounds must remain eligible for streaming."
	)

	stream.free()
	simulation.free()
	print("Campaign-backed regional terrain stream contract tests passed.")
	quit(0)
