class_name CharacterAccessoryFactory
extends RefCounted

## Small runtime primitives are proof-of-pipeline accessories. Replace their
## meshes with authored GLBs while retaining the same socket IDs and item IDs.

static func make_ring(item_id: String, metal_colour: Color = Color("#c9c5bb"), radius: float = 0.012) -> Node3D:
    var root := Node3D.new()
    root.name = item_id
    var mesh_instance := MeshInstance3D.new()
    var torus := TorusMesh.new()
    torus.inner_radius = radius * 0.72
    torus.outer_radius = radius
    torus.rings = 16
    torus.ring_segments = 8
    mesh_instance.mesh = torus
    var material := StandardMaterial3D.new()
    material.albedo_color = metal_colour
    material.metallic = 0.85
    material.roughness = 0.22
    mesh_instance.material_override = material
    root.add_child(mesh_instance)
    return root

static func make_necklace(item_id: String, metal_colour: Color = Color("#c9c5bb")) -> Node3D:
    var root := Node3D.new()
    root.name = item_id
    var chain := MeshInstance3D.new()
    var torus := TorusMesh.new()
    torus.inner_radius = 0.13
    torus.outer_radius = 0.145
    torus.rings = 48
    torus.ring_segments = 8
    chain.mesh = torus
    var material := StandardMaterial3D.new()
    material.albedo_color = metal_colour
    material.metallic = 0.8
    material.roughness = 0.25
    chain.material_override = material
    root.add_child(chain)
    return root
