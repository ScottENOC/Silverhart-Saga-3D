extends SceneTree

const JOURNAL = preload("res://scripts/simulation/campaign_journal.gd")
const PLAYER = preload("res://scripts/simulation/character_state.gd")
const CONTENT = preload("res://scripts/simulation/reddale_espionage_content.gd")
const DIALOGUE = preload("res://scripts/simulation/reddale_espionage_dialogue_service.gd")

var failures := 0

func _initialize() -> void:
	_test_thresholds_and_mission_start()
	_test_double_cross_and_turn_in()
	_test_guard_detection_failure()
	if failures:
		push_error("%d Reddale espionage dialogue assertion(s) failed." % failures)
		quit(1)
		return
	print("Reddale espionage dialogue tests passed.")
	quit(0)

func _check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _journal(standing: float = 0.0, influence: float = 30.0) -> CampaignJournal:
	var journal := JOURNAL.new()
	journal.seed_faction_reputation("silverhart_kingdom", standing, 0.0)
	journal.seed_faction_reputation("ironbond_company", 10.0, 0.0)
	journal.seed_merchant_influence("ironbond_company", "silverhart_kingdom", influence)
	return journal

func _test_thresholds_and_mission_start() -> void:
	var journal := _journal(19.0, 39.0)
	_check(DIALOGUE.dialogue_for_npc(journal, "baron_corwin_aldervale").choices.size() == 1, "Baron must not offer below 20 Kingdom standing")
	_check(DIALOGUE.dialogue_for_npc(journal, "petra_voss").choices.size() == 1, "Guildmaster must not offer below 40 influence")
	journal = _journal(20.0, 30.0)
	var offer := DIALOGUE.dialogue_for_npc(journal, "baron_corwin_aldervale")
	_check(offer.choices.size() == 2, "Baron should offer at 20 standing")
	var player := PLAYER.new("player", "Player")
	var started := DIALOGUE.select_choice(journal, player, "baron_corwin_aldervale", "start_espionage")
	_check(bool(started.get("ok", false)), "Baron mission should start")
	_check(String(started.get("mission", {}).get("guard_id", "")) == "guild_watchman_corley", "Guildhouse mission should identify Corley as its guard")
	_check(String(started.get("mission", {}).get("evidence_id", "")) == "guild_ledgers", "Guildhouse mission should target the guild ledgers")

func _test_double_cross_and_turn_in() -> void:
	var journal := _journal(0.0, 40.0)
	var player := PLAYER.new("player", "Player")
	player.inventory.append("baron_tariff_evidence")
	_check(bool(DIALOGUE.select_choice(journal, player, "petra_voss", "start_espionage").get("ok", false)), "Guildmaster mission should start at 40 influence")
	var flipped := DIALOGUE.select_choice(journal, player, "baron_corwin_aldervale", "double_cross_accept")
	_check(bool(flipped.get("ok", false)), "Baron should be able to flip the Guildmaster's spy")
	var completed := DIALOGUE.select_choice(journal, player, "petra_voss", "return_evidence")
	_check(bool(completed.get("ok", false)), "Double-agent evidence delivery should complete")
	_check(player.gold == 60 and player.experience == 150, "Double agent should receive 60 gold and 150 experience")
	_check(not player.inventory.has("baron_tariff_evidence"), "Delivered evidence should be removed from inventory")
	_check(String(journal.quest_state(CONTENT.BARON_QUEST).get("status", "")) == "completed", "Quest completion should persist")

func _test_guard_detection_failure() -> void:
	var journal := _journal(20.0)
	_check(bool(CONTENT.start(journal, CONTENT.GUILD_QUEST).get("ok", false)), "Guildhouse mission should start")
	var failed := CONTENT.fail(journal, CONTENT.GUILD_QUEST)
	_check(bool(failed.get("ok", false)), "Guard detection should fail the mission")
	_check(String(journal.quest_state(CONTENT.GUILD_QUEST).get("status", "")) == "failed", "Detection failure should persist")
	_check(is_equal_approx(journal.faction_standing("ironbond_company"), -10.0), "Detection should cost 20 Ironbond standing")
