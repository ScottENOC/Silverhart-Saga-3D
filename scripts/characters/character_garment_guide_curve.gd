class_name CharacterGarmentGuideCurve
extends Resource
## A named garment construction guide attached to one exact Ara mesh surface.
## Each point is a barycentric coordinate inside a source triangle, so it follows
## the same skinning and blend-shape evaluation as the body surface.

const VALID_GUIDE_IDS := [
    "neckline", "collar", "shoulder_seam_left", "shoulder_seam_right",
    "armhole_left", "armhole_right", "chest_line", "cup_apex_left",
    "cup_apex_right", "underbust", "waist_natural", "hip_high",
    "hip_full", "seat", "crotch_front", "crotch_back",
    "inseam_left", "inseam_right", "outseam_left", "outseam_right",
    "elbow_opening_left", "elbow_opening_right", "wrist_opening_left",
    "wrist_opening_right", "knee_opening_left", "knee_opening_right",
    "ankle_opening_left", "ankle_opening_right", "foot_opening_left",
    "foot_opening_right", "heel_alignment", "toe_alignment"
]

@export var body_asset_path: String = ""
@export var mesh_node_path: NodePath
@export_range(0, 255, 1) var surface_index: int = 0
@export var surface_name: String = ""
@export_range(0, 1000000, 1) var vertex_count: int = 0
@export var surface_signature: String = ""
@export var guide_id: String = ""
@export var paired_guide_id: String = ""
@export var closed_loop: bool = false
## Each point: { "triangle_indices": PackedInt32Array([a,b,c]),
## "barycentric": PackedFloat32Array([wa,wb,wc]) }.
@export var points: Array[Dictionary] = []

var last_evaluation_error: String = ""


func validate_for_mesh(mesh_instance: MeshInstance3D, body_root: Node3D, expected_body_asset_path: String) -> String:
    if mesh_instance == null or body_root == null or mesh_instance.mesh == null:
        return "A valid mesh instance, body root and mesh resource are required"
    if not expected_body_asset_path.is_empty() and body_asset_path != expected_body_asset_path:
        return "Guide body asset mismatch: expected %s, got %s" % [expected_body_asset_path, body_asset_path]
    if body_root.get_node_or_null(mesh_node_path) != mesh_instance:
        return "Guide mesh path does not resolve to the supplied MeshInstance3D"
    if surface_index < 0 or surface_index >= mesh_instance.mesh.get_surface_count():
        return "Guide surface index is outside the source mesh"
    var mesh := mesh_instance.mesh
    var arrays := mesh.surface_get_arrays(surface_index)
    var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
    if vertices.size() != vertex_count:
        return "Guide vertex count mismatch: expected %d, got %d" % [vertex_count, vertices.size()]
    if mesh.surface_get_name(surface_index) != surface_name:
        return "Guide surface name mismatch"
    if surface_signature.is_empty() or CharacterSurfaceRegionMask.build_surface_signature(mesh, surface_index) != surface_signature:
        return "Guide surface signature mismatch; re-author against the current GLB export"
    if not VALID_GUIDE_IDS.has(guide_id):
        return "Unsupported garment guide ID: %s" % guide_id
    if not paired_guide_id.is_empty() and not VALID_GUIDE_IDS.has(paired_guide_id):
        return "Unsupported paired garment guide ID: %s" % paired_guide_id
    if points.size() < (3 if closed_loop else 2):
        return "A guide needs at least %d points" % (3 if closed_loop else 2)
    for point_index in range(points.size()):
        var point: Dictionary = points[point_index]
        var triangle: Variant = point.get("triangle_indices")
        var barycentric: Variant = point.get("barycentric")
        if not triangle is PackedInt32Array or triangle.size() != 3:
            return "Guide point %d must reference exactly three triangle vertices" % point_index
        if not barycentric is PackedFloat32Array or barycentric.size() != 3:
            return "Guide point %d must contain three barycentric weights" % point_index
        for vertex_index in triangle:
            if vertex_index < 0 or vertex_index >= vertex_count:
                return "Guide point %d references a vertex outside the source surface" % point_index
        var total := 0.0
        for weight in barycentric:
            if not is_finite(weight) or weight < 0.0 or weight > 1.0:
                return "Guide point %d has an invalid barycentric weight" % point_index
            total += weight
        if absf(total - 1.0) > 0.001:
            return "Guide point %d barycentric weights must sum to 1" % point_index
        if not _triangle_exists(arrays, triangle, vertex_count):
            return "Guide point %d does not reference a triangle in the source surface" % point_index
    return ""


