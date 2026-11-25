class_name GoblinThreatCampaignContent
extends RefCounted
## Source-authored Skarn-tooth campaign dialogue and Chief Skarnub's persistent
## relationship hooks. Scene nodes and resource mutation stay in the caller.

const QUEST_ID := "goblin_threat"
const CHIEF_ID := "chief_skarnub"
const GIFT_EVENT_KEY := "skarnub:gift:60_gold"
const GIFT_COST := 60
const FACTION_SIMULATION_SCRIPT = preload("res://scripts/simulation/campaign_faction_simulation.gd")

const OPENING_GREETING := "Another human, come to gawk or to fight? Speak quick."
const GIFT_RESPONSE := "Huh. Didn't expect that. Maybe you're not just another human come to run us off."
const TRUSTED_STAY_RESPONSE := "You've shown good faith. You don't have to leave this land to us — stay, if that's what you want."
const HIGH_STANDING_DIPLOMACY := "You've done right by us. Truth told, this land's more trouble than it's worth — humans always come eventually. Guarantee us safe passage and supplies, and we'll move on. No more blood spilled, on either side."

static func quest_definition() -> Dictionary:
	return {
		"id":QUEST_ID,
		"title":"The Skarn-tooth Tribe",
		"giver":"Elder Marta Wynfield",
		"description":"Resolve the threat posed by the Skarn-tooth tribe.",
		"objectives":[]
	}


func chief_greeting(relationships: PersistentCharacterRelationshipState, context: Dictionary) -> Dictionary:
	if relationships == null:
		return {"ok":false,"reason":"missing_relationship_state"}
	var quest_resolution := str(context.get("quest_resolution", ""))
	if not quest_resolution.is_empty() and quest_resolution != "goblin_alliance":
		return _conversation("We have nothing left to discuss.", [{"id":"skarnub_leave","label":"..."}])
	if quest_resolution == "goblin_alliance":
		return _alliance_greeting(context)
	var options: Array[Dictionary] = []
	if relationships.has_recorded_event(CHIEF_ID, GIFT_EVENT_KEY):
		options.append({"id":"skarnub_offer_alliance","label":"You don't have to leave. Stay.","kind":"goblin_alliance_offer"})
	elif int(context.get("player_gold", 0)) >= GIFT_COST:
		options.append({"id":"skarnub_give_gift","label":"Offer 60 gold as a gift.","kind":"goblin_gift"})
	options.append({"id":"skarnub_offer_favour","label":"I could help you, for the right price.","kind":"goblin_favour_offer"})
	options.append({"id":"skarnub_read_chief","label":"Try to read him.","kind":"relationship_read"})
	options.append({"id":"skarnub_threaten","label":"Leave this land, or face us.","kind":"threat"})
	options.append({"id":"skarnub_leave","label":"Just looking.","kind":"leave"})
	if float(context.get("goblin_standing", 0.0)) >= 40.0:
		return _conversation(HIGH_STANDING_DIPLOMACY, [
			{"id":"skarnub_offer_diplomacy","label":"Agreed. Take what you need and go.","kind":"goblin_diplomacy_offer"},
			{"id":"skarnub_leave","label":"Not yet.","kind":"leave"}
		])
	return _conversation(OPENING_GREETING, options)


func give_chief_gift(relationships: PersistentCharacterRelationshipState, player_gold: int) -> Dictionary:
	if relationships == null:
		return {"ok":false,"reason":"missing_relationship_state"}
	if relationships.has_recorded_event(CHIEF_ID, GIFT_EVENT_KEY):
		return {"ok":false,"reason":"gift_already_given","gold_remaining":player_gold}
	if player_gold < GIFT_COST:
		return {"ok":false,"reason":"insufficient_gold","gold_required":GIFT_COST,"gold_remaining":player_gold}
	var updated := relationships.record_event(CHIEF_ID, GIFT_EVENT_KEY, {"familiarity":2,"trust":20})
	if updated.is_empty():
		return {"ok":false,"reason":"relationship_update_failed","gold_remaining":player_gold}
	return {
		"ok":true,
		"gifted":true,
		"gold_spent":GIFT_COST,
		"gold_remaining":player_gold - GIFT_COST,
		"relationship":updated,
		"speaker":"Chief Skarnub",
		"text":GIFT_RESPONSE,
		"unlocked_choice":"skarnub_offer_alliance"
	}


