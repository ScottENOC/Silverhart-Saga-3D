class_name HollowmereVillage
extends Node3D
## Exterior presentation for the first playable location. Buildings and paths are
## intentionally blockout-quality; the underlying layout is the authored map.

const HEX_RADIUS: float = HexGrid.DEFAULT_RADIUS_M
const GROUND_SIZE: float = 420.0
const ORGANIC_FEATURES = preload("res://scripts/world/organic_world_features.gd")
const CREATURE_ACTOR_SCRIPT = preload("res://scripts/presentation/creature_actor.gd")
const COSMO_TREE_ROOT: String = "res://art/environment/trees/cosmo_generated/"
const COSMO_TREE_VARIANTS := {
	"ash": 4,
	"bush": 4,
	"cherry": 4,
	"laurel": 4,
	"low_poly_bush": 4,
	"low_poly_tree": 6,
	"pine": 4,
	"spruce": 4,
	"tree_fern": 4,
	"willow": 4,
	"winter_oak": 6
}

var grass_material: StandardMaterial3D
var path_material: StandardMaterial3D
var water_material: StandardMaterial3D
var stone_material: StandardMaterial3D
var plaster_material: StandardMaterial3D
var timber_material: StandardMaterial3D
var dark_wood_material: StandardMaterial3D
var roof_material: StandardMaterial3D
var glass_material: StandardMaterial3D
var foliage_materials: Array[StandardMaterial3D] = []
var cosmo_forest_scenes: Dictionary = {}
var field_material: StandardMaterial3D
var crop_material: StandardMaterial3D
var pasture_material: StandardMaterial3D
var fence_material: StandardMaterial3D

func _ready() -> void:
	_create_materials()
	_create_ground()
	_create_paths_and_stream()
	_create_buildings()
	_create_farmstead()
	_create_farm_animals()
	_create_wilderness_animals()
	_create_bridge()
	_create_signpost()
	_create_forest()

func _material(colour: Color, roughness: float = 0.9, metallic: float = 0.0) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = colour
	result.roughness = roughness
	result.metallic = metallic
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	return result

func _create_materials() -> void:
	grass_material = _material(Color(0.27, 0.36, 0.23))
	path_material = _material(Color(0.43, 0.34, 0.23))
	water_material = _material(Color(0.16, 0.31, 0.36), 0.22)
	stone_material = _material(Color(0.38, 0.37, 0.33))
	plaster_material = _material(Color(0.61, 0.53, 0.40))
	timber_material = _material(Color(0.31, 0.18, 0.10))
	dark_wood_material = _material(Color(0.16, 0.09, 0.05))
	roof_material = _material(Color(0.24, 0.25, 0.22))
	glass_material = _material(Color(0.29, 0.45, 0.49, 0.72), 0.18)
	glass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	field_material = _material(Color(0.30, 0.32, 0.17))
	crop_material = _material(Color(0.48, 0.43, 0.22))
	pasture_material = _material(Color(0.24, 0.34, 0.19))
	fence_material = _material(Color(0.28, 0.17, 0.09))
	foliage_materials = [
		_material(Color(0.19, 0.30, 0.17)),
		_material(Color(0.24, 0.35, 0.19)),
		_material(Color(0.29, 0.38, 0.22))
	]

func _create_ground() -> void:
	var ground := MeshInstance3D.new()
	ground.name = "HollowmereGrassland"
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(GROUND_SIZE, GROUND_SIZE)
	ground.mesh = mesh
	ground.position.y = -0.22
	ground.material_override = grass_material
	add_child(ground)

