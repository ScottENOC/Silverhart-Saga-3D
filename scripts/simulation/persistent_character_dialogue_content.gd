class_name PersistentCharacterDialogueContent
extends RefCounted
## Source-authored dialogue memory and consequence hooks for important NPCs.
## This returns content/metadata for the dialogue layer; it never wraps UI nodes
## or depends on a spawned NPC instance.

const DIALOGUE_CHARACTERS := {
	"silverhart_queen":"seraphine_corrin",
	"elf_queen":"aelwen_silthandriel",
	"dwarf_king":"balrik_deepholm",
	"royal_wizard":"court_wizard_thessaly",
	"elder_nessa_wren":"nessa_wren",
	"reddale_guildmaster":"petra_voss",
	"high_cleric":"adelram",
	"deepholds_runesmith":"thrain_emberhand",
	"reddale_captain":"ilsa_rennick"
}

const SERAPHINE_TOPIC_KEYS := {
	"What of the greenskins?":"seraphine:topic:greenskins",
	"What of the Ironbond Company?":"seraphine:topic:ironbond",
	"Rumors of necromancy in Reddale?":"seraphine:topic:necromancy"
}

const SERAPHINE_PERSONAL_QUESTION := "And you, Your Majesty? How are you holding up?"
const SERAPHINE_PERSONAL_RESPONSE := "Your secret's safe with me."

const SERAPHINE_PERSONAL_LINES := {
	"guarded":"Concern is kind. It's also how half this court tries to get a ruler to lower her guard. I'm managing — that will have to do for now.",
	"tired_private":"Tired. There — you've extracted a state secret. The crown is mostly paperwork, funerals, and people asking for certainty from someone who has very little of it to spare.",
	"tired_seen":"Tired, and angrier than I ought to be some days. You asked about me rather than the crown, though. I noticed. Court teaches you to notice things like that.",
	"trusted":"Tired. Frightened, occasionally. Don't repeat that last part — half this court would turn a bad night's sleep into a succession crisis. Still... it's good to be asked as Seraphine once in a while."
}


static func character_id_for_dialogue(dialogue_id: String) -> String:
	return String(DIALOGUE_CHARACTERS.get(dialogue_id, ""))


func note_audience(relationships: PersistentCharacterRelationshipState, dialogue_id: String) -> Dictionary:
	if relationships == null:
		return {"ok":false,"reason":"missing_relationship_state"}
	var character_id := character_id_for_dialogue(dialogue_id)
	if character_id.is_empty():
		return {"ok":false,"reason":"unknown_dialogue_tree"}
	var result := relationships.note_conversation(character_id, "audience:" + dialogue_id, {"familiarity":1})
	return {"ok":true,"character_id":character_id,"relationship":result}


func decorate_seraphine_options(relationships: PersistentCharacterRelationshipState, options: Array[Dictionary]) -> Array[Dictionary]:
	var decorated: Array[Dictionary] = []
	for option_value in options:
		var option: Dictionary = option_value.duplicate(true)
		var label := String(option.get("label", ""))
		if SERAPHINE_TOPIC_KEYS.has(label):
			option["persistent_conversation_key"] = String(SERAPHINE_TOPIC_KEYS[label])
			option["persistent_conversation_delta"] = {"familiarity":1}
		decorated.append(option)
	var relationship := relationships.snapshot("seraphine_corrin") if relationships != null else {}
	if int(relationship.get("familiarity", 0)) >= 9 and not _has_label(decorated, SERAPHINE_PERSONAL_QUESTION):
		decorated.append({
			"id":"seraphine_personal_burden",
			"label":SERAPHINE_PERSONAL_QUESTION,
			"kind":"persistent_character_personal_question"
		})
	return decorated


func apply_dialogue_choice(relationships: PersistentCharacterRelationshipState, character_id: String, option: Dictionary) -> Dictionary:
	if relationships == null:
		return {"ok":false,"reason":"missing_relationship_state"}
	if not relationships.is_persistent_character(character_id):
		return {"ok":false,"reason":"unknown_persistent_character"}
	var key := String(option.get("persistent_conversation_key", ""))
	if key.is_empty():
		return {"ok":true,"changed":false,"relationship":relationships.snapshot(character_id)}
	var before := relationships.snapshot(character_id)
	var delta: Dictionary = option.get("persistent_conversation_delta", {"familiarity":1})
	var updated := relationships.note_conversation(character_id, key, delta)
	return {"ok":true,"changed":before != updated,"relationship":updated}


