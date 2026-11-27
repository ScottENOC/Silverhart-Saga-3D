class_name CampaignCoordinator
extends Node
## Campaign composition root. Owns campaign-wide setup and service wiring;
## location scenes must not register quest content or seed campaign rules.

const QUEST_SERVICE_SCRIPT = preload("res://scripts/quests/campaign_quest_service.gd")
const HOLLOWMERE_CONTENT = preload("res://scripts/simulation/hollowmere_campaign_content.gd")

var simulation: WorldSimulation
var quest_service: CampaignQuestService


func initialize(world_simulation: WorldSimulation, player_profile: Dictionary = {}) -> Dictionary:
	if world_simulation == null or world_simulation.campaign_journal == null:
		return {"ok": false, "reason": "missing_campaign_simulation"}

	simulation = world_simulation
	simulation.clock.set_world_seconds(11.0 * 3600.0)

	quest_service = QUEST_SERVICE_SCRIPT.new()
	var configured: Dictionary = quest_service.configure(simulation)
	if not bool(configured.get("ok", false)):
		return configured

	var registration: Dictionary = quest_service.register_definitions()
	if not bool(registration.get("ok", false)):
		return registration

	HOLLOWMERE_CONTENT.initialize_social_standings(
		simulation.campaign_journal,
		String(player_profile.get("race", "human"))
	)
	return {"ok": true, "quest_registration": registration}


func quest_state(quest_id: String) -> Dictionary:
	if quest_service == null:
		return {}
	return quest_service.state(quest_id)


func start_quest(quest_id: String) -> Dictionary:
	if quest_service == null:
		return {"ok": false, "reason": "coordinator_not_initialized"}
	return quest_service.start(quest_id)
