extends SceneTree

const RUNTIME_SERVICE = preload("res://scripts/simulation/goblin_threat_campaign_runtime_service.gd")
const SIMULATION_SCRIPT = preload("res://scripts/simulation/world_simulation.gd")
const CHARACTER_SCRIPT = preload("res://scripts/simulation/character_state.gd")
const RELATIONSHIP_SCRIPT = preload("res://scripts/simulation/persistent_character_relationship_state.gd")
const DIALOGUE_SERVICE = preload("res://scripts/simulation/goblin_threat_dialogue_service.gd")
const EVENT_ROUTER = preload("res://scripts/simulation/campaign_quest_event_router.gd")
const QUEST_REGISTRY = preload("res://scripts/simulation/campaign_quest_definition_registry.gd")

const ALDRIC_ID := "ser_aldric_thorne"
var _failures: int = 0


func _initialize() -> void:
	_test_chief_gift_is_paid_once()
	_test_favour_effects_reach_campaign_state()
	_test_alliance_rescues_aldric_and_completes_his_quest()
	_test_scout_note_is_a_one_time_world_effect()
	_test_direct_aldric_rescue()
	_test_nix_recruitment_uses_goblin_profile()
	_test_existing_lieutenant_is_converted_on_recruitment()
	_test_chief_dialogue_routes_gift_transaction()
	_test_alliance_follow_up_mine_raid_and_spy_quest()
	_test_chief_death_resolves_assault()
	_test_assassination_opens_nix_succession()
	if _failures > 0:
		push_error("%d Skarn-tooth runtime assertion(s) failed." % _failures)
		quit(1)
		return
	print("Skarn-tooth runtime tests passed.")
	quit(0)


func _check(condition: bool, message: String = "Assertion failed") -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _simulation() -> WorldSimulation:
	var simulation := SIMULATION_SCRIPT.new()
	var player := CHARACTER_SCRIPT.new("player", "Player")
	player.side = "player"
	player.gold = 100
	simulation.register_character(player)
	var aldric := CHARACTER_SCRIPT.new(ALDRIC_ID, "Ser Aldric Thorne")
	aldric.side = "enemy"
	aldric.axial = Vector2i(1, 0)
	simulation.register_character(aldric)
	return simulation


func _test_chief_gift_is_paid_once() -> void:
	var simulation := _simulation()
	var relationships := RELATIONSHIP_SCRIPT.new()
	var first := RUNTIME_SERVICE.give_chief_gift(simulation, relationships)
	_check(bool(first.get("ok", false)))
	_check(simulation.get_character("player").gold == 40, "The chief's gift must deduct 60 actual player gold")
	var repeated := RUNTIME_SERVICE.give_chief_gift(simulation, relationships)
	_check(not bool(repeated.get("ok", true)))
	_check(simulation.get_character("player").gold == 40, "A repeated gift must not spend gold twice")


func _test_favour_effects_reach_campaign_state() -> void:
	var simulation := _simulation()
	var first := RUNTIME_SERVICE.resolve_favour(simulation, "raid_mine")
	_check(bool(first.get("ok", false)))
	_check(bool(first.get("world_effects", {}).get("ok", false)))
	_check(simulation.get_character("player").gold == 160, "The Emberlode raid should award its 60-gold strongbox")
	_check(simulation.get_character("player").experience == 50)
	_check(is_equal_approx(float(simulation.campaign_journal.region_campaign_state("emberlode").get("security", 0.0)), -20.0))
	_check(is_equal_approx(float(simulation.campaign_journal.region_campaign_state("emberlode").get("prosperity", 0.0)), -25.0))
	_check(bool(simulation.campaign_journal.world_campaign_flag("emberlode_raided", false)))
	var repeated := RUNTIME_SERVICE.resolve_favour(simulation, "raid_mine")
	_check(bool(repeated.get("ok", false)) and not bool(repeated.get("applied", true)))
	_check(simulation.get_character("player").gold == 160, "The mine raid reward cannot be farmed")