func begin_favour_negotiation(journal: CampaignJournal) -> Dictionary:
	if journal == null:
		return {"ok":false,"reason":"missing_campaign_journal"}
	if not journal.quest_definitions.has(QUEST_ID):
		var registered := journal.register_quest_definition(quest_definition())
		if not bool(registered.get("ok", false)):
			return registered
	if not journal.quests.has(QUEST_ID):
		var started := journal.start_quest(QUEST_ID)
		if not bool(started.get("ok", false)):
			return started
	return {
		"ok":true,
		"speaker":"Chief Skarnub",
		"text":"Hah. A human with sense. Bring me what I ask, and we'll get along fine.",
		"choices":[{"id":"skarnub_offer_favours","label":"What do you need?","kind":"goblin_favour_menu"}]
	}


func favour_options(goblin_standing: float) -> Array[Dictionary]:
	var options: Array[Dictionary] = [
		{"id":"skarnub_favour_scout","label":"Scout the human village's patrols for you.","kind":"goblin_favour","favour":"scout"},
		{"id":"skarnub_favour_steal","label":"\"Borrow\" supplies from the farm to the south.","kind":"goblin_favour","favour":"steal"},
		{"id":"skarnub_favour_raid_mine","label":"Help you raid the mining camp down the west road for its shinies.","kind":"goblin_favour","favour":"raid_mine"}
	]
	if goblin_standing >= 25.0:
		options.append({"id":"skarnub_favour_raid","label":"Help you take the fight to Hollowmere itself.","kind":"goblin_favour","favour":"raid"})
	options.append({"id":"skarnub_leave","label":"Actually, never mind.","kind":"leave"})
	return options


func read_chief(relationships: PersistentCharacterRelationshipState) -> Dictionary:
	if relationships == null:
		return {"ok":false,"reason":"missing_relationship_state"}
	var relationship := relationships.snapshot(CHIEF_ID)
	if relationship.is_empty():
		return {"ok":false,"reason":"unknown_chief"}
	var trust := int(relationship.get("trust", 0))
	var text := "Skarnub watches you carefully. He is weighing whether you are a threat, a useful tool, or both."
	if trust >= 20:
		text = "The chief's suspicion has eased. He still measures every word, but he now believes you may be useful to his tribe."
	return {"ok":true,"speaker":"Chief Skarnub","text":text,"relationship":relationship}



