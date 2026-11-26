class_name HollowmereEncounter
extends RefCounted
## First authored Hollowmere combat encounter. Combat resolution stays in WorldSimulation.

const PLAYER_CONTROLLED_IDS: Array[String] = ["player", "companion_wren_talbot"]
const ALLY_IDS: Array[String] = ["garrick_holt", "mira_ashbrook", "oskar_vinn"]
const COMBAT_ALLY_IDS: Array[String] = ["player", "companion_wren_talbot", "garrick_holt", "mira_ashbrook", "oskar_vinn"]
const ENEMY_IDS: Array[String] = ["dray_coltayne", "tomlin_brask", "hask_greel"]
const COMBAT_ENCOUNTER_SERVICE = preload("res://scripts/simulation/combat_encounter_service.gd")
const HOLLOWMERE_CAMPAIGN_CONTENT = preload("res://scripts/simulation/hollowmere_campaign_content.gd")

const ALLY_PROFILES := {
	"garrick_holt": {"health": 100, "damage": 3, "melee_hit": 5, "skills": {"club_hit": 1, "club_dmg": 1}},
	"mira_ashbrook": {"health": 100, "damage": 1, "melee_hit": 5, "skills": {"dagger_hit": 1, "stealth_agility": 1}},
	"oskar_vinn": {"health": 100, "damage": 3, "melee_hit": 5, "skills": {"sword_hit": 1, "sword_dmg": 1}}
}

const ENEMY_PROFILES := {
	"dray_coltayne": {"health": 130, "damage": 3, "melee_hit": 5, "skills": {"sword_hit": 1, "sword_dmg": 1, "sword_parry": 1}},
	"tomlin_brask": {"health": 115, "damage": 3, "melee_hit": 5, "skills": {"spear_hit": 1, "spear_dmg": 1}},
	"hask_greel": {"health": 115, "damage": 3, "melee_hit": 5, "skills": {"axe_hit": 1, "axe_dmg": 1}}
}


static func start(simulation: WorldSimulation, additional_party_ids: Array[String] = []) -> Dictionary:
	if simulation == null:
		return {"ok": false, "reason": "missing_simulation"}
	if simulation.is_in_combat:
		return {"ok": false, "reason": "combat_already_active"}
	for character_id in COMBAT_ALLY_IDS + ENEMY_IDS:
		if simulation.get_character(character_id) == null:
			return {"ok": false, "reason": "missing_combatant", "character_id": character_id}

	for ally_id in ALLY_IDS:
		var ally := simulation.get_character(ally_id)
		var ally_profile: Dictionary = ALLY_PROFILES[ally_id]
		ally.max_health = int(ally_profile["health"])
		ally.health = ally.max_health
		ally.base_damage = int(ally_profile["damage"])
		ally.to_hit_melee = float(ally_profile["melee_hit"])
		var ally_skills: Dictionary = ally_profile.get("skills", {})
		ally.skills = ally_skills.duplicate(true)
		ally.tags.append("hollowmere_defender")
		ally.time_points = ActionEconomy.COMBAT_TURN_READY_TP

	for enemy_id in ENEMY_IDS:
		var enemy := simulation.get_character(enemy_id)
		var enemy_profile: Dictionary = ENEMY_PROFILES[enemy_id]
		enemy.side = "enemy"
		enemy.combat_dormant = false
		enemy.max_health = int(enemy_profile["health"])
		enemy.health = enemy.max_health
		enemy.base_damage = int(enemy_profile["damage"])
		enemy.to_hit_melee = float(enemy_profile["melee_hit"])
		var enemy_skills: Dictionary = enemy_profile.get("skills", {})
		enemy.skills = enemy_skills.duplicate(true)
		enemy.tags.append("ironbond_soldier")
		enemy.time_points = ActionEconomy.COMBAT_TURN_READY_TP

	var encounter_party_ids: Array[String] = []
	var controlled_ids: Array[String] = []
	for party_id in COMBAT_ALLY_IDS:
		var member := simulation.get_character(party_id)
		if member != null and member.can_act():
			encounter_party_ids.append(party_id)
			if PLAYER_CONTROLLED_IDS.has(party_id):
				controlled_ids.append(party_id)
	for party_id in additional_party_ids:
		var member := simulation.get_character(party_id)
		if member != null and member.can_act() and not encounter_party_ids.has(party_id):
			encounter_party_ids.append(party_id)
			controlled_ids.append(party_id)

	var encounter_result: Dictionary = COMBAT_ENCOUNTER_SERVICE.begin(simulation, encounter_party_ids, ENEMY_IDS)
	if not bool(encounter_result.get("ok", false)):
		return encounter_result
	var session: Dictionary = encounter_result.get("session", {})
	return {
		"ok": true,
		"enemy_ids": ENEMY_IDS.duplicate(),
		"party_ids": encounter_party_ids,
		"controlled_ids": controlled_ids,
		"previous_states": session.get("previous_states", {})
	}


