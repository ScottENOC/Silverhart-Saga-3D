extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_test_dialogue_tree_memory()
	_test_seraphine_personal_response_thresholds()
	_test_wizard_vendetta_consequences()
	if _failures > 0:
		push_error("%d persistent NPC dialogue assertion(s) failed." % _failures)
		quit(1)
		return
	print("Persistent NPC dialogue content tests passed.")
	quit(0)


func _check(condition: bool, message: String = "Assertion failed") -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _test_dialogue_tree_memory() -> void:
	var relationships := PersistentCharacterRelationshipState.new()
	var content := PersistentCharacterDialogueContent.new()
	_check(PersistentCharacterDialogueContent.character_id_for_dialogue("silverhart_queen") == "seraphine_corrin")
	_check(PersistentCharacterDialogueContent.character_id_for_dialogue("missing_tree").is_empty())
	var first_audience := content.note_audience(relationships, "silverhart_queen")
	var repeated_audience := content.note_audience(relationships, "silverhart_queen")
	_check(bool(first_audience.get("ok", false)))
	_check(int(first_audience.relationship.get("familiarity", -1)) == 6)
	_check(repeated_audience.relationship == first_audience.relationship, "Opening the same dialogue tree twice does not farm familiarity")

	var options: Array[Dictionary] = [
		{"id":"greenskins","label":"What of the greenskins?"},
		{"id":"ironbond","label":"What of the Ironbond Company?"},
		{"id":"necromancy","label":"Rumors of necromancy in Reddale?"},
		{"id":"leave","label":"Goodbye."}
	]
	var decorated := content.decorate_seraphine_options(relationships, options)
	_check(decorated.size() == 4, "Personal question remains gated until familiarity reaches nine")
	var topic_result := content.apply_dialogue_choice(relationships, "seraphine_corrin", decorated[0])
	_check(bool(topic_result.get("changed", false)))
	_check(int(topic_result.relationship.get("familiarity", -1)) == 7)
	var repeated_topic := content.apply_dialogue_choice(relationships, "seraphine_corrin", decorated[0])
	_check(not bool(repeated_topic.get("changed", true)), "A topic choice can only award familiarity once")
	content.apply_dialogue_choice(relationships, "seraphine_corrin", decorated[1])
	content.apply_dialogue_choice(relationships, "seraphine_corrin", decorated[2])
	var unlocked := content.decorate_seraphine_options(relationships, options)
	_check(unlocked.size() == 5)
	_check(String(unlocked[4].get("id", "")) == "seraphine_personal_burden")


func _test_seraphine_personal_response_thresholds() -> void:
	var relationships := PersistentCharacterRelationshipState.new()
	var content := PersistentCharacterDialogueContent.new()
	var guarded := content.seraphine_personal_response(relationships)
	_check(String(guarded.get("line_key", "")) == "guarded", "Low trust selects Seraphine's guarded response")
	_check(String(guarded.get("text", "")).contains("lower her guard"))
	_check(int(guarded.relationship.get("trust", -1)) == 11)
	_check(int(guarded.relationship.get("friendship", -1)) == 4)
	var repeated := content.seraphine_personal_response(relationships)
	_check(repeated.relationship == guarded.relationship, "The personal-burden response is a one-time relationship event")

	var private := PersistentCharacterRelationshipState.new()
	private.set_relationship("seraphine_corrin", {"trust":20,"friendship":14})
	_check(String(content.seraphine_personal_response(private).get("line_key", "")) == "tired_private")
	var seen := PersistentCharacterRelationshipState.new()
	seen.set_relationship("seraphine_corrin", {"trust":20,"friendship":15})
	_check(String(content.seraphine_personal_response(seen).get("line_key", "")) == "tired_seen")
	var trusted := PersistentCharacterRelationshipState.new()
	trusted.set_relationship("seraphine_corrin", {"trust":20,"friendship":35})
	_check(String(content.seraphine_personal_response(trusted).get("line_key", "")) == "trusted")


func _test_wizard_vendetta_consequences() -> void:
	var relationships := PersistentCharacterRelationshipState.new()
	var content := PersistentCharacterDialogueContent.new()
	var not_complete := content.apply_wizard_vendetta_resolution(relationships, "queen", false)
	_check(not bool(not_complete.get("applied", true)))
	var queen := content.apply_wizard_vendetta_resolution(relationships, "queen", true)
	_check(bool(queen.get("applied", false)))
	var seraphine := relationships.snapshot("seraphine_corrin")
	var thessaly := relationships.snapshot("court_wizard_thessaly")
	_check(int(seraphine.get("familiarity", -1)) == 7)
	_check(int(seraphine.get("trust", -1)) == 17)
	_check(int(seraphine.get("friendship", -1)) == 2)
	_check(int(thessaly.get("familiarity", -1)) == 6)
	_check(int(thessaly.get("trust", -1)) == 0)
	_check(int(thessaly.get("friendship", -1)) == 0)
	content.apply_wizard_vendetta_resolution(relationships, "queen", true)
	_check(int(relationships.snapshot("seraphine_corrin").get("trust", -1)) == 17, "Quest completion hooks are idempotent")
	var wizard := content.apply_wizard_vendetta_resolution(relationships, "wizard", true)
	_check(bool(wizard.get("applied", false)))
	_check(int(relationships.snapshot("court_wizard_thessaly").get("trust", -1)) == 9)
	var noble := content.apply_wizard_vendetta_resolution(relationships, "noble", true)
	_check(bool(noble.get("applied", false)))
	_check(int(relationships.snapshot("court_wizard_thessaly").get("trust", -1)) == 0)
