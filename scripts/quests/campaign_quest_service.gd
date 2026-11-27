class_name CampaignQuestService
extends RefCounted
## Campaign-facing facade for quest journal operations.
##
## Scene scripts should coordinate presentation and world effects; quest
## content modules own authored dialogue/rewards, and this service owns the
## common campaign-level entry points.

const QUEST_REGISTRY = preload("res://scripts/quests/campaign_quest_registry.gd")

var _simulation: WorldSimulation


func configure(simulation: WorldSimulation) -> Dictionary:
	if simulation == null or simulation.campaign_journal == null:
		_simulation = null
		return {"ok": false, "reason": "missing_campaign_journal"}
	_simulation = simulation
	return {"ok": true}


func register_definitions() -> Dictionary:
	if _simulation == null:
		return {"ok": false, "reason": "service_not_configured"}
	return QUEST_REGISTRY.register_definitions(_simulation)


func state(quest_id: String) -> Dictionary:
	if _simulation == null:
		return {}
	return _simulation.campaign_journal.quest_state(quest_id)


func start(quest_id: String) -> Dictionary:
	if _simulation == null:
		return {"ok": false, "reason": "service_not_configured"}
	return _simulation.campaign_journal.start_quest(quest_id)


func set_objective_progress(quest_id: String, objective_id: String, progress: float) -> Dictionary:
	if _simulation == null:
		return {"ok": false, "reason": "service_not_configured"}
	return _simulation.campaign_journal.set_objective_progress(quest_id, objective_id, progress)


func complete(quest_id: String) -> Dictionary:
	if _simulation == null:
		return {"ok": false, "reason": "service_not_configured"}
	return _simulation.campaign_journal.complete_quest(quest_id)


func fail(quest_id: String, reason: String) -> Dictionary:
	if _simulation == null:
		return {"ok": false, "reason": "service_not_configured"}
	return _simulation.campaign_journal.fail_quest(quest_id, reason)
