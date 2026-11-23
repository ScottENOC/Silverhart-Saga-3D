extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_test_nix_dialogue_and_succession()
	_test_nix_recruitment()
	_test_aldric_rescue_content()
	_test_grondle_trade_gate()
	_test_scout_note()
	if _failures > 0:
		push_error("%d goblin follow-up assertion(s) failed." % _failures)
		quit(1)
		return
	print("Skarn-tooth follow-up content tests passed.")
	quit(0)


func _check(condition: bool, message: String = "Assertion failed") -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _test_nix_dialogue_and_succession() -> void:
	var content := GoblinThreatFollowupContent.new()
	var opening := content.nix_greeting({})
	_check(str(opening.get("speaker", "")) == "Nix Sharpear")
	_check(str(opening.choices[0].get("id", "")) == "nix_ask_why")
	var explanation := content.nix_patron_response()
	_check(str(explanation.get("text", "")).contains("Somebody's paying close attention"))
	var identity := content.nix_patron_response("who")
	_check(str(identity.get("text", "")).contains("a lot more banners"))

	var assassination := content.nix_greeting({"chief_assassinated":true})
	_check(str(assassination.choices[0].get("id", "")) == "nix_resolve_succession")
	var journal := CampaignJournal.new()
	var succession := content.resolve_stealth_succession(journal)
	_check(bool(succession.get("ok", false)))
	_check(str(journal.quest_state("goblin_threat").get("decisions", {}).get("resolution", "")) == "stealth_succession")

	var alliance := content.nix_greeting({"quest_resolution":"goblin_alliance"})
	_check(str(alliance.choices[0].get("id", "")) == "nix_recruit")
	var recruited := content.nix_greeting({"quest_resolution":"goblin_alliance","nix_recruited":true})
	_check(str(recruited.choices[0].get("id", "")) == "nix_leave")
	var departed := content.nix_greeting({"quest_resolution":"goblin_diplomacy"})
	_check(str(departed.get("text", "")).contains("already gone"))


func _test_nix_recruitment() -> void:
	var content := GoblinThreatFollowupContent.new()
	var blocked := content.nix_recruitment({"quest_resolution":"goblin_diplomacy"})
	_check(not bool(blocked.get("ok", true)))
	_check(str(blocked.get("reason", "")) == "goblin_alliance_required")
	var result := content.nix_recruitment({"quest_resolution":"goblin_alliance"})
	_check(bool(result.get("ok", false)))
	var character: Dictionary = result.get("character", {})
	_check(str(character.get("race", "")) == "human", "Goblin companion uses the current short-human placeholder")
	_check(float(character.get("height_scale", 1.0)) < 1.0)
	_check(float(character.get("build_scale", 1.0)) < 1.0)
	_check(character.get("progression", {}).get("class_levels", []) == ["rogue"])
	_check(result.get("character", {}).get("starts_in_party", false))


func _test_aldric_rescue_content() -> void:
	var content := GoblinThreatFollowupContent.new()
	var captive := content.aldric_captive_greeting({})
	_check(str(captive.get("text", "")) == GoblinThreatFollowupContent.ALDRIC_CAPTIVE_LINE)
	_check(str(captive.choices[0].get("id", "")) == "aldric_free")
	var rescued := content.aldric_captive_greeting({"aldric_recruited":true})
	_check(bool(rescued.get("already_rescued", false)))
	var profile := content.aldric_recruitment_profile()
	_check(str(profile.get("id", "")) == "ser_aldric_thorne")
	_check(profile.get("progression", {}).get("class_levels", []) == ["fighter", "cleric"])
	_check(profile.get("progression", {}).get("skill_picks", []).has("learn_heal"))
	_check(profile.get("extra_inventory", []).has("wooden_shield"))


func _test_grondle_trade_gate() -> void:
	var content := GoblinThreatFollowupContent.new()
	var closed := content.grondle_greeting({"quest_resolution":"goblin_diplomacy"})
	_check(str(closed.get("text", "")) == "Nothing for you here, human.")
	var open := content.grondle_greeting({"quest_resolution":"goblin_alliance"})
	_check(str(open.get("speaker", "")) == "Grondle")
	_check(str(open.choices[0].get("kind", "")) == "open_shop")
	_check(open.choices[0].get("item_ids", []).has("potion_health"))


func _test_scout_note() -> void:
	var content := GoblinThreatFollowupContent.new()
	var first := content.read_scout_note({})
	_check(not bool(first.get("already_read", true)))
	_check(int(first.get("effects", {}).get("region_security", {}).get("hollowmere", 0)) == -3)
	_check(bool(first.get("effects", {}).get("set_world_flag", {}).get("goblin_scout_note_read", false)))
	var repeated := content.read_scout_note({"goblin_scout_note_read":true})
	_check(bool(repeated.get("already_read", false)))
	_check(repeated.get("effects", {}).is_empty())
