class_name Campaign2SettlementBuilder
extends RefCounted
## Builds source-described settlement structures and NPC presentation inside streamed chunks.
## The data layout is separate from the reusable 3D construction routines.

const HEX_RADIUS := HexGrid.DEFAULT_RADIUS_M
const ARA_ACTOR_SCRIPT = preload("res://scripts/presentation/ara_character_actor.gd")
const FEMALE_BODY := "res://art/characters/ara_runtime/ara_person_body.glb"
const MALE_BODY := "res://art/characters/ara_runtime/ara_person_male_body.glb"
const HAIR_ROOT := "res://art/characters/ara_runtime/hair/"

var settlements: Array = []

func _init(source_layouts: Array = []) -> void:
	settlements = source_layouts.duplicate(true)

func add_settlements_in_chunk(parent: Node3D, chunk_min: Vector2i, chunk_size: int) -> void:
	for settlement in settlements:
		for building in settlement.get("buildings", []):
			var centre := _read_hex(building.get("center", {}))
			if _contains_chunk(centre, chunk_min, chunk_size):
				_build_building(parent, settlement, building)
		for npc in settlement.get("npcs", []):
			var position := _read_hex(npc.get("position", {}))
			if _contains_chunk(position, chunk_min, chunk_size):
				_add_npc(parent, npc)

func _build_building(parent: Node3D, settlement: Dictionary, building: Dictionary) -> void:
	var kind := String(building.get("kind", "house"))
	if kind != "house":
		return
	var centre := _read_hex(building.get("center", {}))
	var house := Node3D.new()
	house.name = String(building.get("id", "SettlementHouse"))
	house.position = HexGrid.axial_to_world(centre, HEX_RADIUS)
	house.rotation.y = deg_to_rad(-30.0)
	parent.add_child(house)

	var stone := _material(Color("#81796d"))
	var plaster := _material(Color("#c5ae86"))
	var timber := _material(Color("#68462d"))
	var dark_wood := _material(Color("#40291c"))
	var roof := _material(Color("#424a47"))
	var glass := _material(Color("#52717a"), 0.22)
	var hearth := _material(Color("#655d50"))

	_add_box(house, "StoneFoundation", Vector3(0.0, 0.18, 0.0), Vector3(13.2, 0.36, 12.4), stone)
	_add_box(house, "InteriorWoodFloor", Vector3(0.0, 0.40, 0.0), Vector3(12.4, 0.12, 11.6), dark_wood)

	# Three complete walls and a split east wall leave the source-authored
	# east-facing door opening aligned with the short spur to the north road.
	_add_wall(house, "NorthWall", Vector3(0.0, 1.95, -5.85), Vector3(13.0, 3.1, 0.34), plaster, timber)
	_add_wall(house, "SouthWall", Vector3(0.0, 1.95, 5.85), Vector3(13.0, 3.1, 0.34), plaster, timber)
	_add_wall(house, "WestWall", Vector3(-6.35, 1.95, 0.0), Vector3(0.34, 3.1, 11.7), plaster, timber)
	_add_wall(house, "EastWallNorth", Vector3(6.35, 1.95, -4.15), Vector3(0.34, 3.1, 3.4), plaster, timber)
	_add_wall(house, "EastWallSouth", Vector3(6.35, 1.95, 4.15), Vector3(0.34, 3.1, 3.4), plaster, timber)

	_add_box(house, "DoorFrame", Vector3(6.48, 1.55, 0.0), Vector3(0.20, 2.75, 2.65), timber)
	_add_box(house, "FrontDoor", Vector3(6.61, 1.48, 0.0), Vector3(0.12, 2.45, 2.12), dark_wood)
	_add_box(house, "DoorHandle", Vector3(6.70, 1.35, -0.62), Vector3(0.08, 0.16, 0.08), stone)
	_add_box(house, "PorchStep", Vector3(7.05, 0.22, 0.0), Vector3(1.65, 0.30, 3.0), stone)

	# Windows on the north and south elevations, with dark timber lintels.
	for window_x in [-3.6, 3.6]:
		_add_box(house, "NorthWindowGlass", Vector3(window_x, 2.05, -6.04), Vector3(1.55, 1.15, 0.08), glass)
		_add_box(house, "NorthWindowLintel", Vector3(window_x, 2.70, -6.10), Vector3(1.85, 0.16, 0.16), timber)
		_add_box(house, "SouthWindowGlass", Vector3(window_x, 2.05, 6.04), Vector3(1.55, 1.15, 0.08), glass)
		_add_box(house, "SouthWindowLintel", Vector3(window_x, 2.70, 6.10), Vector3(1.85, 0.16, 0.16), timber)

	var left_roof := _add_box(house, "RoofLeftSlope", Vector3(-3.25, 5.45, 0.0), Vector3(7.6, 0.30, 13.0), roof)
	left_roof.rotation.z = deg_to_rad(31.0)
	var right_roof := _add_box(house, "RoofRightSlope", Vector3(3.25, 5.45, 0.0), Vector3(7.6, 0.30, 13.0), roof)
	right_roof.rotation.z = deg_to_rad(-31.0)
	_add_box(house, "RoofRidge", Vector3(0.0, 7.39, 0.0), Vector3(0.30, 0.30, 13.2), dark_wood)
	_add_box(house, "Chimney", Vector3(-4.7, 5.55, -3.7), Vector3(1.15, 3.1, 1.15), stone)
	_add_box(house, "FireplaceHearth", Vector3(-4.7, 0.78, -4.65), Vector3(2.4, 0.55, 1.6), hearth)
	_add_box(house, "FireplaceMantel", Vector3(-4.7, 2.05, -5.25), Vector3(2.6, 0.20, 0.30), timber)

	# Keep a small metadata record on the structure for the later interior/door
	# transition and building-integrity systems.
	house.set_meta("campaign2_settlement_id", String(settlement.get("id", "")))
	house.set_meta("campaign2_building_id", String(building.get("id", "")))
	house.set_meta("source_door_hex", _read_hex(building.get("door", {})))