## Resolve one of the mutually exclusive campaign outcomes. Reputation changes
## are applied to CampaignJournal here; scene-level consequences are returned
## as descriptors for the campaign runtime to enact exactly once.
func resolve_threat(journal: CampaignJournal, resolution: String, relationships: PersistentCharacterRelationshipState = null) -> Dictionary:
	if journal == null:
		return {"ok":false,"reason":"missing_campaign_journal"}
	var outcomes := {
		"goblin_diplomacy":{
			"kingdom":-10.0,"goblin":15.0,
			"effects":{"region_security":{"hollowmere":8},"experience":150,"rescue_aldric":true,"aldric_attitude":-10,"message":"The Skarn-tooth tribe breaks camp and moves on."}
		},
		"goblin_alliance":{
			"kingdom":-20.0,"goblin":25.0,
			"effects":{"region_security":{"hollowmere":-10},"experience":100,"rescue_aldric":true,"aldric_attitude":-20,"message":"The Skarn-tooth tribe stays, with your blessing."}
		},
		"assault":{
			"kingdom":20.0,"goblin":-30.0,
			"effects":{"region_security":{"hollowmere":15},"experience":300,"rescue_aldric":true,"aldric_attitude":25,"message":"With Chief Skarnub fallen and the camp broken, the threat is over."}
		},
		"stealth_succession":{
			"kingdom":15.0,"goblin":5.0,
			"effects":{"region_security":{"hollowmere":12},"experience":250,"rescue_aldric":true,"aldric_attitude":20,"message":"Under Nix's lead, the tribe leaves the area peacefully."}
		},
		"betrayal":{
			"kingdom":-60.0,"goblin":30.0,
			"effects":{"region_security":{"hollowmere":-30},"region_prosperity":{"hollowmere":-30},"aldric_attitude":0,"aldric_leaves_if_recruited":true,"message":"You lead the goblins toward Hollowmere. There is no going back."}
		}
	}
	if not outcomes.has(resolution):
		return {"ok":false,"reason":"unknown_resolution"}
	if resolution == "goblin_diplomacy" and journal.faction_standing("goblin_tribe") < 40.0:
		return {"ok":false,"reason":"insufficient_goblin_standing","required":40}
	if resolution == "goblin_alliance" and (relationships == null or not relationships.has_recorded_event(CHIEF_ID, GIFT_EVENT_KEY)):
		return {"ok":false,"reason":"chief_gift_required"}
	var started := _ensure_threat_quest_started(journal)
	if not bool(started.get("ok", false)):
		return started
	var current := journal.quest_state(QUEST_ID)
	var decisions: Dictionary = current.get("decisions", {})
	if String(current.get("status", "")) == "completed":
		return {"ok":true,"applied":false,"reason":"already_resolved","resolution":String(decisions.get("resolution", ""))}
	var recorded := journal.record_decision(QUEST_ID, "resolution", resolution)
	if not bool(recorded.get("ok", false)):
		return recorded
	var outcome: Dictionary = outcomes[resolution]
	var effects: Dictionary = outcome.get("effects", {})
	var kingdom_change := journal.adjust_faction_reputation("silverhart_kingdom", float(outcome.kingdom), 15.0, "goblin_threat:" + resolution)
	var goblin_change := FACTION_SIMULATION_SCRIPT.adjust_goblin_reputation(journal, float(outcome.goblin), 20.0, "goblin_threat:" + resolution)
	var completed := journal.complete_quest(QUEST_ID)
	if not bool(completed.get("ok", false)):
		return completed
	return {
		"ok":true,"applied":true,"resolution":resolution,
		"reputation":{"silverhart_kingdom":kingdom_change,"goblin_tribe":goblin_change},
		"effects":effects.duplicate(true)
	}


