class_name CharacterSurfaceRegionMask
extends Resource
## Authored semantic weights for one exact skinned mesh surface.
## The signature intentionally includes rest vertices and indices: re-exporting or
## reordering the source mesh invalidates the mask instead of silently mislabelling it.

const REGION_IDS := [
    "breast_left",
    "breast_right",
    "underbust",
    "waist",
    "hip_left",
    "hip_right",
    "buttock_left",
    "buttock_right",
    "groin",
    "face_front",
    "lips",
    "ear_left",
    "ear_right",
    "neck_front",
    "neck_back",
    "neck_left",
    "neck_right",
    "clavicle_left",
    "clavicle_right",
    "areola_left",
    "areola_right",
    "nipple_left",
    "nipple_right",
    "chest_back",
    "abdomen_upper",
    "abdomen_lower",
    "waist_front",
    "waist_back",
    "waist_left",
    "waist_right",
    "flank_left",
    "flank_right",
    "pelvis_front",
    "pelvis_back",
    "perineum",
    "anal_region",
    "vulva_external",
    "penis_external",
    "scrotum",
    "shoulder_left",
    "shoulder_right",
    "elbow_left",
    "elbow_right",
    "forearm_left",
    "forearm_right",
    "wrist_left",
    "wrist_right",
    "palm_left",
    "palm_right",
    "hand_back_left",
    "hand_back_right",
    "thigh_inner_left",
    "thigh_inner_right",
    "thigh_outer_left",
    "thigh_outer_right",
    "knee_left",
    "knee_right",
    "calf_left",
    "calf_right",
    "ankle_left",
    "ankle_right",
    "foot_top_left",
    "foot_top_right",
    "foot_sole_left",
    "foot_sole_right"
]

@export var body_asset_path: String = ""
@export var mesh_node_path: NodePath
@export_range(0, 255, 1) var surface_index: int = 0
@export var surface_name: String = ""
@export_range(0, 1000000, 1) var vertex_count: int = 0
@export var surface_signature: String = ""
## Dictionary[String, PackedFloat32Array], with one [0, 1] weight per source vertex.
@export var region_weights: Dictionary = {}


static func build_surface_signature(mesh: Mesh, requested_surface_index: int) -> String:
    if mesh == null or requested_surface_index < 0 or requested_surface_index >= mesh.get_surface_count():
        return ""
    var arrays := mesh.surface_get_arrays(requested_surface_index)
    var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
    var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
    if vertices.is_empty():
        return ""
    var context := HashingContext.new()
    if context.start(HashingContext.HASH_SHA256) != OK:
        return ""
    context.update(vertices.to_byte_array())
    context.update(indices.to_byte_array())
    context.update(mesh.surface_get_name(requested_surface_index).to_utf8_buffer())
    return context.finish().hex_encode()


func validate_for_mesh(mesh_instance: MeshInstance3D, body_root: Node3D, expected_body_asset_path: String) -> String:
    if mesh_instance == null or body_root == null or mesh_instance.mesh == null:
        return "A valid mesh instance, body root and mesh resource are required"
    if not expected_body_asset_path.is_empty() and body_asset_path != expected_body_asset_path:
        return "Mask body asset mismatch: expected %s, got %s" % [expected_body_asset_path, body_asset_path]
    if body_root.get_node_or_null(mesh_node_path) != mesh_instance:
        return "Mask mesh path does not resolve to the supplied MeshInstance3D"
    if surface_index < 0 or surface_index >= mesh_instance.mesh.get_surface_count():
        return "Mask surface index is outside the source mesh"
    var arrays := mesh_instance.mesh.surface_get_arrays(surface_index)
    var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
    if vertices.size() != vertex_count:
        return "Mask vertex count mismatch: expected %d, got %d" % [vertex_count, vertices.size()]
    if mesh_instance.mesh.surface_get_name(surface_index) != surface_name:
        return "Mask surface name mismatch"
    var actual_signature := build_surface_signature(mesh_instance.mesh, surface_index)
    if surface_signature.is_empty() or actual_signature != surface_signature:
        return "Mask surface signature mismatch; re-author against the current GLB export"
    if region_weights.is_empty():
        return "Mask contains no semantic region weights"
    for region_variant in region_weights:
        var region_id := String(region_variant)
        if not REGION_IDS.has(region_id):
            return "Unsupported fine surface region ID: %s" % region_id
        var weights: Variant = region_weights[region_variant]
        if not weights is PackedFloat32Array or weights.size() != vertex_count:
            return "Region %s must contain exactly %d PackedFloat32 weights" % [region_id, vertex_count]
        var has_weight := false
        for weight in weights:
            if not is_finite(weight) or weight < 0.0 or weight > 1.0:
                return "Region %s contains a non-finite or out-of-range weight" % region_id
            has_weight = has_weight or weight > 0.0
        if not has_weight:
            return "Region %s contains no weighted vertices" % region_id
    return ""
