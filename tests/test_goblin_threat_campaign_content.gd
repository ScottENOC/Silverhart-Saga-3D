extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_test_opening_dialogue_and_gift()
	_test_favour_negotiation_and_options()
	_test_alliance_follow_up_dialogue()
	if _failures > 0:
		push_error("%d Skarn-tooth campaign assertion(s) failed." % _failures)
		quit(1)
		return
	print("Skarn-tooth campaign content tests passed.")
	quit(0)


func _check(condition: bool, message: String = "Assertion failed") -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _test_opening_dialogue_and_gift() -> void:
	var relationships := PersistentCharacterRelationshipState.new()
	var content := GoblinThreatCampaignContent.new()
	var opening := content.chief_greeting(relationships, {"goblin_standing":0})
	_check(bool(opening.get("ok", false)))
	_check(String(opening.get("text", "")) == GoblinThreatCampaignContent.OPENING_GREETING)
	var options: Array = opening.get("choices", [])
	_check(options.size() == 4)
	_check(String(options[0].get("id", "")) == "skarnub_offer_favour")
	_check(not relationships.has_recorded_event("chief_skarnub", GoblinThreatCampaignContent.GIFT_EVENT_KEY))

	var short := content.give_chief_gift(relationships, 59)
	_check(not bool(short.get("ok", true)))
	_check(String(short.get("reason", "")) == "insufficient_gold")
	_check(int(short.get("gold_remaining", -1)) == 59)
	_check(not relationships.has_recorded_event("chief_skarnub", GoblinThreatCampaignContent.GIFT_EVENT_KEY))

	var gift := content.give_chief_gift(relationships, 100)
	_check(bool(gift.get("ok", false)))
	_check(int(gift.get("gold_spent", -1)) == 60)
	_check(int(gift.get("gold_remaining", -1)) == 40)
	_check(int(gift.relationship.get("trust", -1)) == 20)
	_check(int(gift.relationship.get("familiarity", -1)) == 2)
	_check(String(gift.get("text", "")) == GoblinThreatCampaignContent.GIFT_RESPONSE)

	var repeated := content.give_chief_gift(relationships, 100)
	_check(not bool(repeated.get("ok", true)))
	_check(String(repeated.get("reason", "")) == "gift_already_given")
	_check(int(relationships.snapshot("chief_skarnub").get("trust", -1)) == 20, "The gift cannot be paid twice to farm trust")

	var after_gift := content.chief_greeting(relationships, {"goblin_standing":0})
	_check(String(after_gift.choices[0].get("id", "")) == "skarnub_offer_alliance", "The 60-gold gift unlocks the alliance offer")
	var read := content.read_chief(relationships)
	_check(bool(read.get("ok", false)))
	_check(String(read.get("text", "")).contains("suspicion has eased"))


func _test_favour_negotiation_and_options() -> void:
	var journal := CampaignJournal.new()
	var content := GoblinThreatCampaignContent.new()
	var started := content.begin_favour_negotiation(journal)
	_check(bool(started.get("ok", false)))
	_check(String(journal.quest_state("goblin_threat").get("status", "")) == "active")
	var repeated := content.begin_favour_negotiation(journal)
	_check(bool(repeated.get("ok", false)), "Returning to the chief does not duplicate the active quest")
	var low := content.favour_options(0.0)
	_check(low.size() == 4, "Low goblin standing does not expose the Hollowmere raid favour")
	var high := content.favour_options(25.0)
	_check(high.size() == 5, "Standing 25 unlocks the Hollowmere raid favour")
	_check(String(high[3].get("favour", "")) == "raid")


func _test_alliance_follow_up_dialogue() -> void:
	var relationships := PersistentCharacterRelationshipState.new()
	var content := GoblinThreatCampaignContent.new()
	var resolved := content.chief_greeting(relationships, {"quest_resolution":"goblin_diplomacy"})
	_check(String(resolved.get("text", "")) == "We have nothing left to discuss.")
	var alliance := content.chief_greeting(relationships, {"quest_resolution":"goblin_alliance","goblin_scout_note_read":true,"mine_raid_completed":true})
	_check(String(alliance.choices[0].get("id", "")) == "skarnub_start_spy")
	var active_spy := content.chief_greeting(relationships, {"quest_resolution":"goblin_alliance","greenskin_spy_started":true})
	_check(String(active_spy.get("text", "")).contains("Northwatch still stands"))
	var completed_mine := content.chief_greeting(relationships, {"quest_resolution":"goblin_alliance","mine_raid_completed":true})
	_check(String(completed_mine.get("text", "")).contains("We're settled here"))
	var available_mine := content.chief_greeting(relationships, {"quest_resolution":"goblin_alliance"})
	_check(String(available_mine.choices[0].get("id", "")) == "skarnub_start_mine_raid")
