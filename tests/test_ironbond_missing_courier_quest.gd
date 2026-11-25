extends SceneTree

const QUEST = preload("res://scripts/simulation/ironbond_missing_courier_quest.gd")


func _initialize() -> void:
	_test_source_authored_offer()
	_test_acceptance_is_one_time()
	_test_declining_does_not_create_a_quest()
	print("Ironbond missing courier quest tests passed.")
	quit(0)


func _test_source_authored_offer() -> void:
	var journal := CampaignJournal.new()
	var registered := QUEST.register(journal)
	assert(bool(registered.get("ok", false)), "The missing courier quest definition must register")
	assert(bool(QUEST.register(journal).get("ok", false)), "Registering the same source quest must be idempotent")
	var definition: Dictionary = journal.quest_definitions[QUEST.QUEST_ID]
	assert(String(definition.get("title", "")) == "The Missing Courier")
	assert(String(definition.get("faction_id", "")) == "ironbond_company")
	assert(definition.get("objectives", []).size() == 1)

	var opening := QUEST.opening_dialogue()
	assert(String(opening.get("speaker", "")) == "Dray Coltayne")
	assert(String(opening.get("text", "")).contains("Company can use people like that"))
	assert(opening.get("choices", []).size() == 2)

	var asked := QUEST.handle_dialogue_choice(journal, QUEST.CHOICE_PREFIX + "ask")
	assert(bool(asked.get("ok", false)))
	var mission: Dictionary = asked.get("dialogue", {})
	assert(String(mission.get("text", "")).contains("satchel of signed contracts"))
	assert(journal.quest_state(QUEST.QUEST_ID).is_empty(), "Asking what Dray needs must not accept the quest")


func _test_acceptance_is_one_time() -> void:
	var journal := CampaignJournal.new()
	QUEST.register(journal)
	var before := journal.faction_standing("ironbond_company")
	var accepted := QUEST.handle_dialogue_choice(journal, QUEST.CHOICE_PREFIX + "accept")
	assert(bool(accepted.get("ok", false)))
	assert(bool(accepted.get("accepted", false)))
	assert(bool(accepted.get("dismiss_after_continue", false)))
	assert(String(journal.quest_state(QUEST.QUEST_ID).get("status", "")) == "active")
	assert(String(journal.quest_state(QUEST.QUEST_ID).get("decisions", {}).get("offer_response", "")) == "accepted")
	assert(is_equal_approx(journal.faction_standing("ironbond_company"), before + 10.0), "Accepting the job must grant the source-authored Ironbond standing")
	var repeated := QUEST.handle_dialogue_choice(journal, QUEST.CHOICE_PREFIX + "accept")
	assert(not bool(repeated.get("ok", true)), "The same offer must not create or reward the quest twice")
	assert(is_equal_approx(journal.faction_standing("ironbond_company"), before + 10.0), "Repeated acceptance must not farm faction standing")


func _test_declining_does_not_create_a_quest() -> void:
	var journal := CampaignJournal.new()
	QUEST.register(journal)
	var declined := QUEST.handle_dialogue_choice(journal, QUEST.CHOICE_PREFIX + "decline")
	assert(bool(declined.get("ok", false)))
	assert(bool(declined.get("dismiss_after_continue", false)))
	assert(String(declined.get("dialogue", {}).get("text", "")) == "Suit yourself.")
	assert(journal.quest_state(QUEST.QUEST_ID).is_empty(), "Declining must leave the quest unstarted")
	var walked_away := QUEST.handle_dialogue_choice(journal, QUEST.CHOICE_PREFIX + "walk_away")
	assert(bool(walked_away.get("dismiss_now", false)), "Walking away must dismiss the waiting soldiers")
