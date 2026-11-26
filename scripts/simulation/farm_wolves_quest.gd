class_name FarmWolvesQuest
extends RefCounted
## Source-faithful 3D adaptation of Campaign 2's Old Mac farm quest.
## Combatants are registered by HollowTankard so the encounter uses the
## existing WorldSimulation and initiative system.

const QUEST_ID := "farm_wolves"
const OBJECTIVE_ID := "wolves_defeated"
const REWARD_GOLD := 25
const REWARD_EXPERIENCE := 150
const REWARD_REPUTATION := 15
const WOLF_IDS: Array[String] = ["farm_wolf_01", "farm_wolf_02", "farm_wolf_03"]
const PARTY_IDS: Array[String] = ["player", "companion_wren_talbot"]
const COMBAT_ENCOUNTER_SERVICE = preload("res://scripts/simulation/combat_encounter_service.gd")

static func definition() -> Dictionary:
	return {
		"id": QUEST_ID,
		"title": "Wolves at the Farm",
		"description": "Drive the wolves away from Old Mac's pasture and protect his remaining cattle.",
		"objectives": [
			{"id": OBJECTIVE_ID, "description": "Defeat the three wolves at their den.", "target": 3.0, "required": true}
		]
	}

static func greeting(journal: CampaignJournal, wolves_remaining: int) -> Dictionary:
	var state := journal.quest_state(QUEST_ID)
	var status := String(state.get("status", ""))
	if status.is_empty():
		return {
			"speaker": "Old Mac",
			"text": "Wolves have been worrying my cattle the past few nights. They've already killed two of the herd. I found a broken rail and blood leading off towards the treeline. I'm too old to hunt a pack on my own.",
			"choices": [
				{"id": "farm_wolves_accept", "label": "I'll deal with the wolves.", "text": ""},
				{"id": "farm_wolves_decline", "label": "Not my problem.", "text": "Old Mac gives a tired nod. He turns back towards the pasture."}
			]
		}
	if status == "active":
		var objectives: Dictionary = state.get("objectives", {})
		var objective: Dictionary = objectives.get(OBJECTIVE_ID, {})
		if bool(objective.get("completed", false)):
			return {
				"speaker": "Old Mac",
				"text": "You got them! By God, every last one. That's a weight off, truly. The cows can graze without being hunted now.",
				"choices": [{"id": "farm_wolves_turn_in", "label": "Glad to help.", "text": ""}]
			}
		if wolves_remaining > 0:
			return {
				"speaker": "Old Mac",
				"text": "Still hear them out there. Best finish the job before they come back for the cattle.",
				"choices": [{"id": "farm_wolves_continue", "label": "I'll see it through.", "text": ""}]
			}
		return {
			"speaker": "Old Mac",
			"text": "They usually keep to their den beyond the broken fence. Follow the blood trail into the trees.",
			"choices": [{"id": "farm_wolves_continue", "label": "I'll take a look.", "text": ""}]
		}
	return {
		"speaker": "Old Mac",
		"text": "Pasture's quiet now, thanks to you. The cows are safe.",
		"choices": [{"id": "continue", "label": "Good.", "text": ""}]
	}

static func accept(journal: CampaignJournal) -> Dictionary:
	if journal == null:
		return {"ok": false, "reason": "missing_journal"}
	var result := journal.start_quest(QUEST_ID)
	if not bool(result.get("ok", false)):
		return result
	journal.record_decision(QUEST_ID, "accepted", "yes")
	return result

static func record_wolf_defeat(journal: CampaignJournal, defeated_count: int) -> Dictionary:
	if journal == null:
		return {"ok": false, "reason": "missing_journal"}
	return journal.set_objective_progress(QUEST_ID, OBJECTIVE_ID, float(defeated_count))

static func turn_in(journal: CampaignJournal, player: CharacterState) -> Dictionary:
	if journal == null or player == null:
		return {"ok": false, "reason": "missing_journal_or_player"}
	var state := journal.quest_state(QUEST_ID)
	if String(state.get("status", "")) != "active":
		return {"ok": false, "reason": "quest_not_active"}
	var objectives: Dictionary = state.get("objectives", {})
	var objective: Dictionary = objectives.get(OBJECTIVE_ID, {})
	if not bool(objective.get("completed", false)):
		return {"ok": false, "reason": "wolves_not_defeated"}
	var result := journal.complete_quest(QUEST_ID)
	if not bool(result.get("ok", false)):
		return result
	player.gold += REWARD_GOLD
	player.experience += REWARD_EXPERIENCE
	journal.adjust_npc_reputation("old_mac", REWARD_REPUTATION, 20.0, "Protected Old Mac's cattle")
	return {"ok": true, "gold": REWARD_GOLD, "experience": REWARD_EXPERIENCE, "reputation": REWARD_REPUTATION}


