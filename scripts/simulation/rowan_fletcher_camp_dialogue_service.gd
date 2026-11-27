class_name RowanFletcherCampDialogueService
extends RefCounted
## Ambient exchanges between Rowan and companions while he is an overnight
## guest. Rowan leaves at dawn, so these conversations are deliberately evening
## content and are keyed to his individual camp visit.

const RELATIONSHIP_STORE := preload("res://scripts/simulation/persistent_character_relationship_store.gd")
const ROWAN_ID := "rowan_fletcher"

const PAIR_DIALOGUE := {
	"ser_aldric_thorne": [
		{"speaker_id":"ser_aldric_thorne","text":"You take the edge of the firelight even when you're off watch. Old habit?"},
		{"speaker_id":"rowan_fletcher","text":"A hunter learns to see the dark without standing in it. A soldier learns much the same, I imagine."}
	],
	"reyna_fletcher": [
		{"speaker_id":"rowan_fletcher","text":"You read a trail quickly. Most folk look for prints; you notice where the birds have gone quiet."},
		{"speaker_id":"reyna_fletcher","text":"And you noticed that? Perhaps you aren't as difficult to keep up with as you look."}
	],
	"fenn_oakheart": [
		{"speaker_id":"fenn_oakheart","text":"You cut across the slope instead of following the stream. The deer have been doing the same."},
		{"speaker_id":"rowan_fletcher","text":"The stream is an easy guide for people. That's why the wary things leave it to us."}
	],
	"mirabel_quill": [
		{"speaker_id":"mirabel_quill","text":"Would you mind describing the tracks you found beyond the ridge? I should like to compare them with my field notes."},
		{"speaker_id":"rowan_fletcher","text":"I'll try. But if you draw them, leave out the mud. It never looks as impressive on a page."}
	],
	"nix_sharpear": [
		{"speaker_id":"nix_sharpear","text":"You set your bow where you can reach it without looking. Expecting trouble?"},
		{"speaker_id":"rowan_fletcher","text":"No. Expecting to wake in the dark and not remember where I put it. There's a difference."}
	],
	"snik_fangtooth": [
		{"speaker_id":"snik_fangtooth","text":"Hunter says he can find anything. Can he find the rabbit I hid?"},
		{"speaker_id":"rowan_fletcher","text":"If it was a rabbit, perhaps. If it was your supper, I'd start by looking under your bedroll."}
	],
	"brother_alden": [
		{"speaker_id":"brother_alden","text":"Does the hunt ever trouble you? Taking a life to preserve another is no small thing."},
		{"speaker_id":"rowan_fletcher","text":"It should trouble a person a little. If it ever becomes easy, that's when I'd worry."}
	],
	"dagna": [
		{"speaker_id":"dagna","text":"The stew has a good flavour tonight. Did you bring the herbs?"},
		{"speaker_id":"rowan_fletcher","text":"A handful from the lower path. I can show you where they grow, if you promise not to tell the whole forest."}
	],
	"wren_talbot": [
		{"speaker_id":"wren_talbot","text":"You travel alone so often. Don't you ever grow tired of having only your own thoughts for company?"},
		{"speaker_id":"rowan_fletcher","text":"Sometimes. A quiet road is a good place to think, but a warm fire is a better place to stop."}
	]
}

