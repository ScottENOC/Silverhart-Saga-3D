class_name CampCompanionDialogueService
extends RefCounted
## Authored ambient conversations between party companions.
## Dialogue is deliberately separate from player-facing dialogue trees: these
## are autonomous exchanges that companions initiate with one another at camp.

const TOPICS: Array[String] = ["road", "work", "home", "danger"]

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
	return character_id.trim_prefix("companion_").trim_prefix("companion_")

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
	var first_result := bonds.record_interaction(
		first_id, second_id, "camp_conversation",
		{"familiarity": 1.0, "trust": 0.5, "friendship": 0.5}, event_key + ":first"
	)
	var second_result := bonds.record_interaction(
		second_id, first_id, "camp_conversation",
		{"familiarity": 1.0, "trust": 0.5, "friendship": 1.0}, event_key + ":second"
	)
	var changed := bool(first_result.get("changed", false)) or bool(second_result.get("changed", false))
	if changed:
		camp.record_social_interaction(first_id, 2.0)
		camp.record_social_interaction(second_id, 2.0)
	return {
		"ok": true,
		"changed": changed,
		"first_to_second": first_result,
		"second_to_first": second_result
	}
