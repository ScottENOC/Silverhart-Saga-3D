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
		instance.free()
	print("PLAYER_BODY_ASSET_TEST: PASS (female and male body scenes load with Ara skeletons)")
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