static func resolve_dialogue_choice(
	journal: CampaignJournal,
	player: CharacterState,
	choice_id: String,
	choice_text: String = ""
) -> Dictionary:
	## Resolves Old Mac's dialogue choices here, keeping quest-specific dialogue
	## and rewards out of the location/presentation script.
	var response: Dictionary = {}
	var completed := false
	var reward_data: Dictionary = {}
	match choice_id:
		"farm_wolves_accept":
			var result := accept(journal)
			if bool(result.get("ok", false)):
				response = _response("Bless you. The fence is broken on the western side of the pasture. I found blood leading into the trees. Their den must be out there somewhere.", "I'll follow the trail.")
			else:
				response = _response("I cannot ask you to take that on just now.", "All right.")
		"farm_wolves_turn_in":
			var reward := turn_in(journal, player)
			if bool(reward.get("ok", false)):
				reward_data = reward
				response = _response("I won't forget what you've done. Take this, and know the farm owes you a favour.", "Thank you.")
				completed = true
			else:
				response = _response("The cattle are not safe yet.", "I'll return.")
		"farm_wolves_continue", "farm_wolves_decline":
			response = _response(choice_text if not choice_text.is_empty() else "Take care on the road.", "Continue")
		_:
			return {"handled": false}
	return {"handled": true, "dialogue": response, "quest_completed": completed, "reward": reward_data}


static func _response(body: String, choice_label: String) -> Dictionary:
	return {
		"speaker": "Old Mac",
		"text": body,
		"choices": [{"id": "continue", "label": choice_label, "text": ""}]
	}

static func start_encounter(
	simulation: WorldSimulation,
	party_ids: Array[String],
	enemy_ids: Array[String] = WOLF_IDS
) -> Dictionary:
	if simulation == null:
		return {"ok": false, "reason": "missing_simulation"}
	var valid_party: Array[String] = []
	for character_id in party_ids:
		var member := simulation.get_character(character_id)
		if member != null and member.can_act() and not valid_party.has(character_id):
			valid_party.append(character_id)
	var active_enemies: Array[String] = []
	for character_id in enemy_ids:
		var enemy := simulation.get_character(character_id)
		if enemy != null and enemy.can_act() and not active_enemies.has(character_id):
			active_enemies.append(character_id)
	var started: Dictionary = COMBAT_ENCOUNTER_SERVICE.begin(simulation, valid_party, active_enemies)
	if not bool(started.get("ok", false)):
		return started
	var session: Dictionary = started.get("session", {})
	return {
		"ok": true,
		"party_ids": valid_party,
		"enemy_ids": active_enemies,
		"session": session
	}


static func resolve_combat(
	simulation: WorldSimulation,
	journal: CampaignJournal,
	party_ids: Array[String],
	session: Dictionary
) -> Dictionary:
	if simulation == null:
		return {"ok": false, "resolved": false, "reason": "missing_simulation"}
	var party_defeated := true
	for character_id in party_ids:
		var member := simulation.get_character(character_id)
		if member != null and member.can_act():
			party_defeated = false
			break
	var enemies_defeated := true
	for character_id in WOLF_IDS:
		var enemy := simulation.get_character(character_id)
		if enemy != null and enemy.can_act():
			enemies_defeated = false
			break
	if not party_defeated and not enemies_defeated:
		return {"ok": true, "resolved": false}
	COMBAT_ENCOUNTER_SERVICE.finish(simulation, session)
	if party_defeated:
		return {
			"ok": true,
			"resolved": true,
			"outcome": "defeat",
			"speaker": "Wilderness",
			"message": "The wolves drive you back. They remain at their den, and Old Mac's cattle are still in danger. You can return when ready.",
			"choice_label": "Retreat."
		}
	var progress := record_wolf_defeat(journal, WOLF_IDS.size())
	return {
		"ok": bool(progress.get("ok", false)),
		"resolved": true,
		"outcome": "victory",
		"speaker": "Wilderness",
		"message": "The last wolf falls. The den is quiet. Old Mac will want to know the cattle are safe.",
		"choice_label": "Return to the farm.",
		"status_text": "The wolf pack is defeated. Return to Old Mac."
	}
