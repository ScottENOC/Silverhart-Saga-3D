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
	if vertices.size() < 3:
		push_error("Regional terrain hex did not produce its first triangle.")
		quit(1)
		return

	# Godot 4 uses clockwise winding for front faces. The generated top surface
	# must therefore have a negative Y component from the conventional cross
	# product of its first two edges, while its explicit vertex normals point up.
	var winding_normal := (vertices[1] - vertices[0]).cross(vertices[2] - vertices[0])
	if winding_normal.y >= 0.0:
		push_error("Regional terrain triangle winding is back-face orientation: %s" % winding_normal)
		quit(1)
		return

	quit(0)