func _add_wall(parent: Node3D, node_name: String, position: Vector3, size: Vector3, plaster: Material, timber: Material) -> void:
	_add_box(parent, node_name + "_Plaster", position, size, plaster)
	var beam_height := 0.18
	_add_box(parent, node_name + "_TopBeam", position + Vector3(0.0, size.y * 0.5 - beam_height * 0.5, 0.0), Vector3(size.x, beam_height, size.z + 0.04), timber)
	_add_box(parent, node_name + "_BottomBeam", position - Vector3(0.0, size.y * 0.5 - beam_height * 0.5, 0.0), Vector3(size.x, beam_height, size.z + 0.04), timber)

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

func _material(colour: Color, roughness: float = 0.88) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = roughness
	return material

func _add_npc(parent: Node3D, npc: Dictionary) -> void:
	var npc_id := String(npc.get("id", "campaign2_npc"))
	var name := String(npc.get("name", npc_id))
	var variant := String(npc.get("body_variant", "female"))
	var actor := ARA_ACTOR_SCRIPT.new() as AraCharacterActor
	actor.name = "NPC_" + npc_id
	parent.add_child(actor)
	var asset_path := MALE_BODY if variant == "male" else FEMALE_BODY
	var loaded := actor.configure(asset_path)
	var appearance: Dictionary = npc.get("appearance", {})
	if loaded:
		actor.apply_player_profile({
			"skin_colour": appearance.get("skin_colour", "#b9825f"),
			"eye_colour": appearance.get("eye_colour", "Brown"),
			"hair_colour": appearance.get("hair_colour", "Dark brown"),
			"height_scale": float(appearance.get("height_scale", 1.0)),
			"build_scale": float(appearance.get("build_scale", 1.0)),
			"body_variant": variant,
			"gender_presentation": appearance.get("gender_presentation", "Androgynous"),
			"pronouns": appearance.get("pronouns", "they/them")
		})
		var hair_style := String(appearance.get("hair_style", ""))
		if not hair_style.is_empty():
			actor.set_hairstyle(HAIR_ROOT + variant + "_" + hair_style + ".glb")
		actor.apply_equipment_visuals(npc.get("visual_equipment", {}))
	else:
		_add_fallback_person(actor)

	var hex := _read_hex(npc.get("position", {}))
	actor.position = HexGrid.axial_to_world(hex, HEX_RADIUS)
	actor.rotation.y = deg_to_rad(180.0)
	actor.set_meta("campaign2_npc_id", npc_id)
	actor.set_meta("dialogue_id", String(npc.get("dialogue_id", "")))
	actor.set_meta("faction_id", String(npc.get("faction_id", "")))
	actor.set_meta("side", String(npc.get("side", "neutral")))
	actor.set_meta("class_levels", npc.get("class_levels", []))
	actor.set_meta("skill_picks", npc.get("skill_picks", []))
	actor.set_meta("quest_hooks", npc.get("quest_hooks", []))
	actor.add_to_group("campaign2_npc")

	var label := Label3D.new()
	label.name = "Name_" + npc_id
	label.text = name
	label.font_size = 30
	label.pixel_size = 0.012
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = Color("#f4e7ca")
	label.outline_size = 6
	label.outline_modulate = Color("#17212a")
	label.position = actor.position + Vector3(0.0, 2.35, 0.0)
	parent.add_child(label)

func _add_fallback_person(parent: Node3D) -> void:
	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.34
	body_mesh.height = 1.65
	body.mesh = body_mesh
	body.position = Vector3(0.0, 0.85, 0.0)
	body.material_override = _material(Color("#687a83"))
	parent.add_child(body)
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.22
	head_mesh.height = 0.44
	head.mesh = head_mesh
	head.position = Vector3(0.0, 1.78, 0.0)
	head.material_override = _material(Color("#c99e7a"))
	parent.add_child(head)

func _contains_chunk(hex: Vector2i, chunk_min: Vector2i, chunk_size: int) -> bool:
	return hex.x >= chunk_min.x and hex.x < chunk_min.x + chunk_size and hex.y >= chunk_min.y and hex.y < chunk_min.y + chunk_size

func _read_hex(value: Dictionary) -> Vector2i:
	return Vector2i(int(value.get("q", 0)), int(value.get("r", 0)))