func seraphine_personal_response(relationships: PersistentCharacterRelationshipState) -> Dictionary:
	if relationships == null:
		return {"ok":false,"reason":"missing_relationship_state"}
	var relationship := relationships.snapshot("seraphine_corrin")
	if relationship.is_empty():
		return {"ok":false,"reason":"unknown_persistent_character"}
	var line_key := "trusted"
	if int(relationship.get("trust", 0)) < 20:
		line_key = "guarded"
	elif int(relationship.get("friendship", 0)) < 15:
		line_key = "tired_private"
	elif int(relationship.get("friendship", 0)) < 35:
		line_key = "tired_seen"
	var updated := relationships.note_conversation("seraphine_corrin", "seraphine:personal_burden", {"familiarity":2,"trust":1,"friendship":4})
	return {"ok":true,"text":String(SERAPHINE_PERSONAL_LINES[line_key]),"line_key":line_key,"response_label":SERAPHINE_PERSONAL_RESPONSE,"relationship":updated}


func apply_wizard_vendetta_resolution(relationships: PersistentCharacterRelationshipState, resolution: String, quest_completed_now: bool) -> Dictionary:
	if relationships == null:
		return {"ok":false,"reason":"missing_relationship_state"}
	if not quest_completed_now:
		return {"ok":true,"applied":false,"reason":"quest_not_newly_completed"}
	var events: Array[Dictionary] = []
	match resolution:
		"queen":
			events = [
				{"character_id":"seraphine_corrin","event_key":"wizard_vendetta:evidence_to_crown","delta":{"familiarity":2,"trust":7,"friendship":2}},
				{"character_id":"court_wizard_thessaly","event_key":"wizard_vendetta:evidence_to_crown","delta":{"familiarity":2,"trust":-8,"friendship":-4}}
			]
		"wizard":
			events = [{"character_id":"court_wizard_thessaly","event_key":"wizard_vendetta:warned_thessaly","delta":{"familiarity":2,"trust":9,"friendship":4}}]
		"noble":
			events = [{"character_id":"court_wizard_thessaly","event_key":"wizard_vendetta:evidence_to_corstane","delta":{"familiarity":2,"trust":-12,"friendship":-6}}]
		_:
			return {"ok":false,"reason":"unknown_resolution"}
	var results: Array[Dictionary] = []
	for event in events:
		results.append(relationships.record_event(String(event.character_id), String(event.event_key), event.delta))
	return {"ok":true,"applied":true,"events":results}


## Build Queen Seraphine's source-authored audience from campaign state. The
## caller supplies world flags and player inventory facts; this content layer
## never reaches into scene nodes or duplicates campaign state.
func seraphine_greeting(context: Dictionary, relationships: PersistentCharacterRelationshipState) -> Dictionary:
	if relationships == null:
		return {"ok":false,"reason":"missing_relationship_state"}
	var is_greenskin := bool(context.get("player_is_greenskin", false))
	if is_greenskin and not bool(context.get("goblin_vouched_by_marta", false)):
		return {
			"ok":false,
			"reason":"greenskin_not_vouched",
			"speaker":"Queen Seraphine Corrin",
			"text":"Guards! Get that thing out of my hall before I have it removed the hard way.",
			"choices":[{"id":"seraphine_leave","label":"..."}]
		}
	note_audience(relationships, "silverhart_queen")
	var standing := float(context.get("silverhart_standing", 0.0))
	var greeting := "Another face passing through court. Say your piece, if you have one."
	if is_greenskin:
		greeting = "Elder Marta vouches for you, of all things. I still don't trust a greenskin in my hall, but I trust her judgment more than I distrust you. Speak your piece."
	elif standing >= 40.0:
		greeting = "So — you're the one Reddale and Hollowmere keep writing to me about. Good work, whatever you've been doing out there. The crown remembers those who make its work easier."
	elif standing >= 10.0:
		greeting = "You've kept my barony's business in decent order, from what reaches my desk. Keep it that way."
	elif standing <= -20.0:
		greeting = "I know your name, and not from anything I'd call flattering. Mind yourself in my hall."
	var options: Array[Dictionary] = []
	if context.has("goblin_standing"):
		options.append({"id":"seraphine_topic_greenskins","label":"What of the greenskins?","kind":"seraphine_topic"})
	if context.has("ironbond_influence"):
		options.append({"id":"seraphine_topic_ironbond","label":"What of the Ironbond Company?","kind":"seraphine_topic"})
	options.append({"id":"seraphine_topic_necromancy","label":"Rumors of necromancy in Reddale?","kind":"seraphine_topic"})
	if bool(context.get("manor_granted", false)):
		options.append({"id":"seraphine_manor_followup","label":"About the manor you granted me...","kind":"seraphine_manor_followup"})
	elif standing >= 60.0:
		options.append({"id":"seraphine_request_favour","label":"Your Majesty, might I ask a favor?","kind":"seraphine_manor_request"})
	if bool(context.get("wizard_vendetta_active", false)) and bool(context.get("has_wizard_corruption_evidence", false)):
		options.append({"id":"seraphine_wizard_evidence","label":"I have evidence concerning your Court Wizard.","kind":"seraphine_wizard_evidence"})
	if bool(context.get("chancellor_tunnel_discovered", false)) and not bool(context.get("chancellor_tunnel_reported", false)):
		options.append({"id":"seraphine_report_chancellor_tunnel","label":"Your Majesty, I must tell you something about your Chancellor.","kind":"seraphine_chancellor_tunnel"})
	options.append({"id":"seraphine_leave","label":"Just paying my respects, Your Majesty.","kind":"leave"})
	options = decorate_seraphine_options(relationships, options)
	return {"ok":true,"speaker":"Queen Seraphine Corrin","text":greeting,"choices":options,"relationship":relationships.snapshot("seraphine_corrin")}


