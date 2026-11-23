extends RefCounted
class_name BodyPressureController
## Connects the spring solver to explicitly authored, localised pressure blend shapes.
## Shape names use the convention Pressure_<RegionName>, e.g. Pressure_LeftChest.
## The blend shape itself must be authored in the compressed direction.

var _solver := BodyPressureSolver.new()
var _bound_meshes: Array[MeshInstance3D] = []
var _targets: Dictionary = {}

func register_region(region_id: StringName, profile: BodyRegionProfile) -> void:
	_solver.register_region(region_id, profile)
	_bind_region_targets(region_id)

func unregister_region(region_id: StringName) -> void:
	_solver.unregister_region(region_id)
	_targets.erase(region_id)

func has_region(region_id: StringName) -> bool:
	return _solver.has_region(region_id)

func apply_pressure(region_id: StringName, force_n: float) -> void:
	_solver.apply_pressure(region_id, force_n)

func get_compression_m(region_id: StringName) -> float:
	return _solver.get_compression_m(region_id)

func bind_model(model_root: Node3D) -> void:
	_bound_meshes.clear()
	_targets.clear()
	if model_root == null:
		return
	_collect_meshes(model_root, _bound_meshes)
	for region_id in _solver.get_region_ids():
		_bind_region_targets(region_id)

## Advances the physics and updates all registered blend-shape targets.
func step(delta: float) -> void:
	_solver.step(delta)
	for region_id in _targets:
		var maximum := _solver.get_max_compression_m(region_id)
		if maximum <= 0.0:
			continue
		var amount := clampf(_solver.get_compression_m(region_id) / maximum, 0.0, 1.0)
		for target in _targets[region_id]:
			var mesh := target["mesh"] as MeshInstance3D
			if not is_instance_valid(mesh) or mesh.mesh == null:
				continue
			var shape_index := int(target["shape_index"])
			if shape_index >= mesh.mesh.get_blend_shape_count():
				continue
			var base_value := float(target["base_value"])
			var gain := float(target["gain"])
			mesh.set_blend_shape_value(shape_index, clampf(base_value + amount * gain, -1.0, 1.0))

func get_bound_target_count(region_id: StringName) -> int:
	var matches: Array = _targets.get(region_id, [])
	return matches.size()

func _bind_region_targets(region_id: StringName) -> void:
	var matches: Array[Dictionary] = []
	var expected := _normalise_shape_name("Pressure_" + String(region_id))
	for mesh in _bound_meshes:
		if not is_instance_valid(mesh) or mesh.mesh == null:
			continue
		for shape_index in range(mesh.mesh.get_blend_shape_count()):
			var shape_name := String(mesh.mesh.get_blend_shape_name(shape_index))
			if _normalise_shape_name(shape_name) != expected:
				continue
			matches.append({
				"mesh": mesh,
				"shape_index": shape_index,
				"base_value": mesh.get_blend_shape_value(shape_index),
				"gain": 1.0
			})
	_targets[region_id] = matches

func _normalise_shape_name(value: String) -> String:
	return value.to_lower().replace("_", "").replace("-", "").replace(" ", "")

func _collect_meshes(node: Node, output: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		output.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_meshes(child, output)
