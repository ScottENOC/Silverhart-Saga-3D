extends SceneTree

const COMPANION_CAMPAIGN_SCRIPT = preload("res://scripts/simulation/companion_campaign_content.gd")

var _failures: int = 0


func _initialize() -> void:
	_test_opening_dialogue_and_gift()
	_test_favour_negotiation_and_options()
	_test_alliance_follow_up_dialogue()
	_test_threat_resolution_paths()
	_test_resolution_with_registered_companion_quest()
	_test_favour_consequences()
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
	_check(str(opening.get("text", "")) == GoblinThreatCampaignContent.OPENING_GREETING)
	var options: Array = opening.get("choices", [])
	_check(options.size() == 4)
	_check(str(options[0].get("id", "")) == "skarnub_offer_favour")
	_check(not relationships.has_recorded_event("chief_skarnub", GoblinThreatCampaignContent.GIFT_EVENT_KEY))

	var short := content.give_chief_gift(relationships, 59)
	_check(not bool(short.get("ok", true)))
	_check(str(short.get("reason", "")) == "insufficient_gold")
	_check(int(short.get("gold_remaining", -1)) == 59)
	_check(not relationships.has_recorded_event("chief_skarnub", GoblinThreatCampaignContent.GIFT_EVENT_KEY))

	var gift := content.give_chief_gift(relationships, 100)
	_check(bool(gift.get("ok", false)))
	_check(int(gift.get("gold_spent", -1)) == 60)
	_check(int(gift.get("gold_remaining", -1)) == 40)
	_check(int(gift.relationship.get("trust", -1)) == 20)
	_check(int(gift.relationship.get("familiarity", -1)) == 2)
	_check(str(gift.get("text", "")) == GoblinThreatCampaignContent.GIFT_RESPONSE)

	var repeated := content.give_chief_gift(relationships, 100)
	_check(not bool(repeated.get("ok", true)))
	_check(str(repeated.get("reason", "")) == "gift_already_given")
	_check(int(relationships.snapshot("chief_skarnub").get("trust", -1)) == 20, "The gift cannot be paid twice to farm trust")

	var after_gift := content.chief_greeting(relationships, {"goblin_standing":0})
	_check(str(after_gift.choices[0].get("id", "")) == "skarnub_offer_alliance", "The 60-gold gift unlocks the alliance offer")
	var read := content.read_chief(relationships)
	_check(bool(read.get("ok", false)))
	_check(str(read.get("text", "")).contains("suspicion has eased"))


func _test_favour_negotiation_and_options() -> void:
	var journal := CampaignJournal.new()
	var content := GoblinThreatCampaignContent.new()
	var started := content.begin_favour_negotiation(journal)
	_check(bool(started.get("ok", false)))
	_check(str(journal.quest_state("goblin_threat").get("status", "")) == "active")
	var repeated := content.begin_favour_negotiation(journal)
	_check(bool(repeated.get("ok", false)), "Returning to the chief does not duplicate the active quest")
	var low := content.favour_options(0.0)
	_check(low.size() == 4, "Low goblin standing does not expose the Hollowmere raid favour")
	var high := content.favour_options(25.0)
	_check(high.size() == 5, "Standing 25 unlocks the Hollowmere raid favour")
	_check(str(high[3].get("favour", "")) == "raid")


func _test_alliance_follow_up_dialogue() -> void:
	var relationships := PersistentCharacterRelationshipState.new()
	var content := GoblinThreatCampaignContent.new()
	var resolved := content.chief_greeting(relationships, {"quest_resolution":"goblin_diplomacy"})
	_check(str(resolved.get("text", "")) == "We have nothing left to discuss.")
	var alliance := content.chief_greeting(relationships, {"quest_resolution":"goblin_alliance","goblin_scout_note_read":true,"mine_raid_completed":true})
	_check(str(alliance.choices[0].get("id", "")) == "skarnub_start_spy")
	var active_spy := content.chief_greeting(relationships, {"quest_resolution":"goblin_alliance","greenskin_spy_started":true})
	_check(str(active_spy.get("text", "")).contains("Northwatch still stands"))
	var completed_mine := content.chief_greeting(relationships, {"quest_resolution":"goblin_alliance","mine_raid_completed":true})
	_check(str(completed_mine.get("text", "")).contains("We're settled here"))
	var available_mine := content.chief_greeting(relationships, {"quest_resolution":"goblin_alliance"})
	_check(str(available_mine.choices[0].get("id", "")) == "skarnub_start_mine_raid")


