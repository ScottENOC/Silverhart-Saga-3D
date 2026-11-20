class_name WorldSettlementPresenter
extends Node3D
## Generic settlement presentation component.
## Receives authored settlement definitions and composes shared feature,
## vegetation and creature presenters. It contains no settlement-specific rules.

const AUTHORED_SETTLEMENT_PRESENTER = preload("res://scripts/world/authored_settlement_presenter.gd")
const WORLD_VEGETATION = preload("res://scripts/world/world_vegetation_generator.gd")
const CREATURE_ACTOR_SCRIPT = preload("res://scripts/presentation/creature_actor.gd")

var definition: Dictionary = {}
var materials: Dictionary = {}
var _configured := false

func configure_location(location_definition: Dictionary) -> void:
	definition = location_definition.duplicate(true)
	_configured = not definition.is_empty()

func _ready() -> void:
	if not _configured:
		push_error("WorldSettlementPresenter requires an authored location definition.")
		return
	var hex_radius := float(definition.get("hex_radius", HexGrid.DEFAULT_RADIUS_M))
	if hex_radius <= 0.0:
		push_error("Settlement %s has an invalid hex radius." % String(definition.get("id", "")))
		return
	_create_materials(definition.get("palette", {}))
	_create_ground(definition.get("ground", {}))
	_present_authored_features(definition.get("features", {}), hex_radius)
	_spawn_authored_creatures(definition.get("creatures", []), hex_radius)
	_generate_vegetation(definition.get("vegetation", {}), hex_radius)

func _material(colour: Color, roughness: float = 0.9, metallic: float = 0.0) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = colour
	result.roughness = roughness
	result.metallic = metallic
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	if colour.a < 1.0:
		result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return result

func _create_materials(palette: Dictionary) -> void:
	for key in palette:
		var entry: Variant = palette[key]
		if entry is Color:
			materials[String(key)] = _material(entry)
		elif entry is Dictionary:
			materials[String(key)] = _material(
				entry.get("colour", Color.WHITE),
				float(entry.get("roughness", 0.9)),
				float(entry.get("metallic", 0.0))
			)
	var required := ["grass", "path", "water", "bank", "stone", "plaster", "timber",
		"dark_wood", "roof", "glass", "field", "crop", "pasture", "fence", "blood"]
	for key in required:
		if not materials.has(key):
			push_error("Settlement %s is missing palette material '%s'." % [String(definition.get("id", "")), key])

func _create_ground(ground_definition: Dictionary) -> void:
	var ground := MeshInstance3D.new()
	ground.name = String(ground_definition.get("name", "SettlementGround"))
	var mesh := PlaneMesh.new()
	var size := float(ground_definition.get("size", 420.0))
	mesh.size = Vector2(size, size)
	ground.mesh = mesh
	ground.position.y = float(ground_definition.get("height", -0.22))
	ground.material_override = materials.get(String(ground_definition.get("material", "grass")))
	add_child(ground)

func _present_authored_features(features: Dictionary, hex_radius: float) -> void:
	var result := AUTHORED_SETTLEMENT_PRESENTER.present(
		self,
		features.get("identity", {}),
		features.get("data", {}),
		_resolve_material_bindings(features.get("materials", {})),
		hex_radius
	)
	if not bool(result.get("ok", false)):
		push_error("Authored settlement presentation failed: %s" % result)


func _resolve_material_bindings(value: Variant) -> Variant:
	if value is Dictionary:
		var resolved: Dictionary = {}
		for key in value:
			resolved[key] = _resolve_material_bindings(value[key])
		return resolved
	if value is Array:
		var resolved: Array = []
		for item in value:
			resolved.append(_resolve_material_bindings(item))
		return resolved
	if value is String and materials.has(value):
		return materials[value]
	return value

func _spawn_authored_creatures(placements: Array, hex_radius: float) -> void:
	for placement in placements:
		if not placement is Dictionary:
			push_error("Settlement creature placement must be a dictionary.")
			continue
		var actor := CREATURE_ACTOR_SCRIPT.new() as CreatureActor
		actor.name = String(placement.get("id", ""))
		actor.creature_kind = String(placement.get("kind", ""))
		actor.behaviour = String(placement.get("behaviour", ""))
		actor.axial_hex = placement.get("hex", Vector2i.ZERO)
		actor.model_scale = float(placement.get("scale", 1.0))
		actor.add_to_group("creature_actors")
		var filename := String(placement.get("asset", ""))
		if filename.is_empty():
			filename = "%s.gltf" % actor.creature_kind.capitalize()
		actor.model_path = "res://art/creatures/quaternius/%s" % filename
		actor.position = HexGrid.axial_to_world(actor.axial_hex, hex_radius, 0.0)
		actor.rotation.y = deg_to_rad(float(posmod(actor.axial_hex.x * 37 + actor.axial_hex.y * 19, 360)))
		add_child(actor)

func _generate_vegetation(vegetation: Dictionary, hex_radius: float) -> void:
	if vegetation.is_empty():
		return
	var forest := vegetation.get("forest", {})
	var understorey := vegetation.get("understorey", {})
	_generate_vegetation_pass(forest, hex_radius)
	_generate_vegetation_pass(understorey, hex_radius)

func _generate_vegetation_pass(pass_definition: Dictionary, hex_radius: float) -> void:
	if pass_definition.is_empty():
		return
	var candidate_script: Variant = pass_definition.get("candidate_script")
	var selector_script: Variant = pass_definition.get("selector_script")
	var candidate_filter := Callable(candidate_script, String(pass_definition.get("candidate_method", "")))
	var family_selector := Callable(selector_script, String(pass_definition.get("selector_method", "")))
	WORLD_VEGETATION.generate_hex_grid(
		self,
		int(pass_definition.get("min_q", -96)),
		int(pass_definition.get("max_q", 96)),
		int(pass_definition.get("min_r", -96)),
		int(pass_definition.get("max_r", 96)),
		int(pass_definition.get("spacing", 4)),
		hex_radius,
		candidate_filter,
		pass_definition.get("density_offset", Vector2i.ZERO),
		float(pass_definition.get("density_threshold", 0.0)),
		family_selector,
		float(pass_definition.get("scale_min", 0.78)),
		float(pass_definition.get("scale_range", 0.46)),
		String(pass_definition.get("node_prefix", "SettlementVegetation")),
		bool(pass_definition.get("understorey", false))
	)

## Reconnects authored presentation actors to persistent simulation state.
## Restored state always wins over the authored starting position.
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
		var existing_state := simulation.get_character(animal_id)
		if existing_state != null:
			if existing_state.race != "animal" or existing_state.creature_kind != actor.creature_kind:
				skipped.append({"actor": actor.name, "reason": "existing_state_profile_mismatch"})
				continue
			actor.simulation_state = existing_state
			actor.axial_hex = existing_state.axial
			var radius := float(definition.get("hex_radius", HexGrid.DEFAULT_RADIUS_M))
			actor.position = HexGrid.axial_to_world(existing_state.axial, radius, 0.0)
			actor.rotation.y = deg_to_rad(float(2 - existing_state.facing_direction) * 60.0)
			registered_ids.append(existing_state.id)
			continue
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
