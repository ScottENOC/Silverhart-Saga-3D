class_name CampSiteEvaluator
extends RefCounted
## Evaluates physical camp placement against authoritative world-map state.
## Scene-specific presentation, dwelling discovery and camp startup stay outside.

static func evaluate(
	simulation: WorldSimulation,
	hex: Vector2i,
	is_upper_floor: bool,
	world_position: Vector3
) -> Dictionary:
	if simulation == null or simulation.map_data == null:
		return {"ok": false, "reason": "missing_world"}
	if is_upper_floor or not simulation.map_data.has_cell(hex) or not simulation.map_data.is_walkable(hex):
		return {"ok": false, "reason": "unsuitable_ground"}
	if simulation.is_hex_occupied(hex):
		return {"ok": false, "reason": "site_occupied"}

	var nearby_trees := false
	var water_nearby := false
	for candidate in simulation.map_data.cells:
		var candidate_hex: Vector2i = candidate
		if not simulation.is_hex_within_range(hex, candidate_hex, 4):
			continue
		var terrain := simulation.map_data.terrain_id_at(candidate_hex)
		if terrain == "forest":
			nearby_trees = true
		elif terrain == "water":
			water_nearby = true
		if nearby_trees and water_nearby:
			break

	return {
		"ok": true,
		"site": {
			"hex": hex,
			"position": world_position,
			"walkable": true,
			"occupied": false,
			"terrain_id": simulation.map_data.terrain_id_at(hex)
		},
		"environment": {
			"trees_nearby": nearby_trees,
			"water_nearby": water_nearby
		}
	}
