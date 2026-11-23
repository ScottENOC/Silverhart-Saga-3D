class_name WorldCanopySettlementPresentation
extends RefCounted
## Reusable presentation for data-authored treehouse/canopy settlements.
## Geometry is driven by each location's canopy_presentation definition.

const FLOOR_HEIGHT := 3.2

static func present_chunk(parent: Node3D, location_definition: Dictionary, chunk_min: Vector2i, chunk_size: int, hex_radius: float) -> Dictionary:
	if parent == null or location_definition.is_empty() or chunk_size <= 0 or hex_radius <= 0.0:
		return {"ok": false, "reason": "invalid_canopy_chunk_arguments"}
	var data: Dictionary = location_definition.get("canopy_presentation", {})
	if data.is_empty():
		return {"ok": true, "trunks": 0, "platforms": 0, "bridge_segments": 0, "branches": 0}
	var origin := Vector2i.ZERO
	var counts := {"ok": true, "trunks": 0, "platforms": 0, "bridge_segments": 0, "branches": 0}
	var trunk: Dictionary = data.get("tree_trunk", {})
	if not trunk.is_empty() and _contains(_read_hex(trunk.get("position", {})), chunk_min, chunk_size):
		_add_trunk(parent, trunk, origin, hex_radius)
		counts["trunks"] = 1
	for platform_variant in data.get("platforms", []):
		if not platform_variant is Dictionary:
			continue
		var platform: Dictionary = platform_variant
		if _contains(_read_hex(platform.get("center", {})), chunk_min, chunk_size):
			_add_platform(parent, platform, origin, hex_radius, false)
			counts["platforms"] = int(counts["platforms"]) + 1
	for branch_variant in data.get("branches", []):
		if not branch_variant is Dictionary:
			continue
		var branch: Dictionary = branch_variant
		var from_hex := _read_hex(branch.get("from", {}))
		var to_hex := _read_hex(branch.get("to", {}))
		var midpoint := (HexGrid.axial_to_world(from_hex, hex_radius) + HexGrid.axial_to_world(to_hex, hex_radius)) * 0.5
		midpoint.y = float(branch.get("floor", 1)) * FLOOR_HEIGHT
		if _contains(HexGrid.world_to_axial(midpoint, hex_radius), chunk_min, chunk_size):
			_add_branch(parent, branch, origin, hex_radius)
			counts["branches"] = int(counts["branches"]) + 1
	for bridge_variant in data.get("bridges", []):
		if bridge_variant is Dictionary:
			counts["bridge_segments"] = int(counts["bridge_segments"]) + _add_bridge(parent, bridge_variant, origin, hex_radius, false, chunk_min, chunk_size)
	return counts

static func present_trunk(parent: Node3D, location_definition: Dictionary, origin: Vector2i, hex_radius: float) -> bool:
	if parent == null or location_definition.is_empty() or hex_radius <= 0.0:
		return false
	var data: Dictionary = location_definition.get("canopy_presentation", {})
	var trunk: Dictionary = data.get("tree_trunk", {})
	if trunk.is_empty():
		return true
	_add_trunk(parent, trunk, origin, hex_radius)
	for branch_variant in data.get("branches", []):
		if branch_variant is Dictionary:
			_add_branch(parent, branch_variant, origin, hex_radius)
	return true

static func present_floor(parent: Node3D, location_definition: Dictionary, floor_number: int, origin: Vector2i, hex_radius: float) -> Dictionary:
	if parent == null or location_definition.is_empty() or hex_radius <= 0.0:
		return {"ok": false, "reason": "invalid_canopy_floor_arguments"}
	var data: Dictionary = location_definition.get("canopy_presentation", {})
	var platforms := 0
	var bridge_segments := 0
	for platform_variant in data.get("platforms", []):
		if platform_variant is Dictionary and int(platform_variant.get("floor", 0)) == floor_number:
			_add_platform(parent, platform_variant, origin, hex_radius, true)
			platforms += 1
	for bridge_variant in data.get("bridges", []):
		if bridge_variant is Dictionary and int(bridge_variant.get("floor", 0)) == floor_number:
			bridge_segments += _add_bridge(parent, bridge_variant, origin, hex_radius, true)
	return {"ok": true, "platforms": platforms, "bridge_segments": bridge_segments}

