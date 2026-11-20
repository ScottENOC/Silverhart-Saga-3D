extends SceneTree

const CATALOG = preload("res://scripts/creatures/creature_asset_catalog.gd")

func _initialize() -> void:
	assert(CATALOG.has_asset("ashwing_drake_lite"))
	assert(not CATALOG.has_asset("missing_creature"))
	assert(CATALOG.default_asset_for_species("dragon") == "ashwing_drake_lite")
	assert(CATALOG.default_asset_for_species("wyvern").is_empty())
	assert(is_equal_approx(CATALOG.scale_for("ashwing_drake_lite", "small"), 0.65))
	assert(is_equal_approx(CATALOG.scale_for("ashwing_drake_lite", "large"), 1.55))
	assert(CATALOG.colour_for("red").r > CATALOG.colour_for("red").g)
	assert(CATALOG.colour_for("gold").r > CATALOG.colour_for("gold").b)
	var definition := CATALOG.get_definition("ashwing_drake_lite")
	assert(definition.get("species") == "dragon")
	assert(definition.get("animation_map", {}).get("fly") == "fly_loop")
	print("Creature asset catalog tests passed.")
	quit()