func _create_paths_and_stream() -> void:
	# The hex map still owns movement and water occupancy. These continuous
	# ribbons are a visual treatment: the visible riverbanks and roads are not
	# forced to follow the six-sided cell outlines.
	var river_points: Array[Vector3] = []
	var river_qr: Array[Vector2i] = [
		Vector2i(-30, -22), Vector2i(-24, -24), Vector2i(-18, -22),
		Vector2i(-12, -24), Vector2i(-6, -27), Vector2i(0, -24),
		Vector2i(5, -24), Vector2i(8, -25), Vector2i(12, -27),
		Vector2i(18, -25), Vector2i(24, -28), Vector2i(30, -25)
	]
	for hex in river_qr:
		river_points.append(HexGrid.axial_to_world(hex, HEX_RADIUS, -0.055))
	var river_widths := PackedFloat32Array([3.0, 3.8, 4.5, 3.2, 4.2, 3.5, 2.7, 2.0, 3.1, 4.3, 3.6, 2.8])
	add_child(ORGANIC_FEATURES.make_ribbon("VillageStream", river_points, river_widths, water_material, 0.0, 10))

	# A slightly wider, darker strip beneath the water gives the banks a
	# natural transition rather than a hard hexagonal edge.
	var bank_material := _material(Color(0.22, 0.25, 0.17))
	var bank_widths := PackedFloat32Array()
	for width in river_widths:
		bank_widths.append(width + 1.25)
	add_child(ORGANIC_FEATURES.make_ribbon("StreamBanks", river_points, bank_widths, bank_material, -0.035, 10))

	# Main roads wander gently between authored destinations. The logical
	# route cells remain the existing axial paths used by movement/pathfinding.
	var north_south: Array[Vector3] = []
	for hex in [Vector2i(8, -40), Vector2i(9, -32), Vector2i(8, -25), Vector2i(7, -17), Vector2i(8, -9), Vector2i(7, -2), Vector2i(8, 7), Vector2i(8, 16), Vector2i(8, 24), Vector2i(11, 28), Vector2i(16, 32), Vector2i(14, 38), Vector2i(11, 44), Vector2i(12, 50), Vector2i(12, 54), HollowmereVillageData.FARMHOUSE_DOOR]:
		north_south.append(HexGrid.axial_to_world(hex, HEX_RADIUS, 0.025))
	var road_widths := PackedFloat32Array([2.5, 2.8, 2.6, 2.4, 2.5, 2.8, 2.5, 2.6, 3.1, 2.8, 2.4, 2.6, 2.4, 2.6, 2.8, 2.5])
	add_child(ORGANIC_FEATURES.make_ribbon("NorthSouthRoad", north_south, road_widths, path_material, 0.0, 8))

	var east_west: Array[Vector3] = []
	for hex in [Vector2i(-40, 24), Vector2i(-30, 23), Vector2i(-20, 25), Vector2i(-10, 24), Vector2i(0, 23), Vector2i(8, 24), Vector2i(16, 25), Vector2i(26, 23), Vector2i(36, 24)]:
		east_west.append(HexGrid.axial_to_world(hex, HEX_RADIUS, 0.025))
	var crossroad_widths := PackedFloat32Array([2.2, 2.4, 2.6, 2.3, 2.5, 3.1, 2.6, 2.4, 2.2])
	add_child(ORGANIC_FEATURES.make_ribbon("EastWestRoad", east_west, crossroad_widths, path_material, 0.0, 8))

	# Short village lanes connect the tavern and homes to the main route.
	var village_lane: Array[Vector3] = []
	for hex in [Vector2i(8, 16), Vector2i(5, 12), Vector2i(2, 8), Vector2i(0, 5), Vector2i(0, 0), Vector2i(1, -5), Vector2i(8, -9)]:
		village_lane.append(HexGrid.axial_to_world(hex, HEX_RADIUS, 0.03))
	var lane_widths := PackedFloat32Array([2.1, 2.0, 2.0, 2.4, 2.2, 2.0, 2.2])
	add_child(ORGANIC_FEATURES.make_ribbon("TavernVillageLane", village_lane, lane_widths, path_material, 0.0, 8))

	# Retain the village's ring road and individual building spurs, but soften
	# their visible geometry so the roads no longer read as hex-cell borders.
	var ring_points: Array[Vector3] = []
	for hex in [Vector2i(-8, -6), Vector2i(0, -6), Vector2i(8, -6), Vector2i(8, 0), Vector2i(8, 6), Vector2i(0, 6), Vector2i(-8, 6), Vector2i(-8, 0), Vector2i(-8, -6)]:
		ring_points.append(HexGrid.axial_to_world(hex, HEX_RADIUS, 0.028))
	var ring_widths := PackedFloat32Array([1.9, 2.0, 2.1, 2.0, 2.1, 2.0, 2.1, 2.0, 1.9])
	add_child(ORGANIC_FEATURES.make_ribbon("TavernRingRoad", ring_points, ring_widths, path_material, 0.0, 6))

	var spurs: Array = [
		{"name": "StoreLane", "points": [Vector2i(0, 6), Vector2i(0, 10), Vector2i(0, 15)]},
		{"name": "ChapelLane", "points": [Vector2i(-8, 0), Vector2i(-10, 0), Vector2i(-11, 0)]},
		{"name": "ElderLane", "points": [Vector2i(0, -6), Vector2i(0, -8), Vector2i(0, -10)]},
		{"name": "MiraLane", "points": [Vector2i(8, 6), Vector2i(9, 8), Vector2i(10, 9)]},
		{"name": "OskarLane", "points": [Vector2i(-4, 6), Vector2i(-4, 8), Vector2i(-4, 9)]}
	]
	for spur in spurs:
		var points: Array[Vector3] = []
		for hex in spur["points"]:
			points.append(HexGrid.axial_to_world(hex, HEX_RADIUS, 0.032))
		var widths := PackedFloat32Array([1.8, 1.7, 1.6])
		add_child(ORGANIC_FEATURES.make_ribbon(String(spur["name"]), points, widths, path_material, 0.0, 8))

