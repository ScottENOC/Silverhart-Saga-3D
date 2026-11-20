class_name WorldBuildingFactory
extends RefCounted
## Shared procedural building presentation.
## Location/settlement scripts provide definitions; this factory owns construction.

const HEX_RADIUS: float = HexGrid.DEFAULT_RADIUS_M

const ARCHETYPES := {
	"cottage": {
		"width": 13.0, "depth": 12.0, "wall_height": 3.1, "roof_rise": 1.95,
		"foundation_colour": "#81796d", "floor_colour": "#40291c",
		"wall_colour": "#c5ae86", "timber_colour": "#68462d",
		"door_colour": "#40291c", "roof_colour": "#424a47",
		"glass_colour": "#52717a", "roof_style": "gable"
	},
	"shop": {
		"width": 15.0, "depth": 13.0, "wall_height": 3.4, "roof_rise": 2.0,
		"foundation_colour": "#81796d", "floor_colour": "#40291c",
		"wall_colour": "#c5ae86", "timber_colour": "#68462d",
		"door_colour": "#40291c", "roof_colour": "#424a47",
		"glass_colour": "#52717a", "roof_style": "gable"
	},
	"chapel": {
		"width": 15.0, "depth": 21.0, "wall_height": 4.2, "roof_rise": 2.8,
		"foundation_colour": "#81796d", "floor_colour": "#514638",
		"wall_colour": "#b9b3a3", "timber_colour": "#55483b",
		"door_colour": "#34271f", "roof_colour": "#454b50",
		"glass_colour": "#52717a", "roof_style": "gable"
	},
	"barn": {
		"width": 18.0, "depth": 14.0, "wall_height": 3.5, "roof_rise": 2.2,
		"foundation_colour": "#716b5c", "floor_colour": "#493323",
		"wall_colour": "#8c6846", "timber_colour": "#54351f",
		"door_colour": "#382719", "roof_colour": "#48443a",
		"glass_colour": "#52717a", "roof_style": "gable"
	},
	"manor": {
		"width": 21.0, "depth": 18.0, "wall_height": 4.0, "roof_rise": 2.5,
		"foundation_colour": "#81796d", "floor_colour": "#40291c",
		"wall_colour": "#c5ae86", "timber_colour": "#68462d",
		"door_colour": "#40291c", "roof_colour": "#424a47",
		"glass_colour": "#52717a", "roof_style": "gable"
	}
}

const KIND_TO_ARCHETYPE := {
	"house": "cottage",
	"cottage": "cottage",
	"shop": "shop",
	"general_store": "shop",
	"chapel": "chapel",
	"barn": "barn",
	"manor": "manor"
}

## Returns null for an invalid/unsupported definition instead of silently
## creating a misleading generic house.
static func create_building(parent: Node3D, settlement: Dictionary, definition: Dictionary) -> Node3D:
	if parent == null or definition.is_empty():
		return null
	var building_id := String(definition.get("id", "")).strip_edges()
	if building_id.is_empty():
		return null

	var archetype := _resolve_archetype(definition)
	if not ARCHETYPES.has(archetype):
		return null
	var config: Dictionary = ARCHETYPES[archetype].duplicate(true)
	var overrides: Variant = definition.get("dimensions", {})
	if overrides is Dictionary:
		for key in ["width", "depth", "wall_height", "roof_rise"]:
			if overrides.has(key):
				config[key] = float(overrides[key])
	if float(config.width) <= 2.0 or float(config.depth) <= 2.0 or float(config.wall_height) <= 1.5:
		return null

	var centre := _read_hex(definition.get("center", {}))
	var root := Node3D.new()
	root.name = building_id
	root.position = HexGrid.axial_to_world(centre, HEX_RADIUS)
	root.rotation.y = deg_to_rad(float(definition.get("rotation_degrees", -30.0)))
	parent.add_child(root)

	_build_shell(root, config, definition)
	_build_entrance(root, config, definition)
	_build_windows(root, config, definition)
	_build_roof(root, config)
	if _has_feature(definition, "fireplace"):
		_build_fireplace(root, config)

	root.set_meta("settlement_id", String(settlement.get("id", "")))
	root.set_meta("building_id", building_id)
	root.set_meta("archetype", archetype)
	root.set_meta("source_door_hex", _read_hex(definition.get("door", {})))
	return root

static func supports_definition(definition: Dictionary) -> bool:
	if String(definition.get("id", "")).strip_edges().is_empty():
		return false
	return ARCHETYPES.has(_resolve_archetype(definition))

static func archetype_ids() -> Array[String]:
	var result: Array[String] = []
	for key in ARCHETYPES:
		result.append(String(key))
	return result

