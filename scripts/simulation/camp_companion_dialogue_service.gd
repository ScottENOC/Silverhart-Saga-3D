class_name CampCompanionDialogueService
extends RefCounted
## Authored ambient conversations between party companions.
## Dialogue is deliberately separate from player-facing dialogue trees: these
## are autonomous exchanges that companions initiate with one another at camp.

const TOPICS: Array[String] = ["road", "work", "home", "danger"]


const CAMPAIGN_RESOLUTION_STANCES := {
	"fenn_living_boundary": {
		"preserve_marsh": "managed_stewardship",
		"drain_marsh": "pragmatism",
		"compensate_preserve": "managed_stewardship",
		"managed_spillway": "managed_stewardship"
	},
	"aldric_weight_of_command": {
		"shared_command": "shared_responsibility",
		"take_every_burden": "self_reliance",
		"refuse_command": "shared_responsibility"
	},
	"mirabel_borrowed_voice": {
		"limited_testimony": "restraint",
		"full_reconstruction": "bold_inquiry",
		"refuse_method": "restraint"
	},
	"mirabel_place_for_dangerous_books": {
		"accept_curatorship": "institutional_trust",
		"shared_archive": "shared_responsibility",
		"keep_wandering": "independence"
	},
	"fenn_fire_in_understory": {
		"mosaic_burn": "managed_stewardship",
		"obey_rule": "tradition",
		"hand_clear": "restraint"
	},
	"fenn_groves_answer": {
		"return_traditional": "tradition",
		"changed_charter": "adaptation",
		"remain_outside": "independence"
	},
	"reyna_shared_watch": {
		"joint_watch": "shared_responsibility",
		"reyna_centre": "self_reliance",
		"private_network": "independence"
	},
	"reyna_rangers_writ": {
		"take_writ": "institutional_trust",
		"distributed_charter": "shared_responsibility",
		"reject_writ": "independence"
	},
	"alden_missing_sixth": {
		"return_and_name": "personal_dignity",
		"pursue_network": "pragmatism",
		"close_record": "restraint"
	},
	"alden_rule_for_living": {
		"take_office": "institutional_trust",
		"rotating_ministry": "shared_responsibility",
		"return_contemplation": "independence"
	}
}

const CHARACTER_STANCES := {
	"ser_aldric_thorne": {"shared_responsibility": 2, "tradition": 1, "institutional_trust": 1, "self_reliance": -1, "restraint": 1},
	"nix_sharpear": {"independence": 2, "self_reliance": 1, "pragmatism": 2, "institutional_trust": -2, "shared_responsibility": -1, "managed_stewardship": -1},
	"warlord_grukk_ironhide": {"self_reliance": 2, "tradition": 2, "shared_responsibility": -2, "institutional_trust": -2, "restraint": -1},
	"reyna_fletcher": {"shared_responsibility": 2, "independence": 1, "institutional_trust": -1, "personal_dignity": 1, "restraint": 1},
	"mirabel_quill": {"restraint": 2, "bold_inquiry": 1, "adaptation": 2, "tradition": -1, "institutional_trust": 0},
	"fenn_oakheart": {"managed_stewardship": 2, "tradition": 1, "adaptation": 2, "self_reliance": -1, "restraint": 1},
	"brother_alden": {"personal_dignity": 2, "restraint": 2, "shared_responsibility": 1, "pragmatism": 1, "institutional_trust": 1},
	"snik_fangtooth": {"independence": 2, "pragmatism": 1, "self_reliance": 1, "institutional_trust": -2, "tradition": -1},
	"wren_talbot": {"shared_responsibility": 1, "personal_dignity": 2, "restraint": 1, "institutional_trust": 0}
}