func _add_hex_surface(node_name: String, cells: Array[Vector2i], material: Material, elevation: float) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corners := HexGrid.corner_offsets(HEX_RADIUS * 1.005)
	for hex in cells:
		var centre := HexGrid.axial_to_world(hex, HEX_RADIUS, elevation)
		for i in range(HexGrid.SIDE_COUNT):
			var next_i := (i + 1) % HexGrid.SIDE_COUNT
			surface.set_normal(Vector3.UP)
			surface.add_vertex(centre)
			surface.add_vertex(centre + Vector3(corners[next_i].x, 0.0, corners[next_i].y))
			surface.add_vertex(centre + Vector3(corners[i].x, 0.0, corners[i].y))
	var mesh := surface.commit()
	if mesh == null:
		return
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	add_child(instance)

func _create_buildings() -> void:
	# Positions and entrances follow Campaign 2's Hollowmere layout.
	_create_cottage("GeneralStore", Vector2i(0, 18), 8.5, 6.5, 2.9, 1.8, "north")
	_create_cottage("Chapel", Vector2i(-14, 0), 6.8, 7.2, 3.2, 2.0, "east")
	_create_cottage("EldersHouse", Vector2i(0, -12), 6.0, 5.4, 2.65, 1.55, "south")
	_create_cottage("MiraHouse", Vector2i(12, 9), 5.5, 5.0, 2.5, 1.45, "west")
	_create_cottage("OskarHouse", Vector2i(-6, 9), 5.5, 5.0, 2.5, 1.45, "east")
	_add_store_sign()
	_add_chapel_bell_tower()

func _create_farmstead() -> void:
	# The southern signposted road reaches Old Mac's working farm.
	_create_cottage("OldMacFarmhouse", HollowmereVillageData.FARMHOUSE, 8.0, 6.4, 2.9, 1.8, "south")
	var barn_centre := HexGrid.axial_to_world(HollowmereVillageData.FARM_BARN, HEX_RADIUS)
	var barn := Node3D.new()
	barn.name = "OldMacBarn"
	barn.position = barn_centre
	add_child(barn)
	_add_box(barn, "BarnFoundation", Vector3(0.0, 0.12, 0.0), Vector3(13.0, 0.24, 9.0), stone_material)
	_add_box(barn, "BarnRearWall", Vector3(0.0, 2.1, 4.2), Vector3(12.5, 4.0, 0.25), timber_material)
	_add_box(barn, "BarnLeftWall", Vector3(-6.1, 2.1, 0.0), Vector3(0.25, 4.0, 8.5), timber_material)
	_add_box(barn, "BarnRightWall", Vector3(6.1, 2.1, 0.0), Vector3(0.25, 4.0, 8.5), timber_material)
	_add_box(barn, "BarnFrontLeft", Vector3(-3.9, 2.1, -4.2), Vector3(4.5, 4.0, 0.25), timber_material)
	_add_box(barn, "BarnFrontRight", Vector3(3.9, 2.1, -4.2), Vector3(4.5, 4.0, 0.25), timber_material)
	_add_box(barn, "BarnDoorLeft", Vector3(-1.55, 1.8, -4.32), Vector3(0.18, 3.5, 0.16), dark_wood_material)
	_add_box(barn, "BarnDoorRight", Vector3(1.55, 1.8, -4.32), Vector3(0.18, 3.5, 0.16), dark_wood_material)
	var roof_a := _add_box(barn, "BarnRoofA", Vector3(-3.0, 5.0, 0.0), Vector3(7.2, 0.25, 10.0), roof_material)
	roof_a.rotation_degrees.z = -28.0
	var roof_b := _add_box(barn, "BarnRoofB", Vector3(3.0, 5.0, 0.0), Vector3(7.2, 0.25, 10.0), roof_material)
	roof_b.rotation_degrees.z = 28.0
	_add_box(barn, "BarnRidge", Vector3(0.0, 6.7, 0.0), Vector3(0.25, 0.25, 10.2), dark_wood_material)

	# Irregular fields sit beside the farm track; crop rows are separate reusable ribbons.
	_add_farm_field("NorthwestField", [Vector2i(0, 42), Vector2i(13, 40), Vector2i(19, 52), Vector2i(4, 58)], field_material)
	_add_farm_field("EasternCropField", [Vector2i(19, 42), Vector2i(34, 40), Vector2i(38, 55), Vector2i(23, 60)], field_material)
	_add_farm_field("SouthernPasture", [Vector2i(1, 61), Vector2i(15, 62), Vector2i(17, 74), Vector2i(2, 73)], pasture_material)
	_add_crop_rows()
	_add_farm_fence("FarmyardFence", [Vector2i(5, 50), Vector2i(8, 47), Vector2i(18, 47), Vector2i(26, 51), Vector2i(24, 59), Vector2i(15, 61), Vector2i(7, 58), Vector2i(5, 50)])
	_add_farm_fence("PastureFence", [Vector2i(1, 61), Vector2i(15, 62), Vector2i(17, 74), Vector2i(2, 73), Vector2i(1, 61)])
	_add_broken_fence_and_blood_trail()
	var yard_lane: Array[Vector3] = []
	for hex in HollowmereVillageData.FARMYARD_CENTRELINE:
		yard_lane.append(HexGrid.axial_to_world(hex, HEX_RADIUS, 0.035))
	add_child(ORGANIC_FEATURES.make_ribbon("FarmyardLane", yard_lane, PackedFloat32Array([2.2, 2.0, 2.0, 2.0]), path_material, 0.0, 8))

