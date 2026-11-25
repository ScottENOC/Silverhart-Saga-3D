extends Node3D
## Lightweight procedural placeholder for the source-authored skeletal house
## guardians. Keeps the encounter readable until a dedicated skeleton asset is
## added; simulation, targeting and combat remain in WorldSimulation.

var bone_material: StandardMaterial3D
var shadow_material: StandardMaterial3D


func _ready() -> void:
	_build_visual()


func _build_visual() -> void:
	bone_material = _make_material(Color("#d5c9a8"))
	shadow_material = _make_material(Color("#302c29"))
	_add_bone("Spine", Vector3(0.0, 0.85, 0.0), Vector3(0.0, 1.55, 0.0), 0.11)
	_add_bone("Pelvis", Vector3(-0.22, 0.82, 0.0), Vector3(0.22, 0.82, 0.0), 0.09)
	_add_bone("Rib_01", Vector3(-0.26, 1.42, 0.0), Vector3(0.26, 1.42, 0.0), 0.055)
	_add_bone("Rib_02", Vector3(-0.30, 1.27, 0.0), Vector3(0.30, 1.27, 0.0), 0.05)
	_add_bone("Rib_03", Vector3(-0.27, 1.12, 0.0), Vector3(0.27, 1.12, 0.0), 0.05)
	_add_bone("Rib_04", Vector3(-0.22, 0.99, 0.0), Vector3(0.22, 0.99, 0.0), 0.045)
	_add_bone("Left_Clavicle", Vector3(0.0, 1.52, 0.0), Vector3(-0.35, 1.48, 0.0), 0.07)
	_add_bone("Right_Clavicle", Vector3(0.0, 1.52, 0.0), Vector3(0.35, 1.48, 0.0), 0.07)
	_add_bone("Left_Upper_Arm", Vector3(-0.35, 1.48, 0.0), Vector3(-0.48, 1.08, 0.0), 0.065)
	_add_bone("Left_Forearm", Vector3(-0.48, 1.08, 0.0), Vector3(-0.42, 0.76, 0.04), 0.055)
	_add_bone("Right_Upper_Arm", Vector3(0.35, 1.48, 0.0), Vector3(0.48, 1.08, 0.0), 0.065)
	_add_bone("Right_Forearm", Vector3(0.48, 1.08, 0.0), Vector3(0.42, 0.76, 0.04), 0.055)
	_add_bone("Left_Thigh", Vector3(-0.14, 0.78, 0.0), Vector3(-0.18, 0.40, 0.0), 0.075)
	_add_bone("Left_Shin", Vector3(-0.18, 0.40, 0.0), Vector3(-0.20, 0.08, 0.04), 0.06)
	_add_bone("Right_Thigh", Vector3(0.14, 0.78, 0.0), Vector3(0.18, 0.40, 0.0), 0.075)
	_add_bone("Right_Shin", Vector3(0.18, 0.40, 0.0), Vector3(0.20, 0.08, 0.04), 0.06)
	_add_skull()
	_add_eye(Vector3(-0.105, 1.83, -0.17))
	_add_eye(Vector3(0.105, 1.83, -0.17))


func _add_skull() -> void:
	var skull := MeshInstance3D.new()
	skull.name = "Skull"
	var mesh := SphereMesh.new()
	mesh.radius = 0.19
	mesh.height = 0.34
	skull.mesh = mesh
	skull.position = Vector3(0.0, 1.83, 0.0)
	skull.material_override = bone_material
	add_child(skull)
	_add_bone("Jaw", Vector3(-0.11, 1.68, -0.01), Vector3(0.11, 1.68, -0.01), 0.035)


func _add_eye(position: Vector3) -> void:
	var eye := MeshInstance3D.new()
	eye.name = "EyeSocket"
	var mesh := SphereMesh.new()
	mesh.radius = 0.055
	mesh.height = 0.11
	eye.mesh = mesh
	eye.position = position
	eye.material_override = shadow_material
	add_child(eye)


func _add_bone(bone_name: String, start: Vector3, finish: Vector3, radius: float) -> void:
	var direction := finish - start
	if direction.length_squared() <= 0.0001:
		return
	var bone := MeshInstance3D.new()
	bone.name = bone_name
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = direction.length() + radius * 2.0
	bone.mesh = mesh
	bone.position = (start + finish) * 0.5
	bone.quaternion = Quaternion(Vector3.UP, direction.normalized())
	bone.material_override = bone_material
	add_child(bone)


func _make_material(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.96
	return material
