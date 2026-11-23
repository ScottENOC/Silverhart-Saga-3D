class_name GoblinCampCampaignContent
extends RefCounted
## Source-backed Skarn-tooth Camp dialogue choices and resolution effects.
## The UI only presents these choices; persistent consequences live in CampaignJournal.
## Region changes, XP, inventory and companion-attitude changes are returned to the
## campaign composition layer for application through its existing systems.

const QUEST_ID := "goblin_threat"
const MINE_QUEST_ID := "goblin_mine_raid"
const SPY_QUEST_ID := "greenskin_spy"
const SCOUT_NOTE_ID := "goblin_scout_note"

const ADDITIONAL_QUESTS := [
	{
		"id": MINE_QUEST_ID,
		"title": "A Favor for the Tribe",
		"description": "Help the Skarn-tooth tribe raid Emberlode's gold mine.",
		"objectives": [{"id": "raid_emberlode", "description": "Lead the goblins in the raid on Emberlode.", "target": 1.0, "required": true}]
	},
	{
		"id": SPY_QUEST_ID,
		"title": "A Hand on the Inside",
		"description": "Help the greenskin warband take Northwatch Fort.",
		"objectives": [{"id": "northwatch_taken", "description": "Help the greenskin warband take Northwatch Fort.", "target": 1.0, "required": true}]
	},
	{
		"id": SCOUT_NOTE_ID,
		"title": "A Foreign Scout's Note",
		"description": "Read the foreign-made note left beside Chief Skarnub's hut.",
		"objectives": [{"id": "note_read", "description": "Read the note beside the chief's hut.", "target": 1.0, "required": true}]
	}
]

const RESOLUTION_EFFECTS := {
	"goblin_diplomacy": {
		"kingdom": [-10.0, 10.0], "goblins": [15.0, 15.0],
		"region": {"hollowmere": {"security": 8}}, "experience": 150,
		"aldric_rescued": true, "aldric_attitude": -10
	},
	"goblin_alliance": {
		"kingdom": [-20.0, 15.0], "goblins": [25.0, 20.0],
		"region": {"hollowmere": {"security": -10}}, "experience": 100,
		"aldric_rescued": true, "aldric_attitude": -20
	},
	"assault": {
		"kingdom": [20.0, 20.0], "goblins": [-30.0, 20.0],
		"region": {"hollowmere": {"security": 15}}, "experience": 300,
		"aldric_rescued": true, "aldric_attitude": 25
	},
	"stealth_succession": {
		"kingdom": [15.0, 15.0], "goblins": [5.0, 10.0],
		"region": {"hollowmere": {"security": 12}}, "experience": 250,
		"aldric_rescued": true, "aldric_attitude": 20
	},
	"betrayal": {
		"kingdom": [-60.0, 30.0], "goblins": [30.0, 20.0],
		"region": {"hollowmere": {"security": -30, "prosperity": -30}},
		"experience": 0, "aldric_rescued": false, "aldric_attitude": -100
	}
}

static func register_quest_definitions(journal: CampaignJournal) -> void:
	if journal == null:
		return
	CompanionCampaignContent.register_quest_definitions(journal)
	for definition_value in ADDITIONAL_QUESTS:
		var definition: Dictionary = definition_value
		var quest_id := String(definition.id)
		if not journal.quest_definitions.has(quest_id):
			journal.register_quest_definition(definition)