func _create_farm_animals() -> void:
	# Old Mac's surviving herd occupies the fenced southern pasture.
	_spawn_creature("FarmCowA", "cow", "farm", Vector2i(5, 66), 0.82)
	_spawn_creature("FarmCowB", "cow", "farm", Vector2i(10, 69), 0.82)
	_spawn_creature("FarmCowC", "cow", "farm", Vector2i(13, 64), 0.82)
	# A farm horse is present as a visible future mount candidate.
	_spawn_creature("FarmHorse", "horse", "mount", Vector2i(24, 57), 0.82)
	# A second coat variant and a small farm dog use their own original glTF scenes.
	_spawn_creature("FarmWhiteHorse", "horse", "mount", Vector2i(27, 61), 0.82, "Horse_White.gltf")
	_spawn_creature("FarmShiba", "shiba_inu", "farm", Vector2i(19, 60), 0.48, "ShibaInu.gltf")

func _add_broken_fence_and_blood_trail() -> void:
	var gap_hex := Vector2i(1, 67)
	var gap_centre := HexGrid.axial_to_world(gap_hex, HEX_RADIUS, 0.04)
	var broken := Node3D.new()
	broken.name = "BrokenPastureFence"
	broken.position = gap_centre
	add_child(broken)
	var rail_a := _add_box(broken, "BrokenRailA", Vector3(-0.55, 0.32, -0.25), Vector3(1.3, 0.10, 0.12), fence_material)
	rail_a.rotation.y = deg_to_rad(-24.0)
	var rail_b := _add_box(broken, "BrokenRailB", Vector3(0.55, 0.22, 0.22), Vector3(1.0, 0.10, 0.12), dark_wood_material)
	rail_b.rotation.y = deg_to_rad(18.0)

	var blood_material := _material(Color(0.22, 0.045, 0.025))
	var trail_hexes: Array[Vector2i] = [Vector2i(1, 67), Vector2i(-4, 68), Vector2i(-10, 69), Vector2i(-17, 70), Vector2i(-24, 71), Vector2i(-31, 72), Vector2i(-38, 73)]
	for index in range(trail_hexes.size()):
		var stain := MeshInstance3D.new()
		stain.name = "BloodTrail_%02d" % index
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.13 if index < 3 else 0.075
		mesh.bottom_radius = mesh.top_radius
		mesh.height = 0.018
		mesh.radial_segments = 7
		stain.mesh = mesh
		stain.material_override = blood_material
		stain.position = HexGrid.axial_to_world(trail_hexes[index], HEX_RADIUS, 0.015)
		add_child(stain)

func _create_wilderness_animals() -> void:
	# Ambient wildlife is placed in the outer forest belt, away from the
	# settlement, farm and roads. These are presentation actors; encounter
	# spawning and combat ownership remain with the world simulation.
	_spawn_creature("WildernessDeer", "deer", "passive_wildlife", Vector2i(-34, 18), 0.78)
	_spawn_creature("WildernessStag", "stag", "passive_wildlife", Vector2i(37, -12), 0.82)
	_spawn_creature("WildernessFox", "fox", "passive_wildlife", Vector2i(-29, -30), 0.72)
	_spawn_creature("WildernessWolf", "wolf", "predator", Vector2i(39, 39), 0.76)

## Registers the existing exterior animal actors in the campaign simulation.
## They remain neutral and dormant until an encounter explicitly activates them.
func register_animals_with_simulation(simulation: WorldSimulation) -> Dictionary:
	if simulation == null:
		return {"ok": false, "reason": "missing_simulation", "registered_ids": []}
	var registered_ids: Array[String] = []
	var skipped: Array[Dictionary] = []
	for child in get_children():
		var actor := child as CreatureActor
		if actor == null:
			continue
		var animal_id := "animal_" + actor.name.to_lower()
		var state := actor.create_simulation_state(animal_id, actor.name, actor.axial_hex)
		if state == null:
			skipped.append({"actor": actor.name, "reason": "missing_animal_profile"})
			continue
		state.side = "neutral"
		state.combat_dormant = true
		if not state.tags.has("ambient_animal"):
			state.tags.append("ambient_animal")
		var result := simulation.register_animal(state)
		if not bool(result.get("ok", false)):
			skipped.append({"actor": actor.name, "reason": String(result.get("reason", "registration_failed"))})
			continue
		actor.simulation_state = state
		registered_ids.append(state.id)
	return {"ok": skipped.is_empty(), "registered_ids": registered_ids, "skipped": skipped}