## Build the streamed Queen audience from authoritative simulation state. The
## world adapter supplies the relationship state but does not assemble campaign
## facts or know which flags the authored greeting requires.
func seraphine_greeting_from_simulation(
	simulation: WorldSimulation,
	relationships: PersistentCharacterRelationshipState
) -> Dictionary:
	if simulation == null or simulation.campaign_journal == null:
		return {"ok":false,"reason":"missing_campaign"}
	var journal := simulation.campaign_journal
	var wizard_quest := journal.quest_state("wizard_vendetta")
	var player := simulation.get_character(simulation.player_character_id)
	var context := {
		"silverhart_standing": journal.faction_standing("silverhart_kingdom"),
		"manor_granted": simulation.campaign_dwellings != null and bool(simulation.campaign_dwellings.owned.get("silverhart_manor", false)),
		"goblin_standing": journal.faction_standing("goblin_tribe"),
		"ironbond_influence": journal.merchant_influence_for("ironbond_company", "silverhart_kingdom"),
		"necromancer_standing": journal.faction_standing("necromancer_cult"),
		"phylactery_returned": bool(simulation.get_meta("phylactery_returned", false)),
		"has_phylactery_shard": _character_has_item(player, "phylactery_shard"),
		"wizard_vendetta_active": String(wizard_quest.get("status", "")) == "active",
		"has_wizard_corruption_evidence": _character_has_item(player, "wizard_corruption_evidence"),
		"chancellor_tunnel_discovered": bool(simulation.get_meta("chancellor_tunnel_discovered", false)),
		"chancellor_tunnel_reported": bool(simulation.get_meta("chancellor_tunnel_reported_to_queen", false))
	}
	return seraphine_greeting(context, relationships)