func _test_alliance_rescues_aldric_and_completes_his_quest() -> void:
	var simulation := _simulation()
	var relationships := RELATIONSHIP_SCRIPT.new()
	var gift := RUNTIME_SERVICE.give_chief_gift(simulation, relationships)
	_check(bool(gift.get("ok", false)))
	var alliance := RUNTIME_SERVICE.resolve_threat(simulation, "goblin_alliance", relationships)
	_check(bool(alliance.get("ok", false)))
	_check(bool(alliance.get("world_effects", {}).get("ok", false)))
	_check(String(simulation.campaign_journal.quest_state("goblin_threat").get("status", "")) == "completed")
	_check(String(simulation.campaign_journal.quest_state("aldric_rescue").get("status", "")) == "completed")
	_check(bool(simulation.campaign_journal.world_campaign_flag("aldric_rescued", false)))
	_check(simulation.campaign_journal.npc_standing(ALDRIC_ID) == 60.0)
	_check(simulation.get_character(ALDRIC_ID).side == "neutral")
	_check(simulation.campaign_journal.npc_standing(ALDRIC_ID) == 40.0)
	_check(simulation.get_character("player").experience == 100)
	_check(is_equal_approx(float(simulation.campaign_journal.region_campaign_state("hollowmere").get("security", 0.0)), -10.0))


func _test_scout_note_is_a_one_time_world_effect() -> void:
	var simulation := _simulation()
	var first := RUNTIME_SERVICE.read_scout_note(simulation)
	_check(bool(first.get("ok", false)))
	_check(bool(simulation.campaign_journal.world_campaign_flag("goblin_scout_note_read", false)))
	_check(is_equal_approx(float(simulation.campaign_journal.region_campaign_state("hollowmere").get("security", 0.0)), -3.0))
	var repeated := RUNTIME_SERVICE.read_scout_note(simulation)
	_check(bool(repeated.get("ok", false)) and bool(repeated.get("already_read", false)))
	_check(is_equal_approx(float(simulation.campaign_journal.region_campaign_state("hollowmere").get("security", 0.0)), -3.0))


func _test_direct_aldric_rescue() -> void:
	var simulation := _simulation()
	var first := RUNTIME_SERVICE.rescue_aldric(simulation)
	_check(bool(first.get("ok", false)))
	_check(String(simulation.campaign_journal.quest_state("aldric_rescue").get("status", "")) == "completed")
	_check(bool(simulation.campaign_journal.world_campaign_flag("aldric_rescued", false)))
	_check(simulation.get_character(ALDRIC_ID).side == "neutral")
	var repeated := RUNTIME_SERVICE.rescue_aldric(simulation)
	_check(bool(repeated.get("ok", false)) and bool(repeated.get("already_applied", false)))


func _test_nix_recruitment_uses_goblin_profile() -> void:
	var simulation := _simulation()
	var relationships := RELATIONSHIP_SCRIPT.new()
	RUNTIME_SERVICE.give_chief_gift(simulation, relationships)
	var resolved := RUNTIME_SERVICE.resolve_threat(simulation, "goblin_alliance", relationships)
	_check(bool(resolved.get("ok", false)))
	var recruited := RUNTIME_SERVICE.recruit_nix(simulation)
	_check(bool(recruited.get("ok", false)), "Nix should be created and recruited after the alliance")
	_check(simulation.is_party_member("nix_sharpear"))
	var nix := simulation.get_character("nix_sharpear")
	_check(nix != null and nix.race == "goblin", "Nix must use the source goblin race, not human")
	_check(nix != null and nix.progression_mode == "companion")