func _spawn_creature(actor_name: String, kind: String, behaviour_name: String, hex: Vector2i, scale_factor: float, asset_filename: String = "") -> void:
	var actor := CREATURE_ACTOR_SCRIPT.new() as CreatureActor
	actor.name = actor_name
	actor.creature_kind = kind
	actor.behaviour = behaviour_name
	actor.axial_hex = hex
	actor.add_to_group("creature_actors")
	actor.model_scale = scale_factor
	var filename := asset_filename if not asset_filename.is_empty() else "%s.gltf" % kind.capitalize()
	actor.model_path = "res://art/creatures/quaternius/%s" % filename
	actor.position = HexGrid.axial_to_world(hex, HEX_RADIUS, 0.0)
	actor.rotation.y = deg_to_rad(float(posmod(hex.x * 37 + hex.y * 19, 360)))
	add_child(actor)

func _add_farm_field(node_name: String, corners: Array[Vector2i], material: Material) -> void:
	var points: Array[Vector3] = []
	var centre := Vector3.ZERO
	for hex in corners:
		var point := HexGrid.axial_to_world(hex, HEX_RADIUS, -0.16)
		points.append(point)
		centre += point
	centre /= float(points.size())
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(points.size()):
		surface.set_normal(Vector3.UP)
		surface.add_vertex(centre)
		surface.add_vertex(points[index])
		surface.add_vertex(points[(index + 1) % points.size()])
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = surface.commit()
	instance.material_override = material
	add_child(instance)

func _add_crop_rows() -> void:
	for row in range(8):
		var q := 3 + row
		var start := HexGrid.axial_to_world(Vector2i(q, 43), HEX_RADIUS, -0.10)
		var finish := HexGrid.axial_to_world(Vector2i(q + 9, 53), HEX_RADIUS, -0.10)
		add_child(ORGANIC_FEATURES.make_ribbon("CropRowNorthwest%d" % row, [start, (start + finish) * 0.5 + Vector3(0.0, 0.0, 0.8), finish], PackedFloat32Array([0.16, 0.20, 0.16]), crop_material, 0.0, 4))
	for row in range(9):
		var q := 22 + row
		var start := HexGrid.axial_to_world(Vector2i(q, 43), HEX_RADIUS, -0.10)
		var finish := HexGrid.axial_to_world(Vector2i(q - 1, 57), HEX_RADIUS, -0.10)
		add_child(ORGANIC_FEATURES.make_ribbon("CropRowEast%d" % row, [start, finish], PackedFloat32Array([0.16, 0.16]), crop_material, 0.0, 4))

func _add_farm_fence(node_name: String, points: Array[Vector2i]) -> void:
	var root := Node3D.new()
	root.name = node_name
	add_child(root)
	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = 0.07
	post_mesh.bottom_radius = 0.11
	post_mesh.height = 1.25
	post_mesh.radial_segments = 6
	for index in range(points.size() - 1):
		var a := HexGrid.axial_to_world(points[index], HEX_RADIUS, 0.0)
		var b := HexGrid.axial_to_world(points[index + 1], HEX_RADIUS, 0.0)
		var distance := a.distance_to(b)
		var segments := maxi(1, ceili(distance / 2.5))
		for step in range(segments + 1):
			var t := float(step) / float(segments)
			var position := a.lerp(b, t)
			var post := MeshInstance3D.new()
			post.mesh = post_mesh
			post.position = position + Vector3.UP * 0.62
			post.material_override = fence_material
			root.add_child(post)
		var midpoint := (a + b) * 0.5
		var direction := b - a
		var rail := _add_box(root, "FenceRail", midpoint + Vector3.UP * 0.42, Vector3(0.12, 0.12, distance), fence_material)
		rail.rotation.y = atan2(direction.x, direction.z)
		var upper := _add_box(root, "FenceRailUpper", midpoint + Vector3.UP * 0.82, Vector3(0.12, 0.12, distance), fence_material)
		upper.rotation.y = atan2(direction.x, direction.z)

