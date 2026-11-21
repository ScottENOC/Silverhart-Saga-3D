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
var _cached_surface_graph: AStar3D
var _cached_graph_signature := ""


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


## Returns a dense route constrained to the source mesh's triangle-edge graph.
## This is a surface-following approximation, not an exact continuous geodesic.
func evaluate_surface_path(surface_regions: CharacterSurfaceRegions) -> Array[Dictionary]:
    last_evaluation_error = ""
    if surface_regions == null:
        last_evaluation_error = "Surface-region evaluator is null"
        return []
    var mesh_instance := surface_regions.get_surface_mesh_instance(mesh_node_path, surface_index)
    if mesh_instance == null or mesh_instance.mesh == null:
        last_evaluation_error = "Contact path source mesh is unavailable"
        return []
    var arrays := mesh_instance.mesh.surface_get_arrays(surface_index)
    var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
    if vertices.size() != vertex_count:
        last_evaluation_error = "Contact path source vertex count changed"
        return []
    var graph := _get_surface_graph(vertices, arrays)
    if graph == null:
        return []
    var dense: Array[Dictionary] = []
    var segment_count := points.size() if closed_loop else points.size() - 1
    for segment_index in range(segment_count):
        var next_index := (segment_index + 1) % points.size()
        var start_point: Dictionary = points[segment_index]
        var end_point: Dictionary = points[next_index]
        var start_anchor := _evaluate_control_point(surface_regions, start_point, segment_index)
        var end_anchor := _evaluate_control_point(surface_regions, end_point, next_index)
        if start_anchor.is_empty() or end_anchor.is_empty():
            return []
        if segment_index == 0:
            dense.append(start_anchor)
        var start_vertex := _nearest_triangle_vertex(start_point, vertices)
        var end_vertex := _nearest_triangle_vertex(end_point, vertices)
        var route: PackedInt64Array = graph.get_id_path(start_vertex, end_vertex)
        if route.is_empty():
            last_evaluation_error = "Mesh edge graph has no route between contact points %d and %d" % [segment_index, next_index]
            return []
        for route_index in range(route.size()):
            var vertex_index := int(route[route_index])
            var sample := surface_regions.get_surface_vertex_sample(mesh_node_path, surface_index, vertex_index)
            if sample.is_empty():
                last_evaluation_error = "Surface vertex %d unavailable while evaluating contact route" % vertex_index
                return []
            dense.append({
                "position": sample["position"],
                "normal": sample["normal"],
                "point_index": -1,
                "surface_vertex_index": vertex_index,
                "is_control_point": false
            })
        if not (closed_loop and next_index == 0):
            dense.append(end_anchor)
    if dense.size() < 2:
        last_evaluation_error = "Surface contact route produced fewer than two samples"
        return []
    _build_dense_frames(dense, closed_loop)
    if not last_evaluation_error.is_empty():
        return []
    return dense


func _evaluate_control_point(surface_regions: CharacterSurfaceRegions, point: Dictionary, point_index: int) -> Dictionary:
    var triangle: PackedInt32Array = point["triangle_indices"]
    var weights: PackedFloat32Array = point["barycentric"]
    var position := Vector3.ZERO
    var normal := Vector3.ZERO
    for corner in range(3):
        var sample := surface_regions.get_surface_vertex_sample(mesh_node_path, surface_index, triangle[corner])
        if sample.is_empty():
            last_evaluation_error = "Surface sample unavailable at contact path point %d" % point_index
            return {}
        position += sample["position"] * weights[corner]
        normal += sample["normal"] * weights[corner]
    if normal.length_squared() < 0.000001:
        last_evaluation_error = "Degenerate normal at contact path point %d" % point_index
        return {}
    return {
        "position": position,
        "normal": normal.normalized(),
        "point_index": point_index,
        "is_control_point": true
    }


func _nearest_triangle_vertex(point: Dictionary, vertices: PackedVector3Array) -> int:
    var triangle: PackedInt32Array = point["triangle_indices"]
    var weights: PackedFloat32Array = point["barycentric"]
    var anchor := Vector3.ZERO
    for corner in range(3):
        anchor += vertices[triangle[corner]] * weights[corner]
    var nearest := triangle[0]
    var best_distance := INF
    for vertex_index in triangle:
        var distance := vertices[vertex_index].distance_squared_to(anchor)
        if distance < best_distance:
            best_distance = distance
            nearest = vertex_index
    return nearest


func _get_surface_graph(vertices: PackedVector3Array, arrays: Array) -> AStar3D:
    if _cached_surface_graph != null and _cached_graph_signature == surface_signature:
        return _cached_surface_graph
    var graph := AStar3D.new()
    for vertex_index in range(vertices.size()):
        graph.add_point(vertex_index, vertices[vertex_index])
    var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
    var triangle_indices := PackedInt32Array()
    if indices.is_empty():
        for vertex_index in range(vertices.size()):
            triangle_indices.append(vertex_index)
    else:
        triangle_indices = indices
    if triangle_indices.size() % 3 != 0:
        last_evaluation_error = "Source surface index buffer is not a triangle list"
        return null
    var connected_edges: Dictionary = {}
    for offset in range(0, triangle_indices.size(), 3):
        var triangle := [int(triangle_indices[offset]), int(triangle_indices[offset + 1]), int(triangle_indices[offset + 2])]
        for edge_index in range(3):
            var a: int = triangle[edge_index]
            var b: int = triangle[(edge_index + 1) % 3]
            if a < 0 or b < 0 or a >= vertices.size() or b >= vertices.size() or a == b:
                continue
            var low := mini(a, b)
            var high := maxi(a, b)
            var edge_key: int = low * vertices.size() + high
            if connected_edges.has(edge_key):
                continue
            connected_edges[edge_key] = true
            graph.connect_points(a, b)
    _cached_surface_graph = graph
    _cached_graph_signature = surface_signature
    return _cached_surface_graph


func _build_dense_frames(samples: Array[Dictionary], closed: bool) -> void:
    for sample_index in range(samples.size()):
        var previous_index := sample_index - 1
        var next_index := sample_index + 1
        if closed:
            previous_index = posmod(previous_index, samples.size())
            next_index = posmod(next_index, samples.size())
        else:
            previous_index = maxi(previous_index, 0)
            next_index = mini(next_index, samples.size() - 1)
        var normal: Vector3 = samples[sample_index]["normal"]
        var tangent := _project_to_surface(
            samples[next_index]["position"] - samples[previous_index]["position"], normal
        )
        if tangent.length_squared() < 0.000001:
            var reference := Vector3.RIGHT if absf(normal.dot(Vector3.RIGHT)) < 0.9 else Vector3.UP
            tangent = reference.cross(normal)
        if tangent.length_squared() < 0.000001:
            last_evaluation_error = "Could not construct a stable frame at dense path sample %d" % sample_index
            return
        tangent = tangent.normalized()
        var binormal := tangent.cross(normal).normalized()
        tangent = normal.cross(binormal).normalized()
        var frame := Basis(tangent, normal, binormal).orthonormalized()
        samples[sample_index]["tangent"] = tangent
        samples[sample_index]["binormal"] = binormal
        samples[sample_index]["frame"] = Transform3D(frame, samples[sample_index]["position"])
