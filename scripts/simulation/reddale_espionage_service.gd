class_name ReddaleEspionageService
extends RefCounted
## Persistent, source-derived mirror espionage quests for Baron Corwin and Petra Voss.
## Quest progress and choices live in CampaignJournal so scene changes do not reset them.

const FACTIONS = preload("res://scripts/simulation/campaign_faction_system.gd")
const VISION = preload("res://scripts/simulation/vision_rules.gd")
const QUESTS := {
	"spy_on_guild": {
		"title":"Eyes on the Guildhouse",
		"giver":"Baron Corwin Aldervale",
		"target_npc":"baron_corwin_aldervale",
		"target_faction":"ironbond_company",
		"evidence_id":"guild_ledger_evidence",
		"evidence_hex":Vector2i(147, 33),
		"guard_id":"guild_watchman_corley",
		"guard_hex":Vector2i(145, 34),
		"evidence_text":"Ironbond's private ledgers",
		"failure_text":"Guild Watchman Corley spotted you in the guildhouse.",
		"start_standing":20.0,
		"objective":"Enter the Ironbond guildhouse, find the private ledgers and leave unseen."
	},
	"spy_on_baron": {
		"title":"A Look at the Ledgers",
		"giver":"Guildmaster Petra Voss",
		"target_npc":"petra_voss",
		"target_faction":"silverhart_kingdom",
		"evidence_id":"baron_tariff_evidence",
		"evidence_hex":Vector2i(147, 13),
		"guard_id":"steward_halvard_greer",
		"guard_hex":Vector2i(145, 14),
		"evidence_text":"the steward's real tariff tally",
		"failure_text":"Steward Halvard Greer caught you in the manor.",
		"start_standing":40.0,
		"objective":"Enter the Baron's manor, find the steward's true tariff tally and leave unseen."
	}
}
const DOUBLE_CROSS_STANDING := -40.0
const FAILURE_STANDING_HIT := -20.0
const KNOWLEDGE_DELTA := 15.0
const COMPLETION_XP := 150


static func register_definitions(journal: CampaignJournal) -> void:
	if journal == null:
		return
	for quest_id_value in QUESTS:
		var quest_id := String(quest_id_value)
		if journal.quest_definitions.has(quest_id):
			continue
		journal.register_quest_definition({
			"id":quest_id,
			"title":String(QUESTS[quest_id].title),
			"objectives":[{"id":"recover_evidence","target":1.0,"required":true}]
		})


static func interact(journal: CampaignJournal, npc_id: String, player_hex: Vector2i) -> Dictionary:
	if journal == null:
		return {}
	register_definitions(journal)
	if npc_id == "baron_corwin_aldervale":
		return _interact_with_baron(journal, player_hex)
	if npc_id == "petra_voss":
		return _interact_with_petra(journal, player_hex)
	return {}


static func _interact_with_baron(journal: CampaignJournal, _player_hex: Vector2i) -> Dictionary:
	var quest: Dictionary = journal.quest_state("spy_on_guild")
	if String(quest.get("status", "")) == "active":
		if not bool(quest.get("evidence_recovered", false)):
			return _prompt("Baron Corwin Aldervale", "Still no word from the guildhouse? Find the ledgers and bring them to me.", [{"id":"close","label":"I'm working on it."}])
		if not bool(quest.get("evidence_handed_in", false)):
			return _hand_in_prompt("Baron Corwin Aldervale", "You found their ledgers. Let me see what Ironbond has been hiding.", "spy_on_guild")
	if String(quest.get("status", "")) == "failed":
		return _prompt("Baron Corwin Aldervale", "I heard you were caught snooping around the guildhouse. I won't ask you to try again.", [{"id":"close","label":"Understood."}])
	if String(quest.get("status", "")) == "completed":
		return _prompt("Baron Corwin Aldervale", "The ledgers have given me enough to act. Reddale will remember who brought them to light.", [{"id":"close","label":"Good."}])
	var trust := journal.faction_standing("silverhart_kingdom")
	if trust < float(QUESTS.spy_on_guild.start_standing):
		return _prompt("Baron Corwin Aldervale", "Reddale answers to me. Earn the Crown's trust before asking me to share matters of state.", [{"id":"close","label":"Understood."}])
	return _offer_prompt(journal, "spy_on_guild")


