class_name WorldSettlementFeatureComposer
extends RefCounted
## Chunk-scoped dispatcher for canonical settlement presentation features.
## Authored definitions remain immutable; each chunk owns only its disposable nodes.

const BUILDING_FACTORY = preload("res://scripts/world/world_building_factory.gd")
const POLYLINE_FACTORY = preload("res://scripts/world/world_polyline_feature_factory.gd")
const BRIDGE_FACTORY = preload("res://scripts/world/world_bridge_feature_factory.gd")
const AGRICULTURE_FACTORY = preload("res://scripts/world/world_agricultural_feature_factory.gd")
const PROP_FACTORY = preload("res://scripts/world/world_prop_feature_factory.gd")

static func compose_chunk(
	parent: Node3D,
	entry: Dictionary,
	chunk_min: Vector2i,
	chunk_size: int,
	hex_radius: float = HexGrid.DEFAULT_RADIUS_M
) -> Dictionary:
	if parent == null or entry.is_empty() or chunk_size <= 0 or hex_radius <= 0.0:
		return {"ok": false, "reason": "invalid_composition_input"}
	var settlement_id := String(entry.get("id", ""))
	var definition: Dictionary = entry.get("definition", {})
	var presentation: Dictionary = definition.get("presentation", {})
	if String(presentation.get("mode", "chunked")) != "chunked":
		return {"ok": true, "skipped": "presentation_mode"}
	var origin := _read_hex(entry.get("origin", Vector2i.ZERO))
	var layout: Dictionary = definition.get("layout", {})
	var material_groups := _resolve_material_groups(presentation)
	var buildings: Array = []
	var building_anchors: Dictionary = {}
	for source in layout.get("buildings", []):
		if not source is Dictionary:
			continue
		var building: Dictionary = source.duplicate(true)
		var centre := _read_hex(building.get("center", Vector2i.ZERO)) + origin
		building["center"] = centre
		if building.has("door"):
			building["door"] = _read_hex(building["door"]) + origin
		building_anchors[String(building.get("id", ""))] = centre
		building_anchors[String(building.get("node_name", building.get("id", "")))] = centre
		if _contains_chunk(centre, chunk_min, chunk_size):
			buildings.append(building)
	var created_buildings := 0
	for building in buildings:
		if BUILDING_FACTORY.create_building(parent, {"id": settlement_id}, building) != null:
			created_buildings += 1

	var route_fragments: Array = []
	for source_route in layout.get("paths", []):
		if not source_route is Dictionary or String(source_route.get("feature_type", "route")) != "route":
			continue
		route_fragments.append_array(_route_fragments_for_chunk(source_route, origin, chunk_min, chunk_size))
	var route_nodes: Array[Node3D] = POLYLINE_FACTORY.render_features(
		parent, route_fragments, material_groups.get("routes", {}), hex_radius
	)

	var bridge_count := 0
	for source_bridge in layout.get("bridges", []):
		if not source_bridge is Dictionary:
			continue
		var bridge: Dictionary = source_bridge.duplicate(true)
		var centre := _read_hex(bridge.get("centre", Vector2i.ZERO)) + origin
		bridge["centre"] = centre
		if _contains_chunk(centre, chunk_min, chunk_size):
			if BRIDGE_FACTORY.create_bridge(parent, bridge, material_groups.get("bridge", {}), hex_radius) != null:
				bridge_count += 1

	var fields: Array = []
	var crop_rows: Array = []
	var fences: Array = []
	for source_field in layout.get("fields", []):
		if not source_field is Dictionary:
			continue
		var feature_type := String(source_field.get("feature_type", ""))
		var feature := _translate_feature_coordinates(source_field, origin)
		var anchor := _agricultural_anchor(feature, feature_type)
		if not _contains_chunk(anchor, chunk_min, chunk_size):
			continue
		match feature_type:
			"field":
				fields.append(feature)
			"crop_row":
				crop_rows.append(feature)
			"fence":
				fences.append(feature)
	var agriculture_result := AGRICULTURE_FACTORY.render_features(
		parent, fields, crop_rows, fences, material_groups.get("agriculture", {}), hex_radius
	)

	var props_by_category := {
		"landmark_props": [],
		"quest_props": [],
		"wayfinding_props": []
	}
	for source_prop in layout.get("props", []):
		if not source_prop is Dictionary:
			continue
		var category := String(source_prop.get("feature_type", ""))
		if not props_by_category.has(category):
			continue
		var prop := _translate_feature_coordinates(source_prop, origin)
		var anchor := _prop_anchor(prop, building_anchors)
		if _contains_chunk(anchor, chunk_min, chunk_size):
			props_by_category[category].append(prop)
	var props_ok := true
	for category in props_by_category:
		var material_key: String = "props" if category == "landmark_props" else String(category)
		var ok := PROP_FACTORY.render_features(
			parent,
			props_by_category[category],
			material_groups.get(material_key, {}),
			hex_radius
		)
		props_ok = props_ok and ok

	var ok := (
		created_buildings == buildings.size()
		and route_nodes.size() == route_fragments.size()
		and bridge_count == _expected_bridge_count(layout.get("bridges", []), origin, chunk_min, chunk_size)
		and bool(agriculture_result.get("ok", false))
		and props_ok
	)
	return {
		"ok": ok,
		"settlement_id": settlement_id,
		"buildings": created_buildings,
		"routes": route_nodes.size(),
		"bridges": bridge_count,
		"fields": int(agriculture_result.get("fields", 0)),
		"crop_rows": int(agriculture_result.get("crop_rows", 0)),
		"fences": int(agriculture_result.get("fences", 0)),
		"props": props_by_category.get("landmark_props", []).size()
			+ props_by_category.get("quest_props", []).size()
			+ props_by_category.get("wayfinding_props", []).size()
	}

