extends SceneTree

const ELDER_CONTENT = preload("res://scripts/simulation/elder_marta_content.gd")
const LOCKET_PICKUP_CONTENT = preload("res://scripts/simulation/elder_locket_pickup_content.gd")

var _failures: int = 0


func _initialize() -> void:
	_test_accepted_locket_quest()
	_test_found_before_accepting()
	_test_chapel_pickup_is_idempotent_and_persistent()
	if _failures > 0:
		push_error("%d Elder Marta assertion(s) failed." % _failures)
		quit(1)
		return
	print("Elder Marta locket content tests passed.")
	quit(0)


func _check(condition: bool, message: String = "Assertion failed") -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _new_locket(instance_id: String) -> Dictionary:
	return ItemCatalog.create_instance("elder_locket", instance_id)


func _test_accepted_locket_quest() -> void:
	var journal := CampaignJournal.new()
	var player := CharacterState.new("player", "Adventurer", Vector2i.ZERO)
	player.gold = 3
	player.experience = 10

	_check(String(ELDER_CONTENT.definition().get("id", "")) == "elder_locket")
	_check(bool(ELDER_CONTENT.register_definition(journal).get("ok", false)))
	var opening := ELDER_CONTENT.greeting(journal, player)
	_check(String(opening.speaker) == "Elder Marta Wynfield")
	_check(String(opening.choices[0].id) == "marta_offer_help")

	var offer := ELDER_CONTENT.resolve_choice(journal, player, "marta_offer_help")
	_check(bool(offer.get("ok", false)))
	_check(String(offer.dialogue.text).contains("old chapel"))
	_check(String(offer.dialogue.choices[0].id) == "marta_accept_locket")

	var accepted := ELDER_CONTENT.resolve_choice(journal, player, "marta_accept_locket")
	_check(bool(accepted.get("ok", false)))
	_check(String(journal.quest_state(ELDER_CONTENT.QUEST_ID).get("status", "")) == "active")
	var waiting := ELDER_CONTENT.greeting(journal, player)
	_check(String(waiting.text).contains("keeping an eye out"))

	var missing := ELDER_CONTENT.turn_in(journal, player)
	_check(String(missing.get("reason", "")) == "locket_missing")
	_check(player.gold == 3)
	_check(player.experience == 10)

	_check(player.add_inventory_item(_new_locket("marta_locket_active")))
	var ready := ELDER_CONTENT.greeting(journal, player)
	_check(String(ready.choices[0].id) == "marta_turn_in_locket")
	var completed := ELDER_CONTENT.resolve_choice(journal, player, "marta_turn_in_locket")
	_check(bool(completed.get("ok", false)))
	_check(String(journal.quest_state(ELDER_CONTENT.QUEST_ID).get("status", "")) == "completed")
	_check(player.inventory.is_empty(), "Turn-in consumes the locket")
	_check(player.gold == 23)
	_check(player.experience == 110)
	_check(journal.npc_standing(ELDER_CONTENT.NPC_ID) == 15.0)
	_check(journal.npc_knowledge.get(ELDER_CONTENT.NPC_ID, 0.0) == 20.0)

	var repeated := ELDER_CONTENT.turn_in(journal, player)
	_check(String(repeated.get("reason", "")) == "quest_already_completed")
	_check(player.gold == 23)
	_check(player.experience == 110)


func _test_chapel_pickup_is_idempotent_and_persistent() -> void:
	var player := CharacterState.new("player", "Adventurer", Vector2i.ZERO)
	var collected := LOCKET_PICKUP_CONTENT.collect(player)
	_check(bool(collected.get("ok", false)))
	_check(not bool(collected.get("already_owned", true)))
	_check(player.inventory.size() == 1)
	_check(String(player.inventory[0].get("id", "")) == "elder_locket")
	_check(String(player.inventory[0].get("instance_id", "")) == LOCKET_PICKUP_CONTENT.INSTANCE_ID)

	var repeated := LOCKET_PICKUP_CONTENT.collect(player)
	_check(bool(repeated.get("ok", false)))
	_check(bool(repeated.get("already_owned", false)))
	_check(player.inventory.size() == 1, "Revisiting the pickup must not duplicate the locket.")

	var runtime_source := FileAccess.get_file_as_string("res://scripts/world/hollow_tankard.gd")
	_check(runtime_source.contains("Vector2i(-14, 0)"), "The chapel pickup must use the source-authored hex.")
	_check(runtime_source.contains('"elder_locket_collected": elder_locket_collected'), "The pickup state must be saved.")
	_check(runtime_source.contains('elder_locket_collected = bool(flags.get("elder_locket_collected", false))'), "The pickup state must be restored.")
	_check(runtime_source.contains("not _interact_with_chapel_locket()"), "The F-key interaction must collect the pickup.")


func _test_found_before_accepting() -> void:
	var journal := CampaignJournal.new()
	var player := CharacterState.new("player", "Adventurer", Vector2i.ZERO)
	_check(player.add_inventory_item(_new_locket("marta_locket_pre_found")))

	var offer := ELDER_CONTENT.resolve_choice(journal, player, "marta_offer_help")
	_check(bool(offer.get("ok", false)))
	_check(String(offer.dialogue.text).contains("You already have it"))
	_check(String(offer.dialogue.choices[0].id) == "marta_turn_in_locket")

	var completed := ELDER_CONTENT.resolve_choice(journal, player, "marta_turn_in_locket")
	_check(bool(completed.get("ok", false)))
	_check(bool(completed.get("quest_completed", false)))
	_check(String(journal.quest_state(ELDER_CONTENT.QUEST_ID).get("status", "")) == "completed")
	_check(player.inventory.is_empty())
	_check(player.gold == ELDER_CONTENT.REWARD_GOLD)
	_check(player.experience == ELDER_CONTENT.REWARD_EXPERIENCE)
