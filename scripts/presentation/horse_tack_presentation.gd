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

    # A narrow pad and low, broad seat sit along the horse's back.
    _add_box(tack, "SaddleBlanket", Vector3(1.25, 0.09, 1.55), Vector3(0.0, 3.02, 0.02), WOOL)
    var seat := SphereMesh.new()
    seat.radius = 0.5
    seat.height = 1.0
    seat.radial_segments = 16
    seat.rings = 8
    var seat_node := _add_mesh(tack, "SaddleSeat", seat, LEATHER)
    seat_node.position = Vector3(0.0, 3.13, 0.02)
    seat_node.scale = Vector3(0.88, 0.34, 1.42)
    # Pommel faces the horse's head (+Z); cantle faces the hindquarters (-Z).
    _add_box(tack, "SaddlePommel", Vector3(0.76, 0.20, 0.16), Vector3(0.0, 3.23, 0.48), LEATHER)
    _add_box(tack, "SaddleCantle", Vector3(0.80, 0.23, 0.16), Vector3(0.0, 3.25, -0.55), DARK_LEATHER)

    # Girth and stirrups remain separate pieces for later equipment variants.
    _add_box(tack, "SaddleGirth", Vector3(1.42, 0.11, 0.15), Vector3(0.0, 2.45, 0.10), DARK_LEATHER)
    for side in [-1.0, 1.0]:
        var side_name: String = "Left" if side < 0.0 else "Right"
        var x: float = float(side) * 0.56
        _add_strap(tack, "StirrupLeather%s" % side_name, Vector3(x, 3.02, 0.08), Vector3(x, 1.78, 0.08), DARK_LEATHER, 0.065)
        _add_box(tack, "Stirrup%s" % side_name, Vector3(0.10, 0.12, 0.34), Vector3(x, 1.72, 0.08), METAL)

    # The imported horse faces +Z. Keep all bridle pieces on its head, not rump.
    _add_strap(tack, "Crownpiece", Vector3(-0.40, 3.15, 1.43), Vector3(0.40, 3.15, 1.43), LEATHER, 0.07)
    _add_strap(tack, "Browband", Vector3(-0.43, 3.00, 1.62), Vector3(0.43, 3.00, 1.62), LEATHER, 0.065)
    _add_strap(tack, "Noseband", Vector3(-0.38, 2.54, 2.28), Vector3(0.38, 2.54, 2.28), DARK_LEATHER, 0.08)
    for side in [-1.0, 1.0]:
        var side_name: String = "Left" if side < 0.0 else "Right"
        _add_strap(tack, "Cheekpiece%s" % side_name, Vector3(side * 0.40, 3.12, 1.46), Vector3(side * 0.38, 2.54, 2.28), LEATHER, 0.06)
        _add_strap(tack, "Rein%s" % side_name, Vector3(side * 0.38, 2.46, 2.34), Vector3(side * 0.48, 3.08, 0.40), DARK_LEATHER, 0.04)
    _add_strap(tack, "Bit", Vector3(-0.43, 2.45, 2.36), Vector3(0.43, 2.45, 2.36), METAL, 0.05)
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