static func _interact_with_petra(journal: CampaignJournal, _player_hex: Vector2i) -> Dictionary:
	var quest: Dictionary = journal.quest_state("spy_on_baron")
	if String(quest.get("status", "")) == "active":
		if not bool(quest.get("evidence_recovered", false)):
			return _prompt("Guildmaster Petra Voss", "Still no word from the manor? Bring me the steward's true tariff tally.", [{"id":"close","label":"I'm working on it."}])
		if not bool(quest.get("evidence_handed_in", false)):
			return _hand_in_prompt("Guildmaster Petra Voss", "You've the look of someone who's been in the manor. Show me what you found.", "spy_on_baron")
	if String(quest.get("status", "")) == "failed":
		return _prompt("Guildmaster Petra Voss", "I heard the steward caught someone poking around the manor. I won't send you back.", [{"id":"close","label":"Understood."}])
	if String(quest.get("status", "")) == "completed":
		return _prompt("Guildmaster Petra Voss", "Those tariff records will make interesting reading. You did well.", [{"id":"close","label":"Glad to help."}])
	var influence := journal.merchant_influence_for("ironbond_company", "silverhart_kingdom")
	if influence < float(QUESTS.spy_on_baron.start_standing):
		return _prompt("Guildmaster Petra Voss", "The Company has business to settle before I can trust you with anything delicate.", [{"id":"close","label":"Understood."}])
	return _offer_prompt(journal, "spy_on_baron")


static func _offer_prompt(journal: CampaignJournal, quest_id: String) -> Dictionary:
	var definition: Dictionary = QUESTS[quest_id]
	var opposite_id := "spy_on_baron" if quest_id == "spy_on_guild" else "spy_on_guild"
	var opposite: Dictionary = journal.quest_state(opposite_id)
	if String(opposite.get("status", "")) == "active" and not bool(opposite.get("double_cross_offered", false)):
		var is_baron := quest_id == "spy_on_guild"
		var name := "Baron Corwin Aldervale" if is_baron else "Guildmaster Petra Voss"
		var body := "I know you've been sent to spy on my people. Keep playing their agent, but bring what you learn to me first. I'll reward your loyalty. Refuse, and this town will become a hard place for you."
		return _prompt(name, body, [
			{"id":"double_agent","label":"I'm your inside agent now."},
			{"id":"decline_double_agent","label":"You're wrong about me."}
		], {"quest_id":opposite_id})
	var body := "I need proof, not rumours. %s If you're seen, this will go badly for both of us." % String(definition.objective)
	return _prompt(String(definition.giver), body, [
		{"id":"accept","label":"I'll do it."},
		{"id":"decline","label":"Not my business."}
	], {"quest_id":quest_id})


static func _hand_in_prompt(title: String, body: String, quest_id: String) -> Dictionary:
	return _prompt(title, body, [
		{"id":"hand_in","label":"Here is the evidence. (Hand it over)"},
		{"id":"close","label":"Not yet."}
	], {"quest_id":quest_id})


static func _prompt(title: String, body: String, choices: Array[Dictionary], context: Dictionary = {}) -> Dictionary:
	return {"ok":true,"title":title,"body":body,"choices":choices,"context":context}


static func choose(journal: CampaignJournal, quest_id: String, choice_id: String, player: CharacterState = null) -> Dictionary:
	if journal == null or not QUESTS.has(quest_id):
		return {"ok":false,"reason":"unknown_quest"}
	register_definitions(journal)
	var state: Dictionary = journal.quests.get(quest_id, {})
	match choice_id:
		"accept":
			var started := journal.start_quest(quest_id)
			if not bool(started.get("ok", false)):
				return started
			state = journal.quests[quest_id]
			state["evidence_recovered"] = false
			state["evidence_handed_in"] = false
			journal.quests[quest_id] = state
			return {"ok":true,"message":"Quest started: %s" % String(QUESTS[quest_id].title),"mission_started":true}
		"double_agent":
			if String(state.get("status", "")) != "active":
				return {"ok":false,"reason":"quest_not_active"}
			state["double_cross_offered"] = true
			state["double_agent_for"] = "silverhart_kingdom" if quest_id == "spy_on_baron" else "ironbond_company"
			journal.quests[quest_id] = state
			var friendly := String(state["double_agent_for"])
			FACTIONS.adjust_reputation(journal, friendly, 10.0, KNOWLEDGE_DELTA, "Reddale double-agent pledge")
			return {"ok":true,"message":"You have agreed to act as an inside agent for %s." % friendly}
		"decline_double_agent":
			if String(state.get("status", "")) != "active":
				return {"ok":false,"reason":"quest_not_active"}
			state["double_cross_offered"] = true
			state["double_cross_declined"] = true
			journal.quests[quest_id] = state
			var opposing := "silverhart_kingdom" if quest_id == "spy_on_baron" else "ironbond_company"
			FACTIONS.adjust_reputation(journal, opposing, -10.0, KNOWLEDGE_DELTA, "Rejected Reddale double-agent offer")
			return {"ok":true,"message":"You refused the offer. The other side will remember."}
		"hand_in":
			if String(state.get("status", "")) != "active" or not bool(state.get("evidence_recovered", false)):
				return {"ok":false,"reason":"evidence_not_recovered"}
			return _complete_mission(journal, quest_id, player)
		_:
			return {"ok":false,"reason":"unknown_choice"}


