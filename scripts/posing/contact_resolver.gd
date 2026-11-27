extends RefCounted
## Resolves a press between a fingertip pad and a stack of surface layers
## (body tissue, garments, armour) using springs in series.
##
## Layer stack, ordered inner -> outer. Each layer is a Dictionary:
##   id: StringName
##   thickness_m: offset this layer adds above the layer beneath (include any air gap)
##   stiffness_n_per_m: spring constant for the contact patch
##   max_compression_m: bottom-out limit
##   bearing: bool. A rigid shell that spreads load. The load path stops here, so layers
##            beneath it are not compressed. (A helmet does not squash the nose.)
##
## Pad: {thickness_m, stiffness_n_per_m, max_compression_m}.
## approach_dir: unit vector from the surface towards where the finger comes from. Defaults to the
## surface normal; an oblique approach shifts the hover and bone offset along it. Compression is
## always measured along the surface normal.
## Same force passes through every spring in the path, so softer elements move further.

## Returns:
##   outer_point            outermost surface before loading
##   pad_surface_point      where the pad touches after loading
##   bone_tip               where the fingertip BONE must be (the IK target)
##   target_compression_m   how far the outer surface moved inward
##   pad_compression_m      how far the pad squashed
##   layer_compression      {id: metres} for every layer in the load path
##   bottomed_out           ids of layers that hit max_compression_m
##   force_n                force actually applied (0 while approaching)
static func resolve(surface_point: Vector3, surface_normal: Vector3, stack: Array, pad: Dictionary, approach_m: float = 0.0, force_n: float = 0.0, approach_dir: Vector3 = Vector3.ZERO) -> Dictionary:
	var n := surface_normal.normalized()
	var a := n if approach_dir.length_squared() < 1e-12 else approach_dir.normalized()
	var outer_offset := 0.0
	for layer in stack:
		outer_offset += float(layer["thickness_m"])
	var outer_point := surface_point + n * outer_offset

	var force := 0.0 if approach_m > 0.0 else maxf(0.0, force_n)
	var layer_compression := {}
	var bottomed: Array = []
	var target_compression := 0.0
	for i in range(stack.size() - 1, -1, -1):
		var layer: Dictionary = stack[i]
		var raw := force / maxf(1e-9, float(layer["stiffness_n_per_m"]))
		var limit := float(layer.get("max_compression_m", INF))
		var applied := minf(raw, limit)
		if raw > limit:
			bottomed.append(layer["id"])
		layer_compression[layer["id"]] = applied
		target_compression += applied
		if bool(layer.get("bearing", false)):
			break

	var pad_raw := force / maxf(1e-9, float(pad["stiffness_n_per_m"]))
	var pad_limit := float(pad.get("max_compression_m", INF))
	var pad_compression := minf(pad_raw, pad_limit)
	if pad_raw > pad_limit:
		bottomed.append(&"pad")

	var pad_surface := outer_point - n * target_compression + a * maxf(0.0, approach_m)
	var bone_tip := pad_surface + a * (float(pad["thickness_m"]) - pad_compression)
	return {
		"outer_point": outer_point,
		"pad_surface_point": pad_surface,
		"bone_tip": bone_tip,
		"target_compression_m": target_compression,
		"pad_compression_m": pad_compression,
		"layer_compression": layer_compression,
		"bottomed_out": bottomed,
		"force_n": force,
	}


## Loads data/posing/contact_materials.json: {"pads": {...}, "layers": {...}}.
## Returns {} (and pushes an error) if the file is missing or any entry is invalid.
static func load_materials(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("ContactResolver: missing %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("ContactResolver: %s is not a JSON object" % path)
		return {}
	for section in ["pads", "layers"]:
		if not parsed.has(section) or typeof(parsed[section]) != TYPE_DICTIONARY:
			push_error("ContactResolver: %s lacks '%s'" % [path, section])
			return {}
		for key in parsed[section]:
			var entry: Dictionary = parsed[section][key]
			if float(entry.get("stiffness_n_per_m", 0.0)) <= 0.0 or float(entry.get("thickness_m", -1.0)) < 0.0:
				push_error("ContactResolver: invalid material '%s' in %s" % [key, path])
				return {}
	return parsed


## Builds a stack layer from a materials entry.
static func layer_from_material(id: StringName, material: Dictionary) -> Dictionary:
	var layer := material.duplicate()
	layer["id"] = id
	return layer
