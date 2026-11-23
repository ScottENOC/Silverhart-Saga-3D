extends SceneTree

const BODY_ASSETS := [
	"res://art/characters/ara_runtime/ara_player_female_body.glb",
	"res://art/characters/ara_runtime/ara_player_male_body.glb"
]

func _initialize() -> void:
	for asset_path in BODY_ASSETS:
		if not ResourceLoader.exists(asset_path):
			_fail("Player body asset is missing: " + asset_path)
			return
		var packed := load(asset_path) as PackedScene
		if packed == null:
			_fail("Player body asset is not a PackedScene: " + asset_path)
			return
		var instance := packed.instantiate() as Node3D
		if instance == null:
			_fail("Player body asset root is not Node3D: " + asset_path)
			return
		var skeleton := _find_skeleton(instance)
		if skeleton == null or skeleton.get_bone_count() < 20:
			instance.free()
			_fail("Player body asset has no usable Ara skeleton: " + asset_path)
			return
		var meshes: Array[MeshInstance3D] = []
		_collect_meshes(instance, meshes)
		if meshes.is_empty():
			instance.free()
			_fail("Player body asset contains no meshes: " + asset_path)
			return
		if asset_path.ends_with("ara_player_male_body.glb"):
			var anatomy_root := skeleton.find_bone("AnatomyRoot")
			if anatomy_root < 0:
				instance.free()
				_fail("Male player body is missing the AnatomyRoot size-control bone.")
				return
			var has_erect_morph := false
			for mesh_instance in meshes:
				if mesh_instance.mesh == null:
					continue
				for shape_index in range(mesh_instance.mesh.get_blend_shape_count()):
					if String(mesh_instance.mesh.get_blend_shape_name(shape_index)) == "Anatomy_Erect":
						has_erect_morph = true
				if has_erect_morph:
					break
			if not has_erect_morph:
				instance.free()
				_fail("Male player body is missing the flaccid/erect Anatomy_Erect morph target.")
				return
		instance.free()

		var portrait_actor := AraCharacterActor.new()
		root.add_child(portrait_actor)
		if not portrait_actor.configure(asset_path):
			portrait_actor.free()
			_fail("Portrait-enabled Ara actor could not load: " + asset_path)
			return
		if portrait_actor.get_portrait_texture() == null:
			portrait_actor.free()
			_fail("Ara actor did not expose a portrait texture: " + asset_path)
			return
		if portrait_actor.portrait_renderer.get_facial_blend_shape_names().is_empty():
			portrait_actor.free()
			_fail("Portrait renderer did not discover facial blend shapes: " + asset_path)
			return
		portrait_actor.set_portrait_expression("smile")
		portrait_actor.set_portrait_live(true)
		if not portrait_actor.portrait_renderer.is_live():
			portrait_actor.free()
			_fail("Portrait renderer did not enter live dialogue mode: " + asset_path)
			return
		portrait_actor.set_portrait_live(false)
		portrait_actor.free()
	print("PLAYER_BODY_ASSET_TEST: PASS (female and male Ara bodies load with skeletons and portrait rendering)")
	quit(0)


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null


func _collect_meshes(node: Node, output: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		output.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_meshes(child, output)


func _fail(message: String) -> void:
	push_error("PLAYER_BODY_ASSET_TEST: " + message)
	quit(1)