static func _resolve_archetype(definition: Dictionary) -> String:
	var explicit := String(definition.get("archetype", definition.get("style", ""))).to_lower()
	if explicit in ["timber_cottage", "stone_cottage"]:
		return "cottage"
	if ARCHETYPES.has(explicit):
		return explicit
	var kind := String(definition.get("kind", "house")).to_lower()
	return String(KIND_TO_ARCHETYPE.get(kind, ""))

static func _build_shell(root: Node3D, config: Dictionary, definition: Dictionary) -> void:
	var width := float(config.width)
	var depth := float(config.depth)
	var height := float(config.wall_height)
	var foundation := _material(Color(config.foundation_colour))
	var floor := _material(Color(config.floor_colour))
	var plaster := _material(Color(config.wall_colour))
	var timber := _material(Color(config.timber_colour))
	_add_box(root, "Foundation", Vector3(0.0, 0.18, 0.0), Vector3(width + 0.2, 0.36, depth + 0.2), foundation)
	_add_box(root, "Floor", Vector3(0.0, 0.40, 0.0), Vector3(width - 0.6, 0.12, depth - 0.6), floor)

	var door_side := String(definition.get("door_side", "east")).to_lower()
	var door_width := clampf(float(definition.get("door_width", 2.1)), 0.8, minf(width, depth) * 0.45)
	var half_width := width * 0.5
	var half_depth := depth * 0.5
	_add_side(root, "NorthWall", Vector3(0.0, height * 0.5 + 0.4, -half_depth), width, 0.34, height, door_side == "north", door_width, plaster, timber)
	_add_side(root, "SouthWall", Vector3(0.0, height * 0.5 + 0.4, half_depth), width, 0.34, height, door_side == "south", door_width, plaster, timber)
	_add_side(root, "WestWall", Vector3(-half_width, height * 0.5 + 0.4, 0.0), depth, 0.34, height, door_side == "west", door_width, plaster, timber, true)
	_add_side(root, "EastWall", Vector3(half_width, height * 0.5 + 0.4, 0.0), depth, 0.34, height, door_side == "east", door_width, plaster, timber, true)

static func _add_side(parent: Node3D, label: String, centre: Vector3, length: float, thickness: float, height: float, has_door: bool, door_width: float, plaster: Material, timber: Material, along_z: bool = false) -> void:
	var segment_length := (length - door_width) * 0.5 if has_door else length
	if has_door:
		var offset := (door_width + segment_length) * 0.5
		_add_wall_segment(parent, label + "A", centre + (Vector3(0.0, 0.0, -offset) if along_z else Vector3(-offset, 0.0, 0.0)), Vector3(thickness, height, segment_length) if along_z else Vector3(segment_length, height, thickness), plaster, timber)
		_add_wall_segment(parent, label + "B", centre + (Vector3(0.0, 0.0, offset) if along_z else Vector3(offset, 0.0, 0.0)), Vector3(thickness, height, segment_length) if along_z else Vector3(segment_length, height, thickness), plaster, timber)
	else:
		_add_wall_segment(parent, label, centre, Vector3(thickness, height, length) if along_z else Vector3(length, height, thickness), plaster, timber)

static func _add_wall_segment(parent: Node3D, label: String, centre: Vector3, size: Vector3, plaster: Material, timber: Material) -> void:
	_add_box(parent, label + "_Plaster", centre, size, plaster)
	var beam_height := 0.18
	_add_box(parent, label + "_TopBeam", centre + Vector3(0.0, size.y * 0.5 - beam_height * 0.5, 0.0), Vector3(size.x, beam_height, size.z + 0.04), timber)
	_add_box(parent, label + "_BottomBeam", centre - Vector3(0.0, size.y * 0.5 - beam_height * 0.5, 0.0), Vector3(size.x, beam_height, size.z + 0.04), timber)

static func _build_entrance(root: Node3D, config: Dictionary, definition: Dictionary) -> void:
	var side := String(definition.get("door_side", "east")).to_lower()
	var width := float(config.width)
	var depth := float(config.depth)
	var half_width := width * 0.5
	var half_depth := depth * 0.5
	var offset := Vector3(half_width, 0.0, 0.0)
	match side:
		"west": offset = Vector3(-half_width, 0.0, 0.0)
		"north": offset = Vector3(0.0, 0.0, -half_depth)
		"south": offset = Vector3(0.0, 0.0, half_depth)
	var outward := Vector3.RIGHT if side == "east" else (Vector3.LEFT if side == "west" else (Vector3.BACK if side == "north" else Vector3.FORWARD))
	var timber := _material(Color(config.timber_colour))
	var door := _material(Color(config.door_colour))
	var frame_width := float(definition.get("door_width", 2.1))
	_add_box(root, "DoorFrame", offset + Vector3.UP * 1.55, Vector3(0.22, 2.75, frame_width), timber) if side in ["east", "west"] else _add_box(root, "DoorFrame", offset + Vector3.UP * 1.55, Vector3(frame_width, 2.75, 0.22), timber)
	var leaf_offset := offset + outward * 0.13 + Vector3.UP * 1.48
	_add_box(root, "DoorLeaf", leaf_offset, Vector3(0.12, 2.42, frame_width * 0.82), door) if side in ["east", "west"] else _add_box(root, "DoorLeaf", leaf_offset, Vector3(frame_width * 0.82, 2.42, 0.12), door)
	_add_box(root, "PorchStep", offset + outward * 0.75 + Vector3(0.0, 0.22, 0.0), Vector3(1.5, 0.3, 2.6), _material(Color(config.foundation_colour)))