static func search_evidence(journal: CampaignJournal, quest_id: String, player_hex: Vector2i) -> Dictionary:
	if journal == null or not QUESTS.has(quest_id):
		return {"ok":false,"reason":"unknown_quest"}
	var state: Dictionary = journal.quest_state(quest_id)
	if String(state.get("status", "")) != "active":
		return {"ok":false,"reason":"quest_not_active"}
	if bool(state.get("evidence_recovered", false)):
		return {"ok":false,"reason":"already_searched"}
	var target: Vector2i = QUESTS[quest_id].evidence_hex
	if HexGrid.distance(player_hex, target) != 0:
		return {"ok":false,"reason":"not_at_evidence"}
	state = journal.quests[quest_id]
	state["evidence_recovered"] = true
	journal.quests[quest_id] = state
	journal.set_objective_progress(quest_id, "recover_evidence", 1.0)
	return {"ok":true,"message":"You recover %s. Return to %s without being caught." % [String(QUESTS[quest_id].evidence_text), String(QUESTS[quest_id].giver)]}


static func toggle_stealth(
	journal: CampaignJournal,
	quest_id: String,
	player: CharacterState,
	map_data: HexMapData,
	light_level: float = 1.0
) -> Dictionary:
	if journal == null or player == null or map_data == null or not QUESTS.has(quest_id):
		return {"ok":false,"reason":"missing_stealth_context"}
	if player.is_stealthed:
		player.is_stealthed = false
		player.stealth_score = 0
		return {"ok":true,"stealthed":false,"message":"You stop moving stealthily."}
	var quest: Dictionary = journal.quest_state(quest_id)
	if String(quest.get("status", "")) != "active":
		return {"ok":false,"reason":"quest_not_active"}
	var guard_hex: Vector2i = QUESTS[quest_id].guard_hex
	var guard := CharacterState.new(String(QUESTS[quest_id].guard_id), "Guard", guard_hex)
	guard.side = "enemy"
	if VISION.can_see(map_data, guard, player, false, light_level < 0.8):
		return {"ok":false,"reason":"currently_seen","message":"The guard can see you; find cover before attempting to hide."}
	var score := 50
	if _skill_rank(player, "stealth_agility") > 0:
		score += 5
	if _skill_rank(player, "stealth_rogue") > 0:
		score += 5
	score -= roundi(clampf(light_level, 0.0, 1.5) * 40.0)
	var cell: Dictionary = map_data.cells.get(player.axial, {})
	score += int(cell.get("stealth_bonus", 0))
	var terrain_id := map_data.terrain_id_at(player.axial)
	if terrain_id == "foliage" and (_skill_rank(player, "elf_foliage_expertise") > 0 or _skill_rank(player, "druid_foliage_expertise") > 0):
		score += 20
	var armour := String(player.equipment.get("armour", player.equipment.get("armor", "")))
	if armour == "heavy_armor":
		score -= 30
	elif armour == "medium_armor":
		score -= 15
	player.is_stealthed = true
	player.stealth_score = score
	return {"ok":true,"stealthed":true,"stealth_score":score,"message":"You move carefully, keeping to the shadows."}


