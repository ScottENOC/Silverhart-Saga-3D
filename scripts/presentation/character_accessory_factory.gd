class_name CharacterAccessoryFactory
extends RefCounted

## Runtime primitive prototypes. Replace meshes with authored GLBs while retaining
## stable item IDs and the same calibrated attachment socket contract.

static func make_ring(item_id: String, metal_colour: Color = Color("#c9c5bb"), radius: float = 0.012) -> Node3D:
    return _make_torus(item_id, metal_colour, radius, radius * 0.72)

static func make_earring(item_id: String, metal_colour: Color = Color("#c9c5bb")) -> Node3D:
    var root := Node3D.new()
    root.name = item_id
    var hoop := _make_torus("Hoop", metal_colour, 0.009, 0.006)
    root.add_child(hoop)
    return root

static func make_necklace(item_id: String, metal_colour: Color = Color("#c9c5bb")) -> Node3D:
    return _make_torus(item_id, metal_colour, 0.145, 0.13)

static func _make_torus(item_id: String, metal_colour: Color, outer_radius: float, inner_radius: float) -> Node3D:
    var root := Node3D.new()
    root.name = item_id
    var mesh_instance := MeshInstance3D.new()
    var torus := TorusMesh.new()
    torus.inner_radius = inner_radius
    torus.outer_radius = outer_radius
    torus.rings = 32
    torus.ring_segments = 12
    mesh_instance.mesh = torus
    var material := StandardMaterial3D.new()
    material.albedo_color = metal_colour
    material.metallic = 0.85
    material.roughness = 0.22
    mesh_instance.material_override = material
    root.add_child(mesh_instance)
    return root
