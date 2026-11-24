extends SceneTree

const WORLD_STATE_SERVICE = preload("res://scripts/simulation/campaign_world_state_service.gd")
const WORLD_CONSEQUENCE_SERVICE = preload("res://scripts/simulation/campaign_world_consequence_service.gd")
const NPC_INTERACTION_SERVICE = preload("res://scripts/world/campaign_npc_interaction_service.gd")

var failures := 0


func _initialize() -> void:
	_test_actor_presentation_and_interaction_context()
	if failures > 0:
		push_error("%d campaign world state presentation assertion(s) failed." % failures)
		quit(1)
		return
	print("Campaign world state presentation tests passed.")
	quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _test_actor_presentation_and_interaction_context() -> void:
	var simulation := WorldSimulation.new()
	var journal := simulation.campaign_journal
	journal.register_quest_definition({"id":"reddale_cut", "objectives":[]})
	journal.start_quest("reddale_cut")
	journal.record_decision("reddale_cut", "reeve_response", "resist_ironbond")
	var settlements: Array[Dictionary] = [{
		"settlement_id":"reddale",
		"deltas":{"public_order":10.0, "ironbond_presence":-20.0},
		"flags":{"reeve_backed_resistance":true, "public_status":"Public order restored"}
	}]
	var npcs: Array[Dictionary] = [{
		"npc_id":"reeve_aldous_finch",
		"deltas":{"trust":15.0, "fear":-10.0},
		"flags":{
			"will_openly_oppose_ironbond":true,
			"public_status_visible":true,
			"public_status":"Openly opposes Ironbond",
			"show_settlement_status":true
		}
	}]
	var applied := WORLD_CONSEQUENCE_SERVICE.apply_decision_consequences(
		journal, "reddale_cut", "reeve_response", settlements, npcs
	)
	_check(bool(applied.get("ok", false)), "A campaign decision should update persistent settlement and NPC state")

	var actor := Node3D.new()
	actor.name = "ReeveActor"
	actor.set_meta("faction_id", "silverhart_kingdom")
	var name_label := Label3D.new()
	name_label.name = "CharacterNameLabel"
	name_label.text = "Reeve Aldous Finch"
	actor.add_child(name_label)
	root.add_child(actor)
	var decorated := WORLD_STATE_SERVICE.apply_npc_actor_state(
		actor, journal, "reeve_aldous_finch", "reddale", "silverhart_kingdom"
	)
	_check(bool(decorated.get("ok", false)), "The actor should receive a campaign-state projection")
	_check(bool(actor.get_meta("campaign_npc_flags", {}).get("will_openly_oppose_ironbond", false)), "Actor metadata should expose the Reeve's changed stance")
	_check(actor.get_meta("campaign_public_status", "") == "Openly opposes Ironbond", "The actor should expose its authored public status")
	var status_label := actor.get_node_or_null("CampaignStatusLabel") as Label3D
	_check(status_label != null and status_label.text == "Openly opposes Ironbond", "The Reeve's changed stance should be visible above the actor")
	var settlement_label := actor.get_node_or_null("CampaignSettlementStatusLabel") as Label3D
	_check(settlement_label != null and settlement_label.text == "Public order restored", "The Reeve should visibly communicate the settlement-wide outcome")

	var player := CharacterState.new("player", "Player", Vector2i.ZERO)
	player.side = "player"
	simulation.register_character(player)
	var reeve := CharacterState.new("reeve_aldous_finch", "Reeve Aldous Finch", Vector2i(1, 0))
	reeve.side = "neutral"
	simulation.register_character(reeve)
	actor.set_meta("campaign2_npc_id", "reeve_aldous_finch")
	actor.set_meta("campaign2_settlement_id", "reddale")
	actor.add_to_group("campaign2_npc")
	await process_frame
	var nearby := NPC_INTERACTION_SERVICE.nearby_entries(
		simulation, "player", {}, root.get_tree(), 2
	)
	_check(nearby.size() == 1, "The changed Reeve should remain available to nearby interaction")
	if nearby.size() == 1:
		_check(String(nearby[0].get("public_status", "")) == "Openly opposes Ironbond", "Nearby interaction should expose the Reeve's changed public stance")
		_check(String(nearby[0].get("campaign_context", {}).get("settlement_public_status", "")) == "Public order restored", "Nearby interaction should expose the settlement-wide status")
		_check(is_equal_approx(float(nearby[0].get("campaign_context", {}).get("trust", 0.0)), 15.0), "Nearby interaction should expose the Reeve's changed trust")

	var settlement_context := WORLD_STATE_SERVICE.settlement_context(journal, "reddale")
	_check(is_equal_approx(float(settlement_context.get("values", {}).get("public_order", 0.0)), 10.0), "Settlement queries should expose durable public order changes")
	_check(bool(settlement_context.get("flags", {}).get("reeve_backed_resistance", false)), "Settlement queries should expose decision flags")
