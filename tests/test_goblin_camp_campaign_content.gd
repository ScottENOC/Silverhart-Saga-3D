extends SceneTree

const GOBLIN_CONTENT = preload("res://scripts/simulation/goblin_camp_campaign_content.gd")

var _failures := 0

func _initialize() -> void:
	_test_goblin_quest_definitions_and_gift_alliance()
	_test_diplomacy_assault_and_stealth_resolutions()
	_test_favors_and_follow_on_quests()
	if _failures > 0:
		push_error("%d goblin camp campaign assertion(s) failed." % _failures)
		quit(1)
		return
	print("Goblin camp campaign content tests passed.")
	quit(0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)

func _new_journal() -> CampaignJournal:
	var journal := CampaignJournal.new()
	GOBLIN_CONTENT.register_quest_definitions(journal)
	return journal

func _choice_exists(conversation: Dictionary, choice_id: String) -> bool:
	for choice_value in conversation.get("choices", []):
		if String(choice_value.get("id", "")) == choice_id:
			return true
	return false

func _test_goblin_quest_definitions_and_gift_alliance() -> void:
	var journal := _new_journal()
	_check(journal.quest_definitions.has("goblin_threat"), "Goblin threat quest must reuse the companion campaign definition")
	_check(journal.quest_definitions.has("aldric_rescue"), "Aldric rescue quest must be registered")
	_check(journal.quest_definitions.has("goblin_mine_raid"), "The allied mine raid follow-up must be registered")
	_check(journal.quest_definitions.has("greenskin_spy"), "The Northwatch spy follow-up must be registered")
	_check(journal.quest_definitions.has("goblin_scout_note"), "The foreign scout note must have persistent journal state")

	var initial := GOBLIN_CONTENT.chief_conversation(journal)
	_check(_choice_exists(initial, "start:goblin_threat"), "Chief should offer the source 'right price' route")
	_check(not _choice_exists(initial, "resolve:goblin_alliance"), "Alliance must not be available before the chief's gift")
	var gift := GOBLIN_CONTENT.gift_chief(journal, 100)
	_check(bool(gift.get("ok", false)) and int(gift.get("gold_remaining", -1)) == 40, "The source gift costs 60 gold")
	_check(not bool(GOBLIN_CONTENT.gift_chief(journal, 100).get("ok", false)), "The chief must not accept the same gift twice")
	var gifted_conversation := GOBLIN_CONTENT.chief_conversation(journal)
	_check(_choice_exists(gifted_conversation, "resolve:goblin_alliance"), "The gift unlocks the permanent alliance")
	var alliance := GOBLIN_CONTENT.resolve_threat(journal, "goblin_alliance")
	_check(bool(alliance.get("ok", false)), "The gift-enabled alliance resolution should complete")
	_check(String(journal.quest_state("goblin_threat").get("decisions", {}).get("resolution", "")) == "goblin_alliance", "The selected resolution must persist in the journal")
	_check(is_equal_approx(journal.faction_standing("silverhart_kingdom"), -20.0), "Alliance applies the source kingdom penalty")
	_check(is_equal_approx(journal.faction_standing("goblin_tribe"), 25.0), "Alliance applies the source goblin standing increase")
	_check(bool(alliance.get("effects", {}).get("aldric_rescued", false)), "Alliance outcome must request Aldric's rescue")

