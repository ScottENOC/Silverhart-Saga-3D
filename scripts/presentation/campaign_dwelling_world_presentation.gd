class_name CampaignDwellingWorldPresentation
extends RefCounted
## Small exterior representations of the three source-authored player dwellings.
## The authoritative ownership and layout identity remain in CampaignDwellingState.

static func present_all(parent: Node3D, state: CampaignDwellingState, hex_radius: float) -> Dictionary:
	if parent == null or state == null or hex_radius <= 0.0:
		return {"ok": false, "reason": "invalid_dwelling_presentation_input"}
	var previous := parent.get_node_or_null("CampaignDwellingPresentation")
	if previous != null:
		previous.free()
	var root := Node3D.new()
	root.name = "CampaignDwellingPresentation"
	parent.add_child(root)
	var materials := {
		"wood": _material(Color("#725039")),
		"weathered_wood": _material(Color("#51483d")),
		"stone": _material(Color("#77736a")),
		"roof": _material(Color("#373d3e")),
		"repaired_roof": _material(Color("#55483a")),
		"glass": _material(Color("#77929a", 0.82)),
		"shop_wood": _material(Color("#805638")),
		"shop_stone": _material(Color("#888174")),
		"shop_roof": _material(Color("#493b32")),
		"shop_sign": _material(Color("#bd985d")),
		"shop_dark": _material(Color("#34271f")),
		"shop_display": _material(Color("#a17a4f"))
	}
	_present_cottage(root, state, hex_radius, materials)
	_present_abandoned_house(root, state, hex_radius, materials)
	_present_manor(root, state, hex_radius, materials)
	_present_furniture_shop(root, hex_radius, materials)
	return {"ok": true, "site_count": 4, "root": root}


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
	var width := 8.2 if country_house else 5.8
	var depth := 6.4 if country_house else 4.8
	_build_house(site, width, depth, 4.5 if country_house else 2.6, materials, false, true)
	if country_house:
		_add_box(site, "CountryHouseUpperWindowLeft", Vector3(-width * 0.30, 3.45, depth * 0.5 + 0.11), Vector3(0.62, 0.55, 0.06), materials.glass)
		_add_box(site, "CountryHouseUpperWindowRight", Vector3(width * 0.30, 3.45, depth * 0.5 + 0.11), Vector3(0.62, 0.55, 0.06), materials.glass)
		_add_box(site, "CountryHouseRearExtension", Vector3(0.0, 1.1, -depth * 0.42), Vector3(width * 0.72, 2.2, 1.25), materials.wood)


static func _present_abandoned_house(parent: Node3D, state: CampaignDwellingState, radius: float, materials: Dictionary) -> void:
	var site := Node3D.new()
	site.name = "AbandonedRoadsideHouseSite"
	site.position = HexGrid.axial_to_world(Vector2i(14, -176), radius)
	parent.add_child(site)
	var restored := bool(state.owned.get("abandoned_house", false))
	_build_house(site, 7.2, 5.8, 2.8, materials, not restored, restored)


static func _present_manor(parent: Node3D, state: CampaignDwellingState, radius: float, materials: Dictionary) -> void:
	var site := Node3D.new()
	site.name = "SilverhartManorSite"
	site.position = HexGrid.axial_to_world(Vector2i(39, -502), radius)
	parent.add_child(site)
	var fortified := String(state.upgrades.get("silverhart_manor", "")) == "fortify_silverhart_manor"
	_build_house(site, 10.0, 8.0, 5.4, materials, not fortified, fortified)
	_add_box(site, "ManorUpperWindowLeft", Vector3(-3.2, 3.8, 4.11), Vector3(0.72, 0.62, 0.06), materials.glass)
	_add_box(site, "ManorUpperWindowRight", Vector3(3.2, 3.8, 4.11), Vector3(0.72, 0.62, 0.06), materials.glass)
	if fortified:
		_add_box(site, "ManorChimney", Vector3(3.5, 6.1, -2.2), Vector3(0.55, 1.5, 0.55), materials.stone)


