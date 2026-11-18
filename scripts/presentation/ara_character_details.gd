class_name AraCharacterDetails
extends Node3D
## Reusable cosmetic details for Ara characters: socket-mounted jewellery and
## lightweight surface-line tattoo overlays. Profiles own the requested design.

var _target: Node3D
var _details: Dictionary = {}
var _ink_material: StandardMaterial3D
var _metal_material: StandardMaterial3D

func configure(target: Node3D, details: Dictionary) -> void:
    clear()
    _target = target
    _details = details.duplicate(true)
    if _target == null or _details.is_empty():
        return
    _metal_material = StandardMaterial3D.new()
    _metal_material.albedo_color = Color("#c6cbd0")
    _metal_material.metallic = 0.82
    _metal_material.roughness = 0.24
    _ink_material = StandardMaterial3D.new()
    _ink_material.albedo_color = Color.from_string(str(_details.get("tattoo_ink", "#28252d")), Color("#28252d"))
    _ink_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
    _ink_material.roughness = 1.0
    _add_piercings(_details.get("piercings", []))
    _add_tattoos(_details.get("tattoos", []))

func clear() -> void:
    for child in get_children():
        child.queue_free()
    _target = null
    _details.clear()

func _add_piercings(piercings: Array) -> void:
    for piercing_variant in piercings:
        var piercing := String(piercing_variant)
        match piercing:
            "earrings":
                _add_socket_hoop("SOCKET_Earring_L", 0.012)
                _add_socket_hoop("SOCKET_Earring_R", 0.012)
            "nipple_left":
                _add_socket_hoop("SOCKET_Nipple_L", 0.008)
            "clit":
                _add_socket_barbell("SOCKET_ClitoralHood")
            _:
                push_warning("Unknown Ara piercing profile entry: " + piercing)

func _find_named_node(root: Node, wanted: String) -> Node3D:
    if root is Node3D and root.name == wanted:
        return root as Node3D
    for child in root.get_children():
        var found := _find_named_node(child, wanted)
        if found != null:
            return found
    return null

func _add_socket_hoop(socket_name: String, radius: float) -> void:
    var socket := _find_named_node(_target, socket_name)
    if socket == null:
        push_warning("Ara character detail socket is missing: " + socket_name)
        return
    var hoop := MeshInstance3D.new()
    hoop.name = "Piercing_" + socket_name
    var torus := TorusMesh.new()
    torus.inner_radius = radius * 0.78
    torus.outer_radius = radius
    torus.rings = 12
    torus.ring_segments = 24
    hoop.mesh = torus
    hoop.material_override = _metal_material
    add_child(hoop)
    hoop.global_transform = socket.global_transform
    hoop.position += socket.global_basis.z.normalized() * 0.002

func _add_socket_barbell(socket_name: String) -> void:
    var socket := _find_named_node(_target, socket_name)
    if socket == null:
        push_warning("Ara character detail socket is missing: " + socket_name)
        return
    var centre := socket.global_position
    var normal := socket.global_basis.z.normalized()
    var tangent := socket.global_basis.x.normalized()
    var bar := MeshInstance3D.new()
    bar.name = "Piercing_" + socket_name + "_bar"
    var cylinder := CylinderMesh.new()
    cylinder.top_radius = 0.0018
    cylinder.bottom_radius = 0.0018
    cylinder.height = 0.014
    cylinder.radial_segments = 8
    bar.mesh = cylinder
    bar.material_override = _metal_material
    add_child(bar)
    bar.global_position = centre + normal * 0.002
    bar.global_basis = Basis(normal, tangent, normal.cross(tangent).normalized()).orthonormalized()
    for side in [-1.0, 1.0]:
        var bead := MeshInstance3D.new()
        bead.name = "Piercing_" + socket_name + "_bead"
        var sphere := SphereMesh.new()
        sphere.radius = 0.003
        sphere.height = 0.006
        bead.mesh = sphere
        bead.material_override = _metal_material
        add_child(bead)
        bead.global_position = centre + normal * 0.002 + tangent * side * 0.008

