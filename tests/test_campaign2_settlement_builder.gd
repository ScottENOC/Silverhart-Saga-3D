extends SceneTree

const TERRAIN_DATA = preload("res://scripts/world/campaign2_world_terrain_data.gd")
const SETTLEMENT_BUILDER = preload("res://scripts/world/campaign2_settlement_builder.gd")

func _initialize() -> void:
	var terrain = TERRAIN_DATA.new()
	var parent := Node3D.new()
	root.add_child(parent)
	var builder = SETTLEMENT_BUILDER.new(terrain.settlement_layouts)
	builder.add_settlements_in_chunk(parent, Vector2i(0, -384), 24)
	if parent.get_node_or_null("millbrook_house") == null:
		push_error("Canonical Millbrook building was not presented in its owning chunk.")
		quit(1)
		return
	if parent.get_node_or_null("millbrook_house_spur_chunk_0") == null:
		push_error("Millbrook authored road spur was not composed by the shared chunk feature pipeline.")
		quit(1)
		return
	if parent.get_node_or_null("NPC_petra_hollis") == null:
		push_error("Petra's actor was not resolved from the character definition registry.")
		quit(1)
		return
	if parent.get_node_or_null("NPC_border_war_quartermaster") == null:
		push_error("The quartermaster actor was not resolved from the character definition registry.")
		quit(1)
		return

	var hollowmere_parent := Node3D.new()
	root.add_child(hollowmere_parent)
	builder.add_settlements_in_chunk(hollowmere_parent, Vector2i(0, 0), 24)
	if hollowmere_parent.get_node_or_null("GeneralStore") != null:
		push_error("Chunked builder duplicated Hollowmere, which is owned by its location presenter.")
		quit(1)
		return

	print("Campaign 2 canonical settlement builder tests passed.")
	quit(0)
