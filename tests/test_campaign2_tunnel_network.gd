extends SceneTree

const NETWORK = preload("res://scripts/world/campaign2_tunnel_network.gd")

var failures := 0

func _initialize() -> void:
	_check(NETWORK.node_ids() == ["city", "palace", "wilderness"], "The source tunnel network must contain exactly its three named nodes")
	for node_id in NETWORK.node_ids():
		var node: Dictionary = NETWORK.get_node(node_id)
		_check(not String(node.get("location_id", "")).is_empty(), "%s must resolve to a distinct source location" % node_id)
		_check(not String(node.get("object_id", "")).is_empty(), "%s must resolve to its authored junction object" % node_id)
		_check(int(node.get("position", Vector2i.ZERO).x) != 0 or int(node.get("position", Vector2i.ZERO).y) != 0, "%s must have an authored axial position" % node_id)
		var destinations: Array[Dictionary] = NETWORK.destinations_from(node_id)
		_check(destinations.size() == 2, "%s must offer exactly the other two tunnel destinations" % node_id)
		var destination_ids: Array[String] = []
		for destination in destinations:
			destination_ids.append(String(destination.get("id", "")))
			_check(String(destination.get("id", "")) != node_id, "A junction must not offer travel to itself")
			_check(NETWORK.resolve_location_node(String(destination.location_id), NETWORK.FLOOR_NUMBER, String(destination.object_id)) == String(destination.id), "Every destination must resolve back to its own node")
		destination_ids.sort()
		var expected := NETWORK.node_ids()
		expected.erase(node_id)
		_check(destination_ids == expected, "%s must link to both other junctions" % node_id)
	_check(NETWORK.nearby_surface_location(Vector2i(-9, -492)).get("location_id", "") == "silverhart_palace_council_chamber", "The palace secret passage must resolve to its surface location")
	_check(NETWORK.nearby_surface_location(Vector2i(-20, -489)).get("location_id", "") == "silverhart_general_goods", "The city secret passage must resolve to the general goods location")
	_check(NETWORK.nearby_surface_location(Vector2i(-274, 41)).get("location_id", "") == "thieves_cove", "The wilderness cave stair must resolve to Thieves' Cove")
	_check(NETWORK.nearby_surface_location(Vector2i(100, 100)).is_empty(), "Distant cells must not trigger tunnel entrance loading")
	_check(NETWORK.resolve_location_node("thieves_cove", -9, "wilderness_tunnel_junction") == "wilderness", "The wilderness junction must resolve from its source location")
	_check(NETWORK.resolve_location_node("thieves_cove", 0, "wilderness_tunnel_junction").is_empty(), "A junction on the wrong floor must not resolve")
	_check(NETWORK.resolve_location_node("thieves_cove", -9, "not_the_junction").is_empty(), "An unrelated tile object must not resolve as a junction")
	if failures > 0:
		push_error("%d tunnel network test(s) failed." % failures)
		quit(1)
		return
	print("Three-node Thieves' Guild tunnel network topology validated.")
	quit(0)

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
