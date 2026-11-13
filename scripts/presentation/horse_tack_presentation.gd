class_name HorseTackPresentation
extends RefCounted
## Removable, shaped tack presentation for the Quaternius horse.
## Geometry is built in the imported horse's local space and inherits its scale.

const LEATHER := Color("#493020")
const DARK_LEATHER := Color("#241811")
const LEATHER_EDGE := Color("#241710")
const WOOL := Color("#8b795d")
const WOOL_DARK := Color("#62513d")
const METAL := Color("#77736a")

static func attach_to_horse(model_root: Node3D) -> Node3D:
	if model_root == null:
		return null
	var existing := model_root.get_node_or_null("HorseTack")
	if existing != null:
		return existing as Node3D

	var tack := Node3D.new()
	tack.name = "HorseTack"
	model_root.add_child(tack)

	# A shaped cloth numnah follows the back instead of sitting as a flat box.
	_add_saddle_surface(tack, "SaddleBlanket", 0.70, 0.91, 2.99, 0.02, WOOL, 0.035, 0.045)
	# The padded seat is a continuous curved surface with raised pommel and cantle.
	_add_saddle_surface(tack, "SaddleSeat", 0.48, 0.69, 3.105, 0.02, LEATHER, 0.075, 0.16)
	# Raised padded rolls form the pommel and cantle as part of the saddle.
	_add_saddle_roll(tack, "SaddlePommel", Vector3(0.0, 3.18, 0.47), Vector3(0.72, 0.20, 0.20))
	_add_saddle_roll(tack, "SaddleCantle", Vector3(0.0, 3.20, -0.53), Vector3(0.78, 0.23, 0.22))
	# Side skirts/flaps drape down over the horse's barrel.
	for side in [-1.0, 1.0]:
		_add_saddle_flap(tack, side)
		_add_ribbon(tack, "StirrupLeather%s" % ("Left" if side < 0.0 else "Right"), [
			Vector3(side * 0.51, 3.02, 0.06),
			Vector3(side * 0.59, 2.76, 0.02),
			Vector3(side * 0.62, 2.24, 0.00),
			Vector3(side * 0.62, 1.88, 0.00)
		], DARK_LEATHER, 0.105)
		_add_stirrup(tack, side)
		_add_ribbon(tack, "GirthSide%s" % ("Left" if side < 0.0 else "Right"), [
			Vector3(side * 0.57, 2.91, 0.12),
			Vector3(side * 0.61, 2.61, 0.12),
			Vector3(side * 0.59, 2.36, 0.12)
		], DARK_LEATHER, 0.13)

	# The girth passes beneath the barrel; visible side sections join below.
	_add_ribbon(tack, "SaddleGirth", [
		Vector3(-0.59, 2.36, 0.12), Vector3(-0.30, 2.29, 0.12),
		Vector3(0.0, 2.27, 0.12), Vector3(0.30, 2.29, 0.12),
		Vector3(0.59, 2.36, 0.12)
	], DARK_LEATHER, 0.13)

	# Bridle bands are curved ribbons that sit against the head, not floating cuboids.
	_add_ribbon(tack, "Crownpiece", [
		Vector3(-0.39, 3.19, 1.43), Vector3(-0.30, 3.32, 1.34),
		Vector3(0.0, 3.37, 1.30), Vector3(0.30, 3.32, 1.34),
		Vector3(0.39, 3.19, 1.43)
	], LEATHER, 0.075)
	_add_ribbon(tack, "Browband", [
		Vector3(-0.43, 3.02, 1.62), Vector3(-0.22, 3.08, 1.66),
		Vector3(0.0, 3.10, 1.67), Vector3(0.22, 3.08, 1.66),
		Vector3(0.43, 3.02, 1.62)
	], DARK_LEATHER, 0.065)
	_add_ribbon(tack, "Noseband", [
		Vector3(-0.38, 2.57, 2.26), Vector3(-0.22, 2.54, 2.31),
		Vector3(0.0, 2.53, 2.32), Vector3(0.22, 2.54, 2.31),
		Vector3(0.38, 2.57, 2.26)
	], DARK_LEATHER, 0.085)
	for side in [-1.0, 1.0]:
		var side_name := "Left" if side < 0.0 else "Right"
		_add_ribbon(tack, "Cheekpiece%s" % side_name, [
			Vector3(side * 0.39, 3.18, 1.43),
			Vector3(side * 0.42, 2.98, 1.65),
			Vector3(side * 0.40, 2.76, 1.94),
			Vector3(side * 0.38, 2.57, 2.26)
		], LEATHER, 0.065)
		_add_ribbon(tack, "Rein%s" % side_name, [
			Vector3(side * 0.38, 2.48, 2.32),
			Vector3(side * 0.46, 2.57, 1.90),
			Vector3(side * 0.50, 2.78, 1.35),
			Vector3(side * 0.48, 3.02, 0.70),
			Vector3(side * 0.43, 3.08, 0.38)
		], DARK_LEATHER, 0.043)
	_add_ribbon(tack, "Bit", [
		Vector3(-0.43, 2.47, 2.34), Vector3(-0.22, 2.44, 2.37),
		Vector3(0.0, 2.43, 2.38), Vector3(0.22, 2.44, 2.37),
		Vector3(0.43, 2.47, 2.34)
	], METAL, 0.045)
	return tack


