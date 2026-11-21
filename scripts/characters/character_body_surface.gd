class_name CharacterBodySurface
extends RefCounted
## Model-independent contract for querying a character's evaluated skinned surfaces.
##
## Garment construction and surface paths depend on this contract, not on a
## particular character rig, bone naming scheme or anatomy implementation.
## Character-specific adapters implement these methods and may add semantic
## anatomy queries without changing the garment algorithms.


func is_configured() -> bool:
    return false


func get_configuration_error() -> String:
    return "Body surface adapter is not configured"


func get_body_asset_path() -> String:
    return ""


func get_body_root() -> Node3D:
    return null


func get_surface_mesh_instance(_mesh_node_path: NodePath, _surface_index: int) -> MeshInstance3D:
    return null


func get_surface_vertex_sample(
    _mesh_node_path: NodePath,
    _surface_index: int,
    _vertex_index: int
) -> Dictionary:
    return {}


func has_authored_region(_region_id: String, _minimum_weight: float = 0.25) -> bool:
    return false


func get_authored_region_union_samples(
    _region_ids: PackedStringArray,
    _minimum_weight: float = 0.25,
    _max_samples: int = 0
) -> Array[Dictionary]:
    return []