## Adapts the existing authored-location presentation envelope to the same
## canonical feature composer used by streamed settlements. This compatibility
## entry point deliberately keeps the location's ground/ecology/actors owned by
## WorldSettlementPresenter while feature geometry converges on one pipeline.
static func compose_location(
	parent: Node3D,
	location_definition: Dictionary,
	hex_radius: float = HexGrid.DEFAULT_RADIUS_M
) -> Dictionary:
	if parent == null or location_definition.is_empty():
		return {"ok": false, "reason": "invalid_location_input"}
	var feature_bundle: Dictionary = location_definition.get("features", {})
	var data: Dictionary = feature_bundle.get("data", {})
	var source_materials: Dictionary = feature_bundle.get("materials", {})
	var layout := {
		"buildings": _tag_records(data.get("buildings", []), "building"),
		"paths": _tag_records(data.get("routes", []), "route"),
		"bridges": [],
		"fields": [],
		"props": []
	}
	var bridge: Variant = data.get("bridge", {})
	if bridge is Dictionary and not bridge.is_empty():
		layout["bridges"].append(bridge.duplicate(true))
	layout["fields"].append_array(_tag_records(data.get("fields", []), "field"))
	layout["fields"].append_array(_tag_records(data.get("crop_rows", []), "crop_row"))
	layout["fields"].append_array(_tag_records(data.get("fences", []), "fence"))
	for category in ["landmark_props", "quest_props", "wayfinding_props"]:
		layout["props"].append_array(_tag_records(data.get(category, []), category))
	var entry := {
		"id": String(location_definition.get("id", "authored_location")),
		"origin": Vector2i.ZERO,
		"definition": {
			"presentation": {
				"mode": "chunked",
				"hex_radius": hex_radius,
				"palette": location_definition.get("palette", {}),
				"materials": source_materials
			},
			"layout": layout
		}
	}
	# A single encompassing axial window preserves the authored location's
	# existing one-shot lifecycle; streaming callers use compose_chunk directly.
	return compose_chunk(parent, entry, Vector2i(-256, -256), 512, hex_radius)

static func _tag_records(records: Array, feature_type: String) -> Array:
	var result: Array = []
	for source in records:
		if not source is Dictionary:
			continue
		var feature: Dictionary = source.duplicate(true)
		feature["feature_type"] = feature_type
		result.append(feature)
	return result

static func _route_fragments_for_chunk(
	source: Dictionary,
	origin: Vector2i,
	chunk_min: Vector2i,
	chunk_size: int
) -> Array:
	var result: Array = []
	var raw_points: Array = source.get("points", [])
	var raw_widths: Array = source.get("widths", [])
	if raw_points.is_empty() and source.has("from") and source.has("to"):
		raw_points = [source.get("from"), source.get("to")]
		var default_width := float(source.get("width", 2.2))
		raw_widths = [default_width, default_width]
	if raw_points.size() < 2 or raw_points.size() != raw_widths.size():
		return result
	var points: Array[Vector2i] = []
	for value in raw_points:
		points.append(_read_hex(value) + origin)
	var current_points: Array = []
	var current_widths: Array = []
	var fragment_index := 0
	for segment_index in range(points.size() - 1):
		var start := points[segment_index]
		var finish := points[segment_index + 1]
		var steps := maxi(1, HexGrid.distance(start, finish) * 2)
		for step in range(steps + 1):
			if segment_index > 0 and step == 0:
				continue
			var t := float(step) / float(steps)
			var sample := Vector2i(
				roundi(lerpf(float(start.x), float(finish.x), t)),
				roundi(lerpf(float(start.y), float(finish.y), t))
			)
			if _contains_chunk(sample, chunk_min, chunk_size):
				var width := lerpf(float(raw_widths[segment_index]), float(raw_widths[segment_index + 1]), t)
				if current_points.is_empty() or current_points.back() != sample:
					current_points.append(sample)
					current_widths.append(width)
				else:
					current_widths[current_widths.size() - 1] = width
			elif not current_points.is_empty():
				# Include the first sample beyond the chunk edge so the segment
				# crossing the boundary is owned by the chunk containing its start.
				# The adjacent chunk begins at that shared endpoint, avoiding a gap
				# without rendering the same crossing segment twice.
				if current_points.back() != sample:
					current_points.append(sample)
					current_widths.append(lerpf(float(raw_widths[segment_index]), float(raw_widths[segment_index + 1]), t))
				_append_route_fragment(result, source, current_points, current_widths, fragment_index)
				fragment_index += 1
				current_points = []
				current_widths = []
	if not current_points.is_empty():
		_append_route_fragment(result, source, current_points, current_widths, fragment_index)
	return result

