class_name CharacterSurfaceRegions
extends RefCounted
## Deformation-aware surface queries for broad regions shared by the two Ara bases.
##
## Region membership is derived from the mesh's skin-weight influences. Vertex positions
## are evaluated from the active blend-shape deltas and current skeleton pose. This is a
## first proof of concept: broad rig-driven regions, not hand-authored fine anatomy masks.

const REGION_BONE_ALIASES := {
    "head": ["head", "headtop_end"],
    "neck": ["neck", "neck1"],
    "chest": ["spine2", "spine3", "chest"],
    "abdomen": ["spine", "spine1", "spine_01"],
    "pelvis": ["hips", "hip", "pelvis"],
    "shoulder_left": ["leftshoulder", "shoulder_l", "leftshoulderjoint"],
    "shoulder_right": ["rightshoulder", "shoulder_r", "rightshoulderjoint"],
    "upper_arm_left": ["leftarm", "upperarm_l", "leftupperarm"],
    "upper_arm_right": ["rightarm", "upperarm_r", "rightupperarm"],
    "forearm_left": ["leftforearm", "forearm_l", "leftlowerarm"],
    "forearm_right": ["rightforearm", "forearm_r", "rightlowerarm"],
    "hand_left": ["lefthand", "hand_l", "leftwrist"],
    "hand_right": ["righthand", "hand_r", "rightwrist"],
    "thigh_left": ["leftupleg", "upleg_l", "leftupperleg"],
    "thigh_right": ["rightupleg", "upleg_r", "rightupperleg"],
    "calf_left": ["leftleg", "leg_l", "leftlowerleg"],
    "calf_right": ["rightleg", "leg_r", "rightlowerleg"],
    "foot_left": ["leftfoot", "foot_l"],
    "foot_right": ["rightfoot", "foot_r"]
}

var _character_root: Node3D
var _body_root: Node3D
var _skeleton: Skeleton3D
var _surfaces: Array[Dictionary] = []
var _region_bone_indices: Dictionary = {}
var _configured := false
var _configuration_error := ""


func configure(character_root: Node3D, body_root: Node3D) -> bool:
    _character_root = character_root
    _body_root = body_root
    _skeleton = _find_skeleton(body_root) if body_root != null else null
    _surfaces.clear()
    _region_bone_indices.clear()
    _configured = false
    _configuration_error = ""

    if _character_root == null or _body_root == null or _skeleton == null:
        _configuration_error = "Character root, body root and Skeleton3D are required"
        return false

    for region_id in REGION_BONE_ALIASES:
        var indices := _resolve_region_bones(region_id)
        if not indices.is_empty():
            _region_bone_indices[region_id] = indices

    var meshes: Array[MeshInstance3D] = []
    _collect_skinned_meshes(_body_root, meshes)
    if meshes.is_empty():
        _configuration_error = "No skinned Ara MeshInstance3D nodes were found"
        return false

    for mesh_instance in meshes:
        var array_mesh := mesh_instance.mesh as ArrayMesh
        if array_mesh == null:
            _configuration_error = "Expected ArrayMesh on %s" % mesh_instance.name
            _surfaces.clear()
            return false
        if array_mesh.blend_shape_mode not in [Mesh.BLEND_SHAPE_MODE_NORMALIZED, Mesh.BLEND_SHAPE_MODE_RELATIVE]:
            _configuration_error = "Unsupported blend-shape mode on %s" % mesh_instance.name
            _surfaces.clear()
            return false
        var skin := mesh_instance.skin
        for surface_index in range(array_mesh.get_surface_count()):
            var arrays := array_mesh.surface_get_arrays(surface_index)
            var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
            var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
            var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
            var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
            if vertices.is_empty() or normals.size() != vertices.size():
                continue
            if bones.is_empty() or weights.size() != bones.size() or bones.size() % vertices.size() != 0:
                continue
            var influences_per_vertex := bones.size() / vertices.size()
            var bind_to_region: Array[PackedStringArray] = []
            bind_to_region.resize(skin.get_bind_count())
            for bind_index in range(skin.get_bind_count()):
                var bone_name := _skin_bind_bone_name(skin, bind_index)
                var region_ids := PackedStringArray()
                for region_id in _region_bone_indices:
                    if int(_region_bone_indices[region_id].get(bone_name, -1)) >= 0:
                        region_ids.append(String(region_id))
                bind_to_region[bind_index] = region_ids

            var region_weights: Dictionary = {}
            for region_id in REGION_BONE_ALIASES:
                var empty_region_weights := PackedFloat32Array()
                empty_region_weights.resize(vertices.size())
                region_weights[region_id] = empty_region_weights

            for vertex_index in range(vertices.size()):
                for influence_index in range(influences_per_vertex):
                    var array_index := vertex_index * influences_per_vertex + influence_index
                    var influence_weight := weights[array_index]
                    if influence_weight <= 0.0:
                        continue
                    var bind_index := bones[array_index]
                    if bind_index < 0 or bind_index >= bind_to_region.size():
                        continue
                    for region_id in bind_to_region[bind_index]:
                        var region_values: PackedFloat32Array = region_weights[region_id]
                        region_values[vertex_index] += influence_weight
                        region_weights[region_id] = region_values

            _surfaces.append({
                "mesh_instance": mesh_instance,
                "surface_index": surface_index,
                "vertices": vertices,
                "normals": normals,
                "bones": bones,
                "weights": weights,
                "influences_per_vertex": influences_per_vertex,
                "region_weights": region_weights,
                "blend_shape_arrays": array_mesh.surface_get_blend_shape_arrays(surface_index),
                "skin": skin
            })

    if _surfaces.is_empty():
        _configuration_error = "No surfaces contain vertices, normals and valid skin weights"
        return false
    _configured = true
    return true


