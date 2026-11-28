class_name ReynaRescueService
extends RefCounted
## Owns the campaign-state rules for Tessa's rescue; movement and actor presentation stay in the world adapter.

const QUEST_ID := "reyna_dire_wolf_hunt"
const CHILD_ID := "missing_child_tessa"
const DIRE_WOLF_ID := "old_mac_grain_dire_wolf"

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


## Quest progression and proximity decisions remain here; the caller supplies
## world-distance facts and performs the returned presentation/spawn action.
static func objective_complete(simulation: WorldSimulation, objective_id: String) -> bool:
	if simulation == null or simulation.campaign_journal == null:
		return false
	var quest := simulation.campaign_journal.quest_state(QUEST_ID)
	var objectives: Dictionary = quest.get("objectives", {})
	if not objectives.has(objective_id):
		return false
	var objective: Dictionary = objectives[objective_id]
	return bool(objective.get("completed", false)) or float(objective.get("progress", 0.0)) >= float(objective.get("target", 1.0))


static func proximity_action(
	simulation: WorldSimulation,
	near_clue: bool,
	near_shelter: bool,
	child_actor_present: bool
) -> Dictionary:
	if simulation == null or simulation.campaign_journal == null:
		return {"action": "none", "reason": "missing_campaign"}
	var quest := simulation.campaign_journal.quest_state(QUEST_ID)
	if String(quest.get("status", "")) != "active":
		return {"action": "none", "reason": "quest_not_active"}
	if not objective_complete(simulation, "trail_found"):
		return {"action": "record_trail_found"} if near_clue else {"action": "show_trail_clue"}
	if not objective_complete(simulation, "child_rescued") and not child_actor_present and near_shelter:
		return {"action": "spawn_missing_child"}
	return {"action": "none"}


static func record_trail_found(simulation: WorldSimulation) -> Dictionary:
	if simulation == null or simulation.campaign_journal == null:
		return {"ok": false, "reason": "missing_campaign"}
	var quest := simulation.campaign_journal.quest_state(QUEST_ID)
	if String(quest.get("status", "")) != "active":
		return {"ok": false, "reason": "rescue_quest_not_active"}
	return simulation.campaign_journal.set_objective_progress(QUEST_ID, "trail_found", 1.0)


## Resolve the direct interaction prompts for Tessa and the dire wolf.
## Combat startup and character movement remain world-adapter responsibilities.
static func interaction_for_character(simulation: WorldSimulation, character_id: String) -> Dictionary:
	if simulation == null:
		return {"action": "none", "reason": "missing_simulation"}
	if character_id == DIRE_WOLF_ID:
		if not objective_complete(simulation, "child_rescued"):
			return {
				"action": "block_hunt",
				"speaker": "Dire wolf",
				"text": "The dire wolf circles the shepherd's shelter. You cannot safely engage it while Tessa is still inside.",
				"choices": [{"id": "continue", "label": "Understood", "text": ""}]
			}
		return {"action": "start_hunt"}
	if character_id == CHILD_ID:
		if objective_complete(simulation, "child_rescued"):
			return {
				"action": "speak",
				"speaker": "Tessa",
				"text": "Reyna said you were the one who got me out. I don't think I'll ever forget that.",
				"choices": [{"id": "continue", "label": "You're safe now", "text": ""}],
				"expression": "smile"
			}
		return {
			"action": "speak",
			"speaker": "Tessa",
			"text": "Please... it's outside. I can hear it moving around. Reyna said to stay quiet.",
			"choices": [{"id": "reyna_rescue_child", "label": "Come with me. We'll get you home.", "text": ""}],
			"expression": "afraid"
		}
	return {"action": "none"}