static func _append_route_fragment(result: Array, source: Dictionary, points: Array, widths: Array, index: int) -> void:
	if points.size() < 2:
		return
	var fragment := source.duplicate(true)
	if String(fragment.get("material", "")).is_empty():
		fragment["material"] = "path"
	fragment["id"] = "%s_chunk_%d" % [String(source.get("id", "route")), index]
	fragment["points"] = points
	fragment["widths"] = widths
	result.append(fragment)

static func _translate_feature_coordinates(source: Dictionary, origin: Vector2i) -> Dictionary:
	var feature := source.duplicate(true)
	for key in ["anchor", "centre", "center"]:
		if feature.has(key):
			feature[key] = _read_hex(feature[key]) + origin
	for key in ["corners", "points"]:
		if feature.get(key) is Array:
			var translated: Array = []
			for value in feature[key]:
				translated.append(_read_hex(value) + origin)
			feature[key] = translated
	for part in feature.get("parts", []):
		if part is Dictionary and part.has("axial"):
			part["axial"] = _read_hex(part["axial"]) + origin
	return feature

static func _agricultural_anchor(feature: Dictionary, feature_type: String) -> Vector2i:
	var points: Array = feature.get("corners", feature.get("points", []))
	if points.is_empty():
		return _read_hex(feature.get("anchor", Vector2i.ZERO))
	var total := Vector2i.ZERO
	for point in points:
		total += _read_hex(point)
	return Vector2i(roundi(float(total.x) / float(points.size())), roundi(float(total.y) / float(points.size())))

static func _prop_anchor(prop: Dictionary, building_anchors: Dictionary) -> Vector2i:
	if prop.has("anchor"):
		return _read_hex(prop["anchor"])
	var parent_name := String(prop.get("parent_node", ""))
	return _read_hex(building_anchors.get(parent_name, Vector2i.ZERO))

static func _resolve_material_groups(presentation: Dictionary) -> Dictionary:
	var palette: Dictionary = presentation.get("palette", {})
	var bindings: Dictionary = presentation.get("materials", {})
	var resolved_palette: Dictionary = {}
	for key in palette:
		var value: Variant = palette[key]
		var colour := Color.WHITE
		var roughness := 0.9
		var metallic := 0.0
		if value is Color:
			colour = value
		elif value is Dictionary:
			colour = value.get("colour", Color.WHITE)
			roughness = float(value.get("roughness", 0.9))
			metallic = float(value.get("metallic", 0.0))
		elif value is String:
			colour = Color(value)
		var material := StandardMaterial3D.new()
		material.albedo_color = colour
		material.roughness = roughness
		material.metallic = metallic
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		if colour.a < 1.0:
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		resolved_palette[String(key)] = material
	var groups: Dictionary = {}
	for category in bindings:
		var group: Dictionary = {}
		var category_bindings: Dictionary = bindings[category]
		for material_name in category_bindings:
			var palette_key := String(category_bindings[material_name])
			if resolved_palette.has(palette_key):
				group[String(material_name)] = resolved_palette[palette_key]
		groups[String(category)] = group
	if not groups.has("routes"):
		var default_path := StandardMaterial3D.new()
		default_path.albedo_color = Color(0.43, 0.34, 0.23)
		default_path.roughness = 0.95
		groups["routes"] = {"path": default_path, "road": default_path}
	return groups

static func _expected_bridge_count(definitions: Array, origin: Vector2i, chunk_min: Vector2i, chunk_size: int) -> int:
	var count := 0
	for definition in definitions:
		if definition is Dictionary and _contains_chunk(_read_hex(definition.get("centre", Vector2i.ZERO)) + origin, chunk_min, chunk_size):
			count += 1
	return count

static func _contains_chunk(hex: Vector2i, chunk_min: Vector2i, chunk_size: int) -> bool:
	return hex.x >= chunk_min.x and hex.x < chunk_min.x + chunk_size and hex.y >= chunk_min.y and hex.y < chunk_min.y + chunk_size

static func _read_hex(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Dictionary:
		return Vector2i(int(value.get("q", 0)), int(value.get("r", 0)))
	return Vector2i.ZERO
