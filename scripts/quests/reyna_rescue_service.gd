class_name ReynaRescueService
extends RefCounted
## Owns the campaign-state rules for Tessa's rescue; movement and actor presentation stay in the world adapter.

const QUEST_ID := "reyna_dire_wolf_hunt"
const CHILD_ID := "missing_child_tessa"

static func prepare_rescue(simulation: WorldSimulation) -> Dictionary:
	if simulation == null or simulation.campaign_journal == null:
		return {"ok": false, "reason": "missing_campaign"}
	var quest := simulation.campaign_journal.quest_state(QUEST_ID)
	if String(quest.get("status", "")) != "active":
		return {"ok": false, "reason": "rescue_quest_not_active"}
	var objectives: Dictionary = quest.get("objectives", {})
	if not bool(objectives.get("trail_found", {}).get("completed", false)):
		return {"ok": false, "reason": "child_trail_not_found"}
	if simulation.get_character(CHILD_ID) == null:
		return {"ok": false, "reason": "missing_child"}
	return {"ok": true, "character_id": CHILD_ID}


static func complete_rescue(simulation: WorldSimulation, destination_hex: Vector2i) -> Dictionary:
	if simulation == null or simulation.campaign_journal == null:
		return {"ok": false, "reason": "missing_campaign"}
	var quest := simulation.campaign_journal.quest_state(QUEST_ID)
	if String(quest.get("status", "")) != "active":
		return {"ok": false, "reason": "rescue_quest_not_active"}
	var objectives: Dictionary = quest.get("objectives", {})
	if not bool(objectives.get("trail_found", {}).get("completed", false)):
		return {"ok": false, "reason": "child_trail_not_found"}
	var child := simulation.get_character(CHILD_ID)
	if child == null:
		return {"ok": false, "reason": "missing_child"}
	if child.axial != destination_hex:
		return {"ok": false, "reason": "child_not_at_safe_destination"}
	var result := simulation.campaign_journal.set_objective_progress(QUEST_ID, "child_rescued", 1.0)
	if not bool(result.get("ok", false)):
		return result
	return {"ok": true, "character_id": CHILD_ID, "objective_completed": "child_rescued"}