func _create_cottage(id: String, centre_hex: Vector2i, width: float, depth: float, wall_height: float, roof_rise: float, door_side: String) -> void:
	var root := Node3D.new()
	root.name = id
	root.position = HexGrid.axial_to_world(centre_hex, HEX_RADIUS)
	add_child(root)

	var wall_thickness := 0.24
	var wall_y := 0.22 + wall_height * 0.5
	_add_box(root, "StoneFoundation", Vector3(0.0, 0.10, 0.0), Vector3(width + 0.35, 0.20, depth + 0.35), stone_material)

	if door_side == "north" or door_side == "south":
		_add_box(root, "WestWall", Vector3(-width * 0.5, wall_y, 0.0), Vector3(wall_thickness, wall_height, depth), plaster_material)
		_add_box(root, "EastWall", Vector3(width * 0.5, wall_y, 0.0), Vector3(wall_thickness, wall_height, depth), plaster_material)
		var back_z := depth * 0.5 if door_side == "north" else -depth * 0.5
		_add_box(root, "BackWall", Vector3(0.0, wall_y, back_z), Vector3(width, wall_height, wall_thickness), plaster_material)
		var front_z := -depth * 0.5 if door_side == "north" else depth * 0.5
		_add_door_wall(root, front_z, width, wall_height, wall_thickness, false)
		_add_box(root, "FrontDoor", Vector3(0.0, 1.18, front_z), Vector3(1.02, 2.05, 0.12), dark_wood_material)
	else:
		_add_box(root, "NorthWall", Vector3(0.0, wall_y, -depth * 0.5), Vector3(width, wall_height, wall_thickness), plaster_material)
		_add_box(root, "SouthWall", Vector3(0.0, wall_y, depth * 0.5), Vector3(width, wall_height, wall_thickness), plaster_material)
		var back_x := -width * 0.5 if door_side == "east" else width * 0.5
		_add_box(root, "BackWall", Vector3(back_x, wall_y, 0.0), Vector3(wall_thickness, wall_height, depth), plaster_material)
		var front_x := width * 0.5 if door_side == "east" else -width * 0.5
		_add_door_wall(root, front_x, depth, wall_height, wall_thickness, true)
		_add_box(root, "FrontDoor", Vector3(front_x, 1.18, 0.0), Vector3(0.12, 2.05, 1.02), dark_wood_material)

	# Timber framing and a simple pitched roof give the buildings a coherent village silhouette.
	for x in [-width * 0.5 + 0.12, 0.0, width * 0.5 - 0.12]:
		for z in [-depth * 0.5 + 0.12, depth * 0.5 - 0.12]:
			_add_box(root, "TimberPost", Vector3(x, wall_y, z), Vector3(0.16, wall_height + 0.08, 0.16), timber_material)
	var slope_length := sqrt(pow(depth * 0.5, 2.0) + pow(roof_rise, 2.0))
	var roof_angle := rad_to_deg(atan2(roof_rise, depth * 0.5))
	var north_roof := _add_box(root, "NorthRoofSlope", Vector3(0.0, 0.22 + wall_height + roof_rise * 0.5, -depth * 0.25), Vector3(width + 0.65, 0.20, slope_length), roof_material)
	north_roof.rotation_degrees.x = -roof_angle
	var south_roof := _add_box(root, "SouthRoofSlope", Vector3(0.0, 0.22 + wall_height + roof_rise * 0.5, depth * 0.25), Vector3(width + 0.65, 0.20, slope_length), roof_material)
	south_roof.rotation_degrees.x = roof_angle
	_add_box(root, "RoofRidge", Vector3(0.0, 0.22 + wall_height + roof_rise, 0.0), Vector3(width + 0.75, 0.18, 0.22), dark_wood_material)
	_add_box(root, "SideWindow", Vector3(width * 0.5 + 0.02, 1.75, 0.55), Vector3(0.08, 0.72, 0.82), glass_material)
	_add_box(root, "WindowSill", Vector3(width * 0.5 + 0.10, 1.36, 0.55), Vector3(0.16, 0.12, 1.0), timber_material)
	_add_box(root, "Chimney", Vector3(-width * 0.28, wall_height + 0.75, -depth * 0.22), Vector3(0.55, 1.8, 0.58), stone_material)

func _add_door_wall(parent: Node3D, front: float, length: float, wall_height: float, thickness: float, side_wall: bool) -> void:
	var door_width := 1.15
	var segment := maxf(0.5, (length - door_width) * 0.5)
	var wall_y := 0.22 + wall_height * 0.5
	var lintel_y := 0.22 + wall_height - 0.32
	if side_wall:
		_add_box(parent, "DoorWallA", Vector3(front, wall_y, -(door_width * 0.5 + segment * 0.5)), Vector3(thickness, wall_height, segment), plaster_material)
		_add_box(parent, "DoorWallB", Vector3(front, wall_y, door_width * 0.5 + segment * 0.5), Vector3(thickness, wall_height, segment), plaster_material)
		_add_box(parent, "DoorLintel", Vector3(front, lintel_y, 0.0), Vector3(thickness, 0.64, door_width), plaster_material)
	else:
		_add_box(parent, "DoorWallA", Vector3(-(door_width * 0.5 + segment * 0.5), wall_y, front), Vector3(segment, wall_height, thickness), plaster_material)
		_add_box(parent, "DoorWallB", Vector3(door_width * 0.5 + segment * 0.5, wall_y, front), Vector3(segment, wall_height, thickness), plaster_material)
		_add_box(parent, "DoorLintel", Vector3(0.0, lintel_y, front), Vector3(door_width, 0.64, thickness), plaster_material)