static func _build_windows(root: Node3D, config: Dictionary, definition: Dictionary) -> void:
	var count := maxi(0, int(definition.get("windows_per_side", 2)))
	var glass := _material(Color(config.glass_colour), 0.22)
	var timber := _material(Color(config.timber_colour))
	var width := float(config.width)
	var depth := float(config.depth)
	var height := float(config.wall_height)
	for side in ["north", "south", "west", "east"]:
		if side == String(definition.get("door_side", "east")).to_lower():
			continue
		var along_z := side in ["west", "east"]
		var span := depth if along_z else width
		for index in range(count):
			var t := (float(index) + 1.0) / (float(count) + 1.0)
			var local := (t - 0.5) * (span - 2.0)
			var centre := Vector3(local, height * 0.67 + 0.4, -depth * 0.5 - 0.12) if side == "north" else Vector3(local, height * 0.67 + 0.4, depth * 0.5 + 0.12)
			if side == "west":
				centre = Vector3(-width * 0.5 - 0.12, height * 0.67 + 0.4, local)
			elif side == "east":
				centre = Vector3(width * 0.5 + 0.12, height * 0.67 + 0.4, local)
			var size := Vector3(1.45, 1.05, 0.08) if not along_z else Vector3(0.08, 1.05, 1.45)
			_add_box(root, "Window_%s_%d_Glass" % [side, index], centre, size, glass)
			var lintel_size := Vector3(size.x + 0.25, 0.16, size.z + 0.12)
			_add_box(root, "Window_%s_%d_Lintel" % [side, index], centre + Vector3.UP * 0.62, lintel_size, timber)

static func _build_roof(root: Node3D, config: Dictionary) -> void:
	if String(config.get("roof_style", "gable")) != "gable":
		return
	var width := float(config.width)
	var depth := float(config.depth)
	var rise := float(config.roof_rise)
	var half_run := width * 0.5 + 0.35
	var slope_length := Vector2(half_run, rise).length()
	var angle := atan2(rise, half_run)
	var roof := _material(Color(config.roof_colour))
	var ridge := _material(Color(config.timber_colour))
	var y := float(config.wall_height) + 0.4 + rise * 0.5
	var left := _add_box(root, "RoofLeftSlope", Vector3(-half_run * 0.5, y, 0.0), Vector3(slope_length, 0.3, depth + 0.8), roof)
	left.rotation.z = angle
	var right := _add_box(root, "RoofRightSlope", Vector3(half_run * 0.5, y, 0.0), Vector3(slope_length, 0.3, depth + 0.8), roof)
	right.rotation.z = -angle
	_add_box(root, "RoofRidge", Vector3(0.0, float(config.wall_height) + 0.4 + rise, 0.0), Vector3(0.3, 0.3, depth + 0.9), ridge)

static func _build_fireplace(root: Node3D, config: Dictionary) -> void:
	var stone := _material(Color(config.foundation_colour))
	var timber := _material(Color(config.timber_colour))
	var x := -float(config.width) * 0.36
	var z := -float(config.depth) * 0.36
	_add_box(root, "Chimney", Vector3(x, float(config.wall_height) + 1.2, z), Vector3(1.15, 3.1, 1.15), stone)
	_add_box(root, "FireplaceHearth", Vector3(x, 0.78, z - 0.95), Vector3(2.4, 0.55, 1.6), stone)
	_add_box(root, "FireplaceMantel", Vector3(x, 2.05, z - 1.55), Vector3(2.6, 0.20, 0.30), timber)

static func _has_feature(definition: Dictionary, feature: String) -> bool:
	var features: Variant = definition.get("features", [])
	return features is Array and features.has(feature)

static func _add_box(parent: Node3D, node_name: String, position: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = position
	instance.material_override = material
	parent.add_child(instance)
	return instance

static func _material(colour: Color, roughness: float = 0.88) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = roughness
	return material

static func _read_hex(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Dictionary:
		return Vector2i(int(value.get("q", 0)), int(value.get("r", 0)))
	return Vector2i.ZERO