func is_configured() -> bool:
    return _configured and is_instance_valid(_character_root) and is_instance_valid(_skeleton)


func get_configuration_error() -> String:
    return _configuration_error


func get_skeleton() -> Skeleton3D:
    return _skeleton


func has_region(region_id: String, minimum_weight: float = 0.25) -> bool:
    if not is_configured() or not REGION_BONE_ALIASES.has(region_id):
        return false
    for surface in _surfaces:
        var values: PackedFloat32Array = surface["region_weights"][region_id]
        for weight in values:
            if weight >= minimum_weight:
                return true
    return false


func available_regions(minimum_weight: float = 0.25) -> PackedStringArray:
    var result := PackedStringArray()
    for region_id in REGION_BONE_ALIASES:
        if has_region(region_id, minimum_weight):
            result.append(region_id)
    return result


## Returns current character-root-local surface samples. max_samples=0 returns every
## qualifying vertex; a positive limit takes a stable, evenly spaced subset per surface.
func get_region_surface_samples(
    region_id: String,
    minimum_weight: float = 0.25,
    max_samples: int = 0
) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    if not is_configured() or not REGION_BONE_ALIASES.has(region_id):
        return result

    for surface in _surfaces:
        var region_values: PackedFloat32Array = surface["region_weights"][region_id]
        var qualifying: Array[int] = []
        for vertex_index in range(region_values.size()):
            if region_values[vertex_index] >= minimum_weight:
                qualifying.append(vertex_index)
        var stride := 1
        if max_samples > 0 and qualifying.size() > max_samples:
            stride = int(ceil(float(qualifying.size()) / float(max_samples)))
        for qualifying_index in range(0, qualifying.size(), stride):
            var vertex_index := qualifying[qualifying_index]
            var evaluated := _evaluate_vertex(surface, vertex_index)
            if not evaluated.get("valid", false):
                continue
            result.append({
                "position": evaluated["position"],
                "normal": evaluated["normal"],
                "weight": region_values[vertex_index],
                "mesh_instance": surface["mesh_instance"],
                "surface_index": surface["surface_index"],
                "vertex_index": vertex_index,
                "region_id": region_id
            })
    return result


func get_closest_region_sample(
    region_id: String,
    character_local_point: Vector3,
    minimum_weight: float = 0.25,
    max_samples: int = 0
) -> Dictionary:
    var samples := get_region_surface_samples(region_id, minimum_weight, max_samples)
    var best: Dictionary = {}
    var best_distance_squared := INF
    for sample in samples:
        var sample_position: Vector3 = sample["position"]
        var distance_squared: float = sample_position.distance_squared_to(character_local_point)
        if distance_squared < best_distance_squared:
            best_distance_squared = distance_squared
            best = sample
    if not best.is_empty():
        best["distance"] = sqrt(best_distance_squared)
    return best


func get_region_bone_indices(region_id: String) -> PackedInt32Array:
    var result := PackedInt32Array()
    if not _region_bone_indices.has(region_id):
        return result
    for bone_index in _region_bone_indices[region_id].values():
        result.append(int(bone_index))
    return result


