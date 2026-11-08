class_name OrganicWorldFeatures
extends RefCounted
## Converts authored world-space centre lines into smooth, variable-width ribbons.
## Logical hex cells remain unchanged; this script only controls visible geometry.

static func make_ribbon(
    node_name: String,
    control_points: Array[Vector3],
    widths: PackedFloat32Array,
    material: Material,
    y_offset: float = 0.0,
    samples_per_segment: int = 8
) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    instance.name = node_name
    if control_points.size() < 2 or widths.size() != control_points.size():
        return instance

    var sampled_points: Array[Vector3] = []
    var sampled_widths := PackedFloat32Array()
    for segment in range(control_points.size() - 1):
        var p0: Vector3 = control_points[maxi(segment - 1, 0)]
        var p1: Vector3 = control_points[segment]
        var p2: Vector3 = control_points[segment + 1]
        var p3: Vector3 = control_points[mini(segment + 2, control_points.size() - 1)]
        for step in range(samples_per_segment):
            var t := float(step) / float(samples_per_segment)
            sampled_points.append(_catmull_rom(p0, p1, p2, p3, t))
            sampled_widths.append(lerpf(widths[segment], widths[segment + 1], t))
    sampled_points.append(control_points.back())
    sampled_widths.append(widths.back())

    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    for i in range(sampled_points.size()):
        var tangent: Vector3
        if i == 0:
            tangent = sampled_points[1] - sampled_points[0]
        elif i == sampled_points.size() - 1:
            tangent = sampled_points[i] - sampled_points[i - 1]
        else:
            tangent = sampled_points[i + 1] - sampled_points[i - 1]
        tangent.y = 0.0
        tangent = tangent.normalized()
        var side := Vector3(-tangent.z, 0.0, tangent.x)
        var half_width := sampled_widths[i] * 0.5
        var left := sampled_points[i] + side * half_width + Vector3.UP * y_offset
        var right := sampled_points[i] - side * half_width + Vector3.UP * y_offset
        if i == 0:
            continue
        var previous_tangent: Vector3 = (sampled_points[i] - sampled_points[i - 1]).normalized()
        var previous_side := Vector3(-previous_tangent.z, 0.0, previous_tangent.x)
        var previous_half := sampled_widths[i - 1] * 0.5
        var previous_left := sampled_points[i - 1] + previous_side * previous_half + Vector3.UP * y_offset
        var previous_right := sampled_points[i - 1] - previous_side * previous_half + Vector3.UP * y_offset
        _add_quad(surface, previous_left, previous_right, right, left)

    var mesh := surface.commit()
    if mesh != null:
        instance.mesh = mesh
        instance.material_override = material
    return instance

static func _add_quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
    surface.set_normal(Vector3.UP)
    surface.add_vertex(a)
    surface.add_vertex(b)
    surface.add_vertex(c)
    surface.set_normal(Vector3.UP)
    surface.add_vertex(a)
    surface.add_vertex(c)
    surface.add_vertex(d)

static func _catmull_rom(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
    var t2 := t * t
    var t3 := t2 * t
    return 0.5 * (
        2.0 * p1
        + (-p0 + p2) * t
        + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
        + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
    )
