extends SceneTree

const COMPOSER = preload("res://scripts/world/world_settlement_feature_composer.gd")
const HOLLOWMERE_PRESENTATION = preload("res://data/settlements/hollowmere/presentation.gd")

func _initialize() -> void:
	_test_chunk_ownership_and_route_clipping()
	_test_empty_chunk_is_valid()
	_test_hollowmere_location_uses_shared_composer()
	print("World settlement feature composer tests passed.")
	quit(0)

func _test_hollowmere_location_uses_shared_composer() -> void:
	var parent := Node3D.new()
	var result: Dictionary = COMPOSER.compose_location(
		parent,
		HOLLOWMERE_PRESENTATION.DEFINITION,
		HexGrid.DEFAULT_RADIUS_M
	)
	assert(bool(result.get("ok", false)), "Hollowmere authored features should compose through the shared pipeline: %s" % result)
	assert(int(result.get("buildings", 0)) == HOLLOWMERE_PRESENTATION.FEATURE_DATA.buildings.size())
	assert(int(result.get("routes", 0)) == HOLLOWMERE_PRESENTATION.FEATURE_DATA.routes.size())
	assert(int(result.get("bridges", 0)) == 1)
	assert(parent.get_node_or_null("GeneralStore") != null)
	assert(parent.get_node_or_null("Chapel") != null)
	assert(parent.get_node_or_null("NarrowRiverBridge") != null)
	assert(parent.get_node_or_null("GeneralStore/StoreSignPresentation") != null)
	assert(parent.get_node_or_null("Chapel/ChapelBellTowerPresentation") != null)
	parent.free()

func _definition() -> Dictionary:
	return {
		"id": "composer_test",
		"origin": Vector2i.ZERO,
		"definition": {
			"presentation": {
				"mode": "chunked",
				"palette": {"timber": Color(0.3, 0.18, 0.1), "field": Color(0.3, 0.4, 0.2)},
				"materials": {"props": {"timber": "timber"}, "agriculture": {"field": "field"}}
			},
			"layout": {
				"buildings": [{
					"id": "HouseA", "kind": "house", "center": Vector2i(1, 1),
					"door": Vector2i(3, 1), "half_q": 1, "half_r": 1
				}],
				"paths": [{
					"id": "CrossChunkRoad", "feature_type": "route",
					"from": Vector2i(-2, 1), "to": Vector2i(6, 1), "width": 2.0
				}],
				"bridges": [],
				"fields": [{
					"id": "FieldA", "feature_type": "field",
					"corners": [Vector2i(0, 0), Vector2i(2, 0), Vector2i(2, 2)],
					"material": "field"
				}],
				"props": [{
					"id": "HouseSign", "feature_type": "landmark_props",
					"parent_node": "HouseA",
					"parts": [{
						"name": "SignBoard", "type": "box",
						"size": Vector3(1.0, 0.5, 0.1),
						"position": Vector3(0, 2, -1),
						"material": "timber"
					}]
				}]
			}
		}
	}

func _test_chunk_ownership_and_route_clipping() -> void:
	var entry := _definition()
	var first_chunk := Node3D.new()
	var first_result := COMPOSER.compose_chunk(first_chunk, entry, Vector2i.ZERO, 4)
	assert(bool(first_result.get("ok", false)), "First chunk should compose: %s" % first_result)
	assert(first_chunk.get_node_or_null("HouseA") != null, "Building anchor belongs to first chunk")
	assert(first_chunk.get_node_or_null("HouseA/HouseSign/SignBoard") != null, "Building-attached prop should follow its parent building")
	assert(first_chunk.get_node_or_null("FieldA") != null, "Field centroid belongs to first chunk")
	var first_routes := first_chunk.find_children("*", "MeshInstance3D", true, false).filter(func(node): return String(node.name).begins_with("CrossChunkRoad_chunk_"))
	assert(first_routes.size() == 1, "Only the route segment owned by this chunk should be emitted")
	var route_source: Dictionary = entry["definition"]["layout"]["paths"][0]
	var first_fragments: Array = COMPOSER._route_fragments_for_chunk(route_source, Vector2i.ZERO, Vector2i.ZERO, 4)
	assert(first_fragments.size() == 1 and first_fragments[0].get("points", []).back() == Vector2i(4, 1), "First chunk must carry the boundary-crossing segment to the shared endpoint")
	first_chunk.free()

	var second_chunk := Node3D.new()
	var second_result := COMPOSER.compose_chunk(second_chunk, entry, Vector2i(4, 0), 4)
	assert(bool(second_result.get("ok", false)), "Second chunk should compose: %s" % second_result)
	assert(second_chunk.get_node_or_null("HouseA") == null, "Building must not be duplicated in adjacent chunk")
	assert(second_chunk.get_node_or_null("FieldA") == null, "Field must not be duplicated in adjacent chunk")
	var second_routes := second_chunk.find_children("*", "MeshInstance3D", true, false).filter(func(node): return String(node.name).begins_with("CrossChunkRoad_chunk_"))
	assert(second_routes.size() == 1, "Adjacent chunk should receive only its own clipped route segment")
	var second_fragments: Array = COMPOSER._route_fragments_for_chunk(route_source, Vector2i.ZERO, Vector2i(4, 0), 4)
	assert(second_fragments.size() == 1 and second_fragments[0].get("points", []).front() == Vector2i(4, 1), "Adjacent chunk must start at the same boundary endpoint")
	second_chunk.free()

func _test_empty_chunk_is_valid() -> void:
	var parent := Node3D.new()
	var entry := _definition()
	var result := COMPOSER.compose_chunk(parent, entry, Vector2i(40, 40), 4)
	assert(bool(result.get("ok", false)), "A chunk with no settlement features should be a valid empty composition")
	assert(parent.get_child_count() == 0, "Empty chunks should not receive stray presentation nodes")
	parent.free()