const WARM_PAIR_DIALOGUE := {
	"ser_aldric_thorne": [
		{"speaker_id":"rowan_fletcher","text":"I watched you make room for everyone before you settled yourself. You don't have to carry the whole camp, you know."},
		{"speaker_id":"ser_aldric_thorne","text":"An observation I might return to you. You seem more at ease when someone else takes the first watch."}
	],
	"reyna_fletcher": [
		{"speaker_id":"reyna_fletcher","text":"You could have passed through without stopping. I'm glad you didn't."},
		{"speaker_id":"rowan_fletcher","text":"So am I. The road can wait until morning when there's good company by the fire."}
	],
	"fenn_oakheart": [
		{"speaker_id":"fenn_oakheart","text":"You know these woods well enough to travel them alone. Yet you keep finding your way back here."},
		{"speaker_id":"rowan_fletcher","text":"Perhaps the woods aren't the only place worth knowing."}
	],
	"mirabel_quill": [
		{"speaker_id":"mirabel_quill","text":"I kept the notes from your last visit. Your descriptions were more useful than you thought."},
		{"speaker_id":"rowan_fletcher","text":"Then next time I'll try to make them worth keeping. I rather like having a reason to come back."}
	],
	"nix_sharpear": [
		{"speaker_id":"nix_sharpear","text":"I didn't hear you arrive tonight. That's almost a compliment."},
		{"speaker_id":"rowan_fletcher","text":"I'll treasure it. Though I suspect you were simply distracted by your own cleverness."}
	],
	"snik_fangtooth": [
		{"speaker_id":"snik_fangtooth","text":"You came back! I knew you would. You still owe me a story with a monster in it."},
		{"speaker_id":"rowan_fletcher","text":"I remember. I'll make sure this one has a monster large enough to improve your version of it."}
	],
	"brother_alden": [
		{"speaker_id":"brother_alden","text":"You seem less inclined to leave as soon as the fire dies down."},
		{"speaker_id":"rowan_fletcher","text":"I've learned that some company is worth letting the embers settle for."}
	],
	"dagna": [
		{"speaker_id":"dagna","text":"I saved you a place near the fire. I thought you might come by again."},
		{"speaker_id":"rowan_fletcher","text":"You remembered. That makes this feel less like a chance meeting."}
	],
	"wren_talbot": [
		{"speaker_id":"wren_talbot","text":"You always say you'll be gone by first light. I wonder if you ever wish the road would let you stay."},
		{"speaker_id":"rowan_fletcher","text":"Sometimes I do. But I like knowing there's a fire I can find again."}
	]
}


static func build_exchange(
	partner_id: String,
	partner_name: String,
	relationships: PersistentCharacterRelationshipState,
	visit_key: String
) -> Dictionary:
	if relationships == null or partner_id.is_empty() or visit_key.strip_edges().is_empty():
		return {}
	var canonical_partner := CampCompanionDialogueService.canonical_id(partner_id)
	var lines_data: Array = PAIR_DIALOGUE.get(canonical_partner, [])
	if lines_data.size() != 2:
		return {}
	var relationship := relationships.snapshot(ROWAN_ID)
	if relationship.is_empty():
		return {}
	var event_key := event_key_for(visit_key, canonical_partner)
	if relationships.has_recorded_event(ROWAN_ID, event_key):
		return {}
	if int(relationship.get("friendship", 0)) >= 20:
		lines_data = WARM_PAIR_DIALOGUE.get(canonical_partner, lines_data)
	var lines: Array[Dictionary] = []
	for line_value in lines_data:
		var line: Dictionary = line_value
		var speaker_id := ROWAN_ID if String(line.get("speaker_id", "")) == ROWAN_ID else partner_id
		var speaker_name := "Rowan Fletcher" if speaker_id == ROWAN_ID else partner_name
		lines.append({
			"character_id": speaker_id,
			"speaker": speaker_name,
			"text": String(line.get("text", ""))
		})
	return {
		"kind": "rowan_guest_banter",
		"topic": "evening_guest",
		"first_id": String(lines[0].get("character_id", "")),
		"second_id": String(lines[1].get("character_id", "")),
		"partner_id": partner_id,
		"visit_key": visit_key,
		"event_key": event_key,
		"relationship_phase": RowanFletcherEncounterContent.relationship_phase(relationship),
		"lines": lines
	}


static func event_key_for(visit_key: String, partner_id: String) -> String:
	return "rowan:camp-banter:%s:%s" % [visit_key.strip_edges(), CampCompanionDialogueService.canonical_id(partner_id)]


static func record_exchange(
	relationships: PersistentCharacterRelationshipState,
	exchange: Dictionary
) -> Dictionary:
	if relationships == null or String(exchange.get("kind", "")) != "rowan_guest_banter":
		return {}
	var event_key := String(exchange.get("event_key", ""))
	if event_key.is_empty():
		return {}
	return relationships.record_event(ROWAN_ID, event_key, {"familiarity": 1})
