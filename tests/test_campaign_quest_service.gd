extends SceneTree

const QUEST_SERVICE = preload("res://scripts/quests/campaign_quest_service.gd")
const QUEST_REGISTRY = preload("res://scripts/quests/campaign_quest_registry.gd")
const ABANDONED_HOUSE = preload("res://scripts/simulation/abandoned_house_clearing_quest.gd")
const TOLL_TAKER = preload("res://scripts/simulation/toll_taker_quest_content.gd")
const CAMPAIGN_COORDINATOR = preload("res://scripts/campaign/campaign_coordinator.gd")
const FARM_WOLVES = preload("res://scripts/simulation/farm_wolves_quest.gd")


func _initialize() -> void:
	_test_registry_registration()
	_test_campaign_coordinator_initialization()
	_test_service_journal_facade()
	_test_unconfigured_service_fails_safely()
	print("Campaign quest service tests passed.")
	quit(0)


func _test_registry_registration() -> void:
	var simulation := WorldSimulation.new()
	var result := QUEST_REGISTRY.register_definitions(simulation)
	assert(bool(result.get("ok", false)))
	assert(simulation.campaign_journal.quest_definitions.has(ABANDONED_HOUSE.QUEST_ID))
	assert(simulation.campaign_journal.quest_definitions.has(TOLL_TAKER.QUEST_ID))
	assert(result.get("registered_quest_ids", []).size() == 11, "The central registry should register every campaign quest module.")
	assert(result.get("failed_quests", []).is_empty())
	var repeated := QUEST_REGISTRY.register_definitions(simulation)
	assert(bool(repeated.get("ok", false)), "Registry should tolerate repeated registration.")


func _test_campaign_coordinator_initialization() -> void:
	var simulation := WorldSimulation.new()
	var coordinator := CAMPAIGN_COORDINATOR.new()
	var result: Dictionary = coordinator.initialize(simulation, {"race": "human"})
	assert(bool(result.get("ok", false)), "Campaign coordinator should initialize a fresh simulation.")
	assert(is_equal_approx(simulation.clock.world_seconds, 11.0 * 3600.0))
	for quest_id in [
		"hollowmere_ironbond_shakedown",
		FARM_WOLVES.QUEST_ID,
		"elder_locket",
		"aldenreach_message",
		"abandoned_house_cleared"
	]:
		assert(simulation.campaign_journal.quest_definitions.has(quest_id), "Coordinator should register %s." % quest_id)
	assert(not simulation.campaign_journal.npc_reputation.is_empty(), "Coordinator should seed opening social standings.")
	var repeated: Dictionary = coordinator.quest_service.register_definitions()
	assert(bool(repeated.get("ok", false)), "Campaign registration should be safe to repeat.")
	coordinator.free()
	simulation.free()


func _test_service_journal_facade() -> void:
	var simulation := WorldSimulation.new()
	var service := QUEST_SERVICE.new()
	assert(service.configure(simulation).ok)
	var registration := service.register_definitions()
	assert(bool(registration.get("ok", false)))
	assert(registration.get("registered_quest_ids", []).size() == 11, "The service facade should expose the complete registry result.")
	assert(registration.get("failed_quests", []).is_empty())
	var started := service.start(ABANDONED_HOUSE.QUEST_ID)
	assert(bool(started.get("ok", false)))
	assert(String(service.state(ABANDONED_HOUSE.QUEST_ID).get("status", "")) == "active")
	var progress := service.set_objective_progress(
		ABANDONED_HOUSE.QUEST_ID,
		"house_guardians_defeated",
		1.0
	)
	# The service must pass through journal validation rather than inventing
	# objectives or silently accepting unknown quest state.
	assert(bool(progress.get("ok", false)), "Known quest objectives should be updated through the service.")
	var failed := service.fail(ABANDONED_HOUSE.QUEST_ID, "service regression test")
	assert(bool(failed.get("ok", false)), "Quest failures should pass through the service facade.")
	assert(String(service.state(ABANDONED_HOUSE.QUEST_ID).get("status", "")) == "failed")


func _test_unconfigured_service_fails_safely() -> void:
	var service := QUEST_SERVICE.new()
	assert(not bool(service.register_definitions().get("ok", false)))
	assert(not bool(service.start("unknown_quest").get("ok", false)))
	assert(service.state("unknown_quest").is_empty())