static func _add_saddle_roll(parent: Node3D, node_name: String, position: Vector3, scale: Vector3) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 20
	mesh.rings = 10
	var node := _add_mesh(parent, node_name, mesh, LEATHER, 0.88)
	node.position = position
	node.scale = scale


static func _add_saddle_surface(parent: Node3D, node_name: String, half_width: float, half_length: float, base_y: float, centre_z: float, colour: Color, crown: float, end_raise: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var across := 16
	var along := 22
	for zi in range(along):
		var v0 := -1.0 + 2.0 * float(zi) / float(along)
		var v1 := -1.0 + 2.0 * float(zi + 1) / float(along)
		for xi in range(across):
			var u0 := -1.0 + 2.0 * float(xi) / float(across)
			var u1 := -1.0 + 2.0 * float(xi + 1) / float(across)
			var a := _saddle_point(u0, v0, half_width, half_length, base_y, centre_z, crown, end_raise)
			var b := _saddle_point(u1, v0, half_width, half_length, base_y, centre_z, crown, end_raise)
			var c := _saddle_point(u1, v1, half_width, half_length, base_y, centre_z, crown, end_raise)
			var d := _saddle_point(u0, v1, half_width, half_length, base_y, centre_z, crown, end_raise)
			st.add_vertex(a)
			st.add_vertex(b)
			st.add_vertex(c)
			st.add_vertex(a)
			st.add_vertex(c)
			st.add_vertex(d)
	st.generate_normals()
	var mesh := st.commit()
	_add_mesh(parent, node_name, mesh, colour, 0.9)


static func _saddle_point(u: float, v: float, half_width: float, half_length: float, base_y: float, centre_z: float, crown: float, end_raise: float) -> Vector3:
	var taper := 0.88 + 0.12 * cos(absf(v) * PI * 0.5)
	var x := u * half_width * taper
	var y := base_y + crown * (1.0 - u * u) + end_raise * pow(absf(v), 3.0)
	return Vector3(x, y, centre_z + v * half_length)


static func _add_saddle_flap(parent: Node3D, side: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows := 12
	var cols := 8
	for zi in range(rows):
		var v0 := -1.0 + 2.0 * float(zi) / float(rows)
		var v1 := -1.0 + 2.0 * float(zi + 1) / float(rows)
		for xi in range(cols):
			var u0 := float(xi) / float(cols)
			var u1 := float(xi + 1) / float(cols)
			var a := _flap_point(side, u0, v0)
			var b := _flap_point(side, u1, v0)
			var c := _flap_point(side, u1, v1)
			var d := _flap_point(side, u0, v1)
			st.add_vertex(a)
			st.add_vertex(b)
			st.add_vertex(c)
			st.add_vertex(a)
			st.add_vertex(c)
			st.add_vertex(d)
	st.generate_normals()
	_add_mesh(parent, "SaddleFlap%s" % ("Left" if side < 0.0 else "Right"), st.commit(), LEATHER, 0.92)


static func _flap_point(side: float, u: float, v: float) -> Vector3:
	var z := 0.02 + v * 0.62
	var top_x := side * (0.43 + 0.10 * (1.0 - absf(v)))
	var bottom_x := side * (0.57 + 0.04 * (1.0 - absf(v)))
	var x := lerpf(top_x, bottom_x, u)
	var top_y := 3.07 - 0.05 * absf(v)
	var bottom_y := 2.45 + 0.10 * absf(v)
	var y := lerpf(top_y, bottom_y, u) - 0.035 * sin(u * PI)
	return Vector3(x, y, z)


static func _add_stirrup(parent: Node3D, side: float) -> void:
	var centre := Vector3(side * 0.62, 1.84, 0.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var outer := 0.17
	var inner := 0.105
	var top := centre.y + 0.07
	var bottom := centre.y - 0.07
	var x := centre.x
	var z := centre.z
	var points := [
		Vector3(x - outer, top, z), Vector3(x + outer, top, z),
		Vector3(x + inner, bottom, z), Vector3(x - inner, bottom, z)
	]
	st.add_vertex(points[0]); st.add_vertex(points[1]); st.add_vertex(points[2])
	st.add_vertex(points[0]); st.add_vertex(points[2]); st.add_vertex(points[3])
	st.generate_normals()
	_add_mesh(parent, "Stirrup%s" % ("Left" if side < 0.0 else "Right"), st.commit(), METAL, 0.45)


static func _add_ribbon(parent: Node3D, node_name: String, points: Array, colour: Color, width: float) -> void:
	if points.size() < 2:
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(points.size() - 1):
		var p0: Vector3 = points[i]
		var p1: Vector3 = points[i + 1]
		var tangent := (p1 - p0).normalized()
		var width_axis := tangent.cross(Vector3.RIGHT)
		if width_axis.length_squared() < 0.001:
			width_axis = tangent.cross(Vector3.UP)
		width_axis = width_axis.normalized() * width * 0.5
		var a := p0 - width_axis
		var b := p0 + width_axis
		var c := p1 + width_axis
		var d := p1 - width_axis
		st.add_vertex(a); st.add_vertex(b); st.add_vertex(c)
		st.add_vertex(a); st.add_vertex(c); st.add_vertex(d)
	st.generate_normals()
	_add_mesh(parent, node_name, st.commit(), colour, 0.78)


static func _add_mesh(parent: Node3D, node_name: String, mesh: Mesh, colour: Color, roughness: float = 0.82) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = roughness
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	node.material_override = material
	parent.add_child(node)
	return node
