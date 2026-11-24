class_name CharacterSurfaceLandmark
extends Resource
## A semantic point attached to one exact skinned Ara mesh triangle.
## Unlike a rig landmark, this resolves to the animated skin surface.

const VALID_LANDMARK_IDS := [
    "upper_lip", "lower_lip", "mouth_centre",
    "sternum", "clavicle_left", "clavicle_right",
    "breast_apex_left", "breast_apex_right", "nipple_left", "nipple_right",
    "underbust_left", "underbust_right", "waist_front", "waist_left",
    "waist_right", "iliac_crest_left", "iliac_crest_right",
    "hip_front_left", "hip_front_right", "hip_side_left", "hip_side_right",
    "hip_back_left", "hip_back_right", "sacrum", "pubic_symphysis",
    "crotch_front", "crotch_back",
    "palm_left", "palm_right", "fingertip_index_left", "fingertip_index_right",
    "fingertip_middle_left", "fingertip_middle_right",
    "heel_left", "heel_right", "toe_left", "toe_right"
]

@export var body_asset_path: String = ""
@export var mesh_node_path: NodePath
@export_range(0, 255, 1) var surface_index: int = 0
@export var surface_name: String = ""
@export_range(0, 1000000, 1) var vertex_count: int = 0
@export var surface_signature: String = ""
@export var landmark_id: String = ""
@export var triangle_indices: PackedInt32Array = PackedInt32Array()
@export var barycentric: PackedFloat32Array = PackedFloat32Array()
## Triangle edge used as the local tangent reference: 0=AB, 1=BC, 2=CA.
@export_range(0, 2, 1) var tangent_edge: int = 0
## Small offset along the evaluated skin normal; normally zero.
@export var normal_offset: float = 0.0


func validate_for_mesh(mesh_instance: MeshInstance3D, body_root: Node3D, expected_body_asset_path: String) -> String:
    if mesh_instance == null or body_root == null or mesh_instance.mesh == null:
        return "A valid mesh instance, body root and mesh resource are required"
    if not expected_body_asset_path.is_empty() and body_asset_path != expected_body_asset_path:
        return "Landmark body asset mismatch: expected %s, got %s" % [expected_body_asset_path, body_asset_path]
    if body_root.get_node_or_null(mesh_node_path) != mesh_instance:
        return "Landmark mesh path does not resolve to the supplied MeshInstance3D"
    if surface_index < 0 or surface_index >= mesh_instance.mesh.get_surface_count():
        return "Landmark surface index is outside the source mesh"
    var mesh := mesh_instance.mesh
    var arrays := mesh.surface_get_arrays(surface_index)
    var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
    if vertices.size() != vertex_count:
        return "Landmark vertex count mismatch: expected %d, got %d" % [vertex_count, vertices.size()]
    if mesh.surface_get_name(surface_index) != surface_name:
        return "Landmark surface name mismatch"
    if surface_signature.is_empty() or CharacterSurfaceRegionMask.build_surface_signature(mesh, surface_index) != surface_signature:
        return "Landmark surface signature mismatch; re-author against the current GLB export"
    if not VALID_LANDMARK_IDS.has(landmark_id):
        return "Unsupported anatomical surface landmark ID: %s" % landmark_id
    if triangle_indices.size() != 3 or barycentric.size() != 3:
        return "A surface landmark must reference one triangle and three barycentric weights"
    if tangent_edge < 0 or tangent_edge > 2:
        return "Landmark tangent edge must be 0, 1 or 2"
    if not is_finite(normal_offset):
        return "Landmark normal offset must be finite"
    for vertex_index in triangle_indices:
        if vertex_index < 0 or vertex_index >= vertex_count:
            return "Landmark references a vertex outside the source surface"
    var total := 0.0
    for weight in barycentric:
        if not is_finite(weight) or weight < 0.0 or weight > 1.0:
            return "Landmark barycentric weights must be finite and within 0–1"
        total += weight
    if absf(total - 1.0) > 0.001:
        return "Landmark barycentric weights must sum to 1"
    if not _triangle_exists(arrays, triangle_indices, vertex_count):
        return "Landmark does not reference a triangle in the source surface"
    return ""


## Returns a deformation-aware character-local point and local frame.
func evaluate(surface_regions: CharacterSurfaceRegions) -> Dictionary:
    if surface_regions == null:
        return {}
    var samples: Array[Dictionary] = []
    for vertex_index in triangle_indices:
        var sample := surface_regions.get_surface_vertex_sample(mesh_node_path, surface_index, vertex_index)
        if sample.is_empty():
            return {}
        samples.append(sample)
    if samples.size() != 3:
        return {}
    var position := Vector3.ZERO
    var normal := Vector3.ZERO
    for corner in range(3):
        position += samples[corner]["position"] * barycentric[corner]
        normal += samples[corner]["normal"] * barycentric[corner]
    if normal.length_squared() < 0.000001:
        return {}
    normal = normal.normalized()
    position += normal * normal_offset

    var edge_start := 0
    var edge_end := 1
    match tangent_edge:
        1:
            edge_start = 1
            edge_end = 2
        2:
            edge_start = 2
            edge_end = 0
    var tangent: Vector3 = samples[edge_end]["position"] - samples[edge_start]["position"]
    tangent = tangent - normal * tangent.dot(normal)
    if tangent.length_squared() < 0.000001:
        return {}
    tangent = tangent.normalized()
    var binormal := tangent.cross(normal).normalized()
    tangent = normal.cross(binormal).normalized()
    var frame := Basis(tangent, normal, binormal).orthonormalized()
    return {
        "landmark_id": landmark_id,
        "position": position,
        "normal": normal,
        "tangent": tangent,
        "binormal": binormal,
        "frame": Transform3D(frame, position)
    }


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