static func _add_trunk(parent: Node3D, data: Dictionary, origin: Vector2i, radius: float) -> void:
	var hex := _read_hex(data.get("position", {}))
	var height := float(data.get("height", 9.6))
	var root := Node3D.new()
	root.name = String(data.get("id", "CanopyTreeTrunk"))
	root.position = HexGrid.axial_to_world(hex - origin, radius)
	parent.add_child(root)
	var trunk := MeshInstance3D.new()
	trunk.name = "Trunk"
	var mesh := CylinderMesh.new()
	mesh.top_radius = float(data.get("top_radius", 0.8))
	mesh.bottom_radius = float(data.get("base_radius", 1.5))
	mesh.height = height
	mesh.radial_segments = 12
	trunk.mesh = mesh
	trunk.material_override = _material(Color("#59432e"))
	trunk.position.y = height * 0.5
	root.add_child(trunk)
	var root_radius := float(data.get("base_radius", 1.5)) * 1.7
	for index in range(6):
		var angle := TAU * float(index) / 6.0
		var root_mesh := MeshInstance3D.new()
		root_mesh.name = "Root_%02d" % index
		var root_shape := CylinderMesh.new()
		root_shape.top_radius = 0.12
		root_shape.bottom_radius = 0.28
		root_shape.height = 1.8
		root_shape.radial_segments = 6
		root_mesh.mesh = root_shape
		root_mesh.material_override = trunk.material_override
		root_mesh.position = Vector3(cos(angle) * root_radius * 0.42, 0.34, sin(angle) * root_radius * 0.42)
		root_mesh.rotation.z = cos(angle) * deg_to_rad(24.0)
		root_mesh.rotation.x = sin(angle) * deg_to_rad(24.0)
		root.add_child(root_mesh)

static func _add_platform(parent: Node3D, data: Dictionary, origin: Vector2i, radius: float, floor_relative: bool) -> void:
	var centre := _read_hex(data.get("center", {}))
	var floor_number := int(data.get("floor", 1))
	var height := 0.0 if floor_relative else float(floor_number) * FLOOR_HEIGHT
	var platform := Node3D.new()
	platform.name = "SilthandrielPlatform_" + String(data.get("id", "platform"))
	platform.position = HexGrid.axial_to_world(centre - origin, radius, height)
	parent.add_child(platform)
	var deck := MeshInstance3D.new()
	deck.name = "TimberDeck"
	var deck_mesh := CylinderMesh.new()
	deck_mesh.top_radius = float(data.get("radius_hexes", 4.0)) * radius
	deck_mesh.bottom_radius = deck_mesh.top_radius * 0.96
	deck_mesh.height = 0.24
	deck_mesh.radial_segments = 12
	deck.mesh = deck_mesh
	deck.material_override = _material(Color("#795b3d"))
	deck.position.y = -0.12
	platform.add_child(deck)
	var support_height := float(floor_number) * FLOOR_HEIGHT
	var support_radius := deck_mesh.top_radius * 0.76
	for index in range(4):
		var angle := TAU * float(index) / 4.0 + PI / 4.0
		var x := cos(angle) * support_radius
		var z := sin(angle) * support_radius
		var support := MeshInstance3D.new()
		support.name = "Support_%02d" % index
		var support_mesh := CylinderMesh.new()
		support_mesh.top_radius = 0.12
		support_mesh.bottom_radius = 0.16
		support_mesh.height = maxf(1.0, support_height)
		support_mesh.radial_segments = 6
		support.mesh = support_mesh
		support.material_override = _material(Color("#60472f"))
		support.position = Vector3(x, -support_height * 0.5, z)
		platform.add_child(support)
	if not bool(data.get("railings", true)):
		return
	var post_points: Array[Vector3] = []
	var rail_radius := deck_mesh.top_radius * 0.9
	for index in range(8):
		var angle := TAU * float(index) / 8.0
		var point := Vector3(cos(angle) * rail_radius, 0.55, sin(angle) * rail_radius)
		post_points.append(point)
		var post := MeshInstance3D.new()
		post.name = "RailingPost_%02d" % index
		var post_mesh := CylinderMesh.new()
		post_mesh.top_radius = 0.07
		post_mesh.bottom_radius = 0.09
		post_mesh.height = 1.1
		post_mesh.radial_segments = 6
		post.mesh = post_mesh
		post.material_override = _material(Color("#60472f"))
		post.position = point
		platform.add_child(post)
	for index in range(post_points.size()):
		var first := post_points[index] + Vector3(0.0, 0.18, 0.0)
		var second := post_points[(index + 1) % post_points.size()] + Vector3(0.0, 0.18, 0.0)
		_add_beam(platform, "Railing_%02d" % index, first, second, 0.045, Color("#b18a5d"))