func _evaluate_vertex(surface: Dictionary, vertex_index: int) -> Dictionary:
    var vertices: PackedVector3Array = surface["vertices"]
    var normals: PackedVector3Array = surface["normals"]
    var bones: PackedInt32Array = surface["bones"]
    var weights: PackedFloat32Array = surface["weights"]
    var mesh_instance: MeshInstance3D = surface["mesh_instance"]
    var skin: Skin = surface["skin"]
    var influences_per_vertex: int = surface["influences_per_vertex"]
    var local_position := vertices[vertex_index]
    var local_normal := normals[vertex_index]
    var blend_arrays: Array = surface["blend_shape_arrays"]

    for shape_index in range(blend_arrays.size()):
        var shape_weight := mesh_instance.get_blend_shape_value(shape_index)
        if is_zero_approx(shape_weight):
            continue
        var shape_arrays: Array = blend_arrays[shape_index]
        var position_deltas: PackedVector3Array = shape_arrays[Mesh.ARRAY_VERTEX]
        if position_deltas.size() == vertices.size():
            if (mesh_instance.mesh as ArrayMesh).blend_shape_mode == Mesh.BLEND_SHAPE_MODE_NORMALIZED:
                local_position += (position_deltas[vertex_index] - vertices[vertex_index]) * shape_weight
            else:
                local_position += position_deltas[vertex_index] * shape_weight
        var normal_deltas: PackedVector3Array = shape_arrays[Mesh.ARRAY_NORMAL]
        if normal_deltas.size() == normals.size():
            if (mesh_instance.mesh as ArrayMesh).blend_shape_mode == Mesh.BLEND_SHAPE_MODE_NORMALIZED:
                local_normal += (normal_deltas[vertex_index] - normals[vertex_index]) * shape_weight
            else:
                local_normal += normal_deltas[vertex_index] * shape_weight

    var blended_basis := Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO)
    var blended_origin := Vector3.ZERO
    var total_weight := 0.0
    var character_from_skeleton := _character_root.global_transform.affine_inverse() * _skeleton.global_transform

    for influence_index in range(influences_per_vertex):
        var array_index := vertex_index * influences_per_vertex + influence_index
        var influence_weight := weights[array_index]
        if influence_weight <= 0.0:
            continue
        var bind_index := bones[array_index]
        if bind_index < 0 or bind_index >= skin.get_bind_count():
            continue
        var bone_index := _skin_bind_bone_index(skin, bind_index)
        if bone_index < 0 or bone_index >= _skeleton.get_bone_count():
            continue
        var skin_transform: Transform3D = (
            character_from_skeleton
            * _skeleton.get_bone_global_pose(bone_index)
            * skin.get_bind_pose(bind_index)
        )
        blended_basis += skin_transform.basis * influence_weight
        blended_origin += skin_transform.origin * influence_weight
        total_weight += influence_weight

    if total_weight <= 0.00001:
        return {"valid": false}
    var inverse_total_weight := 1.0 / total_weight
    blended_basis = Basis(
        blended_basis.x * inverse_total_weight,
        blended_basis.y * inverse_total_weight,
        blended_basis.z * inverse_total_weight
    )
    blended_origin *= inverse_total_weight
    var blended_skin_transform := Transform3D(blended_basis, blended_origin)
    var character_position := blended_skin_transform * local_position
    var character_normal := (blended_skin_transform.basis.inverse().transposed() * local_normal).normalized()
    return {"valid": true, "position": character_position, "normal": character_normal}


func _resolve_region_bones(region_id: String) -> Dictionary:
    var result: Dictionary = {}
    var aliases: Array = REGION_BONE_ALIASES.get(region_id, [])
    for bone_index in range(_skeleton.get_bone_count()):
        var actual := _normalise_bone_name(_skeleton.get_bone_name(bone_index))
        for alias in aliases:
            var wanted := _normalise_bone_name(String(alias))
            if actual == wanted or actual.ends_with(wanted):
                result[actual] = bone_index
                break
    return result


func _skin_bind_bone_name(skin: Skin, bind_index: int) -> String:
    var named := String(skin.get_bind_name(bind_index))
    if not named.is_empty():
        return _normalise_bone_name(named)
    var bone_index := skin.get_bind_bone(bind_index)
    if bone_index >= 0 and bone_index < _skeleton.get_bone_count():
        return _normalise_bone_name(_skeleton.get_bone_name(bone_index))
    return ""


func _skin_bind_bone_index(skin: Skin, bind_index: int) -> int:
    var named := String(skin.get_bind_name(bind_index))
    if not named.is_empty():
        return _skeleton.find_bone(named)
    return skin.get_bind_bone(bind_index)


func _find_skeleton(node: Node) -> Skeleton3D:
    if node is Skeleton3D:
        return node as Skeleton3D
    for child in node.get_children():
        var found := _find_skeleton(child)
        if found != null:
            return found
    return null


func _collect_skinned_meshes(node: Node, output: Array[MeshInstance3D]) -> void:
    if node is MeshInstance3D:
        var mesh_instance := node as MeshInstance3D
        if mesh_instance.mesh != null and mesh_instance.skin != null:
            output.append(mesh_instance)
    for child in node.get_children():
        _collect_skinned_meshes(child, output)


func _normalise_bone_name(value: String) -> String:
    return value.to_lower().replace("_", "").replace("-", "").replace(" ", "").replace(":", "")