func _test_chief_dialogue_routes_gift_transaction() -> void:
	var simulation := _simulation()
	var relationships := RELATIONSHIP_SCRIPT.new()
	var conversation := DIALOGUE_SERVICE.dialogue_for_npc(simulation, "chief_skarnub", relationships)
	var gift_offered := false
	for choice_value in conversation.get("choices", []):
		if String(choice_value.get("id", "")) == "skarnub_give_gift":
			gift_offered = true
	_check(gift_offered, "Chief dialogue should offer the source 60-gold gift when affordable")
	var result := DIALOGUE_SERVICE.select_choice(simulation, "chief_skarnub", "skarnub_give_gift", relationships)
	_check(bool(result.get("handled", false)) and bool(result.get("ok", false)))
	_check(simulation.get_character("player").gold == 40, "Dialogue choice must deduct the gift from player gold")


func _test_alliance_follow_up_mine_raid_and_spy_quest() -> void:
	var simulation := _simulation()
	var relationships := RELATIONSHIP_SCRIPT.new()
	RUNTIME_SERVICE.give_chief_gift(simulation, relationships)
	var alliance := RUNTIME_SERVICE.resolve_threat(simulation, "goblin_alliance", relationships)
	_check(bool(alliance.get("ok", false)))
	var note := RUNTIME_SERVICE.read_scout_note(simulation)
	_check(bool(note.get("ok", false)))
	var started := RUNTIME_SERVICE.start_mine_raid(simulation)
	_check(bool(started.get("ok", false)))
	_check(String(simulation.campaign_journal.quest_state("goblin_mine_raid").get("status", "")) == "active")
	var raid := RUNTIME_SERVICE.resolve_mine_raid(simulation)
	_check(bool(raid.get("ok", false)) and bool(raid.get("world_effects", {}).get("ok", false)))
	_check(String(simulation.campaign_journal.quest_state("goblin_mine_raid").get("status", "")) == "completed")
	_check(bool(simulation.campaign_journal.world_campaign_flag("goblin_mine_raid_completed", false)))
	_check(simulation.get_character("player").gold == 100)
	_check(simulation.get_character("player").experience == 150)
	_check(is_equal_approx(float(simulation.campaign_journal.region_campaign_state("emberlode").get("security", 0.0)), -20.0))
	_check(is_equal_approx(float(simulation.campaign_journal.region_campaign_state("emberlode").get("prosperity", 0.0)), -25.0))

	var spy_started := RUNTIME_SERVICE.start_greenskin_spy(simulation)
	_check(bool(spy_started.get("ok", false)))
	_check(String(simulation.campaign_journal.quest_state("greenskin_spy").get("status", "")) == "active")

	var saved_journal := simulation.campaign_journal.to_dict()
	var restored_simulation := _simulation()
	QUEST_REGISTRY.register_all(restored_simulation.campaign_journal)
	restored_simulation.campaign_journal.load_dict(saved_journal)
	_check(String(restored_simulation.campaign_journal.quest_state("goblin_mine_raid").get("status", "")) == "completed")
	_check(String(restored_simulation.campaign_journal.quest_state("goblin_scout_note").get("status", "")) == "completed")
	_check(String(restored_simulation.campaign_journal.quest_state("greenskin_spy").get("status", "")) == "active")
	_check(bool(restored_simulation.campaign_journal.world_campaign_flag("goblin_mine_raid_completed", false)))

	var spy_completed := RUNTIME_SERVICE.complete_greenskin_spy(restored_simulation)
	_check(bool(spy_completed.get("ok", false)))
	_check(String(restored_simulation.campaign_journal.quest_state("greenskin_spy").get("status", "")) == "completed")
	_check(bool(restored_simulation.campaign_journal.world_campaign_flag("northwatch_taken_by_greenskins", false)))


