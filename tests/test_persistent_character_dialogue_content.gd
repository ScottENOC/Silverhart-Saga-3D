extends SceneTree

const ILSA_WATCH_CAPTAIN_CONTENT = preload("res://scripts/simulation/ilsa_watch_captain_content.gd")

var _failures: int = 0


func _initialize() -> void:
	_test_dialogue_tree_memory()
	_test_seraphine_personal_response_thresholds()
	_test_wizard_vendetta_consequences()
	_test_ilsa_watch_captain_reflections()
	_test_seraphine_campaign_dialogue()
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


func _test_seraphine_campaign_dialogue() -> void:
	var relationships := PersistentCharacterRelationshipState.new()
	var content := PersistentCharacterDialogueContent.new()
	var blocked := content.seraphine_greeting({"player_is_greenskin":true}, relationships)
	_check(not bool(blocked.get("ok", true)), "An unvouched greenskin cannot enter Seraphine's audience")
	_check(str(blocked.get("reason", "")) == "greenskin_not_vouched")
	_check(int(relationships.snapshot("seraphine_corrin").get("familiarity", -1)) == 5, "A refused audience must not build familiarity")

	var context := {
		"silverhart_standing":65,
		"goblin_standing":35,
		"ironbond_influence":70,
		"necromancer_standing":-5,
		"wizard_vendetta_active":true,
		"has_wizard_corruption_evidence":true,
		"chancellor_tunnel_discovered":true
	}
	var audience := content.seraphine_greeting(context, relationships)
	_check(bool(audience.get("ok", false)))
	_check(str(audience.get("text", "")).contains("crown remembers"))
	var choices: Array = audience.get("choices", [])
	_check(choices.size() == 7, "High standing exposes topics, manor, evidence and tunnel options")
	_check(str(relationships.snapshot("seraphine_corrin").get("familiarity", -1)) == "6")
	var personal_count := 0
	for choice in choices:
		if str(choice.get("id", "")) == "seraphine_personal_burden":
			personal_count += 1
	_check(personal_count == 0, "The personal question stays locked before the three topic conversations")

	var greenskins := content.seraphine_topic_response("greenskins", context, relationships)
	_check(bool(greenskins.get("ok", false)))
	_check(str(greenskins.get("text", "")).contains("Peace with the goblin tribe"))
	var repeated := content.seraphine_topic_response("greenskins", context, relationships)
	_check(repeated.get("relationship", {}) == greenskins.get("relationship", {}), "A topic cannot farm familiarity")
	content.seraphine_topic_response("ironbond", context, relationships)
	var necromancy_context := context.duplicate(true)
	necromancy_context["phylactery_returned"] = true
	var necromancy := content.seraphine_topic_response("necromancy", necromancy_context, relationships)
	_check(str(necromancy.get("text", "")).contains("closed the door on it"))
	var unlocked := content.seraphine_greeting(context, relationships)
	var unlocked_choices: Array = unlocked.get("choices", [])
	_check(str(unlocked_choices[-2].get("id", "")) == "seraphine_personal_burden" or unlocked_choices.any(func(choice: Dictionary) -> bool: return str(choice.get("id", "")) == "seraphine_personal_burden"), "Three distinct topic conversations unlock Seraphine's personal question")
	var personal := content.seraphine_personal_response(relationships)
	_check(bool(personal.get("ok", false)))

	var manor := content.seraphine_manor_request_response()
	_check(str(manor.choices[0].get("effect", "")) == "grant_silverhart_manor")
	var evidence := content.seraphine_wizard_evidence_response()
	_check(str(evidence.choices[0].get("effect", "")) == "resolve_wizard_vendetta_queen")
	var tunnel := content.seraphine_chancellor_tunnel_response()
	_check(tunnel.effects.size() == 3, "Tunnel disclosure carries its flag and both faction-standing consequences")

	var low_standing := content.seraphine_greeting({"silverhart_standing":-25}, PersistentCharacterRelationshipState.new())
	_check(str(low_standing.get("text", "")).contains("not from anything I'd call flattering"))
	var vouched := content.seraphine_greeting({"player_is_greenskin":true,"goblin_vouched_by_marta":true}, PersistentCharacterRelationshipState.new())
	_check(str(vouched.get("text", "")).contains("Elder Marta vouches"))


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