func _add_store_sign() -> void:
	var root := get_node_or_null("GeneralStore") as Node3D
	if root == null:
		return
	_add_box(root, "StoreSignBoard", Vector3(0.0, 2.75, -3.45), Vector3(3.3, 0.55, 0.16), dark_wood_material)
	var sign := Label3D.new()
	sign.name = "StoreSign"
	sign.text = "GENERAL STORE"
	sign.position = Vector3(0.0, 2.62, -3.56)
	sign.font_size = 34
	sign.pixel_size = 0.006
	sign.modulate = Color(0.91, 0.82, 0.63)
	sign.outline_size = 5
	add_child_to(root, sign)

func _add_chapel_bell_tower() -> void:
	var root := get_node_or_null("Chapel") as Node3D
	if root == null:
		return
	_add_box(root, "BellTower", Vector3(0.0, 4.2, -1.4), Vector3(1.45, 2.1, 1.45), stone_material)
	_add_box(root, "BellOpening", Vector3(0.0, 4.35, -0.64), Vector3(0.72, 0.62, 0.08), dark_wood_material)
	_add_box(root, "ChapelCrossStem", Vector3(0.0, 5.75, -1.4), Vector3(0.14, 1.0, 0.14), timber_material)
	_add_box(root, "ChapelCrossBar", Vector3(0.0, 5.85, -1.4), Vector3(0.65, 0.14, 0.14), timber_material)

func _create_bridge() -> void:
	var centre := HexGrid.axial_to_world(HollowmereVillageData.BRIDGE, HEX_RADIUS, 0.0)
	var bridge := Node3D.new()
	bridge.name = "NarrowRiverBridge"
	bridge.position = centre
	# The river follows the q-axis direction; rotate the bridge so its deck
	# meets the channel at a convincing crossing angle.
	bridge.rotation.y = deg_to_rad(-5.0)
	add_child(bridge)
	_add_box(bridge, "StreamBridgeDeck", Vector3(0.0, 0.18, 0.0), Vector3(2.8, 0.24, 4.8), timber_material)
	for side in [-1.0, 1.0]:
		_add_box(bridge, "BridgeRail", Vector3(side * 1.22, 0.62, 0.0), Vector3(0.16, 0.72, 4.6), dark_wood_material)
		for z in [-2.0, 0.0, 2.0]:
			_add_box(bridge, "BridgePost", Vector3(side * 1.22, 0.55, z), Vector3(0.2, 0.95, 0.2), timber_material)

func _create_signpost() -> void:
	var centre := HexGrid.axial_to_world(HollowmereVillageData.CROSSROADS, HEX_RADIUS, 0.0)
	var post := MeshInstance3D.new()
	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = 0.10
	post_mesh.bottom_radius = 0.15
	post_mesh.height = 2.6
	post.mesh = post_mesh
	post.position = centre + Vector3(0.0, 1.3, 0.0)
	post.material_override = timber_material
	add_child(post)
	_add_box(self, "SignboardNorth", centre + Vector3(0.0, 2.0, -0.05), Vector3(4.2, 0.78, 0.14), dark_wood_material)
	_add_box(self, "SignboardSouth", centre + Vector3(0.0, 1.05, -0.05), Vector3(4.2, 0.78, 0.14), dark_wood_material)
	var north_south_label := Label3D.new()
	north_south_label.text = "N  MILLBROOK  /  SILVERHART\nS  OLD MAC'S FARMSTEAD"
	north_south_label.position = centre + Vector3(0.0, 2.0, -0.14)
	north_south_label.font_size = 17
	north_south_label.pixel_size = 0.004
	north_south_label.modulate = Color(0.91, 0.82, 0.63)
	north_south_label.outline_size = 4
	add_child(north_south_label)
	var east_west_label := Label3D.new()
	east_west_label.text = "E  REDDALE  /  W  EMBERLODE"
	east_west_label.position = centre + Vector3(0.0, 1.05, -0.14)
	east_west_label.font_size = 17
	east_west_label.pixel_size = 0.004
	east_west_label.modulate = Color(0.91, 0.82, 0.63)
	east_west_label.outline_size = 4
	add_child(east_west_label)

