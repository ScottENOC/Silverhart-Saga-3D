extends SceneTree

const SIMULATION = preload("res://scripts/simulation/world_simulation.gd")
const LOADER = preload("res://scripts/world/campaign2_location_loader.gd")
const FLOOR_BUILDER = preload("res://scripts/world/campaign2_multistory_floor_map_builder.gd")

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var simulation = SIMULATION.new()
	root.add_child(simulation)
	var wilderness_load: Dictionary = LOADER.load_multistory_location(root, "thieves_cove", simulation)
	var palace_load: Dictionary = LOADER.load_multistory_location(root, "silverhart_palace_tunnel", simulation)
	var city_load: Dictionary = LOADER.load_multistory_location(root, "silverhart_city_tunnel", simulation)
	var council_load: Dictionary = LOADER.load_multistory_location(root, "silverhart_palace_council_chamber", simulation)
	var general_goods_load: Dictionary = LOADER.load_multistory_location(root, "silverhart_general_goods", simulation)
	_check(bool(wilderness_load.get("ok", false)) and bool(palace_load.get("ok", false)) and bool(city_load.get("ok", false)) and bool(council_load.get("ok", false)) and bool(general_goods_load.get("ok", false)), "All three tunnel stubs and both surface entrance locations must load")
	if failures > 0:
		_finish()
		return
	var wilderness = wilderness_load.runtime
	var palace = palace_load.runtime
	var city = city_load.runtime
	var council = council_load.runtime
	var general_goods = general_goods_load.runtime
	var blocked_floor: Dictionary = wilderness.location_state.set_current_floor_for_network_travel(-1)
	_check(not bool(blocked_floor.get("ok", false)), "Tunnel fast travel must not bypass ordinary intermediate floors")
	_check(bool(wilderness.location_state.set_current_floor_for_network_travel(-9).get("ok", false)), "Wilderness stub must be activatable on floor -9")
	var player := CharacterState.new("tunnel_test_player", "Tunnel Test Player", Vector2i(-274, 40))
	simulation.register_character(player)
	var player_actor := Node3D.new()
	root.add_child(player_actor)
	_check(wilderness.register_character_actor("tunnel_test_player", player_actor), "The active tunnel runtime must accept the player actor")
	var wilderness_options: Array[Dictionary] = wilderness.get_tunnel_junction_destinations("tunnel_test_player")
	_check(wilderness_options.size() == 2, "Wilderness junction must offer the palace and city destinations")
	var first_travel: Dictionary = wilderness.travel_to_tunnel_node("tunnel_test_player", palace, "palace")
	_check(bool(first_travel.get("ok", false)), "Wilderness junction must transfer the player to the palace tunnel")
	_check(player.axial == Vector2i(-9, -492) and palace.get_current_floor() == -9, "Palace tunnel travel must update both axial position and active floor")
	_check(not wilderness.is_floor_visible(-9) and palace.is_floor_visible(-9), "Tunnel travel must deactivate the old floor and activate the destination floor")
	_check(player_actor.global_position.y < -20.0, "The transferred player actor must be placed at the destination underground elevation")
	var second_travel: Dictionary = palace.travel_to_tunnel_node("tunnel_test_player", city, "city")
	_check(bool(second_travel.get("ok", false)), "Palace junction must transfer the player to the city tunnel")
	_check(player.axial == Vector2i(-20, -489) and city.get_current_floor() == -9, "City tunnel travel must update both axial position and active floor")
	_check(not palace.is_floor_visible(-9) and city.is_floor_visible(-9), "Second tunnel hop must swap the active location presentation")
	var return_travel: Dictionary = city.travel_to_tunnel_node("tunnel_test_player", wilderness, "wilderness")
	_check(bool(return_travel.get("ok", false)), "City junction must provide a return route to the wilderness den")
	_check(player.axial == Vector2i(-274, 40) and wilderness.get_current_floor() == -9, "Return travel must restore the player to the wilderness junction")
	_check(wilderness.is_floor_visible(-9) and not city.is_floor_visible(-9), "Returning to the wilderness must restore its floor presentation")

	var entrance_player := CharacterState.new("palace_passage_test_player", "Passage Test Player", Vector2i(-10, -492))
	simulation.register_character(entrance_player)
	_check(council.get_nearby_undiscovered_secret_passage_id("palace_passage_test_player") == "palace_secret_passage", "The concealed palace passage must be searchable from an adjacent hex")
	var failed_search: Dictionary = council.search_secret_passage("palace_passage_test_player", "palace_secret_passage", 0.99)
	_check(bool(failed_search.get("ok", false)) and not bool(failed_search.get("found", true)), "A spot-check roll above 35% must not reveal the palace passage")
	_check(not council.location_state.is_secret_discovered("palace_secret_passage"), "A failed spot check must leave the palace passage concealed")
	var successful_search: Dictionary = council.search_secret_passage("palace_passage_test_player", "palace_secret_passage", 0.34)
	_check(bool(successful_search.get("ok", false)) and bool(successful_search.get("found", false)), "A spot-check roll below 35% must reveal the palace passage")
	_check(council.has_floor_object(0, "palace_secret_passage"), "The revealed palace passage must be presented")
	var rebuilt_surface: Dictionary = FLOOR_BUILDER.build_floor_map(council.definition, 0, council.location_state)
	var entrance_object_type := ""
	for tile_object in rebuilt_surface.get("tile_objects", []):
		if String(tile_object.get("id", "")) == "palace_secret_passage":
			entrance_object_type = String(tile_object.get("type", ""))
	_check(entrance_object_type == "tunnel_entrance", "A discovered cross-location passage must not be represented as a local stair")
	_check(bool(simulation.relocate_character("palace_passage_test_player", Vector2i(-9, -492))), "Revealed passage hex must be walkable")
	var entry_node := council.get_tunnel_entry_node("palace_passage_test_player")
	_check(entry_node == "palace", "The revealed council-chamber passage must resolve to the palace junction")
	var entrance_travel: Dictionary = council.enter_tunnel_node("palace_passage_test_player", palace, entry_node)
	_check(bool(entrance_travel.get("ok", false)), "The revealed palace passage must provide entry to its matching tunnel stub")
	var city_entrance_player := CharacterState.new("city_passage_test_player", "City Passage Test Player", Vector2i(-21, -489))
	simulation.register_character(city_entrance_player)
	_check(general_goods.get_nearby_undiscovered_secret_passage_id("city_passage_test_player") == "city_secret_passage", "The concealed general-goods passage must be searchable from an adjacent hex")
	var city_search: Dictionary = general_goods.search_secret_passage("city_passage_test_player", "city_secret_passage", 0.10)
	_check(bool(city_search.get("ok", false)) and bool(city_search.get("found", false)), "The general-goods spot check must reveal its passage on a successful roll")
	_check(general_goods.get_tunnel_entry_node("city_passage_test_player") == "city", "The discovered general-goods passage must resolve to the city junction")
	_check(entrance_player.axial == Vector2i(-9, -492) and palace.get_current_floor() == -9, "Surface passage travel must place the character at the palace junction")
	var surface_return: Dictionary = palace.return_to_surface_passage("palace_passage_test_player", council, "palace")
	_check(bool(surface_return.get("ok", false)), "The palace tunnel must return through the revealed surface passage")
	_check(entrance_player.axial == Vector2i(-9, -492) and council.get_current_floor() == 0, "Return travel must restore the character to the council-chamber passage")

	if failures > 0:
		_finish()
		return
	print("Cross-location Thieves' Guild tunnel travel and revealed palace entrance validated.")
	quit(0)

func _finish() -> void:
	push_error("%d tunnel runtime integration test(s) failed." % failures)
	quit(1)

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
