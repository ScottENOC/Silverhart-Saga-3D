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

	# Source-authored Emberlode and Reddale exteriors and surface actors must
	# appear in the chunks that own their original global axial coordinates.
	var emberlode_west_chunk := Node3D.new()
	root.add_child(emberlode_west_chunk)
	builder.add_settlements_in_chunk(emberlode_west_chunk, Vector2i(-264, 0), 24)
	for node_name in ["emberlode_foremans_hall", "emberlode_mine_entrance", "NPC_corran_vale"]:
		if emberlode_west_chunk.get_node_or_null(node_name) == null:
			push_error("Emberlode source feature was not presented in its owning chunk: " + node_name)
			quit(1)
			return
	var emberlode_east_chunk := Node3D.new()
	root.add_child(emberlode_east_chunk)
	builder.add_settlements_in_chunk(emberlode_east_chunk, Vector2i(-264, 24), 24)
	for node_name in ["emberlode_bunkhouse", "NPC_bettina_marrow", "NPC_rennik_coalmarrow"]:
		if emberlode_east_chunk.get_node_or_null(node_name) == null:
			push_error("Emberlode source feature was not presented in its owning chunk: " + node_name)
			quit(1)
			return

	var reddale_southwest_chunk := Node3D.new()
	root.add_child(reddale_southwest_chunk)
	builder.add_settlements_in_chunk(reddale_southwest_chunk, Vector2i(120, 0), 24)
	for node_name in ["reddale_reeve_house", "NPC_reeve_aldous_finch"]:
		if reddale_southwest_chunk.get_node_or_null(node_name) == null:
			push_error("Reddale source feature was not presented in its owning chunk: " + node_name)
			quit(1)
			return
	var reddale_northwest_chunk := Node3D.new()
	root.add_child(reddale_northwest_chunk)
	builder.add_settlements_in_chunk(reddale_northwest_chunk, Vector2i(120, 24), 24)
	for node_name in ["reddale_guardhouse", "reddale_inn", "reddale_smithy", "NPC_captain_ilsa_rennick", "NPC_watchman_bram_oswick", "NPC_nella_brook", "NPC_mira_selk", "NPC_mirella_thorn", "NPC_torvald_anvik"]:
		if reddale_northwest_chunk.get_node_or_null(node_name) == null:
			push_error("Reddale source feature was not presented in its owning chunk: " + node_name)
			quit(1)
			return
	var reddale_manor_chunk := Node3D.new()
	root.add_child(reddale_manor_chunk)
	builder.add_settlements_in_chunk(reddale_manor_chunk, Vector2i(144, 0), 24)
	for node_name in ["reddale_baron_manor", "NPC_baron_corwin_aldervale", "NPC_steward_halvard_greer"]:
		if reddale_manor_chunk.get_node_or_null(node_name) == null:
			push_error("Reddale source feature was not presented in its owning chunk: " + node_name)
			quit(1)
			return
	var reddale_southeast_chunk := Node3D.new()
	root.add_child(reddale_southeast_chunk)
	builder.add_settlements_in_chunk(reddale_southeast_chunk, Vector2i(144, 24), 24)
	for node_name in ["reddale_ironbond_guildhouse", "NPC_petra_voss", "NPC_osric_vane", "NPC_guild_watchman_corley"]:
		if reddale_southeast_chunk.get_node_or_null(node_name) == null:
			push_error("Reddale source feature was not presented in its owning chunk: " + node_name)
			quit(1)
			return

	var farmstead_chunk := Node3D.new()
	root.add_child(farmstead_chunk)
	builder.add_settlements_in_chunk(farmstead_chunk, Vector2i(0, 192), 24)
	for node_name in ["old_mac_farmhouse", "old_mac_farmhouse_road_spur_chunk_0", "NPC_old_mac"]:
		if farmstead_chunk.get_node_or_null(node_name) == null:
			push_error("Old Mac's source feature was not presented in its owning chunk: " + node_name)
			quit(1)
			return
	var pasture_chunk := Node3D.new()
	root.add_child(pasture_chunk)
	builder.add_settlements_in_chunk(pasture_chunk, Vector2i(-24, 192), 24)
	for node_name in ["old_mac_pasture", "old_mac_pasture_south_fence", "old_mac_pasture_west_fence_upper", "old_mac_pasture_west_fence_lower", "old_mac_broken_fence_rail", "old_mac_blood_spatter_01", "old_mac_blood_spatter_02", "old_mac_blood_spatter_03", "old_mac_blood_spatter_04", "old_mac_blood_spatter_06", "old_mac_blood_spatter_08", "old_mac_blood_spatter_10", "OldMacSheepA", "OldMacSheepB"]:
		if pasture_chunk.get_node_or_null(node_name) == null:
			push_error("Old Mac's source pasture feature was not presented in its owning chunk: " + node_name)
			quit(1)
			return
	var pasture_north_chunk := Node3D.new()
	root.add_child(pasture_north_chunk)
	builder.add_settlements_in_chunk(pasture_north_chunk, Vector2i(-24, 168), 24)
	for node_name in ["old_mac_pasture_north_fence", "old_mac_pasture_east_fence_upper"]:
		if pasture_north_chunk.get_node_or_null(node_name) == null:
			push_error("Old Mac's northern fence feature was not presented in its owning chunk: " + node_name)
			quit(1)
			return
	if pasture_chunk.get_node_or_null("old_mac_pasture_north_fence") != null:
		push_error("Old Mac's northern fence must not be duplicated into the southern pasture chunk.")
		quit(1)
		return

	# SceneTree._initialize runs before the first process frame; wait for the newly
	# added CreatureActor nodes to enter the tree and execute _ready/_load_model.
	await process_frame
	var sheep_actor := pasture_chunk.get_node_or_null("OldMacSheepA") as CreatureActor
	if sheep_actor == null or sheep_actor.model_root == null or sheep_actor.dialogue_id != "farm_sheep":
		push_error("Old Mac's first sheep must load its generated 3D model and retain dialogue identity.")
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

	# Silverhart's palace and outer Warrens are streamed from the same canonical
	# settlement definition; named NPCs must resolve into their owning chunks.
	var silverhart_palace_chunk := Node3D.new()
	root.add_child(silverhart_palace_chunk)
	builder.add_settlements_in_chunk(silverhart_palace_chunk, Vector2i(0, -504), 24)
	for node_name in ["silverhart_grand_hall", "silverhart_barracks", "NPC_queen_seraphine_corrin", "NPC_royal_guard_denna"]:
		if silverhart_palace_chunk.get_node_or_null(node_name) == null:
			push_error("Silverhart palace feature or NPC was not presented in its owning chunk: " + node_name)
			quit(1)
			return

	# The Grand Cathedral is the shared in-world location for Aldric's
	# Measure of an Oath investigation. Both supporting characters must be
	# present in the same streamed settlement chunk with stable dialogue IDs.
	var silverhart_cathedral_chunk := Node3D.new()
	root.add_child(silverhart_cathedral_chunk)
	builder.add_settlements_in_chunk(silverhart_cathedral_chunk, Vector2i(0, -456), 24)
	for node_name in ["silverhart_grand_cathedral", "NPC_preceptor_garran_vey", "NPC_high_cleric_adelram"]:
		if silverhart_cathedral_chunk.get_node_or_null(node_name) == null:
			push_error("Grand Cathedral feature or supporting NPC was not presented in its owning chunk: " + node_name)
			quit(1)
			return
	var garran_actor := silverhart_cathedral_chunk.get_node("NPC_preceptor_garran_vey")
	var adelram_actor := silverhart_cathedral_chunk.get_node("NPC_high_cleric_adelram")
	if String(garran_actor.get_meta("dialogue_id", "")) != "preceptor_garran_vey":
		push_error("Preceptor Garran Vey must retain his chapter-specific dialogue identity.")
		quit(1)
		return
	if String(adelram_actor.get_meta("dialogue_id", "")) != "high_cleric":
		push_error("High Cleric Adelram must retain his source dialogue identity.")
		quit(1)
		return

	var silverhart_warrens_chunk := Node3D.new()
	root.add_child(silverhart_warrens_chunk)
	builder.add_settlements_in_chunk(silverhart_warrens_chunk, Vector2i(0, -432), 24)
	for node_name in ["silverhart_thieves_guild", "silverhart_thieves_guild_vault", "NPC_tessa_nightshade", "NPC_corvin_ashe_guildmaster", "NPC_marsh_dobbins", "NPC_silas_crane"]:
		if silverhart_warrens_chunk.get_node_or_null(node_name) == null:
			push_error("Silverhart Warrens feature or NPC was not presented in its owning chunk: " + node_name)
			quit(1)
			return

	var vault_building := silverhart_warrens_chunk.get_node_or_null("silverhart_thieves_guild_vault")
	if vault_building != null and vault_building.get_node_or_null("DoorFrame") != null:
		push_error("The Silverhart guild vault must not present a visible standard entrance.")
		quit(1)
		return

	print("Campaign 2 canonical settlement builder tests passed.")
	quit(0)
