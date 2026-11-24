class_name AbandonedHouseClearingQuest
extends RefCounted
## World encounter and journal resolution for the three guardians in the
## source-authored abandoned roadside house. The source uses the
## necromancerMinion tag for these enemies; cryptMinion enemies are unrelated.

const QUEST_ID := "abandoned_house_cleared"
const OBJECTIVE_ID := "house_guardians_defeated"
const HOUSE_CENTRE := Vector2i(14, -176)
const GUARDIAN_IDS: Array[String] = [
	"abandoned_house_guardian_01",
	"abandoned_house_guardian_02",
	"abandoned_house_guardian_03"
]
## The first guardian is shifted one row north by the flat-room shear correction
## (-floor(dq / 2)), matching the legacy hexRowShiftFlat(dq) placement.
const GUARDIAN_HEXES: Array[Vector2i] = [
	Vector2i(13, -176),
	Vector2i(15, -177),
	Vector2i(14, -175)
]
const GUARDIAN_HEALTH := 40
const REPUTATION_PENALTY := -5
const REPUTATION_KNOWLEDGE_GAIN := 5
const REPUTATION_APPLIED_TAG := "abandoned_house_reputation_applied"
const PARTY_TURN_POINTS := 100.0


static func definition() -> Dictionary:
	return {
		"id": QUEST_ID,
		"title": "The Abandoned House",
		"description": "Three undead guardians remain in the abandoned roadside house.",
		"objectives": [
			{
				"id": OBJECTIVE_ID,
				"description": "Defeat the three guardians inside the abandoned house.",
				"target": 3.0,
				"required": true
			}
		]
	}


static func register_definition(journal: CampaignJournal) -> Dictionary:
	if journal == null:
		return {"ok": false, "reason": "missing_journal"}
	return journal.register_quest_definition(definition())


static func dynamic_character_records(simulation: WorldSimulation) -> Dictionary:
	var records: Dictionary = {}
	if simulation == null:
		return records
	for guardian_id in GUARDIAN_IDS:
		var guardian := simulation.get_character(guardian_id)
		if guardian != null:
			records[guardian_id] = guardian.to_dict()
	return records


static func ensure_started(journal: CampaignJournal) -> Dictionary:
	if journal == null:
		return {"ok": false, "reason": "missing_journal"}
	register_definition(journal)
	var current := journal.quest_state(QUEST_ID)
	if String(current.get("status", "")) == "completed":
		return {"ok": true, "already_completed": true}
	if String(current.get("status", "")) == "active":
		return {"ok": true, "already_active": true}
	return journal.start_quest(QUEST_ID)


static func ensure_guardians(simulation: WorldSimulation) -> Dictionary:
	if simulation == null:
		return {"ok": false, "reason": "missing_simulation"}
	var created: Array[String] = []
	for index in range(GUARDIAN_IDS.size()):
		var guardian_id := GUARDIAN_IDS[index]
		if simulation.get_character(guardian_id) != null:
			continue
		var guardian := CharacterState.new(guardian_id, "Skeletal guardian", GUARDIAN_HEXES[index])
		guardian.race = "undead"
		guardian.character_class = "warrior"
		guardian.health = GUARDIAN_HEALTH
		guardian.max_health = GUARDIAN_HEALTH
		guardian.base_damage = 5
		guardian.to_hit_melee = 5.0
		guardian.skills = {"sword_hit": 1, "sword_dmg": 1, "health": 1}
		guardian.tags.append("undead")
		guardian.tags.append("skeleton")
		guardian.tags.append("necromancerMinion")
		guardian.side = "enemy"
		guardian.combat_dormant = true
		guardian.time_points = guardian.max_time_points
		simulation.register_character(guardian)
		created.append(guardian_id)
	return {"ok": true, "created_ids": created, "guardian_ids": GUARDIAN_IDS.duplicate()}


static func guardian_count_remaining(simulation: WorldSimulation) -> int:
	if simulation == null:
		return GUARDIAN_IDS.size()
	var remaining := 0
	for guardian_id in GUARDIAN_IDS:
		var guardian := simulation.get_character(guardian_id)
		if guardian != null and guardian.can_act():
			remaining += 1
	return remaining