func seraphine_topic_response(topic: String, context: Dictionary, relationships: PersistentCharacterRelationshipState) -> Dictionary:
	if relationships == null:
		return {"ok":false,"reason":"missing_relationship_state"}
	var text := ""
	match topic:
		"greenskins":
			if not context.has("goblin_standing"):
				return {"ok":false,"reason":"topic_unavailable"}
			var standing := float(context.get("goblin_standing", 0.0))
			if standing >= 30.0:
				text = "Peace with the goblin tribe, brokered by your hand — I still find it strange to say aloud. Strange, and better than another decade of border war. Don't think it makes you popular with everyone at this court, though."
			elif standing <= -30.0:
				text = "Whatever's left of that tribe won't trouble the border again, thanks to you. My generals sleep easier. I'm less sure I do — that kind of ending always seems to breed another one somewhere else."
			else:
				text = "Orc raiders past Aldervale, bigger warbands than the old stories tell. If you've dealt with any of it personally, the crown hasn't heard the particulars yet. I'd like to."
		"ironbond":
			if not context.has("ironbond_influence"):
				return {"ok":false,"reason":"topic_unavailable"}
			var influence := float(context.get("ironbond_influence", 0.0))
			if influence >= 60.0:
				text = "The Company's coin runs through half my treasury's ledgers these days. Convenient, until the day it isn't. I'd sleep better if the crown owed them less."
			elif influence <= 10.0:
				text = "Ironbond's grip on this kingdom has loosened lately — your doing, more than once, if the reports are honest. Good. A crown that answers to merchants isn't much of a crown."
			else:
				text = "The Ironbond Company minds its manners at court and does as it pleases everywhere else. A tolerable arrangement, for now."
		"necromancy":
			if bool(context.get("phylactery_returned", false)):
				text = "You brought that horror to my Chancellor's desk yourself, and I've had priests sworn to secrecy about it ever since. Whatever that thing was building toward, you closed the door on it. I don't forget that kind of favor."
			elif bool(context.get("has_phylactery_shard", false)):
				text = "You carry something you shouldn't, if half of what my Chancellor whispers to me is true. I won't ask what you mean to do with it — but know that I'll hear of it, whatever it is."
			elif float(context.get("necromancer_standing", 0.0)) > 0.0:
				text = "There's talk of a cult working old, ugly magic somewhere near Reddale. Talk only, so far — but talk that keeps reaching my court from too many separate mouths to be nothing."
			else:
				text = "Nothing on my desk about necromancers, thank the gods. Should that change, I trust you'll be one of the first to hear of it — and one of the first I'd ask to do something about it."
		_:
			return {"ok":false,"reason":"unknown_topic"}
	var choice := {
		"persistent_conversation_key":"seraphine:topic:" + topic,
		"persistent_conversation_delta":{"familiarity":1}
	}
	var relationship_result := apply_dialogue_choice(relationships, "seraphine_corrin", choice)
	return {"ok":true,"speaker":"Queen Seraphine Corrin","text":text,"response_label":"I'll keep you informed." if topic == "greenskins" else ("Understood." if topic == "ironbond" else "I'll watch for it."),"relationship":relationship_result.get("relationship", relationships.snapshot("seraphine_corrin"))}


func seraphine_manor_request_response() -> Dictionary:
	return {
		"ok":true,
		"speaker":"Queen Seraphine Corrin",
		"text":"Few enough have earned the right to ask. Go on.",
		"choices":[
			{"id":"seraphine_manor_accept","label":"That empty manor near the inner city — could it be mine?","effect":"grant_silverhart_manor"},
			{"id":"seraphine_leave","label":"Never mind, Your Majesty.","kind":"leave"}
		]
	}


func seraphine_manor_granted_response() -> Dictionary:
	return {
		"ok":true,
		"speaker":"Queen Seraphine Corrin",
		"text":"Done. It's stood empty long enough, and you've more than earned an address inside these walls. See that it doesn't sit derelict a day longer than it has to.",
		"response_label":"I won't waste it.",
		"effect":"grant_silverhart_manor"
	}


func seraphine_wizard_evidence_response() -> Dictionary:
	return {
		"ok":true,
		"speaker":"Queen Seraphine Corrin",
		"text":"Show me.",
		"choices":[
			{"id":"seraphine_hand_over_wizard_evidence","label":"Hand it over.","effect":"resolve_wizard_vendetta_queen"},
			{"id":"seraphine_keep_wizard_evidence","label":"On second thought, no.","kind":"leave"}
		]
	}


func seraphine_chancellor_tunnel_response() -> Dictionary:
	return {
		"ok":true,
		"speaker":"Queen Seraphine Corrin",
		"text":"A tunnel — into MY council chamber? Guards! Seal it, brick by brick if you must, and find out who dug it. You've done the crown a real service, coming to me with this instead of using it yourself.",
		"response_label":"Just doing my part, Your Majesty.",
		"effects":[
			{"type":"set_world_flag","flag":"chancellor_tunnel_reported_to_queen","value":true},
			{"type":"adjust_faction_standing","faction_id":"silverhart_kingdom","delta":15},
			{"type":"adjust_faction_standing","faction_id":"thieves_guild","delta":-20}
		]
	}