func _test_diplomacy_assault_and_stealth_resolutions() -> void:
	var diplomacy_journal := _new_journal()
	diplomacy_journal.adjust_faction_standing("goblin_tribe", 40, "test diplomacy threshold")
	_check(_choice_exists(GOBLIN_CONTENT.chief_conversation(diplomacy_journal), "resolve:goblin_diplomacy"), "Diplomacy unlocks at 40 goblin standing")
	var diplomacy := GOBLIN_CONTENT.resolve_threat(diplomacy_journal, "goblin_diplomacy")
	_check(bool(diplomacy.get("ok", false)), "Diplomacy resolution should complete")
	_check(is_equal_approx(diplomacy_journal.faction_standing("silverhart_kingdom"), -10.0), "Diplomacy applies the source kingdom adjustment")
	_check(int(diplomacy.get("effects", {}).get("region", {}).get("hollowmere", {}).get("security", 0)) == 8, "Diplomacy improves Hollowmere security")

	var assault_journal := _new_journal()
	var assault := GOBLIN_CONTENT.resolve_threat(assault_journal, "assault")
	_check(bool(assault.get("ok", false)), "Assault resolution should complete")
	_check(is_equal_approx(assault_journal.faction_standing("silverhart_kingdom"), 20.0), "Assault improves kingdom standing")
	_check(is_equal_approx(assault_journal.faction_standing("goblin_tribe"), -30.0), "Assault damages goblin standing")
	_check(int(assault.get("effects", {}).get("experience", 0)) == 300, "Assault preserves the source XP reward")

	var stealth_journal := _new_journal()
	var stealth := GOBLIN_CONTENT.resolve_threat(stealth_journal, "stealth_succession")
	_check(bool(stealth.get("ok", false)), "Nix succession should resolve the threat")
	_check(is_equal_approx(stealth_journal.faction_standing("silverhart_kingdom"), 15.0), "Stealth succession improves kingdom standing")
	_check(is_equal_approx(stealth_journal.faction_standing("goblin_tribe"), 5.0), "Stealth succession gives modest goblin goodwill")

	var betrayal_journal := _new_journal()
	var betrayal := GOBLIN_CONTENT.resolve_favor(betrayal_journal, "raid")
	_check(bool(betrayal.get("ok", false)), "Helping raid Hollowmere should complete the betrayal route")
	_check(String(betrayal_journal.quest_state("goblin_threat").get("decisions", {}).get("resolution", "")) == "betrayal", "Hollowmere raid is the irreversible betrayal resolution")
	_check(is_equal_approx(betrayal_journal.faction_standing("silverhart_kingdom"), -60.0), "Betrayal applies the full kingdom penalty exactly once")
	_check(is_equal_approx(betrayal_journal.faction_standing("goblin_tribe"), 30.0), "Betrayal applies the goblin reward exactly once")
	_check(not bool(betrayal.get("effects", {}).get("aldric_rescued", true)), "Betrayal leaves Aldric captive")

func _test_favors_and_follow_on_quests() -> void:
	var journal := _new_journal()
	GOBLIN_CONTENT.start_threat(journal)
	var favors := GOBLIN_CONTENT.offer_favors(journal)
	_check(_choice_exists(favors, "favor:scout"), "Scout favor should be offered")
	_check(_choice_exists(favors, "favor:steal"), "Farm supply favor should be offered")
	_check(_choice_exists(favors, "favor:raid_mine"), "Mine raid favor should be offered")
	_check(not _choice_exists(favors, "favor:raid"), "Direct Hollowmere raid is gated until 25 goblin standing")
	var scout := GOBLIN_CONTENT.resolve_favor(journal, "scout")
	_check(bool(scout.get("ok", false)), "Scout favor should resolve")
	_check(is_equal_approx(journal.faction_standing("goblin_tribe"), 10.0), "Scout favor applies source goblin reputation")
	_check(int(scout.get("effects", {}).get("experience", 0)) == 40, "Scout favor preserves its source XP reward")

	var mine_journal := _new_journal()
	GOBLIN_CONTENT.start_mine_raid(mine_journal)
	var mine := GOBLIN_CONTENT.complete_mine_raid(mine_journal)
	_check(bool(mine.get("ok", false)), "The allied mine raid can be completed")
	_check(String(mine_journal.quest_state("goblin_mine_raid").get("status", "")) == "completed", "Mine raid completion is persisted")
	_check(int(mine.get("effects", {}).get("gold", 0)) == 60, "Mine raid preserves the 60 gold plunder")

	var spy_journal := _new_journal()
	GOBLIN_CONTENT.resolve_threat(spy_journal, "goblin_alliance")
	GOBLIN_CONTENT.mark_scout_note_read(spy_journal)
	GOBLIN_CONTENT.mark_mine_raid_complete(spy_journal)
	var follow_up := GOBLIN_CONTENT.chief_conversation(spy_journal)
	_check(_choice_exists(follow_up, "start:greenskin_spy"), "The read scout note and completed mine favor unlock the Northwatch follow-up")
	GOBLIN_CONTENT.start_northwatch_spy(spy_journal)
	_check(bool(GOBLIN_CONTENT.mark_northwatch_taken(spy_journal).get("ok", false)), "Northwatch outcome can be persisted in the journal")