func _test_chief_death_resolves_assault() -> void:
	var simulation := _simulation()
	var chief := CHARACTER_SCRIPT.new("chief_skarnub", "Chief Skarnub")
	chief.axial = Vector2i(2, 0)
	simulation.register_character(chief)
	var router := EVENT_ROUTER.new()
	router.bind(simulation)
	chief.apply_damage(1000)
	_check(String(simulation.campaign_journal.quest_state("goblin_threat").get("status", "")) == "completed")
	_check(String(simulation.campaign_journal.quest_state("goblin_threat").get("decisions", {}).get("resolution", "")) == "assault")
	_check(simulation.get_character("player").experience == 300)
	_check(is_equal_approx(float(simulation.campaign_journal.region_campaign_state("hollowmere").get("security", 0.0)), 15.0))


func _test_assassination_opens_nix_succession() -> void:
	var simulation := _simulation()
	var chief := CHARACTER_SCRIPT.new("chief_skarnub", "Chief Skarnub")
	chief.axial = Vector2i(2, 0)
	simulation.register_character(chief)
	var router := EVENT_ROUTER.new()
	router.bind(simulation)
	_check(bool(RUNTIME_SERVICE.mark_chief_assassinated(simulation).get("ok", false)))
	chief.apply_damage(1000)
	_check(String(simulation.campaign_journal.quest_state("goblin_threat").get("status", "")) == "active", "Assassination should leave the succession decision open")
	var nix_conversation := RUNTIME_SERVICE.nix_greeting(simulation)
	var succession_offered := false
	for choice_value in nix_conversation.get("choices", []):
		if String(choice_value.get("id", "")) == "nix_resolve_succession":
			succession_offered = true
	_check(succession_offered, "Nix should offer peaceful succession after an assassination")
	var resolved := DIALOGUE_SERVICE.select_choice(simulation, "nix_sharpear", "nix_resolve_succession", RELATIONSHIP_SCRIPT.new())
	_check(bool(resolved.get("ok", false)))
	_check(String(simulation.campaign_journal.quest_state("goblin_threat").get("decisions", {}).get("resolution", "")) == "stealth_succession")
	_check(simulation.get_character("player").experience == 250)


func _test_existing_lieutenant_is_converted_on_recruitment() -> void:
	var simulation := _simulation()
	var lieutenant := CHARACTER_SCRIPT.new("nix_sharpear", "Nix Sharpear")
	lieutenant.side = "neutral"
	lieutenant.axial = Vector2i(2, 0)
	simulation.register_character(lieutenant)
	var relationships := RELATIONSHIP_SCRIPT.new()
	RUNTIME_SERVICE.give_chief_gift(simulation, relationships)
	var alliance := RUNTIME_SERVICE.resolve_threat(simulation, "goblin_alliance", relationships)
	_check(bool(alliance.get("ok", false)))
	var recruited := RUNTIME_SERVICE.recruit_nix(simulation)
	_check(bool(recruited.get("ok", false)))
	_check(simulation.is_party_member("nix_sharpear"))
	_check(lieutenant.race == "goblin", "The pre-existing lieutenant actor must be converted to the playable goblin race")
	_check(lieutenant.progression_mode == "companion")
	_check(int(lieutenant.skills.get("dagger_hit", 0)) > 0)
	_check(int(lieutenant.skills.get("stealth_rogue", 0)) > 0)


func _test_betrayal_blocks_aldric_recruitment_if_not_already_recruited() -> void:
	var simulation := _simulation()
	var rescued := RUNTIME_SERVICE.rescue_aldric(simulation)
	_check(bool(rescued.get("ok", false)))
	simulation.campaign_journal.adjust_faction_standing("goblin_tribe", 25.0, "test betrayal")
	var betrayal := RUNTIME_SERVICE.resolve_favour(simulation, "raid")
	_check(bool(betrayal.get("ok", false)))
	_check(simulation.campaign_journal.npc_standing(ALDRIC_ID) == 0.0)
	var greeting := RUNTIME_SERVICE.aldric_captive_greeting(simulation)
	var recruit_offered := false
	for choice_value in greeting.get("choices", []):
		if String(choice_value.get("id", "")).begins_with("recruit:"):
			recruit_offered = true
	_check(not recruit_offered, "Aldric must refuse recruitment after the betrayal outcome")
