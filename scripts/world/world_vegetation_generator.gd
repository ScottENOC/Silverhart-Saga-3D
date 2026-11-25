class_name WorldVegetationGenerator
extends RefCounted
## Shared runtime vegetation placement and instancing for every world location.
## Locations provide terrain/biome predicates and family-selection rules; this
## class owns deterministic placement, variation, scaling and model loading.

const ASSET_ROOT := "res://art/environment/trees/cosmo_generated/"
const FAMILY_VARIANTS := {
	"ash": 4,
	"bush": 4,
	"cherry": 4,
	"laurel": 4,
	"low_poly_bush": 4,
	"low_poly_tree": 6,
	"pine": 4,
	"spruce": 4,
	"tree_fern": 4,
	"willow": 4,
	"winter_oak": 6
}

static var _scene_cache: Dictionary = {}

static func generate_hex_grid(
	parent: Node3D,
	min_q: int,
	max_q: int,
	min_r: int,
	max_r: int,
	spacing: int,
	hex_radius: float,
	candidate_filter: Callable,
	density_offset: Vector2i,
	density_threshold: float,
	family_selector: Callable,
	scale_min: float,
	scale_range: float,
	node_prefix: String,
	is_understorey: bool = false
) -> int:
	if parent == null or spacing <= 0 or candidate_filter.is_null() or family_selector.is_null():
		push_warning("World vegetation generation received an incomplete grid configuration.")
		return 0

	var spawned := 0
	for q in range(min_q, max_q + 1, spacing):
		for r in range(min_r, max_r + 1, spacing):
			var hex := Vector2i(q, r)
			if not bool(candidate_filter.call(hex)):
				continue
			var density_roll := stable_noise(q + density_offset.x, r + density_offset.y)
			if density_roll < density_threshold:
				continue
			var family := String(family_selector.call(hex, density_roll))
			var size_roll := stable_noise(q + 811, r - 617)
			var scale_factor := scale_min + size_roll * scale_range
			if family == "low_poly_tree":
				scale_factor *= 0.92
			elif family == "tree_fern":
				scale_factor *= 0.88
			var jitter_x := (stable_noise(q + 31, r + 19) - 0.5) * 1.5
			var jitter_z := (stable_noise(q - 43, r + 71) - 0.5) * 1.5
			var position := HexGrid.axial_to_world(hex, hex_radius) + Vector3(jitter_x, 0.0, jitter_z)
			var seed_value := int(stable_noise(q + 137, r - 53) * 2147483646.0)
			var rotation_y := stable_noise(q + 503, r - 907) * TAU
			var node_name := "%s_%03d" % [node_prefix, spawned]
			if _spawn_model(parent, family, seed_value, position, scale_factor, rotation_y, node_name, hex, is_understorey):
				spawned += 1
	return spawned

## Generates only the deterministic vegetation candidates owned by one world
## chunk. Candidate and biome rules remain in settlement data; the shared
## generator owns stable placement, asset selection and instancing.
static func generate_settlement_chunk(
	parent: Node3D,
	chunk_min: Vector2i,
	chunk_size: int,
	hex_radius: float,
	vegetation: Dictionary,
	origin: Vector2i = Vector2i.ZERO
) -> Dictionary:
	if parent == null or chunk_size <= 0 or hex_radius <= 0.0:
		return {"ok": false, "forest": 0, "understorey": 0}
	var counts := {"ok": true, "forest": 0, "understorey": 0}
	for pass_name in ["forest", "understorey"]:
		var pass_definition: Dictionary = vegetation.get(pass_name, {})
		if pass_definition.is_empty():
			continue
		var candidate_script: Variant = pass_definition.get("candidate_script")
		var selector_script: Variant = pass_definition.get("selector_script")
		var candidate_method := String(pass_definition.get("candidate_method", ""))
		var selector_method := String(pass_definition.get("selector_method", ""))
		if not candidate_script is Script or not selector_script is Script or candidate_method.is_empty() or selector_method.is_empty():
			counts["ok"] = false
			continue
		var candidate_filter := Callable(candidate_script, candidate_method).bind(pass_definition.get("candidate_context", {}))
		var family_selector := Callable(selector_script, selector_method).bind(pass_definition.get("selector_context", {}))
		var spacing := int(pass_definition.get("spacing", 1))
		if spacing <= 0:
			counts["ok"] = false
			continue
		var local_min := chunk_min - origin
		var local_max := chunk_min + Vector2i(chunk_size - 1, chunk_size - 1) - origin
		# Align each chunk to the same zero-anchored lattice as the former
		# location-wide pass. Chunk boundaries therefore cannot shift candidates.
		var first_q := ceili(float(local_min.x) / float(spacing)) * spacing
		var first_r := ceili(float(local_min.y) / float(spacing)) * spacing
		var spawned := 0
		for q in range(first_q, local_max.x + 1, spacing):
			for r in range(first_r, local_max.y + 1, spacing):
				var local_hex := Vector2i(q, r)
				if not bool(candidate_filter.call(local_hex)):
					continue
				var offset: Vector2i = pass_definition.get("density_offset", Vector2i.ZERO)
				var density_roll := stable_noise(q + offset.x, r + offset.y)
				if density_roll < float(pass_definition.get("density_threshold", 0.0)):
					continue
				var family := String(family_selector.call(local_hex, density_roll))
				if family.is_empty():
					continue
				var size_roll := stable_noise(q + 811, r - 617)
				var scale_factor := float(pass_definition.get("scale_min", 0.78)) + size_roll * float(pass_definition.get("scale_range", 0.46))
				if family == "low_poly_tree":
					scale_factor *= 0.92
				elif family == "tree_fern":
					scale_factor *= 0.88
				var jitter_x := (stable_noise(q + 31, r + 19) - 0.5) * 1.5
				var jitter_z := (stable_noise(q - 43, r + 71) - 0.5) * 1.5
				var world_hex := local_hex + origin
				var position := HexGrid.axial_to_world(world_hex, hex_radius) + Vector3(jitter_x, 0.0, jitter_z)
				var seed_value := int(stable_noise(q + 137, r - 53) * 2147483646.0)
				var rotation_y := stable_noise(q + 503, r - 907) * TAU
				var prefix := String(pass_definition.get("node_prefix", "SettlementVegetation"))
				var node_name := "%s_%d_%d" % [prefix, q, r]
				if _spawn_model(parent, family, seed_value, position, scale_factor, rotation_y, node_name, world_hex, bool(pass_definition.get("understorey", pass_name == "understorey"))):
					spawned += 1
		counts[pass_name] = spawned
	return counts