static func chief_conversation(journal: CampaignJournal, gifted_in: bool = false) -> Dictionary:
	if journal == null:
		return {}
	var quest := journal.quest_state(QUEST_ID)
	var resolution := String(quest.get("decisions", {}).get("resolution", ""))
	var goblin_standing := journal.faction_standing("goblin_tribe")
	if not resolution.is_empty() and resolution != "goblin_alliance":
		return _conversation("Chief Skarnub", "We have nothing left to discuss.", [_choice("continue", "...")])
	if resolution == "goblin_alliance":
		var mine := journal.quest_state(MINE_QUEST_ID)
		var spy := journal.quest_state(SPY_QUEST_ID)
		var note_read := _completed(journal, SCOUT_NOTE_ID)
		if note_read and String(mine.get("status", "")) == "completed" and spy.is_empty():
			return _conversation("Chief Skarnub", "You've proven useful, human. There's a bigger prize than a mine — the warband pressing Northwatch Fort could use eyes and a hand on the inside. Help us take it, and there'll be a place for you when it falls.", [_choice("start:" + SPY_QUEST_ID, "I'll help you take Northwatch."), _choice("continue", "Not yet.")])
		if not spy.is_empty() and String(spy.get("status", "")) != "completed":
			return _conversation("Chief Skarnub", "Northwatch still stands. Get in there and help our warband bring it down.", [_choice("continue", "On it.")])
		if String(mine.get("status", "")) == "completed":
			return _conversation("Chief Skarnub", "We're settled here, thanks to you. That mine haul didn't hurt either.", [_choice("continue", "Good.")])
		if mine.is_empty():
			return _conversation("Chief Skarnub", "Since you've let us stay... there's a mining camp down the west road. Rich pickings, if you're willing to lead us there.", [_choice("start:" + MINE_QUEST_ID, "I'll help you raid it."), _choice("continue", "Not yet.")])
		return _conversation("Chief Skarnub", "Well? Are we raiding that mine or not?", [_choice("resolve_favor:raid_mine", "Lead the raid now."), _choice("continue", "Not yet.")])
	if goblin_standing >= 40.0:
		return _conversation("Chief Skarnub", "You've done right by us. Truth told, this land's more trouble than it's worth — humans always come eventually. Guarantee us safe passage and supplies, and we'll move on. No more blood spilled, on either side.", [_choice("resolve:goblin_diplomacy", "Agreed. Take what you need and go."), _choice("continue", "Not yet.")])
	var choices: Array[Dictionary] = []
	if gifted_in or bool(quest.get("decisions", {}).get("chief_gifted_in", false)):
		choices.append(_choice("resolve:goblin_alliance", "You don't have to leave. Stay."))
	choices.append(_choice("start:" + QUEST_ID, "I could help you, for the right price."))
	choices.append(_choice("read_the_room", "Try to read him."))
	choices.append(_choice("threaten", "Leave this land, or face us."))
	choices.append(_choice("continue", "Just looking."))
	return _conversation("Chief Skarnub", "Another human, come to gawk or to fight? Speak quick.", choices)

static func gift_chief(journal: CampaignJournal, available_gold: int) -> Dictionary:
	if journal == null:
		return {"ok": false, "reason": "missing_journal"}
	if available_gold < 60:
		return {"ok": false, "reason": "insufficient_gold", "required_gold": 60}
	if not journal.quest_state(QUEST_ID).is_empty() and journal.quest_state(QUEST_ID).get("decisions", {}).has("chief_gifted_in"):
		return {"ok": false, "reason": "already_gifted"}
	var started := _ensure_started(journal, QUEST_ID)
	if not bool(started.get("ok", false)):
		return started
	var decision := journal.record_decision(QUEST_ID, "chief_gifted_in", "gifted")
	if not bool(decision.get("ok", false)):
		return decision
	return {"ok": true, "gold_remaining": available_gold - 60, "gold_spent": 60}

static func offer_favors(journal: CampaignJournal) -> Dictionary:
	if journal == null:
		return {}
	var choices: Array[Dictionary] = [
		_choice("favor:scout", "Scout the human village's patrols for you."),
		_choice("favor:steal", "\"Borrow\" supplies from the farm to the south."),
		_choice("favor:raid_mine", "Help you raid the mining camp down the west road for its shinies.")
	]
	if journal.faction_standing("goblin_tribe") >= 25.0:
		choices.append(_choice("favor:raid", "Help you take the fight to Hollowmere itself."))
	choices.append(_choice("continue", "Actually, never mind."))
	return _conversation("Chief Skarnub", "Plenty a human could do for us, if they've the stomach for it.", choices)

static func resolve_favor(journal: CampaignJournal, kind: String) -> Dictionary:
	if journal == null:
		return {"ok": false, "reason": "missing_journal"}
	var effects: Dictionary = {}
	match kind:
		"scout":
			_apply_reputation(journal, 10.0, 10.0, -8.0, 10.0, "passed Hollowmere patrol routes to the goblins")
			effects = {"region": {"hollowmere": {"security": -4}}, "experience": 40, "aldric_attitude": -8}
		"steal":
			_apply_reputation(journal, 8.0, 10.0, -5.0, 10.0, "stole farm supplies for the goblins")
			effects = {"region": {"hollowmere": {"prosperity": -5}}, "experience": 30, "aldric_attitude": -5}
		"raid_mine":
			_apply_reputation(journal, 15.0, 15.0, -15.0, 15.0, "helped goblins raid Emberlode")
			effects = {"region": {"emberlode": {"security": -20, "prosperity": -25}}, "experience": 50, "gold": 60, "aldric_attitude": -15, "emberlode_raided": true}
		"raid":
			_apply_reputation(journal, 30.0, 20.0, -60.0, 30.0, "led goblins against Hollowmere")
			var completed := _resolve_threat(journal, "betrayal")
			if not bool(completed.get("ok", false)):
				return completed
			effects = {"region": {"hollowmere": {"security": -30, "prosperity": -30}}, "experience": 0, "aldric_rescued": false, "companion_departure": "ser_aldric_thorne"}
		_:
			return {"ok": false, "reason": "unknown_favor"}
	return {"ok": true, "effects": effects}

