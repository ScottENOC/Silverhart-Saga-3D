extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_test_roster_and_encounter_gates()
	_test_overnight_guest_and_progression()
	_test_decline_and_save_load()
	if _failures > 0:
		push_error("%d Rowan Fletcher encounter assertion(s) failed." % _failures)
		quit(1)
		return
	print("Rowan Fletcher encounter tests passed.")
	quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _context(visit_key: String) -> Dictionary:
	return {"camp_active": true, "rowan_nearby": true, "visit_key": visit_key}


func _test_roster_and_encounter_gates() -> void:
	var relationships := PersistentCharacterRelationshipState.new()
	var profile := PersistentCharacterRelationshipState.profile_for("rowan_fletcher")
	_check(String(profile.get("name", "")) == "Rowan Fletcher", "Rowan should be registered as a persistent NPC.")
	_check(String(profile.get("gender", "")) == "male", "Rowan should be authored as male.")
	_check(String(profile.get("affinity_mode", "")) == "full", "Rowan should support independent attraction and romantic-bond meters.")
	_check(relationships.roster().size() == 11, "The persistent NPC roster should include Rowan.")
	_check(RowanFletcherEncounterContent.relationship_phase(relationships.snapshot("rowan_fletcher")) == "new_acquaintance", "Rowan should begin as a new acquaintance.")
	var absent := RowanFletcherEncounterContent.build_encounter(relationships, {"camp_active": false, "rowan_nearby": true, "visit_key": "day1:camp1"})
	_check(bool(absent.get("ok", false)) and not bool(absent.get("available", true)), "Rowan should not appear without an active camp.")
	var first := RowanFletcherEncounterContent.build_encounter(relationships, _context("day1:camp1"))
	_check(bool(first.get("available", false)), "Rowan should offer to share camp when nearby.")
	_check(String(first.get("stage", "")) == "first_meeting", "The first visit should use first-meeting dialogue.")


func _test_overnight_guest_and_progression() -> void:
	var relationships := PersistentCharacterRelationshipState.new()
	var first := RowanFletcherEncounterContent.build_encounter(relationships, _context("day1:camp1"))
	var accepted := RowanFletcherEncounterContent.resolve_choice(relationships, "day1:camp1", "welcome")
	_check(bool(accepted.get("ok", false)) and bool(accepted.get("accepted_overnight_stay", false)), "Welcoming Rowan should accept his one-night stay.")
	var guest: Dictionary = accepted.get("camp_occupant", {})
	_check(String(guest.get("occupant_id", "")) == "rowan_fletcher" and String(guest.get("kind", "")) == "guest", "Rowan should be represented as a temporary camp guest.")
	_check(not bool(guest.get("participates_in_party", true)) and not bool(guest.get("can_work", true)), "Rowan must not become a party member or camp worker.")
	_check(bool(guest.get("leaves_at_dawn", false)), "Rowan should leave at dawn rather than become a permanent camp resident.")
	_check(int(accepted.relationship.get("friendship", 0)) == 2, "A warm welcome should begin building friendship.")
	var repeated := RowanFletcherEncounterContent.build_encounter(relationships, _context("day1:camp1"))
	_check(not bool(repeated.get("available", true)) and String(repeated.get("reason", "")) == "visit_already_resolved", "The same camp visit should not repeat after resolution.")

	var second := RowanFletcherEncounterContent.build_encounter(relationships, _context("day4:camp2"))
	_check(bool(second.get("available", false)) and String(second.get("stage", "")) == "first_meeting", "A later meeting should be a new encounter while familiarity is still low.")
	var conversation := RowanFletcherEncounterContent.resolve_choice(relationships, "day4:camp2", "ask_about_travels")
	_check(int(conversation.relationship.get("familiarity", 0)) == 4, "A later conversation should increase familiarity.")
	_check(bool(conversation.get("accepted_overnight_stay", false)), "Continuing the conversation should still permit Rowan to stay for the night.")
	_check(RowanFletcherEncounterContent.relationship_phase(conversation.relationship) == "new_acquaintance", "The relationship phase should remain distinct from a committed romance.")

	var progressed := relationships.adjust_relationship("rowan_fletcher", {"familiarity": 12, "friendship": 20, "trust": 25, "attraction": 20, "romantic_bond": 35}, "test accumulated long-distance relationship")
	_check(RowanFletcherEncounterContent.relationship_phase(progressed) == "long_distance_romance", "The relationship phase should recognise a gradual long-distance romance only after its separate axes mature.")


func _test_decline_and_save_load() -> void:
	var relationships := PersistentCharacterRelationshipState.new()
	var before := relationships.snapshot("rowan_fletcher")
	var declined := RowanFletcherEncounterContent.resolve_choice(relationships, "day1:camp1", "decline")
	_check(bool(declined.get("ok", false)) and not bool(declined.get("accepted_overnight_stay", true)), "The player should be able to decline Rowan's invitation.")
	_check(not declined.has("camp_occupant"), "Declining should not register Rowan at camp.")
	_check(declined.relationship == before, "A polite refusal should not automatically damage the relationship.")
	var restored := PersistentCharacterRelationshipState.new()
	restored.from_dict(relationships.to_dict())
	_check(true, "Relationship state restore should complete.")
	_check(restored.snapshot("rowan_fletcher") == relationships.snapshot("rowan_fletcher"), "Rowan's relationship meters should survive save/load.")
	_check(restored.has_recorded_event("rowan_fletcher", "rowan:camp-visit:day1:camp1"), "Resolved visits should remain recorded after save/load.")