static func _add_branch(parent: Node3D, data: Dictionary, origin: Vector2i, radius: float) -> void:
	var from_hex := _read_hex(data.get("from", {}))
	var to_hex := _read_hex(data.get("to", {}))
	var floor_number := int(data.get("floor", 1))
	var height := float(floor_number) * FLOOR_HEIGHT
	var start := HexGrid.axial_to_world(from_hex - origin, radius, height)
	var finish := HexGrid.axial_to_world(to_hex - origin, radius, height)
	if start.distance_to(finish) < 0.01:
		return
	_add_beam(parent, "SilthandrielBranch_" + String(data.get("id", "branch")), start, finish, 0.32, Color("#59432e"))

static func _add_bridge(parent: Node3D, data: Dictionary, origin: Vector2i, radius: float, floor_relative: bool, chunk_min: Vector2i = Vector2i.ZERO, chunk_size: int = 0) -> int:
	var from_hex := _read_hex(data.get("from", {}))
	var to_hex := _read_hex(data.get("to", {}))
	var floor_number := int(data.get("floor", 1))
	var base_y := 0.0 if floor_relative else float(floor_number) * FLOOR_HEIGHT
	var start := HexGrid.axial_to_world(from_hex - origin, radius, base_y)
	var finish := HexGrid.axial_to_world(to_hex - origin, radius, base_y)
	var segment_count := maxi(4, int(data.get("segments", 14)))
	var width := float(data.get("width", 1.2))
	var direction := Vector3(finish.x - start.x, 0.0, finish.z - start.z)
	if direction.length() < 0.01:
		return 0
	direction = direction.normalized()
	var side := Vector3(-direction.z, 0.0, direction.x) * width * 0.5
	var spawned := 0
	for index in range(segment_count):
		var first := start.lerp(finish, float(index) / float(segment_count))
		var second := start.lerp(finish, float(index + 1) / float(segment_count))
		var midpoint := (first + second) * 0.5
		if chunk_size > 0:
			var midpoint_hex := HexGrid.world_to_axial(midpoint, radius) + origin
			if not _contains(midpoint_hex, chunk_min, chunk_size):
				continue
		var plank := MeshInstance3D.new()
		plank.name = "SilthandrielBridge_%s_Plank_%02d" % [String(data.get("id", "rope_bridge")), index]
		var plank_mesh := BoxMesh.new()
		plank_mesh.size = Vector3(width, 0.14, maxf(0.25, first.distance_to(second) + 0.12))
		plank.mesh = plank_mesh
		plank.material_override = _material(Color("#92704a"))
		plank.position = midpoint + Vector3(0.0, -0.13, 0.0)
		plank.rotation.y = atan2(direction.x, direction.z)
		parent.add_child(plank)
		for side_index in range(2):
			var offset := side if side_index == 0 else -side
			_add_beam(parent, "SilthandrielBridge_%s_Rope_%02d_%d" % [String(data.get("id", "rope_bridge")), index, side_index], first + offset + Vector3(0.0, 0.56, 0.0), second + offset + Vector3(0.0, 0.56, 0.0), 0.045, Color("#a9865c"))
		spawned += 1
	return spawned

static func _add_beam(parent: Node3D, node_name: String, first: Vector3, second: Vector3, beam_radius: float, colour: Color) -> void:
	var direction := second - first
	var length := direction.length()
	if length < 0.01:
		return
	var beam := MeshInstance3D.new()
	beam.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = beam_radius
	mesh.bottom_radius = beam_radius
	mesh.height = length
	mesh.radial_segments = 6
	beam.mesh = mesh
	beam.material_override = _material(colour)
	beam.position = (first + second) * 0.5
	beam.rotation = Vector3(PI * 0.5, atan2(direction.x, direction.z), 0.0)
	parent.add_child(beam)

static func _material(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.88
	return material

static func _read_hex(value: Variant) -> Vector2i:
	if value is Dictionary:
		return Vector2i(int(value.get("q", 0)), int(value.get("r", 0)))
	return Vector2i.ZERO

static func _contains(hex: Vector2i, chunk_min: Vector2i, chunk_size: int) -> bool:
	return hex.x >= chunk_min.x and hex.x < chunk_min.x + chunk_size and hex.y >= chunk_min.y and hex.y < chunk_min.y + chunk_size
