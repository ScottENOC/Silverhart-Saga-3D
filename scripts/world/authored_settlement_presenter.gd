class_name AuthoredSettlementPresenter
extends RefCounted
## Composes authored settlement data through shared world-feature factories.
## This class owns assembly order only; settlement-specific content remains data.

const BUILDING_FACTORY = preload("res://scripts/world/world_building_factory.gd")
const POLYLINE_FACTORY = preload("res://scripts/world/world_polyline_feature_factory.gd")
const BRIDGE_FACTORY = preload("res://scripts/world/world_bridge_feature_factory.gd")
const AGRICULTURE_FACTORY = preload("res://scripts/world/world_agricultural_feature_factory.gd")
const PROP_FACTORY = preload("res://scripts/world/world_prop_feature_factory.gd")

## Expected data keys:
## buildings, routes, bridge, fields, crop_rows, fences,
## landmark_props, quest_props, wayfinding_props.
## Material keys are feature-factory bindings, not settlement-specific globals.
static func present(
	parent: Node3D,
	settlement: Dictionary,
	data: Dictionary,
	materials: Dictionary,
	hex_radius: float
) -> Dictionary:
	if parent == null or settlement.is_empty() or hex_radius <= 0.0:
		return {"ok": false, "reason": "invalid_parent_settlement_or_scale"}
	var settlement_id := String(settlement.get("id", "")).strip_edges()
	if settlement_id.is_empty():
		return {"ok": false, "reason": "missing_settlement_id"}
	for key in ["buildings", "routes", "fields", "crop_rows", "fences",
			"landmark_props", "quest_props", "wayfinding_props"]:
		if not data.get(key, []) is Array:
			return {"ok": false, "reason": "invalid_%s" % key}
	var building_definitions: Array = data.get("buildings", [])
	var route_definitions: Array = data.get("routes", [])
	var field_definitions: Array = data.get("fields", [])
	var crop_row_definitions: Array = data.get("crop_rows", [])
	var fence_definitions: Array = data.get("fences", [])
	var landmark_definitions: Array = data.get("landmark_props", [])
	var quest_definitions: Array = data.get("quest_props", [])
	var wayfinding_definitions: Array = data.get("wayfinding_props", [])
	var bridge_definition: Variant = data.get("bridge", {})
	if not bridge_definition is Dictionary:
		return {"ok": false, "reason": "invalid_bridge_definition"}
	for building in building_definitions:
		if not building is Dictionary or not BUILDING_FACTORY.supports_definition(building):
			return {"ok": false, "reason": "unsupported_building_definition"}
	# Fail before constructing anything if a feature collection has invalid
	# shape. The underlying factories validate detailed geometry/material data.
	var created_buildings := 0
	for building in building_definitions:
		if BUILDING_FACTORY.create_building(parent, settlement, building) != null:
			created_buildings += 1
	var route_nodes: Array[Node3D] = POLYLINE_FACTORY.render_features(
		parent, route_definitions, materials.get("routes", {}), hex_radius
	)
	var bridge_node: Node3D = BRIDGE_FACTORY.create_bridge(
		parent, bridge_definition, materials.get("bridge", {}), hex_radius
	)
	var agriculture_result: Dictionary = AGRICULTURE_FACTORY.render_features(
		parent,
		field_definitions,
		crop_row_definitions,
		fence_definitions,
		materials.get("agriculture", {}),
		hex_radius
	)
	var landmark_ok: bool = PROP_FACTORY.render_features(
		parent, landmark_definitions, materials.get("props", {}), hex_radius
	)
	var quest_ok: bool = PROP_FACTORY.render_features(
		parent, quest_definitions, materials.get("quest_props", {}), hex_radius
	)
	var wayfinding_ok: bool = PROP_FACTORY.render_features(
		parent, wayfinding_definitions, materials.get("wayfinding_props", {}), hex_radius
	)
	var ok := (
		created_buildings == building_definitions.size()
		and route_nodes.size() == route_definitions.size()
		and bridge_node != null
		and bool(agriculture_result.get("ok", false))
		and landmark_ok and quest_ok and wayfinding_ok
	)
	return {
		"ok": ok,
		"settlement_id": settlement_id,
		"buildings": created_buildings,
		"routes": route_nodes.size(),
		"bridge": bridge_node != null,
		"agriculture": agriculture_result,
		"landmark_props": landmark_definitions.size() if landmark_ok else 0,
		"quest_props": quest_definitions.size() if quest_ok else 0,
		"wayfinding_props": wayfinding_definitions.size() if wayfinding_ok else 0
	}
