extends SceneTree

const PREVIEW_SCRIPT := preload("res://scripts/world/campaign2_regional_world_preview.gd")
const TERRAIN_DATA_SCRIPT := preload("res://scripts/world/campaign2_world_terrain_data.gd")


func _initialize() -> void:
	var preview := Node3D.new()
	preview.set_script(PREVIEW_SCRIPT)
	preview.set("terrain_data", TERRAIN_DATA_SCRIPT.new())

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	preview.call("_add_hex_to_surface", surface, Vector2i(8, 24), 0.0)
	var mesh := surface.commit()
	if mesh == null or mesh.get_surface_count() != 1:
		push_error("Regional terrain hex did not produce a triangle surface.")
		quit(1)
		return

	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if vertices.size() != HexGrid.SIDE_COUNT * 3:
		push_error("Regional terrain hex should produce six triangles (18 vertices), got %d." % vertices.size())
		quit(1)
		return
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	if normals.size() != vertices.size():
		push_error("Regional terrain mesh must provide one explicit normal per vertex.")
		quit(1)
		return

	# Godot 4 uses clockwise winding for front faces. Every top-facing fan
	# triangle must use that order while retaining upward-facing vertex normals.
	for triangle in range(HexGrid.SIDE_COUNT):
		var offset := triangle * 3
		var winding_normal := (vertices[offset + 1] - vertices[offset]).cross(vertices[offset + 2] - vertices[offset])
		if winding_normal.y >= 0.0:
			push_error("Regional terrain triangle %d has back-face winding: %s" % [triangle, winding_normal])
			quit(1)
			return
		for vertex_index in range(offset, offset + 3):
			if normals[vertex_index].y < 0.99:
				push_error("Regional terrain triangle %d has a non-upward vertex normal: %s" % [triangle, normals[vertex_index]])
				quit(1)
				return

	quit(0)
