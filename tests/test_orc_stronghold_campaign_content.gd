extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_test_acceptance_and_completion()
	_test_recruitment_gate()
	if _failures > 0:
		push_error("%d Skarnak's Hold assertion(s) failed." % _failures)
		quit(1)
		return
	print("Skarnak's Hold campaign content tests passed.")
	quit(0)


func _check(condition: bool, message: String = "Assertion failed") -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _test_acceptance_and_completion() -> void:
	var journal := CampaignJournal.new()
	var accepted := OrcStrongholdCampaignContent.accept(journal)
	_check(bool(accepted.get("ok", false)), "Grukk can start Prove Your Strength")
	_check(String(journal.quest_state(OrcStrongholdCampaignContent.QUEST_ID).get("status", "")) == "active")
	var repeated := OrcStrongholdCampaignContent.accept(journal)
	_check(bool(repeated.get("ok", false)), "Returning to Grukk does not duplicate the quest")
	_check(not bool(repeated.get("applied", true)))

	var player := CharacterState.new("player", "Player")
	player.gold = 10
	var troll := CharacterState.new(OrcStrongholdCampaignContent.TROLL_ID, "Denning Troll")
	troll.alive = false
	var completed := OrcStrongholdCampaignContent.complete_if_troll_defeated(journal, player, troll)
	_check(bool(completed.get("ok", false)), "A defeated denning troll completes the active quest")
	_check(String(journal.quest_state(OrcStrongholdCampaignContent.QUEST_ID).get("status", "")) == "completed")
	_check(player.gold == 50, "Quest grants the source-authored 40 gold")
	_check(player.experience == 150, "Quest grants the source-authored 150 XP")
	_check(is_equal_approx(journal.faction_standing("orc_raiders"), 25.0), "Quest grants 25 orc standing")


func _test_recruitment_gate() -> void:
	var journal := CampaignJournal.new()
	OrcStrongholdCampaignContent.accept(journal)
	var player := CharacterState.new("player", "Player")
	var troll := CharacterState.new(OrcStrongholdCampaignContent.TROLL_ID, "Denning Troll")
	troll.alive = false
	OrcStrongholdCampaignContent.complete_if_troll_defeated(journal, player, troll)
	var grukk := CharacterState.new(OrcStrongholdCampaignContent.GRUKK_ID, "Warlord Grukk Ironhide")
	grukk.side = "neutral"
	_check(not OrcStrongholdCampaignContent.can_recruit_grukk(journal, grukk), "25 standing unlocks trade, not recruitment")
	journal.adjust_faction_standing("orc_raiders", 15, "test recruitment threshold")
	_check(OrcStrongholdCampaignContent.can_recruit_grukk(journal, grukk), "40 standing unlocks Grukk recruitment")
	grukk.side = "player"
	_check(not OrcStrongholdCampaignContent.can_recruit_grukk(journal, grukk), "Recruitment cannot be repeated")
