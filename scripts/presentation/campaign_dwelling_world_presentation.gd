class_name CampaignDwellingWorldPresentation
extends RefCounted
## Small exterior representations of the three source-authored player dwellings.
## The authoritative ownership and layout identity remain in CampaignDwellingState.

static func present_all(parent: Node3D, state: CampaignDwellingState, hex_radius: float) -> Dictionary:
	if parent == null or state == null or hex_radius <= 0.0:
		return {"ok": false, "reason": "invalid_dwelling_presentation_input"}
	var previous := parent.get_node_or_null("CampaignDwellingPresentation")
	if previous != null:
		previous.queue_free()
	var root := Node3D.new()
	root.name = "CampaignDwellingPresentation"
	parent.add_child(root)
	var materials := {
		"wood": _material(Color("#725039")),
		"weathered_wood": _material(Color("#51483d")),
		"stone": _material(Color("#77736a")),
		"roof": _material(Color("#373d3e")),
		"repaired_roof": _material(Color("#55483a")),
		"glass": _material(Color("#77929a", 0.82))
	}
	_present_cottage(root, state, hex_radius, materials)
	_present_abandoned_house(root, state, hex_radius, materials)
	_present_manor(root, state, hex_radius, materials)
	return {"ok": true, "site_count": 3, "root": root}


static func _present_cottage(parent: Node3D, state: CampaignDwellingState, radius: float, materials: Dictionary) -> void:
	var site := Node3D.new()
	site.name = "CrossroadsCottageSite"
	site.position = HexGrid.axial_to_world(Vector2i(13, 27), radius)
	parent.add_child(site)
	if not bool(state.owned.get("crossroads_cottage", false)):
		for offset in [Vector3(-1.8, 0.45, -1.35), Vector3(1.8, 0.45, -1.35), Vector3(-1.8, 0.45, 1.35), Vector3(1.8, 0.45, 1.35)]:
			_add_box(site, "PlotStake", offset, Vector3(0.12, 0.9, 0.12), materials.weathered_wood)
		return
	var country_house := String(state.upgrades.get("crossroads_cottage", "")) == "upgrade_country_house"
	var width := 5.8 if country_house else 4.2
	var depth := 4.5 if country_house else 3.3
	_build_house(site, width, depth, 2.5 if country_house else 2.2, materials, false, true)
	if country_house:
		_add_box(site, "CountryHouseRearExtension", Vector3(0.0, 1.1, -depth * 0.42), Vector3(width * 0.72, 2.2, 1.25), materials.wood)
		_add_box(site, "CountryHouseBenchPorch", Vector3(1.4, 0.32, depth * 0.58), Vector3(1.4, 0.28, 0.42), materials.wood)


static func _present_abandoned_house(parent: Node3D, state: CampaignDwellingState, radius: float, materials: Dictionary) -> void:
	var site := Node3D.new()
	site.name = "AbandonedRoadsideHouseSite"
	site.position = HexGrid.axial_to_world(Vector2i(14, -176), radius)
	parent.add_child(site)
	var restored := bool(state.owned.get("abandoned_house", false))
	_build_house(site, 4.7, 3.6, 2.25, materials, not restored, restored)


static func _present_manor(parent: Node3D, state: CampaignDwellingState, radius: float, materials: Dictionary) -> void:
	var site := Node3D.new()
	site.name = "SilverhartManorSite"
	site.position = HexGrid.axial_to_world(Vector2i(39, -502), radius)
	parent.add_child(site)
	var fortified := String(state.upgrades.get("silverhart_manor", "")) == "fortify_silverhart_manor"
	_build_house(site, 6.8, 5.4, 2.8, materials, not fortified, fortified)
	if fortified:
		_add_box(site, "ManorChimney", Vector3(2.2, 3.45, -1.4), Vector3(0.48, 1.3, 0.48), materials.stone)


static func _build_house(
	parent: Node3D,
	width: float,
	depth: float,
	wall_height: float,
	materials: Dictionary,
	ruined: bool,
	repaired: bool
) -> void:
	var wall_material: Material = materials.wood if repaired or not ruined else materials.weathered_wood
	var roof_material: Material = materials.repaired_roof if repaired else materials.roof
	_add_box(parent, "StoneFooting", Vector3(0.0, 0.12, 0.0), Vector3(width + 0.35, 0.24, depth + 0.35), materials.stone)
	var front_height := wall_height * (0.7 if ruined else 1.0)
	_add_box(parent, "FrontWallLeft", Vector3(-width * 0.29, front_height * 0.5 + 0.18, depth * 0.5), Vector3(width * 0.42, front_height, 0.18), wall_material)
	_add_box(parent, "FrontWallRight", Vector3(width * 0.29, front_height * 0.5 + 0.18, depth * 0.5), Vector3(width * 0.42, front_height, 0.18), wall_material)
	_add_box(parent, "RearWall", Vector3(0.0, wall_height * 0.5 + 0.18, -depth * 0.5), Vector3(width, wall_height, 0.18), wall_material)
	_add_box(parent, "LeftWall", Vector3(-width * 0.5, wall_height * 0.5 + 0.18, 0.0), Vector3(0.18, wall_height, depth), wall_material)
	_add_box(parent, "RightWall", Vector3(width * 0.5, wall_height * 0.5 + 0.18, 0.0), Vector3(0.18, wall_height, depth), wall_material)
	_add_box(parent, "Door", Vector3(0.0, 0.95, depth * 0.5 + 0.105), Vector3(0.8, 1.75, 0.1), materials.weathered_wood)
	_add_box(parent, "WindowLeft", Vector3(-width * 0.34, 1.45, depth * 0.5 + 0.11), Vector3(0.58, 0.52, 0.06), materials.glass)
	_add_box(parent, "WindowRight", Vector3(width * 0.34, 1.45, depth * 0.5 + 0.11), Vector3(0.58, 0.52, 0.06), materials.glass)
	if ruined:
		_add_box(parent, "BrokenRoofSection", Vector3(-width * 0.22, wall_height + 0.45, 0.0), Vector3(width * 0.62, 0.18, depth * 1.12), roof_material)
		_add_box(parent, "CollapsedBeam", Vector3(width * 0.18, wall_height + 0.12, depth * 0.08), Vector3(width * 0.72, 0.18, 0.2), materials.weathered_wood)
	else:
		var left_roof := _add_box(parent, "LeftRoofSlope", Vector3(-width * 0.23, wall_height + 0.42, 0.0), Vector3(width * 0.62, 0.2, depth * 1.16), roof_material)
		left_roof.rotation.z = deg_to_rad(-28.0)
		var right_roof := _add_box(parent, "RightRoofSlope", Vector3(width * 0.23, wall_height + 0.42, 0.0), Vector3(width * 0.62, 0.2, depth * 1.16), roof_material)
		right_roof.rotation.z = deg_to_rad(28.0)


static func _add_box(parent: Node3D, node_name: String, position: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = position
	instance.material_override = material
	parent.add_child(instance)
	return instance


static func _material(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.94
	return material
