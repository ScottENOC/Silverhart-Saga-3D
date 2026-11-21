class_name CharacterSurfaceContactPath
extends Resource
## A semantic trajectory traced by surface-attached control points.
## Intended for contact choreography (e.g. fingertip paths), not garment seams.

@export var body_asset_path: String = ""
@export var mesh_node_path: NodePath
@export_range(0, 255, 1) var surface_index: int = 0
@export var surface_name: String = ""
@export_range(0, 1000000, 1) var vertex_count: int = 0
@export var surface_signature: String = ""
@export var path_id: String = ""
@export var closed_loop: bool = false
## Each point stores triangle_indices: PackedInt32Array and barycentric: PackedFloat32Array.
@export var points: Array[Dictionary] = []

var last_evaluation_error := ""


func validate_for_mesh(mesh_instance: MeshInstance3D, body_root: Node3D, expected_asset: String) -> String:
    if mesh_instance == null or body_root == null or mesh_instance.mesh == null:
        return "A valid mesh instance, body root and mesh resource are required"
    if body_root.get_node_or_null(mesh_node_path) != mesh_instance:
        return "Contact path mesh path does not resolve to the supplied MeshInstance3D"
    if not expected_asset.is_empty() and body_asset_path != expected_asset:
        return "Contact path body asset mismatch"
    var mesh := mesh_instance.mesh
    if surface_index < 0 or surface_index >= mesh.get_surface_count():
        return "Contact path surface index is outside the source mesh"
    if mesh.surface_get_name(surface_index) != surface_name:
        return "Contact path surface name mismatch"
    var arrays := mesh.surface_get_arrays(surface_index)
    var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
    if vertices.size() != vertex_count:
        return "Contact path vertex count mismatch"
    if surface_signature.is_empty() or CharacterSurfaceRegionMask.build_surface_signature(mesh, surface_index) != surface_signature:
        return "Contact path surface signature mismatch"
    if path_id.strip_edges().is_empty():
        return "Contact path needs a semantic path ID"
    if points.size() < (3 if closed_loop else 2):
        return "Contact path needs at least %d control points" % (3 if closed_loop else 2)
    for point_index in range(points.size()):
        var point: Dictionary = points[point_index]
        var triangle: Variant = point.get("triangle_indices")
        var weights: Variant = point.get("barycentric")
        if not triangle is PackedInt32Array or triangle.size() != 3:
            return "Contact path point %d must reference one triangle" % point_index
        if not weights is PackedFloat32Array or weights.size() != 3:
            return "Contact path point %d must have three barycentric weights" % point_index
        for vertex_index in triangle:
            if vertex_index < 0 or vertex_index >= vertex_count:
                return "Contact path point %d references an invalid vertex" % point_index
        var total := 0.0
        for weight in weights:
            if not is_finite(weight) or weight < 0.0 or weight > 1.0:
                return "Contact path point %d has invalid barycentric weights" % point_index
            total += weight
        if absf(total - 1.0) > 0.001:
            return "Contact path point %d weights must sum to 1" % point_index
        if not _triangle_exists(arrays, triangle):
            return "Contact path point %d does not reference a source triangle" % point_index
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
        var weights: PackedFloat32Array = point["barycentric"]
        var position := Vector3.ZERO
        var normal := Vector3.ZERO
        for corner in range(3):
            var sample := surface_regions.get_surface_vertex_sample(mesh_node_path, surface_index, triangle[corner])
            if sample.is_empty():
                last_evaluation_error = "Surface sample unavailable at contact path point %d" % point_index
                return []
            position += sample["position"] * weights[corner]
            normal += sample["normal"] * weights[corner]
        if normal.length_squared() < 0.000001:
            last_evaluation_error = "Degenerate normal at contact path point %d" % point_index
            return []
        result.append({
            "position": position,
            "normal": normal.normalized(),
            "point_index": point_index,
            "fallback_edges": [
                surface_regions.get_surface_vertex_sample(mesh_node_path, surface_index, triangle[1])["position"]
                    - surface_regions.get_surface_vertex_sample(mesh_node_path, surface_index, triangle[0])["position"],
                surface_regions.get_surface_vertex_sample(mesh_node_path, surface_index, triangle[2])["position"]
                    - surface_regions.get_surface_vertex_sample(mesh_node_path, surface_index, triangle[0])["position"],
                surface_regions.get_surface_vertex_sample(mesh_node_path, surface_index, triangle[2])["position"]
                    - surface_regions.get_surface_vertex_sample(mesh_node_path, surface_index, triangle[1])["position"]
            ]
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
        var normal: Vector3 = result[point_index]["normal"]
        var tangent := _project_to_surface(
            result[next_index]["position"] - result[previous_index]["position"], normal
        )
        if tangent.length_squared() < 0.000001:
            # Smoothed vertex normals can make a perfectly valid surface chord
            # appear normal-aligned. Fall back to a real edge of the attached
            # source triangle, projected onto the evaluated tangent plane.
            var fallback_edges: Array = result[point_index]["fallback_edges"]
            var longest_edge := Vector3.ZERO
            for edge in fallback_edges:
                var projected := _project_to_surface(edge, normal)
                if projected.length_squared() > longest_edge.length_squared():
                    longest_edge = projected
            tangent = longest_edge
        if tangent.length_squared() < 0.000001:
            last_evaluation_error = "No stable tangent at contact path point %d" % point_index
            return []
        tangent = tangent.normalized()
        var binormal := tangent.cross(normal).normalized()
        tangent = normal.cross(binormal).normalized()
        var frame := Basis(tangent, normal, binormal).orthonormalized()
        result[point_index]["tangent"] = tangent
        result[point_index]["binormal"] = binormal
        result[point_index]["frame"] = Transform3D(frame, result[point_index]["position"])
        result[point_index].erase("fallback_edges")
    return result


func _triangle_exists(arrays: Array, triangle: PackedInt32Array) -> bool:
    var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
    if indices.is_empty():
        for offset in range(0, vertex_count - 2, 3):
            if _same_triangle(triangle, PackedInt32Array([offset, offset + 1, offset + 2])):
                return true
        return false
    for offset in range(0, indices.size() - 2, 3):
        if _same_triangle(triangle, PackedInt32Array([indices[offset], indices[offset + 1], indices[offset + 2]])):
            return true
    return false


func _same_triangle(a: PackedInt32Array, b: PackedInt32Array) -> bool:
    var left := [a[0], a[1], a[2]]
    var right := [b[0], b[1], b[2]]
    left.sort()
    right.sort()
    return left == right


func _project_to_surface(vector: Vector3, normal: Vector3) -> Vector3:
    return vector - normal * vector.dot(normal)
