class_name HorseTackPresentation
extends RefCounted
## First-pass, independently removable tack blockout for the Quaternius horse.
## Coordinates are in the unscaled imported model's space; the parent model_root
## applies the horse's runtime scale. Keep this presentation-only.

const LEATHER := Color("#493020")
const DARK_LEATHER := Color("#241811")
const WOOL := Color("#8b795d")
const METAL := Color("#77736a")

static func attach_to_horse(model_root: Node3D) -> Node3D:
    if model_root == null:
        return null
    var existing := model_root.get_node_or_null("HorseTack")
    if existing != null:
        return existing as Node3D

    var tack := Node3D.new()
    tack.name = "HorseTack"
    model_root.add_child(tack)

    # Saddle blanket and a smooth, low-profile saddle seat.
    _add_box(tack, "SaddleBlanket", Vector3(1.35, 0.10, 1.65), Vector3(0.0, 3.02, 0.05), WOOL)
    var seat := CapsuleMesh.new()
    seat.radius = 0.48
    seat.height = 1.28
    seat.radial_segments = 12
    seat.rings = 4
    var seat_node := _add_mesh(tack, "SaddleSeat", seat, LEATHER)
    seat_node.position = Vector3(0.0, 3.16, 0.05)
    seat_node.rotation.x = deg_to_rad(90.0)
    _add_box(tack, "SaddlePommel", Vector3(0.82, 0.24, 0.20), Vector3(0.0, 3.28, -0.49), LEATHER)
    _add_box(tack, "SaddleCantle", Vector3(0.86, 0.28, 0.18), Vector3(0.0, 3.30, 0.59), DARK_LEATHER)

    # Girth under the horse's barrel, with visible near/far stirrup leathers.
    _add_box(tack, "SaddleGirth", Vector3(1.48, 0.12, 0.16), Vector3(0.0, 2.45, 0.12), DARK_LEATHER)
    for side in [-1.0, 1.0]:
        var x := side * 0.58
        _add_strap(tack, "StirrupLeather%s" % str(side), Vector3(x, 3.05, 0.12), Vector3(x, 1.72, 0.12), DARK_LEATHER, 0.075)
        _add_box(tack, "Stirrup%s" % str(side), Vector3(0.10, 0.12, 0.38), Vector3(x, 1.66, 0.12), METAL)

    # Bridle: crown, cheek pieces, browband, noseband and bit.
    _add_strap(tack, "Crownpiece", Vector3(-0.43, 3.15, -1.45), Vector3(0.43, 3.15, -1.45), LEATHER, 0.075)
    _add_strap(tack, "Browband", Vector3(-0.47, 3.00, -1.62), Vector3(0.47, 3.00, -1.62), LEATHER, 0.07)
    _add_strap(tack, "Noseband", Vector3(-0.43, 2.52, -2.32), Vector3(0.43, 2.52, -2.32), DARK_LEATHER, 0.09)
    for side in [-1.0, 1.0]:
        _add_strap(tack, "Cheekpiece%s" % str(side), Vector3(side * 0.43, 3.12, -1.48), Vector3(side * 0.43, 2.52, -2.32), LEATHER, 0.065)
        _add_strap(tack, "Rein%s" % str(side), Vector3(side * 0.43, 2.45, -2.38), Vector3(side * 0.48, 3.10, 0.42), DARK_LEATHER, 0.045)
    _add_strap(tack, "Bit", Vector3(-0.48, 2.43, -2.40), Vector3(0.48, 2.43, -2.40), METAL, 0.055)
    return tack

static func _add_box(parent: Node3D, node_name: String, size: Vector3, position: Vector3, colour: Color) -> MeshInstance3D:
    var mesh := BoxMesh.new()
    mesh.size = size
    var node := _add_mesh(parent, node_name, mesh, colour)
    node.position = position
    return node

static func _add_mesh(parent: Node3D, node_name: String, mesh: Mesh, colour: Color) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    node.name = node_name
    node.mesh = mesh
    var material := StandardMaterial3D.new()
    material.albedo_color = colour
    material.roughness = 0.82
    node.material_override = material
    parent.add_child(node)
    return node

static func _add_strap(parent: Node3D, node_name: String, start: Vector3, finish: Vector3, colour: Color, width: float) -> void:
    var direction := finish - start
    var length := direction.length()
    if length < 0.001:
        return
    var mesh := BoxMesh.new()
    mesh.size = Vector3(width, length, width * 0.55)
    var node := _add_mesh(parent, node_name, mesh, colour)
    node.position = (start + finish) * 0.5
    node.quaternion = Quaternion(Vector3.UP, direction.normalized())
