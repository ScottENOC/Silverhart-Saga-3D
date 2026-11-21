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
	builder.add_settlements_in_chunk(hollowmere_parent, Vector2i(0, 0), 24, "chunked")
	if hollowmere_parent.get_node_or_null("GeneralStore") == null:
		push_error("Hollowmere buildings should now be composed by the shared chunk builder.")
		quit(1)
		return

	# Hollowmere ecology is now chunk-owned. The wilderness deer starts in this
	# chunk and its gameplay state must survive presentation teardown/rebuild.
	var simulation := WorldSimulation.new()
	var ecology_builder = SETTLEMENT_BUILDER.new(terrain.settlement_layouts, null, simulation)
	var wilderness_chunk := Node3D.new()
	root.add_child(wilderness_chunk)
	ecology_builder.add_settlements_in_chunk(wilderness_chunk, Vector2i(-48, 0), 24, "chunked")
	var deer := wilderness_chunk.get_node_or_null("WildernessDeer") as CreatureActor
	if deer == null:
		push_error("Authored Hollowmere wildlife should be presented by its owning chunk.")
		quit(1)
		return
	var deer_state := simulation.get_character("animal_wildernessdeer")
	if deer_state == null or deer_state.axial != Vector2i(-34, 18):
		push_error("Chunk presentation should register the deer in persistent simulation state.")
		quit(1)
		return
	var vegetation_count := 0
	for child in wilderness_chunk.get_children():
		if child.has_meta("vegetation_family"):
			vegetation_count += 1
	if vegetation_count == 0:
		push_error("Authored Hollowmere forest vegetation should be generated within its owning chunk.")
		quit(1)
		return

	# Retire the presentation nodes, move the simulation state, then rebuild the
	# destination chunk. The actor must follow saved state, not its authored start.
	deer_state.axial = Vector2i(30, 80)
	wilderness_chunk.free()
	var destination_chunk := Node3D.new()
	root.add_child(destination_chunk)
	ecology_builder.add_settlements_in_chunk(destination_chunk, Vector2i(24, 72), 24, "chunked")
	var restored_deer := destination_chunk.get_node_or_null("WildernessDeer") as CreatureActor
	if restored_deer == null or restored_deer.axial_hex != Vector2i(30, 80):
		push_error("Rebuilt chunks must restore creature actors at their persistent simulation positions.")
		quit(1)
		return
	var original_chunk := Node3D.new()
	root.add_child(original_chunk)
	ecology_builder.add_settlements_in_chunk(original_chunk, Vector2i(-48, 0), 24, "chunked")
	if original_chunk.get_node_or_null("WildernessDeer") != null:
		push_error("A moved creature must not be duplicated at its authored starting chunk.")
		quit(1)
		return

	print("Campaign 2 canonical settlement builder tests passed.")
	quit(0)