func _create_forest() -> void:
	_load_cosmo_forest_scenes()
	var tree_index := 0
	# Keep the authored forest footprint and its deterministic four-hex spacing.
	# The old placeholder cylinders are replaced by the generated Cosmo tree GLBs.
	for q in range(-96, 97, 4):
		for r in range(-96, 97, 4):
			var hex := Vector2i(q, r)
			if not HollowmereVillageData.is_forest_candidate(hex):
				continue
			var density_roll := HollowmereVillageData._stable_noise(q + 17, r - 9)
			if density_roll < 0.56:
				continue
			var family := _select_cosmo_tree_family(hex)
			if _spawn_cosmo_vegetation(family, hex, tree_index, false):
				tree_index += 1

	# A lighter understorey fills gaps without blocking the existing roads,
	# buildings, stream crossing or farm. Shrubs and ferns are deliberately
	# less frequent than canopy trees.
	var understorey_index := 0
	for q in range(-96, 97, 8):
		for r in range(-96, 97, 8):
			var hex := Vector2i(q, r)
			if not HollowmereVillageData.is_forest_candidate(hex):
				continue
			if HollowmereVillageData.has_tree(hex):
				continue
			var density_roll := HollowmereVillageData._stable_noise(q + 977, r - 337)
			if density_roll < 0.70:
				continue
			var near_stream := _is_near_village_stream(hex, 7.0)
			var family := "bush"
			if near_stream and density_roll < 0.84:
				family = "tree_fern"
			elif density_roll > 0.91:
				family = "low_poly_bush"
			if _spawn_cosmo_vegetation(family, hex, understorey_index, true):
				understorey_index += 1

func _load_cosmo_forest_scenes() -> void:
	if not cosmo_forest_scenes.is_empty():
		return
	for family in COSMO_TREE_VARIANTS:
		var variants: Array[PackedScene] = []
		for variant in range(1, int(COSMO_TREE_VARIANTS[family]) + 1):
			var path := COSMO_TREE_ROOT + "%s_%02d.glb" % [family, variant]
			var packed := load(path) as PackedScene
			if packed == null:
				push_error("Could not load Cosmo forest model: %s" % path)
				continue
			variants.append(packed)
		cosmo_forest_scenes[family] = variants

func _select_cosmo_tree_family(hex: Vector2i) -> String:
	var roll := HollowmereVillageData._stable_noise(hex.x + 401, hex.y - 719)
	if _is_near_village_stream(hex, 7.0):
		if roll < 0.48:
			return "willow"
		if roll < 0.66:
			return "ash"
		if roll < 0.82:
			return "laurel"
		if roll < 0.94:
			return "cherry"
		return "spruce"
	if roll < 0.18:
		return "ash"
	if roll < 0.33:
		return "cherry"
	if roll < 0.46:
		return "laurel"
	if roll < 0.64:
		return "pine"
	if roll < 0.80:
		return "spruce"
	if roll < 0.92:
		return "winter_oak"
	return "low_poly_tree"

func _is_near_village_stream(hex: Vector2i, distance: float) -> bool:
	if absi(hex.x) > 34:
		return false
	return absf(float(hex.y) - HollowmereVillageData._river_centre_r(hex.x)) <= distance

func _spawn_cosmo_vegetation(family: String, hex: Vector2i, index: int, is_understorey: bool) -> bool:
	var variants: Array = cosmo_forest_scenes.get(family, [])
	if variants.is_empty():
		return false
	var variant_roll := HollowmereVillageData._stable_noise(hex.x + 137, hex.y - 53)
	var variant_index := mini(int(variant_roll * float(variants.size())), variants.size() - 1)
	var packed := variants[variant_index] as PackedScene
	if packed == null:
		return false
	var vegetation := packed.instantiate() as Node3D
	if vegetation == null:
		push_error("Cosmo model root is not Node3D: %s" % family)
		return false

	var size_roll := HollowmereVillageData._stable_noise(hex.x + 811, hex.y - 617)
	var scale_min := 0.78 if not is_understorey else 0.68
	var scale_range := 0.46 if not is_understorey else 0.48
	var scale_factor := scale_min + size_roll * scale_range
	if family == "low_poly_tree":
		scale_factor *= 0.92
	elif family == "tree_fern":
		scale_factor *= 0.88
	vegetation.name = "Cosmo_%s_%03d" % [family, index]
	vegetation.scale = Vector3.ONE * scale_factor
	var jitter_x := (HollowmereVillageData._stable_noise(hex.x + 31, hex.y + 19) - 0.5) * 1.5
	var jitter_z := (HollowmereVillageData._stable_noise(hex.x - 43, hex.y + 71) - 0.5) * 1.5
	vegetation.position = HexGrid.axial_to_world(hex, HEX_RADIUS) + Vector3(jitter_x, 0.0, jitter_z)
	vegetation.rotation.y = HollowmereVillageData._stable_noise(hex.x + 503, hex.y - 907) * TAU
	add_child(vegetation)
	return true

func _add_box(parent: Node3D, node_name: String, position: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = position
	instance.material_override = material
	parent.add_child(instance)
	return instance

func add_child_to(parent: Node3D, child: Node) -> void:
	parent.add_child(child)

