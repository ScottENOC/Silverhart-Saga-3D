extends RefCounted
## Chunk-owned physical dressing for the source-authored Vampire Grave.
## The sheep remains a static environmental clue; reading, investigation and quest state stay campaign-owned.

const GRAVE_HEX := Vector2i(-256, 28)

static func present_chunk(parent: Node3D, terrain_data: Campaign2WorldTerrainData, chunk_min: Vector2i, chunk_size: int, hex_radius: float) -> Dictionary:
	if parent == null or terrain_data == null or chunk_size <= 0 or hex_radius <= 0.0:
		return {"ok": false, "reason": "invalid_vampire_grave_presentation_arguments"}
	if not _contains(GRAVE_HEX, chunk_min, chunk_size):
		return {"ok": true, "features": 0}
	_add_grave_site(parent, terrain_data, hex_radius)
	return {"ok": true, "features": 1}


static func _add_grave_site(parent: Node3D, terrain_data: Campaign2WorldTerrainData, radius: float) -> void:
	var root := Node3D.new()
	root.name = "VampireGravePresentation"
	root.position = HexGrid.axial_to_world(GRAVE_HEX, radius, terrain_data.elevation_for_hex(GRAVE_HEX))
	parent.add_child(root)

	var earth := _material(Color("#594a37"))
	var fresh_soil := _material(Color("#756044"))
	var wool := _material(Color("#c2bca8"))
	var hide := _material(Color("#887c68"))
	var bone := _material(Color("#e1d8bd"))
	var wound := _material(Color("#482d2b"))

	var mound := MeshInstance3D.new()
	mound.name = "ShallowDisturbedEarth"
	var mound_mesh := SphereMesh.new()
	mound_mesh.radius = 1.0
	mound_mesh.height = 0.48
	mound.mesh = mound_mesh
	mound.scale = Vector3(2.1, 0.34, 1.35)
	mound.position = Vector3(0.0, 0.12, 0.0)
	mound.material_override = earth
	root.add_child(mound)

	for index in range(5):
		var clod := MeshInstance3D.new()
		clod.name = "TurnedSoil_%02d" % index
		var clod_mesh := SphereMesh.new()
		clod_mesh.radius = 0.22 + float(index % 2) * 0.07
		clod_mesh.height = clod_mesh.radius * 0.72
		clod.mesh = clod_mesh
		var angle := TAU * float(index) / 5.0
		clod.position = Vector3(cos(angle) * (0.85 + float(index % 2) * 0.28), 0.18, sin(angle) * 0.58)
		clod.rotation.y = angle
		clod.material_override = fresh_soil
		root.add_child(clod)

	var carcass := Node3D.new()
	carcass.name = "SheepCarcass"
	carcass.position = Vector3(0.18, 0.22, 0.02)
	carcass.rotation.y = deg_to_rad(-24.0)
	root.add_child(carcass)

	var torso := MeshInstance3D.new()
	torso.name = "PartlyBuriedTorso"
	var torso_mesh := CapsuleMesh.new()
	torso_mesh.radius = 0.43
	torso_mesh.height = 1.55
	torso.mesh = torso_mesh
	torso.rotation.z = deg_to_rad(90.0)
	torso.position = Vector3(0.0, 0.02, 0.0)
	torso.material_override = wool
	carcass.add_child(torso)

	var neck := MeshInstance3D.new()
	neck.name = "Neck"
	var neck_mesh := CapsuleMesh.new()
	neck_mesh.radius = 0.19
	neck_mesh.height = 0.62
	neck.mesh = neck_mesh
	neck.position = Vector3(0.62, 0.16, 0.02)
	neck.rotation.z = deg_to_rad(62.0)
	neck.material_override = wool
	carcass.add_child(neck)

	var skull := MeshInstance3D.new()
	skull.name = "Skull"
	var skull_mesh := SphereMesh.new()
	skull_mesh.radius = 0.22
	skull_mesh.height = 0.38
	skull.mesh = skull_mesh
	skull.position = Vector3(0.88, 0.28, 0.12)
	skull.material_override = hide
	carcass.add_child(skull)

	for index in range(4):
		var leg := MeshInstance3D.new()
		leg.name = "Leg_%02d" % index
		var leg_mesh := CylinderMesh.new()
		leg_mesh.top_radius = 0.055
		leg_mesh.bottom_radius = 0.075
		leg_mesh.height = 0.56
		leg.mesh = leg_mesh
		var side := -1.0 if index % 2 == 0 else 1.0
		var along := -0.42 if index < 2 else 0.42
		leg.position = Vector3(along, -0.18, side * 0.27)
		leg.rotation.z = deg_to_rad(22.0 * side)
		leg.material_override = hide
		carcass.add_child(leg)

	var fang := MeshInstance3D.new()
	fang.name = "ShatteredFang"
	var fang_mesh := CylinderMesh.new()
	fang_mesh.top_radius = 0.015
	fang_mesh.bottom_radius = 0.095
	fang_mesh.height = 0.42
	fang_mesh.radial_segments = 6
	fang.mesh = fang_mesh
	fang.position = Vector3(-0.88, 0.18, -0.52)
	fang.rotation.z = deg_to_rad(14.0)
	fang.material_override = bone
	root.add_child(fang)

	# Source buildVampireGrave places a journal directly on the grave hex.
	# Keep the physical clue in the presentation layer; its text and interaction
	# remain owned by campaign content.
	var journal := Node3D.new()
	journal.name = "BuriedJournal"
	journal.position = Vector3(-0.58, 0.24, 0.34)
	journal.rotation.y = deg_to_rad(-18.0)
	journal.rotation.z = deg_to_rad(-12.0)
	root.add_child(journal)
	var leather := _material(Color("#49372b"))
	var paper := _material(Color("#c9b58c"))
	var cover := MeshInstance3D.new()
	cover.name = "LeatherCover"
	var cover_mesh := BoxMesh.new()
	cover_mesh.size = Vector3(0.34, 0.055, 0.26)
	cover.mesh = cover_mesh
	cover.material_override = leather
	journal.add_child(cover)
	var pages := MeshInstance3D.new()
	pages.name = "ParchmentPages"
	var pages_mesh := BoxMesh.new()
	pages_mesh.size = Vector3(0.30, 0.018, 0.23)
	pages.mesh = pages_mesh
	pages.position.y = 0.034
	pages.material_override = paper
	journal.add_child(pages)
	var spine := MeshInstance3D.new()
	spine.name = "JournalSpine"
	var spine_mesh := BoxMesh.new()
	spine_mesh.size = Vector3(0.035, 0.06, 0.27)
	spine.mesh = spine_mesh
	spine.position.x = -0.15
	spine.material_override = leather
	journal.add_child(spine)

	for index in range(2):
		var puncture := MeshInstance3D.new()
		puncture.name = "ThroatPuncture_%02d" % index
		var puncture_mesh := SphereMesh.new()
		puncture_mesh.radius = 0.055
		puncture_mesh.height = 0.035
		puncture.mesh = puncture_mesh
		puncture.position = Vector3(0.93, 0.38, -0.02 + float(index) * 0.14)
		puncture.material_override = wound
		carcass.add_child(puncture)


static func _material(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 1.0
	return material


static func _contains(hex: Vector2i, chunk_min: Vector2i, chunk_size: int) -> bool:
	return hex.x >= chunk_min.x and hex.x < chunk_min.x + chunk_size and hex.y >= chunk_min.y and hex.y < chunk_min.y + chunk_size