func _get_target_bounds() -> AABB:
    var result := AABB()
    var has_bounds := false
    var meshes: Array[MeshInstance3D] = []
    _collect_meshes(_target, meshes)
    for mesh_instance in meshes:
        if mesh_instance.mesh == null:
            continue
        var local_bounds := mesh_instance.mesh.get_aabb()
        var transform := _target.global_transform.affine_inverse() * mesh_instance.global_transform
        for corner in [
            local_bounds.position,
            local_bounds.position + Vector3(local_bounds.size.x, 0, 0),
            local_bounds.position + Vector3(0, local_bounds.size.y, 0),
            local_bounds.position + Vector3(0, 0, local_bounds.size.z),
            local_bounds.position + Vector3(local_bounds.size.x, local_bounds.size.y, 0),
            local_bounds.position + Vector3(local_bounds.size.x, 0, local_bounds.size.z),
            local_bounds.position + Vector3(0, local_bounds.size.y, local_bounds.size.z),
            local_bounds.end
        ]:
            var point := transform * corner
            if not has_bounds:
                result = AABB(point, Vector3.ZERO)
                has_bounds = true
            else:
                result = result.expand(point)
    return result

func _collect_meshes(node: Node, output: Array[MeshInstance3D]) -> void:
    if node is MeshInstance3D:
        output.append(node as MeshInstance3D)
    for child in node.get_children():
        _collect_meshes(child, output)

func _add_tattoos(tattoos: Array) -> void:
    if tattoos.is_empty():
        return
    var bounds := _get_target_bounds()
    if bounds.size.length() <= 0.001:
        push_warning("Ara tattoos skipped: character mesh bounds unavailable")
        return
    var centre := bounds.get_center()
    var size := bounds.size
    var front_z := bounds.position.z + size.z * 0.53
    var back_z := bounds.position.z + size.z * 0.47
    for tattoo_variant in tattoos:
        var tattoo: Dictionary = tattoo_variant if tattoo_variant is Dictionary else {"design": String(tattoo_variant)}
        match str(tattoo.get("design", "")):
            "mirabel_arcane":
                _add_mirabel_arcane(centre, size, back_z, front_z)
            "reyna_shoulder_back":
                _add_reyna_back(centre, size, back_z)
            _:
                push_warning("Unknown Ara tattoo profile design: " + str(tattoo.get("design", "")))

func _add_mirabel_arcane(centre: Vector3, size: Vector3, back_z: float, front_z: float) -> void:
    var ink := _ink_material
    var back := back_z - 0.003
    var front := front_z + 0.003
    var shoulder_y := centre.y + size.y * 0.29
    var mid_y := centre.y + size.y * 0.12
    # Fine-line constellation and rune work across the shoulder blades and spine.
    _add_tube([Vector3(centre.x, shoulder_y, back), Vector3(centre.x - size.x * .08, shoulder_y - size.y * .035, back), Vector3(centre.x, mid_y, back), Vector3(centre.x + size.x * .08, shoulder_y - size.y * .035, back), Vector3(centre.x, shoulder_y, back)], size.y * .0018, ink)
    _add_tube([Vector3(centre.x, shoulder_y, back), Vector3(centre.x, centre.y - size.y * .02, back), Vector3(centre.x, centre.y - size.y * .13, back)], size.y * .0015, ink)
    for side in [-1.0, 1.0]:
        var sx := centre.x + side * size.x * .19
        _add_tube([Vector3(centre.x + side * size.x * .06, shoulder_y, back), Vector3(sx, shoulder_y - size.y * .025, back), Vector3(sx + side * size.x * .025, shoulder_y - size.y * .11, back)], size.y * .0017, ink)
        # A small star/astrolabe mark on each shoulder cap.
        _add_star(Vector3(centre.x + side * size.x * .245, shoulder_y - size.y * .025, back - 0.002), size.y * .018, ink)
        # Delicate forearm sigils, placed on the front-facing side.
        var arm_x := centre.x + side * size.x * .255
        var arm_y := centre.y - size.y * .015
        _add_tube([Vector3(arm_x, arm_y, front), Vector3(arm_x - side * size.x * .018, arm_y - size.y * .035, front), Vector3(arm_x, arm_y - size.y * .07, front)], size.y * .0015, ink)
        _add_star(Vector3(arm_x, arm_y - size.y * .09, front + 0.002), size.y * .012, ink)
    # Fine thigh markings, intentionally sparse and narrow.
    for side in [-1.0, 1.0]:
        var thigh_x := centre.x + side * size.x * .105
        _add_tube([Vector3(thigh_x, centre.y - size.y * .23, front), Vector3(thigh_x + side * size.x * .018, centre.y - size.y * .29, front), Vector3(thigh_x, centre.y - size.y * .35, front)], size.y * .0015, ink)

