extends SceneTree

const COMPOSER = preload("res://scripts/world/world_settlement_feature_composer.gd")
const HOLLOWMERE_PRESENTATION = preload("res://data/settlements/hollowmere/presentation.gd")
const TERRAIN_DATA = preload("res://scripts/world/campaign2_world_terrain_data.gd")

func _initialize() -> void:
	_test_chunk_ownership_and_route_clipping()
	_test_empty_chunk_is_valid()
	_test_hollowmere_location_uses_shared_composer()
	_test_silverhart_city_composes_all_source_props()
	_test_goblin_scout_note_composes_as_streamed_prop()
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


func _test_silverhart_city_composes_all_source_props() -> void:
	var terrain = TERRAIN_DATA.new()
	var silverhart_entry: Dictionary = {}
	for entry in terrain.settlement_layouts:
		if String(entry.get("id", "")) == "silverhart":
			silverhart_entry = entry
			break
	assert(not silverhart_entry.is_empty(), "Silverhart canonical layout must be available to the chunk composer")
	var buildings := 0
	var props := 0
	var curtain_wall_segments := 0
	var city_wall_segments := 0
	var palace_towers := 0
	var city_towers := 0
	var gate_arches := 0
	# Cover the complete source layout, including the Warrens beyond the
	# radius-60 wall. Each feature must be owned by exactly one 24-hex chunk.
	for chunk_q in range(-3, 3):
		for chunk_r in range(-24, -17):
			var parent := Node3D.new()
			var chunk_min := Vector2i(chunk_q, chunk_r) * 24
			var result: Dictionary = COMPOSER.compose_chunk(
				parent, silverhart_entry, chunk_min, 24, HexGrid.DEFAULT_RADIUS_M
			)
			assert(bool(result.get("ok", false)), "Silverhart chunk must compose without errors: %s" % result)
			buildings += int(result.get("buildings", 0))
			props += int(result.get("props", 0))
			for child in parent.get_children():
				var node_name := String(child.name)
				if node_name.begins_with("silverhart_curtain_wall_"):
					curtain_wall_segments += 1
				elif node_name.begins_with("silverhart_city_wall_watchtower_"):
					city_towers += 1
				elif node_name.begins_with("silverhart_city_wall_"):
					city_wall_segments += 1
				elif node_name.begins_with("silverhart_watchtower_"):
					palace_towers += 1
				elif node_name == "silverhart_city_gate_arch":
					gate_arches += 1
			parent.free()
	assert(buildings == 40, "All 40 source Silverhart buildings must be presented once across streamed chunks")
	assert(props == 512, "All 512 remaining source Silverhart props must be presented once across streamed chunks")
	assert(curtain_wall_segments == 138, "Palace curtain wall must present all 138 radius-23 palisade segments")
	assert(city_wall_segments == 357, "Outer city wall must present all 357 segments around its three-cell gate")
	assert(palace_towers == 7, "Palace curtain wall must present its seven source watchtowers")
	assert(city_towers == 2, "Outer city wall must present both source gate watchtowers")
	assert(gate_arches == 1, "Outer city gate must present its source arch")


func _test_goblin_scout_note_composes_as_streamed_prop() -> void:
	var terrain = TERRAIN_DATA.new()
	var camp_entry: Dictionary = {}
	for entry in terrain.settlement_layouts:
		if String(entry.get("id", "")) == "skarn_tooth_camp":
			camp_entry = entry
			break
	assert(not camp_entry.is_empty(), "Skarn-tooth Camp canonical layout must be available to the chunk composer")
	var parent := Node3D.new()
	var result: Dictionary = COMPOSER.compose_chunk(parent, camp_entry, Vector2i(192, 0), 24, HexGrid.DEFAULT_RADIUS_M)
	assert(bool(result.get("ok", false)), "Goblin camp chunk must compose without errors: %s" % result)
	assert(int(result.get("props", 0)) == 1, "Goblin camp chunk must present its single source scout-note prop")
	var note := parent.get_node_or_null("skarn_tooth_goblin_scout_note")
	assert(note != null, "Goblin scout note must be emitted by the streamed quest-prop presenter")
	assert(note.get_node_or_null("Parchment") != null, "Goblin scout note must include its parchment surface")
	assert(note.get_node_or_null("InkLineOne") != null, "Goblin scout note must include its ink marks")
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
