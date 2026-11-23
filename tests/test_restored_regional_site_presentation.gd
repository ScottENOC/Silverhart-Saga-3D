extends SceneTree

const TERRAIN_DATA = preload("res://scripts/world/campaign2_world_terrain_data.gd")
const SETTLEMENT_BUILDER = preload("res://scripts/world/campaign2_settlement_builder.gd")


func _initialize() -> void:
	var terrain := TERRAIN_DATA.new()
	var builder = SETTLEMENT_BUILDER.new(terrain.settlement_layouts)

	var grove_chunk := Node3D.new()
	root.add_child(grove_chunk)
	builder.add_settlements_in_chunk(grove_chunk, Vector2i(-276, 0), 24)
	for node_name in ["NPC_elder_nessa_wren", "NPC_fenn_oakheart"]:
		if grove_chunk.get_node_or_null(node_name) == null:
			push_error("Emberwood Grove resident was not restored to its owning chunk: " + node_name)
			quit(1)
			return

	var camp_chunk := Node3D.new()
	root.add_child(camp_chunk)
	builder.add_settlements_in_chunk(camp_chunk, Vector2i(192, 12), 24)
	for node_name in [
		"skarn_tooth_chiefs_hut", "skarn_tooth_hut_west_north",
		"skarn_tooth_hut_east_north", "skarn_tooth_hut_west_south",
		"skarn_tooth_hut_east_south", "skarn_tooth_hut_south",
		"skarn_tooth_campfire", "goblin_scout_note_prop",
		"NPC_chief_skarnub", "NPC_nix_sharpear", "NPC_gralk_bonecaster",
		"NPC_grondle", "NPC_skarn_tooth_guard_01", "NPC_skarn_tooth_guard_02",
		"NPC_skarn_tooth_skulker", "NPC_ser_aldric_thorne"
	]:
		if camp_chunk.get_node_or_null(node_name) == null:
			push_error("Skarn-tooth Camp feature or resident was not restored: " + node_name)
			quit(1)
			return

	var chief := camp_chunk.get_node("NPC_chief_skarnub")
	if float(chief.get_meta("height_scale", 1.0)) >= 1.0 or float(chief.get_meta("body_scale", 1.0)) >= 1.0 or String(chief.get_meta("race", "")) != "goblin":
		push_error("Chief Skarnub must use the short, slight human stand-in while retaining goblin identity.")
		quit(1)
		return
	var campfire := camp_chunk.get_node("skarn_tooth_campfire")
	var glow := campfire.get_node_or_null("CampfireGlow") as OmniLight3D
	if glow == null or not is_equal_approx(glow.omni_range, 21.0):
		push_error("Skarn-tooth campfire must retain its authored light radius.")
		quit(1)
		return
	var aldric := camp_chunk.get_node("NPC_ser_aldric_thorne")
	if not bool(aldric.get_meta("tied_up", false)) or String(aldric.get_meta("dialogue_id", "")) != "ser_aldric_captive":
		push_error("Ser Aldric must remain tied up and use the captive dialogue identity.")
		quit(1)
		return

	print("Restored Emberwood and Skarn-tooth site presentation tests passed.")
	quit(0)