func evaluate(surface_regions: CharacterSurfaceRegions) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    last_evaluation_error = ""
    if surface_regions == null:
        last_evaluation_error = "Surface-region evaluator is null"
        return result
    for point_index in range(points.size()):
        var point: Dictionary = points[point_index]
        var triangle: PackedInt32Array = point["triangle_indices"]
        var barycentric: PackedFloat32Array = point["barycentric"]
        var position := Vector3.ZERO
        var normal := Vector3.ZERO
        for corner in range(3):
            var sample := surface_regions.get_surface_vertex_sample(mesh_node_path, surface_index, triangle[corner])
            if sample.is_empty():
                last_evaluation_error = "Surface sample unavailable at point %d, triangle corner %d (mesh=%s surface=%d vertex=%d)" % [
                    point_index, corner, mesh_node_path, surface_index, triangle[corner]
                ]
                return []
            position += sample["position"] * barycentric[corner]
            normal += sample["normal"] * barycentric[corner]
        if normal.length_squared() < 0.000001:
            last_evaluation_error = "Interpolated normal is degenerate at guide point %d" % point_index
            return []
        result.append({
            "position": position,
            "normal": normal.normalized(),
            "guide_id": guide_id,
            "point_index": point_index
        })
    for point_index in range(result.size()):
        var previous_index := point_index - 1
        var next_index := point_index + 1
        if closed_loop:
            previous_index = posmod(previous_index, result.size())
            next_index = posmod(next_index, result.size())
        else:
            previous_index = maxi(previous_index, 0)
            next_index = mini(next_index, result.size() - 1)
        var tangent: Vector3 = result[next_index]["position"] - result[previous_index]["position"]
        var normal: Vector3 = result[point_index]["normal"]
        tangent -= normal * tangent.dot(normal)
        if tangent.length_squared() < 0.000001:
            last_evaluation_error = "Tangent is degenerate at guide point %d (closed_loop=%s)" % [point_index, closed_loop]
            return []
        tangent = tangent.normalized()
        var binormal := tangent.cross(normal).normalized()
        tangent = normal.cross(binormal).normalized()
        var frame := Basis(tangent, normal, binormal).orthonormalized()
        result[point_index]["tangent"] = tangent
        result[point_index]["binormal"] = binormal
        result[point_index]["frame"] = Transform3D(frame, result[point_index]["position"])
    return result


func _triangle_exists(arrays: Array, triangle: PackedInt32Array, source_vertex_count: int) -> bool:
    var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
    if indices.is_empty():
        if source_vertex_count % 3 != 0:
            return false
        for offset in range(0, source_vertex_count, 3):
            if _same_triangle(triangle, PackedInt32Array([offset, offset + 1, offset + 2])):
                return true
        return false
    for offset in range(0, indices.size() - 2, 3):
        if _same_triangle(triangle, PackedInt32Array([indices[offset], indices[offset + 1], indices[offset + 2]])):
            return true
    return false


func _same_triangle(a: PackedInt32Array, b: PackedInt32Array) -> bool:
    var sorted_a := [a[0], a[1], a[2]]
    var sorted_b := [b[0], b[1], b[2]]
    sorted_a.sort()
    sorted_b.sort()
    return sorted_a == sorted_b
