extends SceneTree

const SERVICE := preload("res://scripts/simulation/camp_companion_dialogue_service.gd")
const CAMPAIGN_RUNTIME_STORE := preload("res://scripts/simulation/companion_campaign_runtime_store.gd")

var _failures := 0
var _exchange_count := 0
var _last_exchange: Dictionary = {}
var _actor_probes: Dictionary = {}


class DialogueActorProbe extends RefCounted:
	var last_activity: String = ""

	func play_camp_activity(activity: String) -> bool:
		last_activity = activity
		return true


func _actor_for_id(character_id: String) -> Object:
	return _actor_probes.get(character_id)


func _on_companion_exchange(exchange: Dictionary) -> void:
	_exchange_count += 1
	_last_exchange = exchange.duplicate(true)


func _initialize() -> void:
	var bonds := CompanionBondState.new()
	var camp := CampSimulation.new()
	var exchange := SERVICE.build_exchange(
		"companion_ser_aldric_thorne",
		"companion_nix_sharpear",
		0,
		bonds,
		"Ser Aldric Thorne",
		"Nix Sharpear"
	)
	_check(not exchange.is_empty(), "Two different companions should be able to exchange dialogue")
	_check(String(exchange.get("topic", "")) == "road")
	var lines: Array = exchange.get("lines", [])
	_check(lines.size() == 2, "An exchange should contain both sides of the conversation")
	_check(String(lines[0].get("character_id", "")) == "companion_ser_aldric_thorne")
	_check(String(lines[1].get("character_id", "")) == "companion_nix_sharpear")
	_check(String(lines[0].get("text", "")).length() > 20)
	_check(String(lines[1].get("text", "")).length() > 20)

	var cottage_exchange := SERVICE.build_exchange(
		"companion_ser_aldric_thorne", "companion_nix_sharpear", 2, bonds,
		"Ser Aldric Thorne", "Nix Sharpear", {"layout_id": "cottage_one_room"}
	)
	_check(String(cottage_exchange.lines[0].text).contains("modest hearth"), "Home conversations should acknowledge the one-room cottage layout.")
	_check(String(cottage_exchange.get("dwelling_layout_id", "")) == "cottage_one_room")
	var manor_exchange := SERVICE.build_exchange(
		"companion_ser_aldric_thorne", "companion_nix_sharpear", 2, bonds,
		"Ser Aldric Thorne", "Nix Sharpear", {"layout_id": "silverhart_manor_livable"}
	)
	_check(String(manor_exchange.lines[0].text).contains("people who pass through"), "Home conversations should distinguish a fortified manor from a cottage.")

	var recorded := SERVICE.record_exchange(bonds, camp, exchange, "test:camp:exchange:1")
	_check(bool(recorded.get("ok", false)) and bool(recorded.get("changed", false)))
	_check(float(bonds.snapshot("companion_ser_aldric_thorne", "companion_nix_sharpear").familiarity) == 1.0)
	_check(float(bonds.snapshot("companion_nix_sharpear", "companion_ser_aldric_thorne").friendship) == 1.0)
	_check(float(camp.condition_for("companion_ser_aldric_thorne").social_satisfaction) == 2.0)
	_check(float(camp.condition_for("companion_nix_sharpear").social_satisfaction) == 2.0)

	var repeated := SERVICE.record_exchange(bonds, camp, exchange, "test:camp:exchange:1")
	_check(bool(repeated.get("ok", false)) and not bool(repeated.get("changed", true)))
	_check(float(bonds.snapshot("companion_ser_aldric_thorne", "companion_nix_sharpear").familiarity) == 1.0)
	_check(float(camp.condition_for("companion_ser_aldric_thorne").social_satisfaction) == 2.0)

	bonds.set_relationship("companion_nix_sharpear", "companion_ser_aldric_thorne", {"familiarity": 30.0, "trust": 25.0, "friendship": 25.0})
	var warm_exchange := SERVICE.build_exchange("companion_ser_aldric_thorne", "companion_nix_sharpear", 1, bonds)
	_check(String(warm_exchange.lines[1].text) == "All right, you've earned a proper answer. Don't let it go to your head.", "Established bonds should unlock warmer responses")

	for first_id in SERVICE.supported_companion_ids():
		for second_id in SERVICE.supported_companion_ids():
			if first_id == second_id:
				continue
			var pair := SERVICE.build_exchange("companion_" + first_id, "companion_" + second_id, 2, bonds)
			_check(not pair.is_empty(), "Every authored companion should have dialogue with every other companion")
			_check((pair.get("lines", []) as Array).size() == 2)

	_check(not SERVICE.build_exchange("companion_warlord_grukk", "companion_nix_sharpear", 3, bonds).is_empty(), "Grukk's actual campaign ID should resolve to his authored profile")
	_check(SERVICE.canonical_id("companion_dagna") == "dagna", "Dagna's companion actor ID should resolve to her camp dialogue profile")
	var dagna_exchange := SERVICE.build_exchange("companion_dagna", "companion_nix_sharpear", 0, bonds, "Dagna", "Nix Sharpear")
	_check(not dagna_exchange.is_empty(), "Dagna should be able to participate in autonomous camp dialogue")
	_check(String(dagna_exchange.lines[0].text).contains("old travelling blessing"), "Dagna's ambient dialogue should acknowledge her religious upbringing without naming a deity or doctrine")
	_check(SERVICE.supported_companion_ids().has("dagna"), "Dagna should be included in the supported camp dialogue roster")
	_check(SERVICE.build_exchange("player", "companion_ser_aldric_thorne", 0, bonds).is_empty())
	_check(SERVICE.build_exchange("companion_ser_aldric_thorne", "companion_ser_aldric_thorne", 0, bonds).is_empty())

	_test_autonomous_director_exchange()

	if _failures > 0:
		push_error("%d camp companion dialogue assertion(s) failed." % _failures)
		quit(1)
		return
	print("Camp companion dialogue tests passed.")
	quit(0)