static func _present_furniture_shop(parent: Node3D, radius: float, materials: Dictionary) -> void:
	var site := Node3D.new()
	site.name = "SilverhartFurnitureShopSite"
	site.position = HexGrid.axial_to_world(Vector2i(8, -496), radius)
	parent.add_child(site)

	# A compact capital-city storefront, deliberately distinct from the player
	# dwellings. The nearby-site interaction remains the authoritative shop UI.
	_add_box(site, "ShopStoneFooting", Vector3(0.0, 0.14, 0.0), Vector3(9.6, 0.28, 7.6), materials.shop_stone)
	_add_box(site, "ShopRearWall", Vector3(0.0, 2.2, -3.55), Vector3(9.0, 4.1, 0.22), materials.shop_wood)
	_add_box(site, "ShopLeftWall", Vector3(-4.4, 2.2, 0.0), Vector3(0.22, 4.1, 7.1), materials.shop_wood)
	_add_box(site, "ShopRightWall", Vector3(4.4, 2.2, 0.0), Vector3(0.22, 4.1, 7.1), materials.shop_wood)
	_add_box(site, "ShopFrontLeft", Vector3(-3.35, 2.2, 3.55), Vector3(2.1, 4.1, 0.22), materials.shop_wood)
	_add_box(site, "ShopFrontRight", Vector3(3.35, 2.2, 3.55), Vector3(2.1, 4.1, 0.22), materials.shop_wood)
	_add_box(site, "ShopDoorFrame", Vector3(0.0, 1.95, 3.57), Vector3(2.2, 3.9, 0.18), materials.shop_dark)
	_add_box(site, "ShopDoor", Vector3(0.0, 1.15, 3.68), Vector3(1.55, 2.3, 0.12), materials.weathered_wood)
	_add_box(site, "ShopWindowLeft", Vector3(-3.35, 2.25, 3.69), Vector3(1.55, 1.35, 0.07), materials.glass)
	_add_box(site, "ShopWindowRight", Vector3(3.35, 2.25, 3.69), Vector3(1.55, 1.35, 0.07), materials.glass)

	var left_roof := _add_box(site, "ShopRoofLeft", Vector3(-2.25, 4.48, 0.0), Vector3(5.2, 0.28, 8.0), materials.shop_roof)
	left_roof.rotation.z = deg_to_rad(-27.0)
	var right_roof := _add_box(site, "ShopRoofRight", Vector3(2.25, 4.48, 0.0), Vector3(5.2, 0.28, 8.0), materials.shop_roof)
	right_roof.rotation.z = deg_to_rad(27.0)
	_add_box(site, "ShopFrontCanopy", Vector3(0.0, 3.45, 4.05), Vector3(8.4, 0.16, 1.05), materials.shop_sign)
	_add_box(site, "ShopSignBacking", Vector3(0.0, 4.15, 3.82), Vector3(3.8, 0.78, 0.16), materials.shop_dark)
	_add_box(site, "ShopSignInset", Vector3(0.0, 4.15, 3.92), Vector3(3.55, 0.58, 0.08), materials.shop_sign)
	var sign_text := Label3D.new()
	sign_text.name = "ShopSign"
	sign_text.text = "FURNISHINGS"
	sign_text.font_size = 32
	sign_text.pixel_size = 0.01
	sign_text.modulate = Color("#30251b")
	sign_text.position = Vector3(0.0, 4.15, 3.99)
	sign_text.rotation.y = PI
	site.add_child(sign_text)

	# Visible stock through the front windows and open doorway.
	_add_box(site, "ShopCounter", Vector3(0.0, 1.0, 1.55), Vector3(4.8, 1.25, 0.72), materials.shop_display)
	_add_box(site, "ShopCounterTop", Vector3(0.0, 1.66, 1.55), Vector3(5.0, 0.12, 0.86), materials.shop_sign)
	_add_box(site, "ShopDisplayBedBase", Vector3(-2.7, 0.45, -1.45), Vector3(2.2, 0.42, 1.35), materials.shop_display)
	_add_box(site, "ShopDisplayBedMattress", Vector3(-2.7, 0.78, -1.45), Vector3(2.05, 0.24, 1.2), materials.glass)
	_add_box(site, "ShopDisplayBedHeadboard", Vector3(-2.7, 1.12, -2.05), Vector3(2.2, 1.05, 0.16), materials.shop_wood)
	_add_box(site, "ShopDisplayTableTop", Vector3(2.45, 1.12, -1.4), Vector3(1.75, 0.16, 1.25), materials.shop_display)
	for leg_x in [-0.68, 0.68]:
		for leg_z in [-0.46, 0.46]:
			_add_box(site, "ShopDisplayTableLeg", Vector3(2.45 + leg_x, 0.55, -1.4 + leg_z), Vector3(0.13, 1.0, 0.13), materials.shop_wood)
	_add_box(site, "ShopDisplayChest", Vector3(2.6, 0.65, 0.55), Vector3(1.25, 0.9, 0.82), materials.shop_wood)
	_add_box(site, "ShopDisplayChestLid", Vector3(2.6, 1.13, 0.55), Vector3(1.32, 0.12, 0.9), materials.shop_sign)
	_add_box(site, "ShopLeftShelf", Vector3(-4.0, 2.35, -1.15), Vector3(0.48, 0.14, 3.8), materials.shop_display)
	_add_box(site, "ShopRightShelf", Vector3(4.0, 2.35, -1.15), Vector3(0.48, 0.14, 3.8), materials.shop_display)


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