func _test_threat_resolution_paths() -> void:
	var content := GoblinThreatCampaignContent.new()
	var diplomacy_journal := CampaignJournal.new()
	diplomacy_journal.adjust_faction_standing("goblin_tribe", 45.0, "test diplomacy threshold")
	var diplomacy := content.resolve_threat(diplomacy_journal, "goblin_diplomacy")
	_check(bool(diplomacy.get("ok", false)), "High-standing diplomacy resolves the threat")
	_check(bool(diplomacy.get("applied", false)))
	_check(str(diplomacy_journal.quest_state("goblin_threat").get("status", "")) == "completed")
	_check(str(diplomacy_journal.quest_state("goblin_threat").get("decisions", {}).get("resolution", "")) == "goblin_diplomacy")
	_check(int(diplomacy.get("effects", {}).get("experience", 0)) == 150)
	var repeated := content.resolve_threat(diplomacy_journal, "assault")
	_check(bool(repeated.get("ok", false)))
	_check(not bool(repeated.get("applied", true)), "A resolved threat cannot be resolved a second time")
	_check(str(repeated.get("resolution", "")) == "goblin_diplomacy")

	var blocked_diplomacy := content.resolve_threat(CampaignJournal.new(), "goblin_diplomacy")
	_check(not bool(blocked_diplomacy.get("ok", true)))
	_check(str(blocked_diplomacy.get("reason", "")) == "insufficient_goblin_standing")

	var alliance_journal := CampaignJournal.new()
	var relationships := PersistentCharacterRelationshipState.new()
	var blocked_alliance := content.resolve_threat(alliance_journal, "goblin_alliance", relationships)
	_check(not bool(blocked_alliance.get("ok", true)))
	_check(str(blocked_alliance.get("reason", "")) == "chief_gift_required")
	content.give_chief_gift(relationships, 60)
	var alliance := content.resolve_threat(alliance_journal, "goblin_alliance", relationships)
	_check(bool(alliance.get("ok", false)), "A recorded gift unlocks the alliance resolution")
	_check(int(alliance.get("effects", {}).get("experience", 0)) == 100)
	_check(int(alliance.get("effects", {}).get("region_security", {}).get("hollowmere", 0)) == -10)

	for resolution in ["assault", "stealth_succession", "betrayal"]:
		var journal := CampaignJournal.new()
		var result := content.resolve_threat(journal, resolution)
		_check(bool(result.get("ok", false)), "Resolution path should apply: " + resolution)
		_check(str(journal.quest_state("goblin_threat").get("decisions", {}).get("resolution", "")) == resolution)
		_check(bool(result.get("effects", {}).get("rescue_aldric", false)) == (resolution != "betrayal"))


func _test_favour_consequences() -> void:
	var content := GoblinThreatCampaignContent.new()
	var scout_journal := CampaignJournal.new()
	var scout := content.resolve_favour(scout_journal, "scout")
	_check(bool(scout.get("ok", false)))
	_check(int(scout.get("effects", {}).get("experience", 0)) == 40)
	var repeated_scout := content.resolve_favour(scout_journal, "scout")
	_check(bool(repeated_scout.get("ok", false)))
	_check(not bool(repeated_scout.get("applied", true)), "A favour cannot be farmed by repeating the same choice")

	var steal := content.resolve_favour(CampaignJournal.new(), "steal")
	_check(bool(steal.get("ok", false)))
	_check(int(steal.get("effects", {}).get("region_prosperity", {}).get("hollowmere", 0)) == -5)

	var mine := content.resolve_favour(CampaignJournal.new(), "raid_mine")
	_check(bool(mine.get("ok", false)))
	_check(int(mine.get("effects", {}).get("player_gold", 0)) == 60)
	_check(bool(mine.get("effects", {}).get("emberlode_raided", false)))

	var low_standing_journal := CampaignJournal.new()
	var blocked_raid := content.resolve_favour(low_standing_journal, "raid")
	_check(not bool(blocked_raid.get("ok", true)))
	_check(str(blocked_raid.get("reason", "")) == "insufficient_goblin_standing")
	var raid_journal := CampaignJournal.new()
	raid_journal.seed_faction_reputation("goblin_tribe", 30.0)
	var raid := content.resolve_favour(raid_journal, "raid")
	_check(bool(raid.get("ok", false)))
	_check(str(raid_journal.quest_state("goblin_threat").get("decisions", {}).get("resolution", "")) == "betrayal")


func _test_resolution_with_registered_companion_quest() -> void:
	for resolution in ["goblin_diplomacy", "goblin_alliance", "assault", "stealth_succession", "betrayal"]:
		var journal := CampaignJournal.new()
		COMPANION_CAMPAIGN_SCRIPT.register_quest_definitions(journal)
		if resolution == "goblin_diplomacy":
			journal.seed_faction_reputation("goblin_tribe", 45.0)
		var relationships := PersistentCharacterRelationshipState.new()
		if resolution == "goblin_alliance":
			GoblinThreatCampaignContent.new().give_chief_gift(relationships, 60)
		var result := GoblinThreatCampaignContent.new().resolve_threat(journal, resolution, relationships)
		_check(bool(result.get("ok", false)), "Registered companion quest definition must resolve: " + resolution)
		var state := journal.quest_state("goblin_threat")
		_check(String(state.get("status", "")) == "completed", "Goblin threat must complete with the shared quest definition: " + resolution)
		_check(bool(state.get("objectives", {}).get("resolved", {}).get("completed", false)), "Shared goblin quest objective must complete: " + resolution)