func resolve_favour(journal: CampaignJournal, favour: String) -> Dictionary:
	if journal == null:
		return {"ok":false,"reason":"missing_campaign_journal"}
	var started := _ensure_threat_quest_started(journal)
	if not bool(started.get("ok", false)):
		return started
	var quest := journal.quest_state(QUEST_ID)
	if String(quest.get("status", "")) != "active":
		return {"ok":false,"reason":"quest_not_active"}
	if favour == "raid":
		if journal.faction_standing("goblin_tribe") < 25.0:
			return {"ok":false,"reason":"insufficient_goblin_standing","required":25}
		return resolve_threat(journal, "betrayal")
	var outcomes := {
		"scout":{"goblin":10.0,"kingdom":-8.0,"knowledge":10.0,"effects":{"region_security":{"hollowmere":-4},"experience":40,"aldric_attitude":-8,"message":"You pass word of Hollowmere's patrol routes to the goblins."}},
		"steal":{"goblin":8.0,"kingdom":-5.0,"knowledge":10.0,"effects":{"region_prosperity":{"hollowmere":-5},"experience":30,"aldric_attitude":-5,"message":"You raid Old Mac's stores and bring the goods back to the tribe."}},
		"raid_mine":{"goblin":15.0,"kingdom":-15.0,"knowledge":15.0,"effects":{"region_security":{"emberlode":-20},"region_prosperity":{"emberlode":-25},"emberlode_raided":true,"player_gold":60,"experience":50,"aldric_attitude":-15,"message":"You lead the raid on Emberlode. Its strongbox and ore stores are taken."}}
	}
	if not outcomes.has(favour):
		return {"ok":false,"reason":"unknown_favour"}
	var decision_id := "favour_" + favour
	var decisions: Dictionary = quest.get("decisions", {})
	if decisions.has(decision_id):
		return {"ok":true,"applied":false,"reason":"favour_already_resolved","favour":favour}
	var recorded := journal.record_decision(QUEST_ID, decision_id, favour)
	if not bool(recorded.get("ok", false)):
		return recorded
	var outcome: Dictionary = outcomes[favour]
	var effects: Dictionary = outcome.get("effects", {})
	var goblin_change := FACTION_SIMULATION_SCRIPT.adjust_goblin_reputation(journal, float(outcome.goblin), float(outcome.knowledge), "goblin_favour:" + favour)
	var kingdom_change := journal.adjust_faction_reputation("silverhart_kingdom", float(outcome.kingdom), float(outcome.knowledge), "goblin_favour:" + favour)
	return {"ok":true,"applied":true,"favour":favour,"reputation":{"goblin_tribe":goblin_change,"silverhart_kingdom":kingdom_change},"effects":effects.duplicate(true)}


func _ensure_threat_quest_started(journal: CampaignJournal) -> Dictionary:
	if not journal.quest_definitions.has(QUEST_ID):
		var registered := journal.register_quest_definition(quest_definition())
		if not bool(registered.get("ok", false)):
			return registered
	if not journal.quests.has(QUEST_ID):
		return journal.start_quest(QUEST_ID)
	return {"ok":true,"quest_id":QUEST_ID}


func _alliance_greeting(context: Dictionary) -> Dictionary:
	var mine_completed := bool(context.get("mine_raid_completed", false))
	var mine_started := bool(context.get("mine_raid_started", false))
	var scout_note_read := bool(context.get("goblin_scout_note_read", false))
	var spy_started := bool(context.get("greenskin_spy_started", false))
	var spy_completed := bool(context.get("greenskin_spy_completed", false))
	if scout_note_read and mine_completed and not spy_started:
		return _conversation(
			"You've proven useful, human. There's a bigger prize than a mine — the warband pressing Northwatch Fort could use eyes and a hand on the inside. Help us take it, and there'll be a place for you when it falls.",
			[
				{"id":"skarnub_start_spy","label":"I'll help you take Northwatch.","kind":"start_greenskin_spy"},
				{"id":"skarnub_leave","label":"Not yet.","kind":"leave"}
			]
		)
	if spy_started and not spy_completed:
		return _conversation("Northwatch still stands. Get in there and help our warband bring it down.", [{"id":"skarnub_spy_status","label":"On it.","kind":"leave"}])
	if mine_completed:
		return _conversation("We're settled here, thanks to you. That mine haul didn't hurt either.", [{"id":"skarnub_leave","label":"Good.","kind":"leave"}])
	if not mine_started:
		return _conversation(
			"Since you've let us stay... there's a mining camp down the west road. Rich pickings, if you're willing to lead us there.",
			[
				{"id":"skarnub_start_mine_raid","label":"I'll help you raid it.","kind":"start_goblin_mine_raid"},
				{"id":"skarnub_leave","label":"Not yet.","kind":"leave"}
			]
		)
	return _conversation("Well? Are we raiding that mine or not?", [
		{"id":"skarnub_resolve_mine_raid","label":"Lead the raid now.","kind":"resolve_goblin_mine_raid"},
		{"id":"skarnub_leave","label":"Not yet.","kind":"leave"}
	])


func _conversation(body: String, choices: Array[Dictionary]) -> Dictionary:
	return {"ok":true,"speaker":"Chief Skarnub","text":body,"choices":choices.duplicate(true)}
