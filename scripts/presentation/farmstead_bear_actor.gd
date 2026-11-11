class_name FarmsteadBearActor
extends Node3D
## Dedicated low-poly brown bear presentation for Old Mac's farmstead.
## Built from shaped meshes rather than the earlier combat-blockout primitives.
## The model faces local -Z, matching the village creature convention.

var _body: MeshInstance3D
var _head_pivot: Node3D
var _leg_pivots: Array[Node3D] = []
var _idle_clock: float = 0.0
var _label: Label3D

var _coat: StandardMaterial3D
var _coat_light: StandardMaterial3D
var _coat_dark: StandardMaterial3D
var _muzzle_material: StandardMaterial3D
var _nose_material: StandardMaterial3D
var _eye_material: StandardMaterial3D
var _iris_material: StandardMaterial3D
var _claw_material: StandardMaterial3D


func _ready() -> void:
    _create_materials()
    _build_body()
    _build_head()
    _build_legs()
    _build_tail()
    _build_label()


func _process(delta: float) -> void:
    _idle_clock += delta
    if is_instance_valid(_body):
        _body.scale.y = 0.94 + sin(_idle_clock * 1.8) * 0.012
    if is_instance_valid(_head_pivot):
        _head_pivot.rotation.y = sin(_idle_clock * 0.72) * 0.035
        _head_pivot.rotation.x = sin(_idle_clock * 1.1) * 0.012
    for index in range(_leg_pivots.size()):
        var phase := _idle_clock * 1.4 + float(index) * PI * 0.5
        _leg_pivots[index].rotation.x = sin(phase) * 0.012


func _create_materials() -> void:
    _coat = _make_material(Color(0.20, 0.105, 0.052))
    _coat_light = _make_material(Color(0.29, 0.16, 0.082))
    _coat_dark = _make_material(Color(0.12, 0.061, 0.033))
    _muzzle_material = _make_material(Color(0.39, 0.255, 0.16))
    _nose_material = _make_material(Color(0.055, 0.038, 0.031), 0.48)
    _eye_material = _make_material(Color(0.025, 0.018, 0.014), 0.35)
    _iris_material = _make_material(Color(0.58, 0.31, 0.09), 0.32)
    _claw_material = _make_material(Color(0.69, 0.61, 0.45))


func _make_material(colour: Color, roughness: float = 0.94) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = colour
    material.roughness = roughness
    return material


func _sphere_mesh(radius: float = 0.5) -> SphereMesh:
    var mesh := SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius * 2.0
    mesh.radial_segments = 16
    mesh.rings = 10
    return mesh


func _add_ellipsoid(parent: Node3D, node_name: String, position: Vector3, dimensions: Vector3, material: Material) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    instance.name = node_name
    instance.mesh = _sphere_mesh(0.5)
    instance.position = position
    instance.scale = dimensions
    instance.material_override = material
    instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
    parent.add_child(instance)
    return instance


func _add_capsule(parent: Node3D, node_name: String, position: Vector3, radius: float, height: float, material: Material) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    instance.name = node_name
    var mesh := CapsuleMesh.new()
    mesh.radius = radius
    mesh.height = height
    mesh.radial_segments = 12
    mesh.rings = 5
    instance.mesh = mesh
    instance.position = position
    instance.material_override = material
    instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
    parent.add_child(instance)
    return instance


func _build_body() -> void:
    var body_root := Node3D.new()
    body_root.name = "BearBodyRig"
    add_child(body_root)

    _body = _add_ellipsoid(body_root, "DeepBarrelBody", Vector3(0.0, 0.91, 0.12), Vector3(1.52, 1.34, 2.12), _coat)
    _body.scale.y = 0.94
    _add_ellipsoid(body_root, "ShoulderHump", Vector3(0.0, 1.13, -0.48), Vector3(1.34, 1.08, 1.12), _coat_light)
    _add_ellipsoid(body_root, "HeavyChest", Vector3(0.0, 0.83, -0.77), Vector3(1.27, 1.13, 0.86), _coat)
    _add_ellipsoid(body_root, "LowerChestFur", Vector3(0.0, 0.55, -0.82), Vector3(0.94, 0.56, 0.50), _coat_light)