const CAMPAIGN_MEMORY_OPENERS := {
	"ser_aldric_thorne": "I have been thinking about %s. %s.",
	"nix_sharpear": "You know what I heard about %s? %s.",
	"warlord_grukk_ironhide": "That business with %s was worth remembering. %s.",
	"reyna_fletcher": "Something about %s has stayed with me. %s.",
	"mirabel_quill": "I keep turning %s over in my mind. %s.",
	"fenn_oakheart": "The lesson I took from %s was this: %s.",
	"brother_alden": "There is something about %s I have not finished considering. %s.",
	"snik_fangtooth": "So, about %s. %s.",
	"wren_talbot": "I keep coming back to %s. %s."
}

const PROFILES := {
	"ser_aldric_thorne": {
		"openers": {
			"road": "When we set out again, I would rather take the ridge road. Better sightlines, fewer places for an ambush.",
			"work": "You have a steady hand. I noticed you kept the camp work moving while the rest of us settled in.",
			"home": "There are people I ought to have gone back to. I tell myself the duty here matters just as much.",
			"danger": "I have seen men mistake courage for the absence of fear. The sensible ones learn to act despite it."
		},
		"guarded_reply": "I do not know you well enough to answer that honestly. Ask me again after a few more miles.",
		"warm_reply": "It is easier to speak plainly when I know the person listening will not use it against me."
	},
	"nix_sharpear": {
		"openers": {
			"road": "If the road looks empty, that's when you should worry. Empty roads mean somebody cleared them for a reason.",
			"work": "You call that stacking wood? I've seen goblin warrens with better organisation. Still, it'll burn.",
			"home": "Don't ask where I'm from unless you want the long version. The short one isn't pretty.",
			"danger": "Big folk always say the plan was good until the arrows start. Funny how that works."
		},
		"guarded_reply": "Maybe. Maybe not. I don't hand out the useful bits to everyone who asks.",
		"warm_reply": "All right, you've earned a proper answer. Don't let it go to your head."
	},
	"warlord_grukk_ironhide": {
		"openers": {
			"road": "We take the hard road. Soft roads make soft fighters, and I have no wish to be soft.",
			"work": "That fire needs more wood. A cold camp makes for a miserable morning and a miserable fight.",
			"home": "A stronghold is stone, smoke and people who know your name. I have left mine behind for now.",
			"danger": "If something comes for us in the dark, let it come close. I am tired of chasing shadows."
		},
		"guarded_reply": "You have not earned the whole story. You have earned that much.",
		"warm_reply": "You have fought beside me. That counts for more than fine words."
	},
	"reyna_fletcher": {
		"openers": {
			"road": "The wind is turning. Tomorrow we should keep to the lower ground until we know what the weather is doing.",
			"work": "Leave the kindling loose at the bottom. A fire needs air as much as it needs fuel.",
			"home": "I used to know every track around Old Mac's farm. I wonder which ones are still there.",
			"danger": "The quiet before an attack is never truly quiet. Listen for what has stopped making noise."
		},
		"guarded_reply": "I keep some things to myself. It is how I have stayed alive this long.",
		"warm_reply": "I don't talk about home much. It feels good to say its name without having to explain everything."
	},
	"mirabel_quill": {
		"openers": {
			"road": "The old survey marks suggest the eastern track predates the current kingdom. I would like to see where it leads.",
			"work": "I can help with the map once the fire is settled. Smoke and damp are both terrible for parchment.",
			"home": "I have spent so long leaving places that I am no longer certain what returning would mean.",
			"danger": "Most ancient wards fail in predictable ways. People, unfortunately, are much less consistent."
		},
		"guarded_reply": "An interesting question. I am not yet convinced you want the honest answer.",
		"warm_reply": "I did not expect to find people whose company I would miss. It is an inconvenient discovery."
	},
	"fenn_oakheart": {
		"openers": {
			"road": "There is water somewhere beyond those trees. I can smell the damp earth, even over the smoke.",
			"work": "Leave a little space around the roots. The forest gives us fuel; we needn't punish it for being generous.",
			"home": "The grove is never silent. Even now, I can almost hear it if I stop trying to.",
			"danger": "Fear is a useful warning, not a master. Listen to it, then decide what needs doing."
		},
		"guarded_reply": "Some things are easier to understand after you have spent a season outdoors together.",
		"warm_reply": "I like that you ask rather than assume. It makes sharing the answer feel easy."
	},
	"brother_alden": {
		"openers": {
			"road": "A measured pace will serve us better than haste. We arrive together, or the journey has already divided us.",
			"work": "There is a quiet discipline in ordinary work. A well-kept fire can be its own small act of care.",
			"home": "The monastery taught me how to be still. It did not teach me how to stop wondering about the world beyond it.",
			"danger": "We cannot choose every trial. We can choose whether we meet it with cruelty or with resolve."
		},
		"guarded_reply": "I would rather not speak carelessly about something that matters. Perhaps another time.",
		"warm_reply": "Thank you for asking. I find that I have more to say when I am not expected to perform certainty."
	},
	"snik_fangtooth": {
		"openers": {
			"road": "I vote we don't use the road. Roads are where people put traps when they know we're coming.",
			"work": "You keep watch while I fetch water? Good. If anything bites me, I expect you to look suitably concerned.",
			"home": "Home is where nobody checks your pockets while you're asleep. I haven't found that place yet.",
			"danger": "If it has more teeth than me, we run. If it has fewer, we negotiate. Simple."
		},
		"guarded_reply": "That's one way to look at it. I have another, but I'm keeping it.",
		"warm_reply": "Fine. I trust you enough to say this once. Don't make me regret it."
	},
	"wren_talbot": {
		"openers": {
			"road": "We should keep moving before the weather turns. I would rather choose our stopping place than be forced into one.",
			"work": "I'll take the next task. Standing around while other people do everything makes me restless.",
			"home": "I miss ordinary things more than grand ones. A familiar voice. A door that opens without checking who is there.",
			"danger": "I don't need anyone pretending the risk is small. I need to know they'll be there when it matters."
		},
		"guarded_reply": "I appreciate the question. I am not ready to give you that answer yet.",
		"warm_reply": "I don't say this often, but I am glad you're here. That is the whole answer."
	}
}

