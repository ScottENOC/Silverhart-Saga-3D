class_name CharacterPortraitRenderer
extends Node
## Renders a character's actual model into a small, isolated SubViewport.
## The viewport is captured once for initiative cards and can be switched to
## continuous rendering while the character is speaking in dialogue.

const VIEWPORT_SIZE := Vector2i(256, 320)
const FACIAL_TOKENS := [
	"face", "mouth", "jaw", "lip", "smile", "frown", "brow", "eyebrow",
	"eye", "blink", "cheek", "viseme", "phoneme", "speech"
]

var _viewport: SubViewport
var _stage: Node3D
var _camera: Camera3D
var _portrait_model: Node3D
var _portrait_animation: AnimationPlayer
var _expression := "neutral"
var _elapsed := 0.0
var _blink_elapsed := 0.0
var _base_rotation := 0.0
var _live := false


func configure(source_model: Node3D) -> bool:
	if source_model == null or not is_instance_valid(source_model):
		return false
	_create_viewport()
	return refresh_source(source_model)


func refresh_source(source_model: Node3D) -> bool:
	if source_model == null or not is_instance_valid(source_model):
		return false
	if _viewport == null:
		_create_viewport()
	if _stage == null:
		return false
	if _portrait_model != null and is_instance_valid(_portrait_model):
		_portrait_model.queue_free()
		_portrait_model = null
	_portrait_animation = null

	_portrait_model = source_model.duplicate() as Node3D
	if _portrait_model == null:
		push_warning("Character portrait could not duplicate the source model.")
		return false
	_portrait_model.name = "PortraitCharacter"
	_portrait_model.transform = source_model.transform
	_stage.add_child(_portrait_model)
	_portrait_animation = _find_animation_player(_portrait_model)
	if _live:
		_play_idle_if_available()
	_fit_camera_to_model()
	set_expression(_expression)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE if not _live else SubViewport.UPDATE_ALWAYS
	return true


func get_texture() -> Texture2D:
	return _viewport.get_texture() if _viewport != null else null


func set_live(enabled: bool) -> void:
	_live = enabled
	if enabled:
		_play_idle_if_available()
	elif _portrait_animation != null and _portrait_animation.is_playing():
		_portrait_animation.pause()
	if _viewport == null:
		return
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if enabled else SubViewport.UPDATE_ONCE


func is_live() -> bool:
	return _live


func set_expression(expression: String) -> void:
	_expression = expression.strip_edges().to_lower()
	if _portrait_model == null or not is_instance_valid(_portrait_model):
		return
	var values := _expression_values(_expression)
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(_portrait_model, meshes)
	for mesh in meshes:
		if mesh.mesh == null:
			continue
		for shape_index in range(mesh.mesh.get_blend_shape_count()):
			var shape_name := _normalise_shape_name(String(mesh.mesh.get_blend_shape_name(shape_index)))
			if not _is_facial_shape(shape_name):
				continue
			var value := 0.0
			for alias in values:
				if shape_name.contains(alias):
					value = float(values[alias])
					break
			mesh.set_blend_shape_value(shape_index, value)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE if not _live else SubViewport.UPDATE_ALWAYS


func get_facial_blend_shape_names() -> Array[String]:
	var result: Array[String] = []
	if _portrait_model == null:
		return result
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(_portrait_model, meshes)
	for mesh in meshes:
		if mesh.mesh == null:
			continue
		for shape_index in range(mesh.mesh.get_blend_shape_count()):
			var shape_name := String(mesh.mesh.get_blend_shape_name(shape_index))
			if _is_facial_shape(_normalise_shape_name(shape_name)) and not result.has(shape_name):
				result.append(shape_name)
	return result


func _create_viewport() -> void:
	if _viewport != null:
		return
	# Dialogue may pause the world simulation; the portrait still needs to blink
	# and play its idle clip while the player is choosing a response.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_viewport = SubViewport.new()
	_viewport.name = "CharacterPortraitViewport"
	_viewport.size = VIEWPORT_SIZE
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_2X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_viewport)

	_stage = Node3D.new()
	_stage.name = "PortraitStage"
	_viewport.add_child(_stage)

	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.035, 0.045, 0.065, 0.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.72, 0.76, 0.86)
	environment.ambient_light_energy = 0.8
	environment_node.environment = environment
	_stage.add_child(environment_node)

	var key_light := DirectionalLight3D.new()
	key_light.name = "PortraitKeyLight"
	key_light.rotation_degrees = Vector3(-28.0, -24.0, 0.0)
	key_light.light_energy = 1.1
	key_light.shadow_enabled = true
	_stage.add_child(key_light)

	var fill_light := OmniLight3D.new()
	fill_light.name = "PortraitFillLight"
	fill_light.position = Vector3(-1.4, 1.2, 1.8)
	fill_light.light_energy = 0.55
	fill_light.omni_range = 5.0
	_stage.add_child(fill_light)

	_camera = Camera3D.new()
	_camera.name = "PortraitCamera"
	_camera.fov = 38.0
	_camera.near = 0.01
	_camera.far = 50.0
	_stage.add_child(_camera)
	_camera.current = true


