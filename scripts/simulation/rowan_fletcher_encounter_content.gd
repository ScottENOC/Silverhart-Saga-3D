class_name RowanFletcherEncounterContent
extends RefCounted
## Occasional, player-facing meetings with Rowan while travelling.
## Rowan remains an independent wandering NPC: accepting his invitation adds a
## one-night camp guest, never a companion or permanent camp occupant.

const CHARACTER_ID := "rowan_fletcher"
const EVENT_PREFIX := "rowan:camp-visit:"
const GUEST_PROFILE := {
	"occupant_id": CHARACTER_ID,
	"kind": "guest",
	"species": "humanoid",
	"participates_in_party": false,
	"can_sleep": true,
	"can_work": false,
	"staying_overnight": true,
	"needs": ["food", "water", "shelter", "sleep", "safety", "social"],
	"leaves_at_dawn": true
}


static func build_encounter(
	relationships: PersistentCharacterRelationshipState,
	context: Dictionary
) -> Dictionary:
	if relationships == null:
		return {"ok": false, "reason": "missing_relationship_state"}
	if not bool(context.get("camp_active", false)) or not bool(context.get("rowan_nearby", false)):
		return {"ok": true, "available": false, "reason": "no_camp_encounter"}
	var visit_key := String(context.get("visit_key", "")).strip_edges()
	if visit_key.is_empty():
		return {"ok": false, "reason": "missing_visit_key"}
	var event_key := EVENT_PREFIX + visit_key
	if relationships.has_recorded_event(CHARACTER_ID, event_key):
		return {"ok": true, "available": false, "reason": "visit_already_resolved"}
	var relationship := relationships.snapshot(CHARACTER_ID)
	if relationship.is_empty():
		return {"ok": false, "reason": "unknown_character"}
	var familiarity := int(relationship.get("familiarity", 0))
	var friendship := int(relationship.get("friendship", 0))
	var attraction := int(relationship.get("attraction", 0))
	var greeting := "Rowan steps out of the dark at the edge of the firelight, one hand raised in greeting. “Didn't expect to find you out here. Mind if I share your camp tonight? I'll be gone before first light.”"
	var stage := "first_meeting"
	if familiarity >= 2:
		stage = "recognition"
		greeting = "A familiar whistle comes from the dark. Rowan approaches with an easy smile. “Seems we keep finding the same roads. Have you room for one more by the fire tonight?”"
	if friendship >= 20:
		stage = "friendship"
		greeting = "Rowan's expression brightens when he sees you. “I was hoping our paths might cross again. If there's room, I'd be glad to share your fire tonight.”"
	if attraction >= 20 and friendship >= 20:
		stage = "mutual_interest"
		greeting = "Rowan lingers just beyond the firelight, smiling in a way that is meant for you alone. “I know I should keep moving. But if you'll have me, I'd rather spend tonight here.”"
	var choices: Array[Dictionary] = [
		{"id": "welcome", "label": "Of course. There's room by the fire.", "kind": "accept_overnight_stay"},
		{"id": "guarded_welcome", "label": "You can stay, but I'll be keeping watch.", "kind": "accept_overnight_stay"},
		{"id": "decline", "label": "Not tonight, Rowan. Safe travels.", "kind": "decline_overnight_stay"}
	]
	if familiarity >= 2:
		choices.insert(1, {"id": "ask_about_travels", "label": "Tell me where the road has taken you.", "kind": "conversation"})
	if friendship >= 12:
		choices.insert(1, {"id": "share_stories", "label": "Sit with me. I've missed our conversations.", "kind": "friendship"})
	if friendship >= 8:
		choices.insert(1, {"id": "warm_greeting", "label": "I'm always glad when our paths cross.", "kind": "romantic_interest"})
	return {
		"ok": true,
		"available": true,
		"character_id": CHARACTER_ID,
		"speaker": "Rowan Fletcher",
		"stage": stage,
		"visit_key": visit_key,
		"text": greeting,
		"choices": choices,
		"relationship": relationship
	}


static func resolve_choice(
	relationships: PersistentCharacterRelationshipState,
	visit_key: String,
	choice_id: String
) -> Dictionary:
	if relationships == null:
		return {"ok": false, "reason": "missing_relationship_state"}
	var clean_visit_key := visit_key.strip_edges()
	if clean_visit_key.is_empty():
		return {"ok": false, "reason": "missing_visit_key"}
	var delta: Dictionary = {}
	var accepted := false
	match choice_id:
		"welcome":
			delta = {"familiarity": 2, "trust": 2, "friendship": 2}
			accepted = true
		"guarded_welcome":
			delta = {"familiarity": 1, "trust": 1}
			accepted = true
		"ask_about_travels":
			delta = {"familiarity": 2, "trust": 1}
			accepted = true
		"share_stories":
			delta = {"familiarity": 2, "trust": 2, "friendship": 3}
			accepted = true
		"warm_greeting":
			delta = {"familiarity": 1, "trust": 2, "friendship": 2, "attraction": 3, "romantic_bond": 3}
			accepted = true
		"decline":
			delta = {}
		_:
			return {"ok": false, "reason": "unknown_choice"}
	var event_key := EVENT_PREFIX + clean_visit_key
	var updated := relationships.record_event(CHARACTER_ID, event_key, delta)
	if updated.is_empty():
		return {"ok": false, "reason": "unknown_character"}
	var result := {
		"ok": true,
		"accepted_overnight_stay": accepted,
		"relationship": updated,
		"leaves_at_dawn": accepted
	}
	if accepted:
		result["camp_occupant"] = GUEST_PROFILE.duplicate(true)
	return result


static func relationship_phase(relationship: Dictionary) -> String:
	var familiarity := int(relationship.get("familiarity", 0))
	var trust := int(relationship.get("trust", 0))
	var friendship := int(relationship.get("friendship", 0))
	var attraction := int(relationship.get("attraction", 0))
	var romantic_bond := int(relationship.get("romantic_bond", 0))
	if romantic_bond >= 20 and trust >= 25 and attraction >= 20:
		return "long_distance_romance"
	if attraction >= 20 and friendship >= 20:
		return "mutual_interest"
	if friendship >= 20:
		return "friendship"
	if familiarity >= 10:
		return "acquaintance"
	return "new_acquaintance"
