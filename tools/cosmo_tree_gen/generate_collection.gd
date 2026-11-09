@tool
extends EditorScript

const PRESET_PATHS: Array[String] = [
	"res://addons/cosmo_tree_gen/presets/ash.tres",
	"res://addons/cosmo_tree_gen/presets/cherry.tres",
	"res://addons/cosmo_tree_gen/presets/laurel.tres",
	"res://addons/cosmo_tree_gen/presets/low_poly_tree.tres",
	"res://addons/cosmo_tree_gen/presets/pine.tres",
	"res://addons/cosmo_tree_gen/presets/spruce.tres",
	"res://addons/cosmo_tree_gen/presets/willow.tres",
	"res://addons/cosmo_tree_gen/presets/winter_oak.tres",
]

const VARIANTS_PER_PRESET := 2
const OUTPUT_DIR := "res://art/environment/trees/cosmo_generated"


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var total := 0
	for preset_path in PRESET_PATHS:
		var preset := load(preset_path) as CosmoTreePreset
		if preset == null:
			push_error("Could not load Cosmo preset: " + preset_path)
			return
		var preset_name := preset_path.get_file().get_basename()
		for variant in range(VARIANTS_PER_PRESET):
			var tree := CosmoTreeGen.new()
			tree.auto_generate = false
			tree.noise_seed = 41000 + total * 137
			tree.apply_preset(preset)
			tree.generate_lod = true
			tree.collision_type = CosmoTreeGen.CollisionType.TRIMESH
			tree.collision_max_height = tree.trunk_params.height * 0.3
			tree.generate()
			tree.name = "%s_%02d" % [preset_name, variant + 1]
			var output_path := "%s/%s_%02d.glb" % [OUTPUT_DIR, preset_name, variant + 1]
			var error_code: Error = await tree.export_gltf(output_path, {
				"Use External Material": true,
				"Include Collisions": true,
			})
			tree.free()
			if error_code != OK:
				push_error("Cosmo export failed for %s: %s" % [output_path, error_string(error_code)])
				return
			print("COSMO_TREE_EXPORTED: " + output_path)
			total += 1
	print("COSMO_TREE_COLLECTION_COMPLETE: %d trees exported" % total)
