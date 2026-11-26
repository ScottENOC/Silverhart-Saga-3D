class_name TollTakerQuestEncounter
extends RefCounted
## Runtime combat and persistent world actor state for Petra Hollis's ogre.
## The source places the ogre twelve q and eight r beyond the abandoned house.

const QUEST_CONTENT = preload("res://scripts/simulation/toll_taker_quest_content.gd")
const ABANDONED_HOUSE = preload("res://scripts/simulation/abandoned_house_clearing_quest.gd")
const COMBAT_ENCOUNTER_SERVICE = preload("res://scripts/simulation/combat_encounter_service.gd")

const OGRE_ID := "toll_taker_ogre"
const OGRE_HEX: Vector2i = ABANDONED_HOUSE.HOUSE_CENTRE + Vector2i(12, 8)
const OGRE_HEALTH := 140


static func is_alive(simulation: WorldSimulation) -> bool:
	if simulation == null:
		return false
	var ogre := simulation.get_character(OGRE_ID)
	return ogre != null and ogre.alive


static func ensure_ogre(simulation: WorldSimulation, spawn_hex: Vector2i = OGRE_HEX) -> Dictionary:
	if simulation == null:
		return {"ok": false, "reason": "missing_simulation"}
	var existing := simulation.get_character(OGRE_ID)
	if existing != null:
		return {"ok": true, "created": false, "character": existing}
	var ogre := CharacterState.new(OGRE_ID, "Toll-Taker Ogre", spawn_hex)
	ogre.race = "ogre"
	ogre.character_class = "brute"
	ogre.level = 3
	ogre.health = OGRE_HEALTH
	ogre.max_health = OGRE_HEALTH
	ogre.base_damage = 9
	ogre.to_hit_melee = 6.0
	ogre.passive_dodge = -1.0
	ogre.skills = {"club_hit": 2, "club_dmg": 2, "health": 3}
	ogre.side = "enemy"
	ogre.combat_dormant = true
	ogre.time_points = ogre.max_time_points
	ogre.tags.append("monster")
	ogre.tags.append("ogre")
	ogre.tags.append("toll_taker_ogre")
	simulation.register_character(ogre)
	return {"ok": true, "created": true, "character": ogre}


static func dynamic_character_records(simulation: WorldSimulation) -> Dictionary:
	var records: Dictionary = {}
	if simulation == null:
		return records
	var ogre := simulation.get_character(OGRE_ID)
	if ogre != null:
		records[OGRE_ID] = ogre.to_dict()
	return records


static func start_encounter(simulation: WorldSimulation, party_ids: Array[String]) -> Dictionary:
	if simulation == null:
		return {"ok": false, "reason": "missing_simulation"}
	if simulation.is_in_combat:
		return {"ok": false, "reason": "combat_already_active"}
	var ogre := simulation.get_character(OGRE_ID)
	if ogre == null or not ogre.can_act():
		return {"ok": false, "reason": "ogre_unavailable"}
	var valid_party: Array[String] = []
	for character_id in party_ids:
		var member := simulation.get_character(character_id)
		if member != null and member.can_act() and not valid_party.has(character_id):
			valid_party.append(character_id)
	if valid_party.is_empty():
		return {"ok": false, "reason": "no_able_party_members"}
	var started: Dictionary = COMBAT_ENCOUNTER_SERVICE.begin(simulation, valid_party, [OGRE_ID])
	if not bool(started.get("ok", false)):
		return started
	return {
		"ok": true,
		"party_ids": valid_party,
		"enemy_ids": [OGRE_ID],
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
	var ogre := simulation.get_character(OGRE_ID)
	var ogre_defeated := ogre == null or not ogre.alive
	if not party_defeated and not ogre_defeated:
		return {"ok": true, "resolved": false}
	COMBAT_ENCOUNTER_SERVICE.finish(simulation, session)
	if party_defeated:
		return {
			"ok": true,
			"resolved": true,
			"outcome": "defeat",
			"speaker": "North Road",
			"message": "The ogre drives you back from the road. It remains at its camp, and Petra will still need your help.",
			"choice_label": "Retreat."
		}
	var progress := QUEST_CONTENT.record_ogre_defeat(journal, false)
	return {
		"ok": bool(progress.get("ok", false)),
		"resolved": true,
		"outcome": "victory",
		"speaker": "North Road",
		"message": "The toll-taking ogre falls. The north road is quiet again. Petra Hollis should hear the news.",
		"choice_label": "Return to Petra.",
		"status_text": "Toll-Taker defeated. Return to Petra Hollis.",
		"remove_actor_ids": [OGRE_ID]
	}