func _fit_camera_to_model() -> void:
	if _portrait_model == null or _camera == null:
		return
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(_portrait_model, meshes)
	var bounds := AABB()
	var has_bounds := false
	for mesh in meshes:
		if mesh.mesh == null or not mesh.visible:
			continue
		# Portraits are often configured before their owning actor enters the
		# world tree. Compose local transforms instead of querying global_transform,
		# which is unavailable until the actor is inside the SceneTree.
		var relative_transform := _relative_transform_to_ancestor(mesh, _portrait_model)
		var local_bounds := mesh.get_aabb()
		for corner in range(8):
			var point := relative_transform * local_bounds.get_endpoint(corner)
			if not has_bounds:
				bounds = AABB(point, Vector3.ZERO)
				has_bounds = true
			else:
				bounds = bounds.expand(point)
	if not has_bounds:
		bounds = AABB(Vector3(-0.3, 0.0, -0.2), Vector3(0.6, 1.8, 0.4))

	var height := maxf(bounds.size.y, 0.8)
	var focus := Vector3(bounds.get_center().x, bounds.position.y + height * 0.80, bounds.get_center().z)
	_camera.position = focus + Vector3(height * 0.10, height * 0.07, height * 1.55)
	_camera.basis = Basis.looking_at(focus - _camera.position, Vector3.UP)
	_base_rotation = _portrait_model.rotation.y


func _relative_transform_to_ancestor(node: Node3D, ancestor: Node3D) -> Transform3D:
	var relative := Transform3D.IDENTITY
	var current: Node = node
	while current != null and current != ancestor:
		if current is Node3D:
			relative = (current as Node3D).transform * relative
		current = current.get_parent()
	return relative


func _play_idle_if_available() -> void:
	if _portrait_animation == null:
		return
	var idle_clip := ""
	for animation_name in _portrait_animation.get_animation_list():
		var candidate := String(animation_name)
		if candidate.to_lower() == "idle" or candidate.to_lower().ends_with("/idle"):
			idle_clip = candidate
			break
	if not idle_clip.is_empty():
		_portrait_animation.play(idle_clip)


func _process(delta: float) -> void:
	if not _live or _portrait_model == null or not is_instance_valid(_portrait_model):
		return
	_elapsed += delta
	_blink_elapsed += delta
	# A barely perceptible idle sway gives non-animated companion exports some
	# life without pretending they have a full-body animation set.
	_portrait_model.rotation.y = _base_rotation + sin(_elapsed * 0.72) * 0.012
	if _blink_elapsed >= 3.8:
		_blink_elapsed = 0.0
		_apply_blink(1.0)
	elif _blink_elapsed < 0.14:
		_apply_blink(1.0 - (_blink_elapsed / 0.14))
	else:
		_apply_blink(0.0)


func _apply_blink(value: float) -> void:
	if _portrait_model == null:
		return
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(_portrait_model, meshes)
	for mesh in meshes:
		if mesh.mesh == null:
			continue
		for shape_index in range(mesh.mesh.get_blend_shape_count()):
			var shape_name := _normalise_shape_name(String(mesh.mesh.get_blend_shape_name(shape_index)))
			if shape_name.contains("blink") or shape_name.contains("eyelidclose"):
				mesh.set_blend_shape_value(shape_index, value)


func _expression_values(expression: String) -> Dictionary:
	match expression:
		"smile", "happy", "friendly", "warm":
			return {"smile": 0.72, "mouthsmile": 0.72, "happy": 0.72, "mouthcornerup": 0.55}
		"frown", "sad", "disappointed":
			return {"frown": 0.68, "mouthfrown": 0.68, "sad": 0.65, "mouthcornerdown": 0.5}
		"angry", "anger", "hostile":
			return {"angry": 0.7, "browdown": 0.65, "browlower": 0.65, "frown": 0.35}
		"surprise", "surprised", "afraid":
			return {"surprise": 0.75, "browinnerup": 0.65, "eyeswide": 0.65, "mouthopen": 0.35}
		"talk", "talking", "speaking":
			return {"mouthopen": 0.22, "jawopen": 0.18, "visemeaa": 0.15}
		_:
			return {}


func _normalise_shape_name(value: String) -> String:
	return value.to_lower().replace("_", "").replace("-", "").replace(" ", "").replace(".", "")


func _is_facial_shape(shape_name: String) -> bool:
	for token in FACIAL_TOKENS:
		if shape_name.contains(token):
			return true
	return false


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null


func _collect_meshes(node: Node, output: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		output.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_meshes(child, output)