static func canonical_id(character_id: String) -> String:
	var canonical := character_id.trim_prefix("companion_")
	# The campaign spawn ID is shorter than the canonical content key.
	if canonical == "warlord_grukk":
		return "warlord_grukk_ironhide"
	return canonical

static func supported_companion_ids() -> Array[String]:
	var result: Array[String] = []
	for id in PROFILES.keys():
		result.append(String(id))
	return result

static func build_exchange(
	first_id: String,
	second_id: String,
	sequence: int,
	bonds: CompanionBondState,
	first_name: String = "",
	second_name: String = ""
) -> Dictionary:
	if first_id.is_empty() or second_id.is_empty() or first_id == second_id:
		return {}
	var first_key := canonical_id(first_id)
	var second_key := canonical_id(second_id)
	if not PROFILES.has(first_key) or not PROFILES.has(second_key):
		return {}
	var topic := TOPICS[posmod(sequence, TOPICS.size())]
	var first_profile: Dictionary = PROFILES[first_key]
	var second_profile: Dictionary = PROFILES[second_key]
	var first_bond := bonds.snapshot(first_id, second_id) if bonds != null else {}
	var second_bond := bonds.snapshot(second_id, first_id) if bonds != null else {}
	var opener := String(first_profile.openers.get(topic, "We should talk about the road ahead."))
	var reply := String(second_profile.openers.get(topic, "I had been thinking the same thing."))
	if float(second_bond.get("familiarity", 0.0)) < 3.0:
		reply = String(second_profile.get("guarded_reply", reply))
	elif float(second_bond.get("friendship", 0.0)) >= 20.0 and float(second_bond.get("trust", 0.0)) >= 15.0:
		reply = String(second_profile.get("warm_reply", reply))
	return {
		"topic": topic,
		"first_id": first_id,
		"second_id": second_id,
		"lines": [
			{"character_id": first_id, "speaker": first_name, "text": opener},
			{"character_id": second_id, "speaker": second_name, "text": reply}
		],
		"relationship_before": {
			"first_to_second": first_bond,
			"second_to_first": second_bond
		}
	}

