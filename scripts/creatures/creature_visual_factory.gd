class_name CreatureVisualFactory
extends RefCounted
## Creates presentation-only creature instances from registered source assets.
## Gameplay state, AI and combat remain owned by simulation systems.

const ASSET_CATALOG = preload("res://scripts/creatures/creature_asset_catalog.gd")

static func create_species(species_name: String, options: Dictionary = {}) -> Node3D:
	var asset_id := String(options.get("asset_id", ASSET_CATALOG.default_asset_for_species(species_name)))
	if asset_id.is_empty():
		push_error("No creature source asset is registered for species: %s" % species_name)
		return null
	return create_creature(asset_id, options)

static func create_creature(asset_id: String, options: Dictionary = {}) -> Node3D:
	var definition := ASSET_CATALOG.get_definition(asset_id)
	if definition.is_empty():
		push_error("Unknown creature asset id: %s" % asset_id)
		return null

	var model_path := String(definition.get("model_path", ""))
	if model_path.is_empty() or not ResourceLoader.exists(model_path):
		push_error(
			"Creature asset '%s' is not installed at '%s'. See docs/creature_asset_pipeline.md."
			% [asset_id, model_path]
		)
		return null

	var packed_scene := load(model_path) as PackedScene
	if packed_scene == null:
		push_error("Creature model did not import as a PackedScene: %s" % model_path)
		return null

	var model_root := packed_scene.instantiate() as Node3D
	if model_root == null:
		push_error("Creature model root is not Node3D: %s" % model_path)
		return null

	var size_name := String(options.get("size", "medium")).to_lower()
	var instance_scale := float(options.get("scale", -1.0))
	if instance_scale <= 0.0:
		instance_scale = ASSET_CATALOG.scale_for(asset_id, size_name)

	var colour_name := String(options.get("colour", options.get("color", "natural")))
	var tint: Color = options.get("tint", ASSET_CATALOG.colour_for(colour_name))

	var instance := Node3D.new()
	instance.name = String(options.get("instance_name", definition.get("display_name", asset_id)))
	model_root.name = "SourceModel"
	model_root.scale = Vector3.ONE * instance_scale
	instance.add_child(model_root)

	_apply_tint_recursive(model_root, tint)

	instance.set_meta("creature_asset_id", asset_id)
	instance.set_meta("creature_species", String(definition.get("species", "unknown")))
	instance.set_meta("creature_size", size_name)
	instance.set_meta("creature_colour", colour_name)
	instance.set_meta("creature_scale", instance_scale)

	var requested_animation := String(options.get("animation", "idle")).to_lower()
	_play_animation(model_root, definition.get("animation_map", {}), requested_animation)

	return instance

static func _apply_tint_recursive(node: Node, tint: Color) -> void:
	if node is MeshInstance3D:
		_tint_mesh_instance(node as MeshInstance3D, tint)
	for child in node.get_children():
		_apply_tint_recursive(child, tint)

static func _tint_mesh_instance(mesh_instance: MeshInstance3D, tint: Color) -> void:
	if mesh_instance.material_override != null:
		var override_material := _tinted_material(mesh_instance.material_override, tint)
		if override_material != null:
			mesh_instance.material_override = override_material
		return

	if mesh_instance.mesh == null:
		return
	for surface_index in range(mesh_instance.mesh.get_surface_count()):
		var source_material := mesh_instance.get_active_material(surface_index)
		if source_material == null:
			continue
		var tinted := _tinted_material(source_material, tint)
		if tinted != null:
			mesh_instance.set_surface_override_material(surface_index, tinted)

static func _tinted_material(source_material: Material, tint: Color) -> Material:
	if source_material is StandardMaterial3D:
		var material := (source_material as StandardMaterial3D).duplicate(true) as StandardMaterial3D
		material.albedo_color = material.albedo_color * tint
		return material
	if source_material is ORMMaterial3D:
		var orm_material := (source_material as ORMMaterial3D).duplicate(true) as ORMMaterial3D
		orm_material.albedo_color = orm_material.albedo_color * tint
		return orm_material
	# Do not replace custom shaders blindly: their texture, normal and mask
	# semantics are asset-specific. A future asset adapter can handle them.
	push_warning("Creature tint skipped unsupported material type: %s" % source_material.get_class())
	return null

static func _play_animation(root: Node, animation_map: Dictionary, requested: String) -> void:
	var animation_name := String(animation_map.get(requested, ""))
	if animation_name.is_empty():
		push_warning("Creature has no animation mapping for '%s'." % requested)
		return
	var player := _find_animation_player(root)
	if player == null:
		push_warning("Creature model has no AnimationPlayer; cannot play '%s'." % animation_name)
		return
	if not player.has_animation(animation_name):
		push_warning("Creature animation '%s' is missing from the imported model." % animation_name)
		return
	player.play(animation_name)

static func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null
