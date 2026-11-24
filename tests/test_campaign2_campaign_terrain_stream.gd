extends SceneTree

const TERRAIN_STREAM = preload("res://scripts/world/campaign2_campaign_terrain_stream.gd")
const MULTISTORY_REGISTRY = preload("res://scripts/world/campaign2_multistory_location_registry.gd")
const COMPANION_RUNTIME_STORE = preload("res://scripts/simulation/companion_campaign_runtime_store.gd")


func stream_registry_contract() -> bool:
	var stream := TERRAIN_STREAM.new() as Campaign2CampaignTerrainStream
	var ok := stream._ensure_multistory_registry() and stream.multistory_registry != null
	stream.free()
	return ok


func _initialize() -> void:
	var simulation := WorldSimulation.new()
	simulation.player_character_id = "player"

	# Both campaign and preview streams use the shared registry initialiser.
	# The campaign subclass overrides _ready(), so this specifically protects
	# its path from skipping the parent preview setup.
	assert(stream_registry_contract(), "Campaign terrain stream must be able to initialise the multi-story registry.")

	# Missing Object metadata is normal on a fresh simulation; state accessors
	# must not call get_meta until the corresponding key exists.
	assert(not simulation.has_meta("companion_relationship_state"))
	assert(not simulation.has_meta("companion_quest_chain_state"))
	assert(COMPANION_RUNTIME_STORE.relationship_state_for(simulation) is CompanionRelationshipState)
	assert(COMPANION_RUNTIME_STORE.quest_chain_state_for(simulation) is CompanionQuestChainState)
	assert(simulation.has_meta("companion_relationship_state"))
	assert(simulation.has_meta("companion_quest_chain_state"))

	var stream := TERRAIN_STREAM.new() as Campaign2CampaignTerrainStream
	stream.configure_campaign(simulation)
	assert(stream.campaign_simulation == simulation, "Terrain stream must retain the authoritative campaign simulation.")
	assert(stream.ecology_simulation == null, "Configuring the stream must not create or assign a second simulation.")
	assert(stream._ensure_multistory_registry(), "Campaign stream must initialise its inherited multi-story registry before streaming.")
	assert(stream.multistory_registry != null, "Campaign stream registry must not be null.")
	assert(not MULTISTORY_REGISTRY.new().get_definition("silthandriel").is_empty(), "Registry fixture must contain the elven capital used by streamed canopy presentation.")

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