static func record_exchange(
	bonds: CompanionBondState,
	camp: CampSimulation,
	exchange: Dictionary,
	event_key: String
) -> Dictionary:
	if bonds == null or camp == null or exchange.is_empty() or event_key.is_empty():
		return {"ok": false, "reason": "invalid_exchange"}
	var first_id := String(exchange.get("first_id", ""))
	var second_id := String(exchange.get("second_id", ""))
	if first_id.is_empty() or second_id.is_empty() or first_id == second_id:
		return {"ok": false, "reason": "invalid_pair"}
	var first_changes := {"familiarity": 1.0, "trust": 0.5, "friendship": 0.5}
	var second_changes := {"familiarity": 1.0, "trust": 0.5, "friendship": 1.0}
	var social_gain := 2.0
	if String(exchange.get("kind", "")) == "campaign_memory":
		var agreement := String(exchange.get("campaign_memory", {}).get("agreement", "neutral"))
		social_gain = 1.0
		match agreement:
			"support":
				first_changes = {"familiarity": 0.5, "trust": 0.5, "friendship": 0.5}
				second_changes = {"familiarity": 0.5, "trust": 0.5, "friendship": 0.5}
			"disagree":
				# Honest disagreement can build trust without pretending the
				# companions suddenly agree or become close friends.
				first_changes = {"familiarity": 0.5, "trust": 0.25}
				second_changes = {"familiarity": 0.5, "trust": 0.5}
			_:
				first_changes = {"familiarity": 0.5}
				second_changes = {"familiarity": 0.5}
	var first_result := bonds.record_interaction(
		first_id, second_id, "camp_conversation", first_changes, event_key + ":first"
	)
	var second_result := bonds.record_interaction(
		second_id, first_id, "camp_conversation", second_changes, event_key + ":second"
	)
	var changed := bool(first_result.get("changed", false)) or bool(second_result.get("changed", false))
	if changed:
		camp.record_social_interaction(first_id, social_gain)
		camp.record_social_interaction(second_id, social_gain)
	return {
		"ok": true,
		"changed": changed,
		"first_to_second": first_result,
		"second_to_first": second_result
	}