func _test_ilsa_watch_captain_reflections() -> void:
	var journal := CampaignJournal.new()
	var relationships := PersistentCharacterRelationshipState.new()
	var first := ILSA_WATCH_CAPTAIN_CONTENT.greeting(journal, relationships)
	_check(bool(first.get("ok", false)), "Ilsa's streamed dialogue should build without quest prerequisites")
	_check(String(first.get("text", "")).contains("Keep your nose clean in Reddale"))
	_check(int(first.relationship.get("familiarity", -1)) == 5, "Opening Ilsa's dialogue records one audience event")
	var repeated := ILSA_WATCH_CAPTAIN_CONTENT.greeting(journal, relationships)
	_check(int(repeated.relationship.get("familiarity", -1)) == 5, "Repeated greetings do not farm familiarity")
	_check(not _has_choice(first.choices, "ilsa_philosophy_law_and_truth"), "The Watch philosophy topic stays locked below familiarity eight")

	relationships.set_relationship("ilsa_rennick", {"familiarity": 8, "trust": 20, "friendship": 10})
	var familiar := ILSA_WATCH_CAPTAIN_CONTENT.greeting(journal, relationships)
	_check(_has_choice(familiar.choices, "ilsa_philosophy_law_and_truth"), "The law-and-truth reflection unlocks at familiarity eight")
	_check(not _has_choice(familiar.choices, "ilsa_philosophy_command_uncertainty"), "The command reflection remains locked below familiarity ten")
	var law := ILSA_WATCH_CAPTAIN_CONTENT.resolve_choice(journal, relationships, "ilsa_philosophy_law_and_truth")
	_check(bool(law.get("ok", false)))
	_check(String(law.get("text", "")).contains("Law is useful when it makes people more willing"))
	_check(int(law.relationship.get("trust", -1)) == 21)
	_check(int(law.relationship.get("friendship", -1)) == 14)
	var repeated_law := ILSA_WATCH_CAPTAIN_CONTENT.resolve_choice(journal, relationships, "ilsa_philosophy_law_and_truth")
	_check(repeated_law.relationship == law.relationship, "Repeating the same reflection does not duplicate its relationship reward")

	var familiar_again := ILSA_WATCH_CAPTAIN_CONTENT.greeting(journal, relationships)
	_check(_has_choice(familiar_again.choices, "ilsa_philosophy_command_uncertainty"), "The command reflection unlocks at familiarity ten")
	var command := ILSA_WATCH_CAPTAIN_CONTENT.resolve_choice(journal, relationships, "ilsa_philosophy_command_uncertainty")
	_check(bool(command.get("ok", false)))
	_check(String(command.get("text", "")).contains("Command is deciding with incomplete information"))
	var locked := ILSA_WATCH_CAPTAIN_CONTENT.resolve_choice(journal, PersistentCharacterRelationshipState.new(), "ilsa_philosophy_command_uncertainty")
	_check(not bool(locked.get("ok", true)), "A locked reflection cannot be forced through a stale choice")

	var eyes_journal := CampaignJournal.new()
	eyes_journal.register_quest_definition({"id": "eyes_on_border", "objectives": []})
	eyes_journal.start_quest("eyes_on_border")
	eyes_journal.complete_quest("eyes_on_border")
	var eyes_relationships := PersistentCharacterRelationshipState.new()
	var eyes_first := ILSA_WATCH_CAPTAIN_CONTENT.greeting(eyes_journal, eyes_relationships)
	_check(int(eyes_first.relationship.get("familiarity", -1)) == 7, "Completing Eyes on the Border records Ilsa's source-authored familiarity event")
	_check(int(eyes_first.relationship.get("trust", -1)) == 4, "Completing Eyes on the Border builds Ilsa's trust")
	_check(int(eyes_first.relationship.get("friendship", -1)) == 2, "Completing Eyes on the Border builds Ilsa's friendship")
	ILSA_WATCH_CAPTAIN_CONTENT.greeting(eyes_journal, eyes_relationships)
	_check(int(eyes_relationships.snapshot("ilsa_rennick").get("trust", -1)) == 4, "Eyes on the Border relationship consequence is idempotent")


func _has_choice(choices: Array, choice_id: String) -> bool:
	for choice_value in choices:
		if String(choice_value.get("id", "")) == choice_id:
			return true
	return false
