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


func _has_label(options: Array[Dictionary], target: String) -> bool:
	for option in options:
		if String(option.get("label", "")) == target:
			return true
	return false