func _build_head() -> void:
    _head_pivot = Node3D.new()
    _head_pivot.name = "BearHeadPivot"
    _head_pivot.position = Vector3(0.0, 1.40, -0.91)
    add_child(_head_pivot)

    _add_ellipsoid(_head_pivot, "BroadBearSkull", Vector3(0.0, 0.10, -0.10), Vector3(0.98, 0.90, 0.94), _coat)
    _add_ellipsoid(_head_pivot, "Forehead", Vector3(0.0, 0.25, -0.34), Vector3(0.78, 0.62, 0.62), _coat_light)
    _add_ellipsoid(_head_pivot, "LongMuzzleBridge", Vector3(0.0, -0.10, -0.57), Vector3(0.54, 0.43, 0.72), _muzzle_material)
    _add_ellipsoid(_head_pivot, "LowerJaw", Vector3(0.0, -0.30, -0.49), Vector3(0.49, 0.25, 0.50), _coat_dark)
    _add_ellipsoid(_head_pivot, "Nose", Vector3(0.0, -0.035, -0.94), Vector3(0.30, 0.22, 0.23), _nose_material)

    for side in [-1.0, 1.0]:
        var ear_x := side * 0.34
        _add_ellipsoid(_head_pivot, "RoundedEar_%s" % ("L" if side < 0.0 else "R"), Vector3(ear_x, 0.48, -0.12), Vector3(0.31, 0.34, 0.24), _coat_dark)
        _add_ellipsoid(_head_pivot, "EarInner_%s" % ("L" if side < 0.0 else "R"), Vector3(ear_x, 0.49, -0.245), Vector3(0.16, 0.18, 0.07), _muzzle_material)
        _add_ellipsoid(_head_pivot, "EyeSocket_%s" % ("L" if side < 0.0 else "R"), Vector3(side * 0.405, 0.16, -0.475), Vector3(0.14, 0.15, 0.10), _coat_dark)
        _add_ellipsoid(_head_pivot, "AmberEye_%s" % ("L" if side < 0.0 else "R"), Vector3(side * 0.445, 0.16, -0.545), Vector3(0.073, 0.078, 0.052), _iris_material)
        _add_ellipsoid(_head_pivot, "Pupil_%s" % ("L" if side < 0.0 else "R"), Vector3(side * 0.45, 0.16, -0.582), Vector3(0.032, 0.048, 0.022), _eye_material)
        _add_ellipsoid(_head_pivot, "MuzzlePad_%s" % ("L" if side < 0.0 else "R"), Vector3(side * 0.16, -0.20, -0.76), Vector3(0.25, 0.20, 0.27), _muzzle_material)


func _build_legs() -> void:
    var leg_specs: Array[Dictionary] = [
        {"name":"FrontLeft", "x":-0.53, "z":-0.55, "radius":0.245, "height":0.82, "front":true},
        {"name":"FrontRight", "x":0.53, "z":-0.55, "radius":0.245, "height":0.82, "front":true},
        {"name":"RearLeft", "x":-0.52, "z":0.77, "radius":0.225, "height":0.76, "front":false},
        {"name":"RearRight", "x":0.52, "z":0.77, "radius":0.225, "height":0.76, "front":false}
    ]
    for spec in leg_specs:
        var pivot := Node3D.new()
        pivot.name = String(spec["name"]) + "Rig"
        pivot.position = Vector3(float(spec["x"]), 0.77, float(spec["z"]))
        add_child(pivot)
        _leg_pivots.append(pivot)

        var radius := float(spec["radius"])
        var height := float(spec["height"])
        _add_capsule(pivot, String(spec["name"]) + "UpperLeg", Vector3(0.0, -0.29, 0.0), radius, height, _coat)
        _add_ellipsoid(pivot, String(spec["name"]) + "Paw", Vector3(0.0, -0.65, -0.12), Vector3(radius * 2.55, 0.34, 0.58), _coat_light)
        for claw_index in range(3):
            var claw := MeshInstance3D.new()
            claw.name = String(spec["name"]) + "Claw_%d" % claw_index
            var claw_mesh := ConeMesh.new()
            claw_mesh.top_radius = 0.006
            claw_mesh.bottom_radius = 0.047
            claw_mesh.height = 0.19
            claw_mesh.radial_segments = 8
            claw.mesh = claw_mesh
            claw.position = Vector3((float(claw_index) - 1.0) * radius * 0.63, -0.69, -0.405)
            claw.rotation.x = -PI * 0.5
            claw.material_override = _claw_material
            pivot.add_child(claw)


func _build_tail() -> void:
    _add_ellipsoid(self, "ShortRoundedTail", Vector3(0.0, 0.91, 1.20), Vector3(0.28, 0.28, 0.32), _coat_dark)


func _build_label() -> void:
    _label = Label3D.new()
    _label.name = "BearName"
    _label.text = "Grain-raiding bear"
    _label.position = Vector3(0.0, 2.22, 0.0)
    _label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    _label.font_size = 28
    _label.outline_size = 5
    add_child(_label)