func _check(condition: bool, message: String = "Assertion failed") -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _test_autonomous_director_exchange() -> void:
	var world := WorldSimulation.new()
	for q in range(-6, 7):
		for r in range(-6, 7):
			var hex := Vector2i(q, r)
			if HexGrid.distance(Vector2i.ZERO, hex) <= 6:
				world.map_data.add_cell(hex, 0.0, true, "grass")
	var player := CharacterState.new("player", "Player", Vector2i(-4, 0))
	player.side = "player"
	var aldric := CharacterState.new("companion_ser_aldric_thorne", "Ser Aldric Thorne", Vector2i(4, 0))
	aldric.side = "player"
	var nix := CharacterState.new("companion_nix_sharpear", "Nix Sharpear", Vector2i(4, -1))
	nix.side = "player"
	world.register_character(player)
	world.register_character(aldric)
	world.register_character(nix)

	# Complete a real authored companion chapter so the ambient conversation
	# must draw its subject and decision from campaign state, not a test string.
	var quest_chain := CAMPAIGN_RUNTIME_STORE.quest_chain_state_for(world)
	quest_chain.register_quest_definitions(world.campaign_journal)
	world.campaign_journal.quests["aldric_measure_of_oath"] = {
		"status": "completed",
		"completed_at": 100.0
	}
	var relationship_state := CAMPAIGN_RUNTIME_STORE.relationship_state_for(world)
	var chapter_start := quest_chain.start(
		"aldric_weight_of_command",
		world.campaign_journal,
		world.get_party_member_ids(),
		relationship_state,
		100.0
	)
	_check(bool(chapter_start.get("ok", false)), "Aldric's next campaign chapter should start when its prerequisite is complete")
	var consultation := quest_chain.consult("aldric_weight_of_command", world.campaign_journal, "adelram", 110.0)
	_check(bool(consultation.get("ok", false)), "The supporting character should be consulted before resolving the chapter")
	var resolution := quest_chain.resolve(
		"aldric_weight_of_command",
		"shared_command",
		world.campaign_journal,
		relationship_state,
		120.0
	)
	_check(bool(resolution.get("ok", false)), "The authored chapter resolution should be recorded in the campaign journal")
	var reyna_memory := SERVICE.build_campaign_memory_exchange(
		aldric.id,
		"companion_reyna_fletcher",
		0,
		world.companion_bonds,
		quest_chain,
		world.campaign_journal,
		aldric.display_name,
		"Reyna Fletcher"
	)
	_check(String(reyna_memory.get("campaign_memory", {}).get("agreement", "")) == "support", "Reyna's shared-watch outlook should support Aldric sharing command")

	# Companion prerequisite quests are campaign memories too, not just later
	# personal chapters. This Fenn outcome is authored in the prerequisite data.
	world.campaign_journal.quests["fenn_living_boundary"] = {
		"status": "completed",
		"completed_at": 130.0,
		"resolution": "managed_spillway"
	}
	var fenn_memory := SERVICE.build_campaign_memory_exchange(
		"companion_fenn_oakheart",
		nix.id,
		0,
		world.companion_bonds,
		quest_chain,
		world.campaign_journal,
		"Fenn Oakheart",
		nix.display_name
	)
	_check(String(fenn_memory.get("campaign_memory", {}).get("chapter_id", "")) == "fenn_living_boundary", "Completed prerequisite quests should be remembered")
	_check(String(fenn_memory.get("campaign_memory", {}).get("agreement", "")) == "disagree", "Nix should be able to disagree with Fenn's managed-spillway decision")

	var started := world.begin_camp({"hex": Vector2i.ZERO, "walkable": true}, {})
	_check(bool(started.get("ok", false)), "The integration test should establish an in-world camp")

	var aldric_probe := DialogueActorProbe.new()
	var nix_probe := DialogueActorProbe.new()
	_actor_probes[aldric.id] = aldric_probe
	_actor_probes[nix.id] = nix_probe
	_exchange_count = 0
	_last_exchange.clear()
	var director := CampPartyActivityDirector.new()
	director.configure(world, Callable(self, "_actor_for_id"))
	director.companion_exchange.connect(_on_companion_exchange)
	director.begin_camp(world.camp_simulation.site)
	director.process_activity_movement(22.1)

	_check(_exchange_count == 1, "The camp director should autonomously start a companion-to-companion exchange")
	_check(String(_last_exchange.get("kind", "")) == "campaign_memory", "A completed companion chapter should surface as ambient party dialogue")
	var memory: Dictionary = _last_exchange.get("campaign_memory", {})
	_check(String(memory.get("chapter_id", "")) == "aldric_weight_of_command", "The dialogue should identify the actual completed chapter")
	_check(String(memory.get("resolution_id", "")) == "shared_command", "The dialogue should remember the recorded resolution")
	_check(String(memory.get("agreement", "")) == "disagree", "Nix should be allowed to disagree with Aldric's shared-command decision")
	var lines: Array = _last_exchange.get("lines", [])
	_check(lines.size() == 2, "Both companions should speak during the exchange")
	_check(String(lines[0].get("character_id", "")) == aldric.id, "The companion whose quest concluded should speak first")
	_check(String(lines[1].get("character_id", "")) == nix.id, "The other companion should answer")
	_check(String(lines[1].get("text", "")).contains("not sure I agree"), "Nix should actually voice his disagreement")
	_check(not ["player"].has(String(lines[0].get("character_id", ""))))
	_check(not ["player"].has(String(lines[1].get("character_id", ""))))
	_check(aldric_probe.last_activity == "socialise", "The first speaker should play the Ara conversation animation")
	_check(nix_probe.last_activity == "socialise", "The second speaker should play the Ara conversation animation")
	_check(float(world.companion_bonds.snapshot(aldric.id, nix.id).familiarity) > 0.0)
	_check(float(world.companion_bonds.snapshot(nix.id, aldric.id).familiarity) > 0.0)
	_check(float(world.companion_bonds.snapshot(aldric.id, nix.id).friendship) == 0.0, "Disagreement should not be converted into automatic friendship")
	_check(float(world.companion_bonds.snapshot(nix.id, aldric.id).friendship) == 0.0, "Disagreement should not be converted into automatic friendship")
	_check(float(world.camp_simulation.condition_for(aldric.id).social_satisfaction) > 0.0)
	_check(float(world.camp_simulation.condition_for(nix.id).social_satisfaction) > 0.0)

	director.process_activity_movement(0.5)
	_check(aldric_probe.last_activity == "socialise" and nix_probe.last_activity == "socialise", "Station routines must not immediately overwrite the conversation animation")
	director.process_activity_movement(22.1)
	_check(_exchange_count == 2, "A campaign memory should be discussed only once by this pair")
	_check(String(_last_exchange.get("kind", "")) != "campaign_memory", "The same completed decision should not be repeated in every camp exchange")
	director.stop()
	director.free()
	_actor_probes.clear()
