class_name WorldGeometryFactory
extends RefCounted

## Shared low-level geometry/material construction for procedural world visuals.
## Building layouts and architectural decisions remain with their owning systems.

static func add_box(
	parent: Node3D,
	node_name: String,
	position: Vector3,
	size: Vector3,
	material: Material
) -> MeshInstance3D:
	if parent == null:
		push_error("WorldGeometryFactory.add_box requires a parent node.")
		return null
	if size.x <= 0.0 or size.y <= 0.0 or size.z <= 0.0:
		push_error("WorldGeometryFactory.add_box requires positive dimensions.")
		return null

	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = position
	instance.material_override = material
	parent.add_child(instance)
	return instance


static func make_material(
	colour: Color,
	roughness: float = 0.88,
	cull_mode: BaseMaterial3D.CullMode = BaseMaterial3D.CULL_BACK
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = roughness
	material.cull_mode = cull_mode
	return material