func _add_reyna_back(centre: Vector3, size: Vector3, back_z: float) -> void:
    var y := centre.y + size.y * 0.29
    var z := back_z - 0.003
    # One connected, balanced shoulder-back motif: a central spear/leaf with
    # mirrored feather-like arcs reaching over both shoulder blades.
    _add_tube([Vector3(centre.x, y + size.y * .025, z), Vector3(centre.x, y - size.y * .055, z), Vector3(centre.x, y - size.y * .16, z)], size.y * .0028, _ink_material)
    for side in [-1.0, 1.0]:
        _add_tube([Vector3(centre.x, y - size.y * .015, z), Vector3(centre.x + side * size.x * .11, y + size.y * .025, z), Vector3(centre.x + side * size.x * .22, y + size.y * .005, z), Vector3(centre.x + side * size.x * .27, y - size.y * .055, z)], size.y * .0026, _ink_material)
        for feather in range(3):
            var x := centre.x + side * size.x * (0.10 + feather * 0.055)
            var yy := y + size.y * (0.012 - feather * 0.012)
            _add_tube([Vector3(x, yy, z), Vector3(x + side * size.x * .025, yy - size.y * .045, z), Vector3(x + side * size.x * .055, yy - size.y * .065, z)], size.y * .0018, _ink_material)
    _add_star(Vector3(centre.x, y + size.y * .035, z - 0.002), size.y * .014, _ink_material)

func _add_star(centre: Vector3, radius: float, material: Material) -> void:
    var points: Array[Vector3] = []
    for index in range(9):
        var angle := TAU * float(index) / 8.0
        var r := radius if index % 2 == 0 else radius * 0.28
        points.append(centre + Vector3(cos(angle) * r, sin(angle) * r, 0))
    points.append(points[0])
    _add_tube(points, radius * 0.075, material)

func _add_tube(points: Array[Vector3], radius: float, material: Material) -> void:
    if points.size() < 2 or radius <= 0.0:
        return
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    const SIDES := 6
    for segment in range(points.size() - 1):
        var a := points[segment]
        var b := points[segment + 1]
        var tangent := (b - a).normalized()
        if tangent.length_squared() < 0.000001:
            continue
        var axis := tangent.cross(Vector3.UP)
        if axis.length_squared() < 0.000001:
            axis = tangent.cross(Vector3.RIGHT)
        axis = axis.normalized()
        var other := tangent.cross(axis).normalized()
        for side in range(SIDES):
            var angle_a := TAU * float(side) / SIDES
            var angle_b := TAU * float(side + 1) / SIDES
            var offset_a := (axis * cos(angle_a) + other * sin(angle_a)) * radius
            var offset_b := (axis * cos(angle_b) + other * sin(angle_b)) * radius
            var a0 := a + offset_a
            var a1 := a + offset_b
            var b0 := b + offset_a
            var b1 := b + offset_b
            surface.add_vertex(a0)
            surface.add_vertex(b0)
            surface.add_vertex(b1)
            surface.add_vertex(a0)
            surface.add_vertex(b1)
            surface.add_vertex(a1)
    surface.generate_normals()
    var mesh := surface.commit()
    if mesh == null:
        return
    var instance := MeshInstance3D.new()
    instance.mesh = mesh
    instance.material_override = material
    instance.name = "TattooLine"
    add_child(instance)
