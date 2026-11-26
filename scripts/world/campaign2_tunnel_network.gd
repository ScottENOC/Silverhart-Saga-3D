class_name Campaign2TunnelNetwork
extends RefCounted
## Source-authored three-node Thieves' Guild tunnel fast-travel network.
## The stubs are separate locations; links are menu travel, not a continuous
## corridor across the world map.

const FLOOR_NUMBER := -9
const NODES := {
	"palace": {
		"location_id": "silverhart_palace_tunnel",
		"object_id": "palace_tunnel_junction",
		"label": "the passage beneath the council chamber",
		"surface_location_id": "silverhart_palace_council_chamber",
		"surface_secret_id": "palace_secret_passage",
		"surface_entry_position": Vector2i(-9, -492),
		"position": Vector2i(-9, -492)
	},
	"city": {
		"location_id": "silverhart_city_tunnel",
		"object_id": "city_tunnel_junction",
		"label": "the passage behind the general goods store",
		"surface_location_id": "silverhart_general_goods",
		"surface_secret_id": "city_secret_passage",
		"surface_entry_position": Vector2i(-20, -489),
		"position": Vector2i(-20, -489)
	},
	"wilderness": {
		"location_id": "thieves_cove",
		"object_id": "wilderness_tunnel_junction",
		"surface_entry_position": Vector2i(-274, 41),
		"label": "the sea-cave den",
		"position": Vector2i(-274, 40)
	}
}

static func node_ids() -> Array[String]:
	var result: Array[String] = []
	for node_id in NODES:
		result.append(String(node_id))
	result.sort()
	return result

static func get_node(node_id: String) -> Dictionary:
	return (NODES.get(node_id, {}) as Dictionary).duplicate(true)

static func destinations_from(node_id: String) -> Array[Dictionary]:
	if not NODES.has(node_id):
		return []
	var result: Array[Dictionary] = []
	for destination_id in node_ids():
		if destination_id == node_id:
			continue
		var destination: Dictionary = get_node(destination_id)
		destination["id"] = destination_id
		result.append(destination)
	return result


## Resolve a surface entrance within one hex of the player. Palace and city
## entries are concealed passage tiles; the wilderness entry is the cave stair.
static func nearby_surface_location(position: Vector2i, interaction_radius: int = 1) -> Dictionary:
	if interaction_radius < 0:
		return {}
	for node_id in node_ids():
		var node: Dictionary = get_node(node_id)
		var entry_position: Variant = node.get("surface_entry_position", null)
		if not entry_position is Vector2i:
			continue
		var distance := HexGrid.distance(position, entry_position)
		if distance > interaction_radius:
			continue
		return {
			"node_id": node_id,
			"location_id": String(node.get("surface_location_id", node.get("location_id", ""))),
			"position": entry_position,
			"distance": distance
		}
	return {}


static func resolve_location_node(location_id: String, floor_number: int, object_id: String) -> String:
	for node_id in NODES:
		var node: Dictionary = NODES[node_id]
		if String(node.get("location_id", "")) != location_id:
			continue
		if int(floor_number) != FLOOR_NUMBER or String(node.get("object_id", "")) != object_id:
			continue
		return String(node_id)
	return ""