## Build a conversation from an actual completed companion chapter. The quest
## journal remains the source of truth: no dialogue is generated for an outcome
## until its completion and selected resolution are recorded there.
static func build_campaign_memory_exchange(
	first_id: String,
	second_id: String,
	sequence: int,
	bonds: CompanionBondState,
	quest_chain: CompanionQuestChainState,
	journal: CampaignJournal,
	first_name: String = "",
	second_name: String = ""
) -> Dictionary:
	if first_id.is_empty() or second_id.is_empty() or first_id == second_id:
		return {}
	if quest_chain == null or journal == null:
		return {}
	var first_key := canonical_id(first_id)
	var second_key := canonical_id(second_id)
	var latest: Dictionary = {}
	var campaign_entries: Array[Dictionary] = quest_chain.all_chapters()
	for prerequisite_value in quest_chain.all_prerequisite_quests():
		campaign_entries.append(prerequisite_value)
	for chapter_value in campaign_entries:
		var chapter: Dictionary = chapter_value
		var owner_id := String(chapter.get("companion_id", ""))
		if owner_id != first_key and owner_id != second_key:
			continue
		var chapter_id := String(chapter.get("id", ""))
		var state := journal.quest_state(chapter_id)
		if String(state.get("status", "")) != "completed":
			continue
		var completed_at := float(state.get("completed_at", state.get("completedAt", 0.0)))
		if latest.is_empty() or completed_at > float(latest.get("completed_at", -1.0)):
			latest = {
				"chapter": chapter,
				"state": state,
				"completed_at": completed_at,
				"owner_id": owner_id,
				"chapter_id": chapter_id
			}
	if latest.is_empty():
		return {}
	var chapter: Dictionary = latest.chapter
	var state: Dictionary = latest.state
	var chapter_id := String(latest.chapter_id)
	var resolution_id := String(state.get("effective_resolution", state.get("resolution", "")))
	var resolutions: Dictionary = chapter.get("resolutions", {})
	var outcome: Dictionary = resolutions.get(resolution_id, {})
	if outcome.is_empty():
		return {}
	var owner_key := String(latest.owner_id)
	var owner_character_id := first_id if first_key == owner_key else second_id
	var partner_character_id := second_id if owner_character_id == first_id else first_id
	var owner_name := first_name if owner_character_id == first_id else second_name
	var partner_name := second_name if partner_character_id == second_id else first_name
	var partner_key := canonical_id(partner_character_id)
	var title := String(chapter.get("title", chapter_id))
	var reason := String(outcome.get("reason", state.get("completion_reason", title)))
	var opener_template := String(CAMPAIGN_MEMORY_OPENERS.get(owner_key, "I have been thinking about %s. %s."))
	var opener := opener_template % [title, reason]
	var stance := String(CAMPAIGN_RESOLUTION_STANCES.get(chapter_id, {}).get(resolution_id, ""))
	var stance_score := float(CHARACTER_STANCES.get(partner_key, {}).get(stance, 0.0)) if not stance.is_empty() else 0.0
	var owner_to_partner := bonds.snapshot(owner_character_id, partner_character_id) if bonds != null else {}
	var partner_to_owner := bonds.snapshot(partner_character_id, owner_character_id) if bonds != null else {}
	var trust := float(partner_to_owner.get("trust", 0.0))
	var friendship := float(partner_to_owner.get("friendship", 0.0))
	var reaction := ""
	var agreement := "neutral"
	if stance_score >= 1.0:
		agreement = "support"
		reaction = "I think I would have made much the same choice. %s" % ("It says something good about the way you handled it." if trust >= 10.0 else "I can see the sense in it.")
	elif stance_score <= -1.0:
		agreement = "disagree"
		if trust >= 10.0 or friendship >= 15.0:
			reaction = "I trust you enough to say I would have chosen differently. %s" % ("I hope you will hear me out, as I would hear you." if trust >= 20.0 else "That does not mean I have stopped standing beside you.")
		else:
			reaction = "I understand why you chose it. I am not sure I agree, and I am not going to pretend otherwise."
	else:
		reaction = "That sounds like it asked more of you than the decision itself. What do you make of it now?"
	var label := String(outcome.get("label", resolution_id))
	var response := "%s, I heard you chose: %s %s" % [owner_name if not owner_name.is_empty() else "You", label, reaction]
	return {
		"kind": "campaign_memory",
		"topic": "campaign_memory",
		"sequence": sequence,
		"first_id": owner_character_id,
		"second_id": partner_character_id,
		"campaign_memory": {
			"chapter_id": chapter_id,
			"completed_at": float(latest.completed_at),
			"resolution_id": resolution_id,
			"stance": stance,
			"agreement": agreement,
			"title": title,
			"reason": reason
		},
		"relationship_before": {
			"first_to_second": owner_to_partner,
			"second_to_first": partner_to_owner
		},
		"lines": [
			{"character_id": owner_character_id, "speaker": owner_name, "text": opener},
			{"character_id": partner_character_id, "speaker": partner_name, "text": response}
		]
	}


static func campaign_memory_event_key(exchange: Dictionary) -> String:
	var memory: Dictionary = exchange.get("campaign_memory", {})
	if memory.is_empty():
		return ""
	return "camp_memory:%s:%s:%s" % [
		String(memory.get("chapter_id", "")),
		String(memory.get("resolution_id", "")),
		str(int(float(memory.get("completed_at", 0.0))))
	]