static func check_guard_detection(
	journal: CampaignJournal,
	quest_id: String,
	player: CharacterState,
	map_data: HexMapData,
	light_level: float = 1.0,
	detection_roll: float = -1.0
) -> Dictionary:
	if journal == null or not QUESTS.has(quest_id) or player == null or map_data == null:
		return {"ok":false,"reason":"missing_detection_context"}
	var state: Dictionary = journal.quest_state(quest_id)
	if String(state.get("status", "")) != "active" or bool(state.get("evidence_handed_in", false)):
		return {"ok":true,"detected":false}
	var guard := CharacterState.new(String(QUESTS[quest_id].guard_id), "Guard", QUESTS[quest_id].guard_hex)
	guard.side = "enemy"
	if not VISION.can_see(map_data, guard, player, false, light_level < 0.8):
		return {"ok":true,"detected":false,"visible":false}
	var spotted := not player.is_stealthed
	if player.is_stealthed:
		var distance := HexGrid.distance(guard.axial, player.axial)
		var distance_bonus := maxi(0, 15 - distance) * 5
		var perception_bonus := VISION.stealth_detection_bonus(guard)
		var spot_chance := maxf(5.0, 100.0 - float(player.stealth_score) + float(distance_bonus + perception_bonus))
		var light_penalty := (1.0 - clampf(light_level, 0.0, 1.0)) * 50.0
		spot_chance -= light_penalty
		var roll := detection_roll
		if roll < 0.0:
			var rng := RandomNumberGenerator.new()
			rng.randomize()
			roll = rng.randf_range(0.0, 100.0)
		spotted = roll < spot_chance
	if not spotted:
		return {"ok":true,"detected":false,"visible":true,"spot_chance":maxf(0.0, 100.0 - float(player.stealth_score) + float(maxi(0, 15 - HexGrid.distance(guard.axial, player.axial)) * 5))}
	player.is_stealthed = false
	player.stealth_score = 0
	journal.fail_quest(quest_id, "guard_detected")
	FACTIONS.adjust_reputation(journal, String(QUESTS[quest_id].target_faction), FAILURE_STANDING_HIT, KNOWLEDGE_DELTA, "Caught during Reddale espionage")
	return {"ok":true,"detected":true,"visible":true,"message":"Caught! %s The mission is blown." % String(QUESTS[quest_id].failure_text)}


static func _skill_rank(player: CharacterState, skill_id: String) -> int:
	var value: Variant = player.skills.get(skill_id, 0)
	if value is Dictionary:
		return maxi(0, int(value.get("rank", value.get("value", 0))))
	return maxi(0, int(value))


static func _complete_mission(journal: CampaignJournal, quest_id: String, player: CharacterState) -> Dictionary:
	var state: Dictionary = journal.quests[quest_id]
	state["evidence_handed_in"] = true
	var double_agent := String(state.get("double_agent_for", ""))
	if quest_id == "spy_on_guild":
		if double_agent == "ironbond_company":
			if journal.faction_standing("ironbond_company") < 0.0:
				journal.adjust_faction_standing("ironbond_company", int(round(-journal.faction_standing("ironbond_company"))), "Double-cross absolution")
			_force_standing(journal, "silverhart_kingdom", DOUBLE_CROSS_STANDING, "Baron double-cross")
			journal.adjust_merchant_influence("ironbond_company", "silverhart_kingdom", 10.0, "Secret Company reward")
		else:
			FACTIONS.adjust_reputation(journal, "silverhart_kingdom", 15.0, 15.0, "Exposed Ironbond ledgers")
			FACTIONS.adjust_reputation(journal, "ironbond_company", -20.0, 20.0, "Exposed Ironbond ledgers")
			journal.adjust_merchant_influence("ironbond_company", "silverhart_kingdom", -10.0, "Baron receives guild ledgers")
	else:
		if double_agent == "silverhart_kingdom":
			if journal.faction_standing("silverhart_kingdom") < 0.0:
				journal.adjust_faction_standing("silverhart_kingdom", int(round(-journal.faction_standing("silverhart_kingdom"))), "Double-cross absolution")
			_force_standing(journal, "ironbond_company", DOUBLE_CROSS_STANDING, "Ironbond double-cross")
			journal.adjust_merchant_influence("ironbond_company", "silverhart_kingdom", -10.0, "Secret Baron reward")
		else:
			FACTIONS.adjust_reputation(journal, "ironbond_company", 15.0, 15.0, "Exposed Baron tariff records")
			journal.adjust_merchant_influence("ironbond_company", "silverhart_kingdom", 10.0, "Petra receives tariff records")
			FACTIONS.adjust_reputation(journal, "silverhart_kingdom", -20.0, 20.0, "Exposed Baron tariff records")
	journal.complete_quest(quest_id)
	if player != null:
		player.experience += COMPLETION_XP
	return {"ok":true,"message":"Quest complete: %s (+%d XP)." % [String(QUESTS[quest_id].title), COMPLETION_XP],"xp_reward":COMPLETION_XP}


static func _force_standing(journal: CampaignJournal, faction_id: String, value: float, reason: String) -> void:
	var current := journal.faction_standing(faction_id)
	journal.adjust_faction_standing(faction_id, int(round(value - current)), reason)