## Resolve a Queen's choice using authoritative campaign state. Inventory,
## faction, quest and world-flag facts are gathered here rather than by the
## location scene adapter.
func resolve_seraphine_campaign_choice_from_state(
	simulation: WorldSimulation,
	choice_id: String,
	relationships: PersistentCharacterRelationshipState,
	active_character_id: String
) -> Dictionary:
	if simulation == null or simulation.campaign_journal == null:
		return {"handled":false,"ok":false,"reason":"missing_campaign"}
	var journal := simulation.campaign_journal
	var wizard_quest := journal.quest_state("wizard_vendetta")
	var player := simulation.get_character(simulation.player_character_id)
	var context := {
		"silverhart_standing": journal.faction_standing("silverhart_kingdom"),
		"goblin_standing": journal.faction_standing("goblin_tribe"),
		"ironbond_influence": journal.merchant_influence_for("ironbond_company", "silverhart_kingdom"),
		"necromancer_standing": journal.faction_standing("necromancer_cult"),
		"phylactery_returned": bool(simulation.get_meta("phylactery_returned", false)),
		"manor_granted": simulation.campaign_dwellings != null and bool(simulation.campaign_dwellings.owned.get("silverhart_manor", false)),
		"has_phylactery_shard": _character_has_item(player, "phylactery_shard"),
		"wizard_vendetta_active": String(wizard_quest.get("status", "")) == "active",
		"has_wizard_corruption_evidence": _character_has_item(player, "wizard_corruption_evidence"),
		"chancellor_tunnel_discovered": bool(simulation.get_meta("chancellor_tunnel_discovered", false)),
		"chancellor_tunnel_reported": bool(simulation.get_meta("chancellor_tunnel_reported_to_queen", false))
	}
	return resolve_seraphine_campaign_choice(simulation, choice_id, context, relationships, active_character_id)


static func _character_has_item(character: CharacterState, item_id: String) -> bool:
	if character == null:
		return false
	for item in character.inventory:
		if String(item.get("id", "")) == item_id:
			return true
	return false


## Resolve the Queen's campaign choices at the simulation boundary. The caller
## supplies inventory facts that belong to the active world/character adapter;
## all authored outcomes and persistent campaign consequences stay here.
func resolve_seraphine_campaign_choice(
	simulation: WorldSimulation,
	choice_id: String,
	context: Dictionary,
	relationships: PersistentCharacterRelationshipState,
	active_character_id: String
) -> Dictionary:
	if not choice_id.begins_with("seraphine_"):
		return {"handled":false}
	if choice_id == "seraphine_leave":
		return {"handled":true,"close":true}

	var response: Dictionary = {}
	var refresh_dwelling_world := false
	match choice_id:
		"seraphine_topic_greenskins":
			response = seraphine_topic_response("greenskins", context, relationships)
		"seraphine_topic_ironbond":
			response = seraphine_topic_response("ironbond", context, relationships)
		"seraphine_topic_necromancy":
			response = seraphine_topic_response("necromancy", context, relationships)
		"seraphine_personal_burden":
			response = seraphine_personal_response(relationships)
		"seraphine_request_favour":
			response = seraphine_manor_request_response()
		"seraphine_manor_accept":
			var grant := simulation.claim_dwelling("claim_silverhart_manor", "materials", "silverhart_palace", active_character_id)
			if not bool(grant.get("ok", false)):
				var reason := String(grant.get("reason", "requirements_not_met")).replace("_", " ")
				return {
					"handled":true,
					"ok":false,
					"dialogue":{
						"speaker":"Queen Seraphine Corrin",
						"text":"I cannot grant the townhouse just now: %s." % reason,
						"choices":[{"id":"continue","label":"Understood","kind":"leave"}]
					}
				}
			simulation.set_meta("silverhart_manor_granted", true)
			refresh_dwelling_world = true
			response = seraphine_manor_granted_response()
		"seraphine_manor_followup":
			response = {
				"ok":true,
				"speaker":"Queen Seraphine Corrin",
				"text":"The grant remains yours. The townhouse is still in need of fortification; timber and stone will see it restored.",
				"response_label":"I will see to it."
			}
		"seraphine_wizard_evidence":
			response = seraphine_wizard_evidence_response()
		"seraphine_report_chancellor_tunnel":
			response = seraphine_chancellor_tunnel_response()
			if bool(response.get("ok", false)):
				simulation.set_meta("chancellor_tunnel_reported_to_queen", true)
				simulation.campaign_journal.adjust_faction_standing("silverhart_kingdom", 15, "reported_chancellor_tunnel_to_queen")
				simulation.campaign_journal.adjust_faction_standing("thieves_guild", -20, "reported_chancellor_tunnel_to_queen")
		_:
			return {"handled":false}

	if not bool(response.get("ok", false)):
		return {
			"handled":true,
			"ok":false,
			"dialogue":{
				"speaker":"Queen Seraphine Corrin",
				"text":"That matter cannot be discussed just now.",
				"choices":[{"id":"continue","label":"Understood","kind":"leave"}]
			}
		}
	return {
		"handled":true,
		"ok":true,
		"dialogue":response,
		"refresh_dwelling_world":refresh_dwelling_world
	}


func _has_label(options: Array[Dictionary], target: String) -> bool:
	for option in options:
		if String(option.get("label", "")) == target:
			return true
	return false
