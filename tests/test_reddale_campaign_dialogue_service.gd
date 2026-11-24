extends SceneTree

const JOURNAL_SCRIPT = preload("res://scripts/simulation/campaign_journal.gd")
const PLAYER_SCRIPT = preload("res://scripts/simulation/character_state.gd")
const DIALOGUE_SERVICE = preload("res://scripts/simulation/reddale_campaign_dialogue_service.gd")

var _failures := 0


func _initialize() -> void:
	_test_offer_and_start_dialogue()
	_test_broker_reward_is_applied_once()
	_test_resistance_dialogue_and_no_reward()
	if _failures > 0:
		quit(1)
		return
	print("Reddale campaign dialogue service tests passed.")
	quit(0)


func _test_offer_and_start_dialogue() -> void:
	var journal := _new_journal(39.0)
	var unavailable := DIALOGUE_SERVICE.dialogue_for_reeve(journal)
	_check(unavailable.get("choices", []).size() == 1, "The Reeve must not offer the quest below the influence threshold")
	journal = _new_journal(40.0)
	var offer := DIALOGUE_SERVICE.dialogue_for_reeve(journal)
	_check(offer.get("choices", []).size() == 2, "The Reeve should offer the quest at the influence threshold")
	var started := DIALOGUE_SERVICE.select_choice(journal, null, "reddale_cut_start")
	_check(bool(started.get("ok", false)), "Selecting the offer should start Reddale's Cut")
	_check(started.get("choices", []).size() == 2, "The started dialogue should expose both source-authored outcomes")
	_check(String(journal.quest_state("reddale_cut").get("status", "")) == "active", "The quest should be active while the player chooses")


func _test_broker_reward_is_applied_once() -> void:
	var journal := _new_journal(40.0)
	_check(bool(DIALOGUE_SERVICE.select_choice(journal, null, "reddale_cut_start").get("ok", false)), "The quest should start")
	var player := PLAYER_SCRIPT.new("player", "Player")
	player.gold = 12
	var result := DIALOGUE_SERVICE.select_choice(journal, player, "broker_ironbond_deal")
	_check(bool(result.get("ok", false)), "The broker outcome should resolve")
	_check(player.gold == 62, "The 50 gold reward must be applied to player gold")
	_check(int(result.get("gold_delta", 0)) == 50, "The dialogue result should report the applied reward")
	var repeated := DIALOGUE_SERVICE.select_choice(journal, player, "broker_ironbond_deal")
	_check(not bool(repeated.get("ok", false)), "The same dialogue choice must not resolve twice")
	_check(player.gold == 62, "Retrying a completed choice must not award gold twice")


func _test_resistance_dialogue_and_no_reward() -> void:
	var journal := _new_journal(40.0)
	_check(bool(DIALOGUE_SERVICE.select_choice(journal, null, "reddale_cut_start").get("ok", false)), "The quest should start")
	var player := PLAYER_SCRIPT.new("player", "Player")
	player.gold = 7
	var result := DIALOGUE_SERVICE.select_choice(journal, player, "resist_ironbond")
	_check(bool(result.get("ok", false)), "The resistance outcome should resolve")
	_check(player.gold == 7, "Resistance must not award or remove gold")
	var aftermath := DIALOGUE_SERVICE.dialogue_for_reeve(journal)
	_check(String(aftermath.get("body", "")).contains("stood its ground"), "The Reeve's follow-up dialogue should reflect the recorded resistance outcome")


func _new_journal(influence: float) -> CampaignJournal:
	var journal := JOURNAL_SCRIPT.new()
	journal.seed_merchant_influence("ironbond_company", "silverhart_kingdom", influence)
	return journal


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
