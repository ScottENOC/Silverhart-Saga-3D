extends SceneTree

const PREVIEW_SCENE := "res://scenes/prototypes/campaign2_regional_world_preview.tscn"
const OUTPUT_DIR := "res://artifacts/campaign2-map-review"

const REVIEW_VIEWS := [
	{"name": "silverhart-centre", "hex": Vector2i(8, -496), "distance": 145.0},
	{"name": "silverhart-north-ring", "hex": Vector2i(8, -526), "distance": 72.0},
	{"name": "silverhart-east-ring", "hex": Vector2i(38, -496), "distance": 72.0},
	{"name": "silverhart-south-ring", "hex": Vector2i(8, -466), "distance": 72.0},
	{"name": "silverhart-west-ring", "hex": Vector2i(-22, -496), "distance": 72.0},
	{"name": "hollowmere", "hex": Vector2i(8, 24), "distance": 105.0},
	{"name": "millbrook", "hex": Vector2i(1, -366), "distance": 90.0},
	{"name": "emberlode", "hex": Vector2i(-256, 22), "distance": 90.0},
	{"name": "reddale", "hex": Vector2i(138, 24), "distance": 105.0},
	{"name": "old-mac-farmstead", "hex": Vector2i(0, 194), "distance": 100.0},
	{"name": "skarn-tooth-camp", "hex": Vector2i(203, 23), "distance": 90.0},
	{"name": "skarnaks-hold", "hex": Vector2i(428, 17), "distance": 90.0},
	{"name": "northwatch", "hex": Vector2i(268, -21), "distance": 95.0},
	{"name": "ridgehold", "hex": Vector2i(426, 43), "distance": 95.0},
	{"name": "kragmoor", "hex": Vector2i(908, -626), "distance": 85.0},
	{"name": "silthandriel", "hex": Vector2i(-252, 934), "distance": 110.0},
	{"name": "vampire-grave", "hex": Vector2i(-256, 28), "distance": 70.0},
	{"name": "old-mac-wolf-den", "hex": Vector2i(-59, 204), "distance": 70.0},
	{"name": "unicorn-vale", "hex": Vector2i(-286, 24), "distance": 85.0},
	{"name": "emberwood-grove", "hex": Vector2i(-266, 10), "distance": 85.0},
	{"name": "ashveil-lair", "hex": Vector2i(101, -366), "distance": 85.0},
	{"name": "thieves-cove", "hex": Vector2i(-274, 40), "distance": 90.0},
	{"name": "vessel-seekers-crypt", "hex": Vector2i(32, -154), "distance": 75.0},
	{"name": "corvin-ashgrave-barrow", "hex": Vector2i(63, -160), "distance": 75.0},
	{"name": "abandoned-house", "hex": Vector2i(14, -176), "distance": 75.0},
	{"name": "lich-chapterhouse", "hex": Vector2i(-39, -346), "distance": 85.0},
	{"name": "mirabel-spider-ruin", "hex": Vector2i(160, 24), "distance": 85.0},
	{"name": "emberlode-mine", "hex": Vector2i(-252, 16), "distance": 80.0}
]

func _initialize() -> void:
	call_deferred("_capture_all_views")


func _capture_all_views() -> void:
	root.size = Vector2i(1600, 900)
	var packed := load(PREVIEW_SCENE) as PackedScene
	if packed == null:
		push_error("Could not load Campaign 2 regional world preview.")
		quit(1)
		return
	var preview: Variant = packed.instantiate()
	root.add_child(preview)
	for _frame in range(12):
		await process_frame
	var preview_camera := preview.get("camera") as Camera3D
	var terrain_data: Variant = preview.get("terrain_data")
	if preview_camera == null or terrain_data == null:
		push_error("Regional preview did not initialise its camera or terrain data.")
		quit(1)
		return
	for layer in preview.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	preview.set("yaw", deg_to_rad(24.0))
	preview.set("pitch", deg_to_rad(58.0))
	var output_path := ProjectSettings.globalize_path(OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(output_path)
	for view in REVIEW_VIEWS:
		var hex: Vector2i = view["hex"]
		preview.set("target", HexGrid.axial_to_world(hex, HexGrid.DEFAULT_RADIUS_M, float(terrain_data.call("elevation_for_hex", hex))))
		preview.set("camera_distance", float(view["distance"]))
		preview.call("_update_camera")
		preview.call("_update_streamed_chunks", true)
		var centre_chunk: Vector2i = terrain_data.call("chunk_for_hex", hex, 24)
		var terrain_counts: Dictionary = {}
		for q in range((centre_chunk.x - 1) * 24, (centre_chunk.x + 2) * 24):
			for r in range((centre_chunk.y - 1) * 24, (centre_chunk.y + 2) * 24):
				var terrain_id := String(terrain_data.call("terrain_for_hex", Vector2i(q, r)))
				terrain_counts[terrain_id] = int(terrain_counts.get(terrain_id, 0)) + 1
		var chunk_meshes: Dictionary = {}
		var streamed_chunks: Dictionary = preview.get("chunk_nodes")
		for chunk_value in streamed_chunks.values():
			var chunk_node := chunk_value as Node3D
			if chunk_node == null:
				continue
			for child in chunk_node.get_children():
				var mesh_instance := child as MeshInstance3D
				if mesh_instance == null or not mesh_instance.name.begins_with("Terrain_") or mesh_instance.mesh == null:
					continue
				chunk_meshes[mesh_instance.name] = int(chunk_meshes.get(mesh_instance.name, 0)) + mesh_instance.mesh.get_surface_count()
		print("[MapReview] %s terrain_cells=%s terrain_mesh_surfaces=%s streamed_chunks=%d" % [
			String(view["name"]), terrain_counts, chunk_meshes, streamed_chunks.size()
		])
		for _frame in range(10):
			await process_frame
		RenderingServer.force_draw(false)
		await process_frame
		var screenshot := root.get_texture().get_image()
		if screenshot.is_empty():
			push_error("Regional map review screenshot was empty: %s" % view["name"])
			quit(1)
			return
		var destination := output_path.path_join(String(view["name"]) + ".png")
		var error := screenshot.save_png(destination)
		if error != OK:
			push_error("Could not save regional map review screenshot: %s" % destination)
			quit(1)
			return
		print("Saved Campaign 2 map review: ", destination)
	quit(0)
