class_name CharacterSurfaceRegionPartition
extends Resource
## Exclusive primary ownership map for one exact mesh surface.
##
## Unlike CharacterSurfaceRegionMask.region_weights (independent overlapping
## feature channels), this resource assigns exactly one primary region to every
## source vertex. A single integer label makes overlap impossible by construction;
## an empty/invalid label is a coverage failure.
##
## Region IDs are supplied by the authoring resource so this contract does not
## impose an incomplete universal anatomy taxonomy.

@export var body_asset_path: String = ""
@export var mesh_node_path: NodePath
@export_range(0, 255, 1) var surface_index: int = 0
@export var surface_name: String = ""
@export_range(0, 1000000, 1) var vertex_count: int = 0
@export var surface_signature: String = ""
@export var region_ids: PackedStringArray = PackedStringArray()
## One region_ids index per source vertex. -1 is never valid in a completed partition.
@export var vertex_region_indices: PackedInt32Array = PackedInt32Array()


static func build_surface_signature(mesh: Mesh, requested_surface_index: int) -> String:
    if mesh == null or requested_surface_index < 0 or requested_surface_index >= mesh.get_surface_count():
        return ""
    var arrays := mesh.surface_get_arrays(requested_surface_index)
    var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
    var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
    if vertices.is_empty() or indices.is_empty():
        return ""
    var context := HashingContext.new()
    if context.start(HashingContext.HASH_SHA256) != OK:
        return ""
    context.update(vertices.to_byte_array())
    context.update(indices.to_byte_array())
    context.update(mesh.surface_get_name(requested_surface_index).to_utf8_buffer())
    return context.finish().hex_encode()


func validate_for_mesh(
    mesh_instance: MeshInstance3D,
    body_root: Node3D,
    expected_body_asset_path: String
) -> String:
    if mesh_instance == null or body_root == null or mesh_instance.mesh == null:
        return "A valid mesh instance, body root and mesh resource are required"
    if not expected_body_asset_path.is_empty() and body_asset_path != expected_body_asset_path:
        return "Partition body asset mismatch: expected %s, got %s" % [expected_body_asset_path, body_asset_path]
    if body_root.get_node_or_null(mesh_node_path) != mesh_instance:
        return "Partition mesh path does not resolve to the supplied MeshInstance3D"
    if surface_index < 0 or surface_index >= mesh_instance.mesh.get_surface_count():
        return "Partition surface index is outside the source mesh"
    var arrays := mesh_instance.mesh.surface_get_arrays(surface_index)
    var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
    var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
    if vertices.size() != vertex_count:
        return "Partition vertex count mismatch: expected %d, got %d" % [vertex_count, vertices.size()]
    if mesh_instance.mesh.surface_get_name(surface_index) != surface_name:
        return "Partition surface name mismatch"
    var actual_signature := build_surface_signature(mesh_instance.mesh, surface_index)
    if surface_signature.is_empty() or actual_signature != surface_signature:
        return "Partition surface signature mismatch; re-author against the current mesh export"
    return validate_arrays(vertices.size(), indices, region_ids, vertex_region_indices)


static func validate_arrays(
    requested_vertex_count: int,
    indices: PackedInt32Array,
    requested_region_ids: PackedStringArray,
    assignments: PackedInt32Array
) -> String:
    if requested_vertex_count <= 0:
        return "Partition requires at least one source vertex"
    if requested_region_ids.is_empty():
        return "Partition requires at least one primary region"
    if assignments.size() != requested_vertex_count:
        return "Partition must assign exactly one primary region to every source vertex"
    var seen_ids := {}
    for region_id in requested_region_ids:
        if region_id.strip_edges().is_empty():
            return "Primary region IDs cannot be empty"
        if seen_ids.has(region_id):
            return "Duplicate primary region ID: %s" % region_id
        seen_ids[region_id] = true
    var counts := PackedInt32Array()
    counts.resize(requested_region_ids.size())
    for vertex_index in assignments.size():
        var region_index := assignments[vertex_index]
        if region_index < 0 or region_index >= requested_region_ids.size():
            return "Vertex %d has no valid primary region assignment" % vertex_index
        counts[region_index] += 1
    for region_index in counts.size():
        if counts[region_index] == 0:
            return "Primary region %s has no assigned vertices" % requested_region_ids[region_index]
    if indices.is_empty() or indices.size() % 3 != 0:
        return "Partition source must contain indexed triangles"
    var adjacency: Array = []
    adjacency.resize(requested_vertex_count)
    for vertex_index in requested_vertex_count:
        adjacency[vertex_index] = []
    for triangle_offset in range(0, indices.size(), 3):
        var a := indices[triangle_offset]
        var b := indices[triangle_offset + 1]
        var c := indices[triangle_offset + 2]
        if a < 0 or a >= requested_vertex_count or b < 0 or b >= requested_vertex_count or c < 0 or c >= requested_vertex_count:
            return "Source triangle references a vertex outside the partition"
        _add_neighbour(adjacency, a, b)
        _add_neighbour(adjacency, b, a)
        _add_neighbour(adjacency, b, c)
        _add_neighbour(adjacency, c, b)
        _add_neighbour(adjacency, c, a)
        _add_neighbour(adjacency, a, c)
    for region_index in requested_region_ids.size():
        var first_vertex := -1
        for vertex_index in assignments.size():
            if assignments[vertex_index] == region_index:
                first_vertex = vertex_index
                break
        var visited := {}
        var stack: Array[int] = [first_vertex]
        visited[first_vertex] = true
        while not stack.is_empty():
            var current: int = stack.pop_back()
            for neighbour_variant in adjacency[current]:
                var neighbour: int = neighbour_variant
                if assignments[neighbour] == region_index and not visited.has(neighbour):
                    visited[neighbour] = true
                    stack.append(neighbour)
        if visited.size() != counts[region_index]:
            return "Primary region %s is split into %d disconnected surface islands" % [
                requested_region_ids[region_index],
                _count_components_for_region(assignments, adjacency, region_index)
            ]
    return ""


static func _add_neighbour(adjacency: Array, from_vertex: int, to_vertex: int) -> void:
    if not adjacency[from_vertex].has(to_vertex):
        adjacency[from_vertex].append(to_vertex)


static func _count_components_for_region(assignments: PackedInt32Array, adjacency: Array, region_index: int) -> int:
    var visited := {}
    var components := 0
    for start_vertex in assignments.size():
        if assignments[start_vertex] != region_index or visited.has(start_vertex):
            continue
        components += 1
        var stack: Array[int] = [start_vertex]
        visited[start_vertex] = true
        while not stack.is_empty():
            var current: int = stack.pop_back()
            for neighbour_variant in adjacency[current]:
                var neighbour: int = neighbour_variant
                if assignments[neighbour] == region_index and not visited.has(neighbour):
                    visited[neighbour] = true
                    stack.append(neighbour)
    return components