static func generate_authored_placements(parent: Node3D, placements: Array[Dictionary]) -> int:
	if parent == null:
		return 0
	var spawned := 0
	for placement in placements:
		var family := String(placement.get("family", ""))
		var position: Vector3 = placement.get("position", Vector3.ZERO)
		var seed_value := int(placement.get("seed", spawned + 1))
		var scale_factor := float(placement.get("scale", 1.0))
		var rotation_y := float(placement.get("rotation_y", stable_noise(seed_value + 503, seed_value - 907) * TAU))
		var node_name := String(placement.get("name", "WorldVegetation_%03d" % spawned))
		if _spawn_model(parent, family, seed_value, position, scale_factor, rotation_y, node_name, Vector2i.ZERO, false):
			spawned += 1
	return spawned

static func catalogue_asset_count() -> int:
	var count := 0
	for family in FAMILY_VARIANTS:
		for variant in range(1, int(FAMILY_VARIANTS[family]) + 1):
			var path := ASSET_ROOT + "%s_%02d.glb" % [family, variant]
			if ResourceLoader.exists(path):
				count += 1
	return count

static func stable_noise(q: int, r: int) -> float:
	var value: int = posmod(q * 92837111 + r * 689287499 + 1013904223, 2147483647)
	return float(value) / 2147483647.0

static func _spawn_model(
	parent: Node3D,
	family: String,
	seed_value: int,
	position: Vector3,
	scale_factor: float,
	rotation_y: float,
	node_name: String,
	hex: Vector2i,
	is_understorey: bool
) -> bool:
	var variants: Array = _load_family(family)
	if variants.is_empty():
		push_error("Unknown or unavailable world vegetation family: %s" % family)
		return false
	var variant_index := posmod(seed_value, variants.size())
	var packed := variants[variant_index] as PackedScene
	if packed == null:
		return false
	var vegetation := packed.instantiate() as Node3D
	if vegetation == null:
		push_error("World vegetation model root is not Node3D: %s" % family)
		return false
	vegetation.name = node_name
	vegetation.position = position
	vegetation.scale = Vector3.ONE * scale_factor
	vegetation.rotation.y = rotation_y
	vegetation.set_meta("vegetation_family", family)
	vegetation.set_meta("vegetation_seed", seed_value)
	vegetation.set_meta("vegetation_hex", hex)
	vegetation.set_meta("vegetation_understorey", is_understorey)
	parent.add_child(vegetation)
	return true

static func _load_family(family: String) -> Array:
	if _scene_cache.has(family):
		return _scene_cache[family]
	if not FAMILY_VARIANTS.has(family):
		return []
	var variants: Array[PackedScene] = []
	for variant in range(1, int(FAMILY_VARIANTS[family]) + 1):
		var path := ASSET_ROOT + "%s_%02d.glb" % [family, variant]
		var packed := load(path) as PackedScene
		if packed == null:
			push_error("Could not load world vegetation model: %s" % path)
			continue
		variants.append(packed)
	_scene_cache[family] = variants
	return variants