static func resolve_threat(journal: CampaignJournal, resolution: String) -> Dictionary:
	if not RESOLUTION_EFFECTS.has(resolution):
		return {"ok": false, "reason": "unknown_resolution"}
	var effects: Dictionary = RESOLUTION_EFFECTS[resolution].duplicate(true)
	var completed := _resolve_threat(journal, resolution)
	if not bool(completed.get("ok", false)):
		return completed
	var kingdom: Array = effects.kingdom
	var goblins: Array = effects.goblins
	journal.adjust_faction_reputation("silverhart_kingdom", float(kingdom[0]), float(kingdom[1]), "resolved the Skarn-tooth threat: " + resolution)
	journal.adjust_faction_reputation("goblin_tribe", float(goblins[0]), float(goblins[1]), "resolved the Skarn-tooth threat: " + resolution)
	return {"ok": true, "resolution": resolution, "effects": effects}

static func mark_scout_note_read(journal: CampaignJournal) -> Dictionary:
	if journal == null:
		return {"ok": false, "reason": "missing_journal"}
	if _completed(journal, SCOUT_NOTE_ID):
		return {"ok": true, "already_read": true}
	var started := _ensure_started(journal, SCOUT_NOTE_ID)
	if not bool(started.get("ok", false)):
		return started
	return CompanionCampaignContent.complete_objective(journal, SCOUT_NOTE_ID, "note_read")

static func mark_mine_raid_complete(journal: CampaignJournal) -> Dictionary:
	if journal == null:
		return {"ok": false, "reason": "missing_journal"}
	var started := _ensure_started(journal, MINE_QUEST_ID)
	if not bool(started.get("ok", false)) and String(started.get("reason", "")) != "quest_already_started":
		return started
	return CompanionCampaignContent.complete_objective(journal, MINE_QUEST_ID, "raid_emberlode")

static func mark_northwatch_taken(journal: CampaignJournal) -> Dictionary:
	if journal == null:
		return {"ok": false, "reason": "missing_journal"}
	var started := _ensure_started(journal, SPY_QUEST_ID)
	if not bool(started.get("ok", false)) and String(started.get("reason", "")) != "quest_already_started":
		return started
	return CompanionCampaignContent.complete_objective(journal, SPY_QUEST_ID, "northwatch_taken")

static func _resolve_threat(journal: CampaignJournal, resolution: String) -> Dictionary:
	var started := _ensure_started(journal, QUEST_ID)
	if not bool(started.get("ok", false)) and String(started.get("reason", "")) != "quest_already_started":
		return started
	return CompanionCampaignContent.complete_with_decision(journal, QUEST_ID, "resolved", "resolution", resolution)

static func _ensure_started(journal: CampaignJournal, quest_id: String) -> Dictionary:
	if not journal.quest_state(quest_id).is_empty():
		return {"ok": false, "reason": "quest_already_started"}
	return journal.start_quest(quest_id)

static func _apply_reputation(journal: CampaignJournal, goblin_delta: float, goblin_knowledge: float, kingdom_delta: float, kingdom_knowledge: float, reason: String) -> void:
	journal.adjust_faction_reputation("goblin_tribe", goblin_delta, goblin_knowledge, reason)
	journal.adjust_faction_reputation("silverhart_kingdom", kingdom_delta, kingdom_knowledge, reason)

static func _completed(journal: CampaignJournal, quest_id: String) -> bool:
	return String(journal.quest_state(quest_id).get("status", "")) == "completed"

static func _conversation(speaker: String, body: String, choices: Array[Dictionary]) -> Dictionary:
	return {"speaker": speaker, "text": body, "choices": choices}

static func _choice(id: String, label: String, available: bool = true, reason: String = "") -> Dictionary:
	return {"id": id, "label": label, "available": available, "unavailable_reason": reason}
