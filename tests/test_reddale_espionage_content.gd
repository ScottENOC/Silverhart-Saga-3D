extends SceneTree

const CONTENT = preload("res://scripts/simulation/reddale_espionage_content.gd")
const JOURNAL = preload("res://scripts/simulation/campaign_journal.gd")
const PLAYER = preload("res://scripts/simulation/character_state.gd")

var failures := 0

func _initialize() -> void:
	_test_gating_and_start()
	_test_detected_failure()
	_test_normal_success()
	_test_double_agent_success()
	if failures:
		push_error("%d Reddale espionage assertion(s) failed." % failures)
		quit(1)
		return
	print("Reddale espionage content tests passed.")
	quit(0)

func _check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _journal(kingdom_standing: float = 0.0, influence: float = 30.0) -> CampaignJournal:
	var journal := JOURNAL.new()
	journal.seed_faction_reputation("silverhart_kingdom", kingdom_standing, 0.0)
	journal.seed_faction_reputation("ironbond_company", 10.0, 0.0)
	journal.seed_merchant_influence("ironbond_company", "silverhart_kingdom", influence)
	return journal

func _test_gating_and_start() -> void:
	var journal := _journal(19.0, 39.0)
	_check(not CONTENT.can_offer(journal, CONTENT.GUILD_QUEST), "Baron's espionage offer must require 20 Kingdom standing")
	_check(not CONTENT.can_offer(journal, CONTENT.BARON_QUEST), "Guildmaster's offer must require 40 Ironbond influence")
	journal = _journal(20.0, 40.0)
	_check(CONTENT.can_offer(journal, CONTENT.GUILD_QUEST), "Baron's offer should unlock at 20 Kingdom standing")
	_check(CONTENT.can_offer(journal, CONTENT.BARON_QUEST), "Guildmaster's offer should unlock at 40 influence")
	_check(bool(CONTENT.start(journal, CONTENT.GUILD_QUEST).get("ok", false)), "Guildhouse quest should start")
	_check(not CONTENT.can_offer(journal, CONTENT.BARON_QUEST), "Only one side of the mirrored espionage chain may be active")

func _test_detected_failure() -> void:
	var journal := _journal(20.0)
	CONTENT.start(journal, CONTENT.GUILD_QUEST)
	var result := CONTENT.fail(journal, CONTENT.GUILD_QUEST)
	_check(bool(result.get("ok", false)), "Detection should fail the quest")
	_check(String(journal.quest_state(CONTENT.GUILD_QUEST).get("status", "")) == "failed", "Failed quest status should persist")
	_check(is_equal_approx(journal.faction_standing("ironbond_company"), -10.0), "Detection should reduce target faction standing by 20")

func _test_normal_success() -> void:
	var journal := _journal(20.0, 30.0)
	CONTENT.start(journal, CONTENT.GUILD_QUEST)
	var player := PLAYER.new("player", "Player")
	var result := CONTENT.complete(journal, CONTENT.GUILD_QUEST, player)
	_check(bool(result.get("ok", false)), "Returning the ledgers should complete the quest")
	_check(player.gold == 40 and player.experience == 150, "Normal delivery should award 40 gold and 150 experience")
	_check(is_equal_approx(journal.faction_standing("silverhart_kingdom"), 35.0), "Normal guildhouse spying should improve Kingdom standing by 15")
	_check(is_equal_approx(journal.faction_standing("ironbond_company"), -10.0), "Normal guildhouse spying should reduce Ironbond standing by 20")
	_check(is_equal_approx(journal.merchant_influence_for("ironbond_company", "silverhart_kingdom"), 20.0), "Normal guildhouse spying should reduce Ironbond influence by 10")

func _test_double_agent_success() -> void:
	var journal := _journal(0.0, 40.0)
	CONTENT.start(journal, CONTENT.BARON_QUEST)
	var flip := CONTENT.record_double_agent(journal, CONTENT.BARON_QUEST, "silverhart_kingdom", true)
	_check(bool(flip.get("ok", false)), "The Baron should be able to flip an active Guildmaster spy")
	var player := PLAYER.new("player", "Player")
	var result := CONTENT.complete(journal, CONTENT.BARON_QUEST, player)
	_check(bool(result.get("ok", false)) and bool(result.get("double_agent", false)), "Double-agent delivery should resolve")
	_check(player.gold == 60, "Double-agent delivery should pay the 60-gold total")
	_check(is_equal_approx(journal.faction_standing("silverhart_kingdom"), 10.0), "The flipped spy should gain the source-authored 10 standing from accepting the offer")
