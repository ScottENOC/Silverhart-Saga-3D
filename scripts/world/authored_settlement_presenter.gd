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
	var bridge_definition: Variant = data.get("bridge", {})
	if not bridge_definition is Dictionary:
		return {"ok": false, "reason": "invalid_bridge_definition"}
	for building in data.get("buildings", []):
		if not building is Dictionary or not BUILDING_FACTORY.supports_definition(building):
			return {"ok": false, "reason": "unsupported_building_definition"}
	# Fail before constructing anything if a feature collection has invalid
	# shape. The underlying factories validate detailed geometry/material data.
	var created_buildings := 0
	for building in data.get("buildings", []):
		if BUILDING_FACTORY.create_building(parent, settlement, building) != null:
			created_buildings += 1
	var route_nodes: Array[Node3D] = POLYLINE_FACTORY.render_features(
		parent, data.get("routes", []), materials.get("routes", {}), hex_radius
	)
	var bridge_node: Node3D = BRIDGE_FACTORY.create_bridge(
		parent, bridge_definition, materials.get("bridge", {}), hex_radius
	)
	var agriculture_result: Dictionary = AGRICULTURE_FACTORY.render_features(
		parent,
		data.get("fields", []),
		data.get("crop_rows", []),
		data.get("fences", []),
		materials.get("agriculture", {}),
		hex_radius
	)
	var landmark_ok: bool = PROP_FACTORY.render_features(
		parent, data.get("landmark_props", []), materials.get("props", {}), hex_radius
	)
	var quest_ok: bool = PROP_FACTORY.render_features(
		parent, data.get("quest_props", []), materials.get("quest_props", {}), hex_radius
	)
	var wayfinding_ok: bool = PROP_FACTORY.render_features(
		parent, data.get("wayfinding_props", []), materials.get("wayfinding_props", {}), hex_radius
	)
	var ok := (
		created_buildings == data.get("buildings", []).size()
		and route_nodes.size() == data.get("routes", []).size()
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
		"landmark_props": data.get("landmark_props", []).size() if landmark_ok else 0,
		"quest_props": data.get("quest_props", []).size() if quest_ok else 0,
		"wayfinding_props": data.get("wayfinding_props", []).size() if wayfinding_ok else 0
	}
