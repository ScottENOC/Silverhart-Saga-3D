extends SceneTree

# Second small batch: add three new vegetation forms with four variants each.
# Existing 28 tree assets are left untouched.
const PRESET_PATHS: Array[String] = [
	"res://addons/cosmo_tree_gen/presets/bush.tres",
	"res://addons/cosmo_tree_gen/presets/low_poly_bush.tres",
	"res://addons/cosmo_tree_gen/presets/tree_fern.tres",
]

const VARIANTS_PER_PRESET := 4
const OUTPUT_DIR := "res://art/environment/trees/cosmo_generated"


func _initialize() -> void:
	call_deferred("_run_collection")


func _run_collection() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var total := 0
	for preset_path in PRESET_PATHS:
		var preset := load(preset_path) as CosmoTreePreset
		if preset == null:
			push_error("Could not load Cosmo preset: " + preset_path)
			quit(1)
			return
		var preset_name := preset_path.get_file().get_basename()
		for variant in range(VARIANTS_PER_PRESET):
			var tree := CosmoTreeGen.new()
			tree.auto_generate = false
			tree.noise_seed = 63000 + total * 137
			tree.apply_preset(preset)
			tree.generate_lod = true
			tree.collision_type = CosmoTreeGen.CollisionType.TRIMESH
			tree.collision_max_height = tree.trunk_params.height * 0.3
			tree.generate()
			var variant_number := variant + 1
			tree.name = "%s_%02d" % [preset_name, variant_number]
			var output_path := "%s/%s_%02d.glb" % [OUTPUT_DIR, preset_name, variant_number]
			var error_code: Error = await tree.export_gltf(output_path, {
				"Use External Material": true,
				"Include Collisions": true,
			})
			tree.free()
			if error_code != OK or not FileAccess.file_exists(output_path):
				push_error("Cosmo export failed for %s: %s" % [output_path, error_string(error_code)])
				quit(1)
				return
			print("COSMO_TREE_EXPORTED: " + output_path)
			total += 1
	print("COSMO_TREE_BATCH_COMPLETE: %d additional assets exported" % total)
	if total != 12:
		push_error("Expected exactly 12 additional assets; exported %d" % total)
		quit(1)
		return
	quit(0)
