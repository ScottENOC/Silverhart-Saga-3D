# Copyright © 2026 CosmonautFrog - MIT License

@tool
extends EditorScenePostImport
## glTF loses custom_aabb, without it the LODs don't swap at the same distance.


func _post_import(scene: Node) -> Object:
	var meshes := scene.get_children().filter(
		func(child: Node) -> bool:
			return child is MeshInstance3D
	)

	var bounds := AABB()
	for mesh: MeshInstance3D in meshes:
		bounds = bounds.merge(mesh.mesh.get_aabb())

	for mesh: MeshInstance3D in meshes:
		mesh.custom_aabb = bounds

	return scene
