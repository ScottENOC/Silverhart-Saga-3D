# Copyright © 2026 CosmonautFrog - MIT License

@tool
extends RefCounted

const LOD_POST_IMPORT: Script = preload("./lod_post_import.gd")


static func _get_import_file(path: String) -> ConfigFile:
	var import := ConfigFile.new()
	var err := import.load(path + ".import")
	if err != OK:
		push_warning("CosmoTreeGen: exporter - error loading %s '%s'" % [path + ".import", error_string(err)])
		return null

	return import


static func _write_import_materials(path: String, state: GLTFState) -> Error:
	var import := _get_import_file(path)
	if import == null:
		return ERR_CANT_OPEN

	var subresources: Dictionary = import.get_value("params", "_subresources", {})
	var materials: Dictionary = subresources.get("materials", {})

	var json_materials: Array = state.json.get("materials", [])
	var state_materials := state.get_materials()
	for i in json_materials.size():
		var material_path := state_materials[i].resource_path
		# creating a new Resource will create a resource_path like "...::xxxxx"
		# this is a bit hacky, couldn't find another way
		if material_path.is_empty() or material_path.contains("::"):
			continue
		materials[json_materials[i]["name"]] = {
			"use_external/enabled": true,
			"use_external/path": ResourceUID.path_to_uid(material_path),
			"use_external/fallback_path": material_path,
		}

	subresources["materials"] = materials
	import.set_value("params", "_subresources", subresources)
	return import.save(path + ".import")


static func _write_import_lods(path: String, tree: CosmoTreeGen) -> Error:
	var import := _get_import_file(path)
	if import == null:
		return ERR_CANT_OPEN

	var subresources: Dictionary = import.get_value("params", "_subresources", {})
	var nodes: Dictionary = subresources.get("nodes", {})

	for mesh: MeshInstance3D in tree.get_meshes():
		nodes["PATH:%s" % mesh.name] = {
			"mesh_instance/visibility_range_begin": mesh.visibility_range_begin,
			"mesh_instance/visibility_range_begin_margin": mesh.visibility_range_begin_margin,
			"mesh_instance/visibility_range_end": mesh.visibility_range_end,
			"mesh_instance/visibility_range_end_margin": mesh.visibility_range_end_margin,
		}

	subresources["nodes"] = nodes
	import.set_value("params", "_subresources", subresources)

	# Godot automatic LODs break the leaf cards
	import.set_value("params", "meshes/generate_lods", false)
	import.set_value("params", "import_script/path", LOD_POST_IMPORT.resource_path)
	return import.save(path + ".import")


static func _set_root_name(path: String, name: String) -> Error:
	var import := _get_import_file(path)
	import.set_value("params", "nodes/root_name", name)
	return import.save(path + ".import")


static func _wait_for_import_file(path: String) -> Error:
	var fs := EditorInterface.get_resource_filesystem()
	var tree := Engine.get_main_loop() as SceneTree
	var res_path := ProjectSettings.localize_path(path)

	fs.scan()
	while true:
		var reimported: PackedStringArray = await fs.resources_reimported
		if reimported.has(res_path):
			break

	await tree.process_frame

	if not FileAccess.file_exists(path + ".import"):
		return ERR_CANT_OPEN

	return OK


static func export_gltf(path: String, tree: CosmoTreeGen, options: Dictionary = {}) -> Error:
	if tree == null:
		return ERR_UNCONFIGURED
	if (
		path.get_file().get_basename().is_empty()
		or path.get_extension() not in ["gltf", "glb"]
	):
		return ERR_FILE_BAD_PATH

	var exported: Array[Node] = []
	for mesh: MeshInstance3D in tree.get_meshes():
		exported.append(mesh.duplicate())

	if options.get("Include Collisions", false):
		for collision: StaticBody3D in tree.get_collisions():
			exported.append(collision.duplicate())

	var file_name := path.get_file().get_basename()
	var root := Node3D.new()
	root.name = file_name
	for node: Node in exported:
		root.add_child(node)
		node.owner = root
		for child in node.get_children():
			child.owner = root

	var document := GLTFDocument.new()
	if not options.get("Export Images", false):
		document.set_image_format("None")
		# FIXME: texture images are not being saved properly, missing name (saved as ".png")

	var state := GLTFState.new()
	var err := document.append_from_scene(root, state)
	if err == OK:
		err = document.write_to_filesystem(state, path)

	if err == OK:
		err = await _wait_for_import_file(path)

	if err == OK and options.get("Use External Material", false):
		err = _write_import_materials(path, state)

	if err == OK and tree.generate_lod:
		err = _write_import_lods(path, tree)

	if err == OK:
		err = _set_root_name(path, tree.name)

	if err == OK:
		var fs := EditorInterface.get_resource_filesystem()
		fs.reimport_files(PackedStringArray([ProjectSettings.localize_path(path)]))

	root.free()
	return err