static func start_encounter(simulation: WorldSimulation, party_ids: Array[String]) -> Dictionary:
	if simulation == null:
		return {"ok": false, "reason": "missing_simulation"}
	if simulation.is_in_combat:
		return {"ok": false, "reason": "combat_already_active"}
	var guardian_result := ensure_guardians(simulation)
	if not bool(guardian_result.get("ok", false)):
		return guardian_result
	if guardian_count_remaining(simulation) == 0:
		return {"ok": false, "reason": "guardians_already_defeated"}
	var valid_party: Array[String] = []
	for character_id in party_ids:
		var member := simulation.get_character(character_id)
		if member != null and member.can_act() and not valid_party.has(character_id):
			valid_party.append(character_id)
	if valid_party.is_empty():
		return {"ok": false, "reason": "no_able_party_members"}
	var previous_states: Dictionary = {}
	for value in simulation.character_states():
		var state: CharacterState = value
		previous_states[state.id] = {
			"side": state.side,
			"combat_dormant": state.combat_dormant
		}
		state.combat_dormant = true
	for character_id in valid_party:
		var member := simulation.get_character(character_id)
		member.side = "player"
		member.combat_dormant = false
		member.time_points = PARTY_TURN_POINTS
	var active_enemy_ids: Array[String] = []
	for guardian_id in GUARDIAN_IDS:
		var guardian := simulation.get_character(guardian_id)
		if guardian == null or not guardian.can_act():
			continue
		guardian.side = "enemy"
		guardian.combat_dormant = false
		guardian.time_points = guardian.max_time_points
		active_enemy_ids.append(guardian_id)
	simulation.start_combat()
	return {
		"ok": true,
		"party_ids": valid_party,
		"enemy_ids": active_enemy_ids,
		"previous_states": previous_states
	}


static func party_defeated(simulation: WorldSimulation, party_ids: Array[String]) -> bool:
	if simulation == null:
		return true
	for character_id in party_ids:
		var member := simulation.get_character(character_id)
		if member != null and member.can_act():
			return false
	return true


static func enemies_defeated(simulation: WorldSimulation) -> bool:
	return guardian_count_remaining(simulation) == 0


static func all_necromancer_minions_defeated(simulation: WorldSimulation) -> bool:
	if simulation == null:
		return false
	for value in simulation.character_states():
		var state: CharacterState = value
		if state.tags.has("necromancerMinion") and state.can_act():
			return false
	return true


static func apply_defeat_consequences(journal: CampaignJournal, simulation: WorldSimulation) -> int:
	if journal == null or simulation == null:
		return 0
	var applied_count := 0
	for guardian_id in GUARDIAN_IDS:
		var guardian := simulation.get_character(guardian_id)
		if guardian == null or guardian.can_act() or guardian.tags.has(REPUTATION_APPLIED_TAG):
			continue
		journal.adjust_faction_reputation(
				"necromancer_cult",
				float(REPUTATION_PENALTY),
				float(REPUTATION_KNOWLEDGE_GAIN),
				"Defeated a necromancer's undead guardian"
			)
		guardian.tags.append(REPUTATION_APPLIED_TAG)
		applied_count += 1
	return applied_count


static func finish_encounter(simulation: WorldSimulation, previous_states: Dictionary) -> void:
	if simulation == null:
		return
	for character_id_value in previous_states.keys():
		var character_id := String(character_id_value)
		var state := simulation.get_character(character_id)
		if state == null:
			continue
		var previous: Dictionary = previous_states[character_id_value]
		state.side = String(previous.get("side", state.side))
		state.combat_dormant = bool(previous.get("combat_dormant", state.combat_dormant))
	for guardian_id in GUARDIAN_IDS:
		var guardian := simulation.get_character(guardian_id)
		if guardian != null:
			guardian.side = "enemy"
			guardian.combat_dormant = true


static func resolve_clearing(journal: CampaignJournal, simulation: WorldSimulation) -> Dictionary:
	if journal == null or simulation == null:
		return {"ok": false, "reason": "missing_journal_or_simulation"}
	var quest := journal.quest_state(QUEST_ID)
	if String(quest.get("status", "")) != "active":
		return {"ok": false, "reason": "quest_not_active"}
	var defeated_count := GUARDIAN_IDS.size() - guardian_count_remaining(simulation)
	var progress := journal.set_objective_progress(QUEST_ID, OBJECTIVE_ID, float(defeated_count))
	if not bool(progress.get("ok", false)):
		return progress
	if defeated_count >= GUARDIAN_IDS.size():
		if not all_necromancer_minions_defeated(simulation):
			return {"ok": true, "completed": false, "defeated": defeated_count, "reason": "other_necromancer_minions_remain"}
		var completed := journal.complete_quest(QUEST_ID)
		if not bool(completed.get("ok", false)):
			return completed
		return {"ok": true, "completed": true, "defeated": defeated_count}
	return {"ok": true, "completed": false, "defeated": defeated_count, "remaining": guardian_count_remaining(simulation)}