static func finish(simulation: WorldSimulation, previous_states: Dictionary) -> void:
	if simulation == null:
		return
	COMBAT_ENCOUNTER_SERVICE.finish(simulation, {"previous_states": previous_states})
	for character_id_value in previous_states:
		var character_id := String(character_id_value)
		var previous: Dictionary = previous_states[character_id_value]
		if String(previous.get("side", "")) != "player":
			continue
		var party_member := simulation.get_character(character_id)
		if party_member != null:
			party_member.side = "player"
			party_member.combat_dormant = false
	for ally_id in ALLY_IDS:
		var ally := simulation.get_character(ally_id)
		if ally != null:
			ally.side = "neutral"
			ally.combat_dormant = true
	for enemy_id in ENEMY_IDS:
		var enemy := simulation.get_character(enemy_id)
		if enemy != null:
			enemy.side = "enemy"
			enemy.combat_dormant = true


static func enemies_defeated(simulation: WorldSimulation) -> bool:
	if simulation == null:
		return false
	for enemy_id in ENEMY_IDS:
		var enemy := simulation.get_character(enemy_id)
		if enemy != null and enemy.can_act():
			return false
	return true


static func party_defeated(simulation: WorldSimulation, party_ids: Array[String] = COMBAT_ALLY_IDS) -> bool:
	if simulation == null:
		return true
	for party_id in party_ids:
		var member := simulation.get_character(party_id)
		if member != null and member.can_act():
			return false
	return true

static func resolve_combat(
	simulation: WorldSimulation,
	journal: CampaignJournal,
	party_ids: Array[String],
	session: Dictionary
) -> Dictionary:
	if simulation == null or journal == null:
		return {"ok": false, "resolved": false, "reason": "missing_simulation_or_journal"}
	if party_defeated(simulation, party_ids):
		finish(simulation, session.get("previous_states", {}))
		journal.fail_quest(HOLLOWMERE_CAMPAIGN_CONTENT.QUEST_ID, "The party was defeated during the Ironbond shakedown.")
		return {
			"ok": true,
			"resolved": true,
			"outcome": "defeat",
			"speaker": "Garrick Holt",
			"message": "The soldiers overpower you. Garrick has no choice but to surrender the due. The confrontation is lost.",
			"choice_label": "Continue."
		}
	if not enemies_defeated(simulation):
		return {"ok": true, "resolved": false}
	finish(simulation, session.get("previous_states", {}))
	var completed := HOLLOWMERE_CAMPAIGN_CONTENT.complete_shakedown(journal)
	var victory_text := HOLLOWMERE_CAMPAIGN_CONTENT.shakedown_victory_text()
	return {
		"ok": bool(completed.get("ok", false)),
		"resolved": true,
		"outcome": "victory",
		"speaker": "Garrick Holt",
		"message": victory_text,
		"choice_label": "Continue.",
		"speech_bubble_character_id": "garrick_holt"
	}
