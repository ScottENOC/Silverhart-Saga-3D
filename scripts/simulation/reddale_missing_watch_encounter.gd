class_name ReddaleMissingWatchEncounter
extends RefCounted
## Persistent two-goblin encounter from campaign2Dialogue.js.
## The source places it 18 q east of Reddale's road endpoint, then spawns
## the second goblin at (+1 q, -1 r).

const QUEST_CONTENT = preload("res://scripts/simulation/reddale_missing_watch_quest.gd")
const COMBAT_ENCOUNTER_SERVICE = preload("res://scripts/simulation/combat_encounter_service.gd")

const GOBLIN_IDS: Array[String] = ["reddale_missing_watch_goblin_01", "reddale_missing_watch_goblin_02"]
const REDDALE_ROAD_END_HEX := Vector2i(138, 24)
const SEARCH_SITE_HEX := REDDALE_ROAD_END_HEX + Vector2i(18, 0)
const GOBLIN_OFFSETS: Array[Vector2i] = [Vector2i.ZERO, Vector2i(1, -1)]
const GOBLIN_HEALTH := 10


static func ensure_goblins(simulation: WorldSimulation, spawn_hex: Vector2i = SEARCH_SITE_HEX) -> Dictionary:
	if simulation == null:
		return {"ok": false, "reason": "missing_simulation"}
	var created_ids: Array[String] = []
	for index in range(GOBLIN_IDS.size()):
		var goblin_id := GOBLIN_IDS[index]
		if simulation.get_character(goblin_id) != null:
			continue
		var goblin := CharacterState.new(goblin_id, "Goblin", spawn_hex + GOBLIN_OFFSETS[index])
		goblin.race = "goblin"
		goblin.character_class = "rogue"
		goblin.level = 1
		# The source goblin has 10 HP and one Health rank. Seed zero HP so
		# register_character's Health-rank application yields the source 10.
		goblin.health = 0
		goblin.max_health = 0
		goblin.base_damage = 2
		goblin.to_hit_melee = 1.0
		goblin.skills = {"health": 1, "meleeDamage": 1, "stealth_rogue": 1}
		goblin.side = "enemy"
		goblin.combat_dormant = true
		goblin.tags.append("monster")
		goblin.tags.append("humanoid")
		goblin.tags.append("goblin")
		goblin.tags.append("reddale_missing_watch_goblin")
		simulation.register_character(goblin)
		if simulation.get_character(goblin_id) != null:
			created_ids.append(goblin_id)
	return {
		"ok": simulation.get_character(GOBLIN_IDS[0]) != null and simulation.get_character(GOBLIN_IDS[1]) != null,
		"created_ids": created_ids,
		"goblins_remaining": goblins_remaining(simulation)
	}


static func goblins_remaining(simulation: WorldSimulation) -> int:
	if simulation == null:
		return 0
	var remaining := 0
	for goblin_id in GOBLIN_IDS:
		var goblin := simulation.get_character(goblin_id)
		if goblin != null and goblin.alive and not goblin.unconscious:
			remaining += 1
	return remaining


static func dynamic_character_records(simulation: WorldSimulation) -> Dictionary:
	var records: Dictionary = {}
	if simulation == null:
		return records
	for goblin_id in GOBLIN_IDS:
		var goblin := simulation.get_character(goblin_id)
		if goblin != null:
			records[goblin_id] = goblin.to_dict()
	return records


static func start_encounter(simulation: WorldSimulation, party_ids: Array[String]) -> Dictionary:
	if simulation == null:
		return {"ok": false, "reason": "missing_simulation"}
	if simulation.is_in_combat:
		return {"ok": false, "reason": "combat_already_active"}
	var valid_party: Array[String] = []
	for character_id in party_ids:
		var member := simulation.get_character(character_id)
		if member != null and member.can_act() and not valid_party.has(character_id):
			valid_party.append(character_id)
	if valid_party.is_empty():
		return {"ok": false, "reason": "no_able_party_members"}
	var active_enemies: Array[String] = []
	for goblin_id in GOBLIN_IDS:
		var goblin := simulation.get_character(goblin_id)
		if goblin != null and goblin.can_act() and not active_enemies.has(goblin_id):
			active_enemies.append(goblin_id)
	if active_enemies.is_empty():
		return {"ok": false, "reason": "goblins_unavailable"}
	var started: Dictionary = COMBAT_ENCOUNTER_SERVICE.begin(simulation, valid_party, active_enemies)
	if not bool(started.get("ok", false)):
		return started
	return {
		"ok": true,
		"party_ids": valid_party,
		"enemy_ids": active_enemies,
		"session": started.get("session", {})
	}


static func resolve_combat(
	simulation: WorldSimulation,
	journal: CampaignJournal,
	party_ids: Array[String],
	session: Dictionary
) -> Dictionary:
	if simulation == null or journal == null:
		return {"ok": false, "resolved": false, "reason": "missing_simulation_or_journal"}
	var party_defeated := true
	for character_id in party_ids:
		var member := simulation.get_character(character_id)
		if member != null and member.can_act():
			party_defeated = false
			break
	var enemies_defeated := goblins_remaining(simulation) == 0
	if not party_defeated and not enemies_defeated:
		return {"ok": true, "resolved": false}
	COMBAT_ENCOUNTER_SERVICE.finish(simulation, session)
	if party_defeated:
		return {
			"ok": true,
			"resolved": true,
			"outcome": "defeat",
			"speaker": "East Road",
			"message": "The goblins drive you back. They remain along the east road, and Captain Rennick still needs your help.",
			"choice_label": "Retreat."
	}
	for goblin_id in GOBLIN_IDS:
		var goblin := simulation.get_character(goblin_id)
		if goblin != null and goblin.alive and goblin.unconscious:
			goblin.apply_damage(goblin.max_health)
	var progress := QUEST_CONTENT.record_goblin_defeats(journal, GOBLIN_IDS.size())
	return {
		"ok": bool(progress.get("ok", false)),
		"resolved": true,
		"outcome": "victory",
		"speaker": "East Road",
		"message": "The two goblins lie still. The east road is quiet for now. Captain Rennick should hear what happened to her patrol.",
		"choice_label": "Return to Captain Rennick.",
		"status_text": "The Missing Watch goblins are defeated. Return to Captain Rennick.",
		"remove_actor_ids": GOBLIN_IDS.duplicate()
	}
