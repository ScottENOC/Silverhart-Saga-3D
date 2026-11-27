extends SceneTree

const QUEST_SERVICE = preload("res://scripts/quests/campaign_quest_service.gd")
const QUEST_REGISTRY = preload("res://scripts/quests/campaign_quest_registry.gd")
const ABANDONED_HOUSE = preload("res://scripts/simulation/abandoned_house_clearing_quest.gd")
const TOLL_TAKER = preload("res://scripts/simulation/toll_taker_quest_content.gd")


func _initialize() -> void:
	_test_registry_registration()
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
	assert(result.get("registered_quest_ids", []).size() == 7, "The central registry should register every campaign quest module.")
	assert(result.get("failed_quests", []).is_empty())
	var repeated := QUEST_REGISTRY.register_definitions(simulation)
	assert(bool(repeated.get("ok", false)), "Registry should tolerate repeated registration.")


func _test_service_journal_facade() -> void:
	var simulation := WorldSimulation.new()
	var service := QUEST_SERVICE.new()
	assert(service.configure(simulation).ok)
	var registration := service.register_definitions()
	assert(bool(registration.get("ok", false)))
	assert(registration.get("registered_quest_ids", []).size() == 7, "The service facade should expose the complete registry result.")
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


func _test_unconfigured_service_fails_safely() -> void:
	var service := QUEST_SERVICE.new()
	assert(not bool(service.register_definitions().get("ok", false)))
	assert(not bool(service.start("unknown_quest").get("ok", false)))
	assert(service.state("unknown_quest").is_empty())
