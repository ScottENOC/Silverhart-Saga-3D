extends SceneTree

const TERRAIN_DATA = preload("res://scripts/world/campaign2_world_terrain_data.gd")
const WOLF_DEN = preload("res://scripts/world/world_wolf_den_presentation.gd")
const ABANDONED_APPROACH = preload("res://scripts/world/world_abandoned_house_approach_presentation.gd")
const BORDER_FORTS = preload("res://scripts/world/world_border_fort_presentation.gd")

var failures := 0

func _initialize() -> void:
	_test_wolf_den_chunk_ownership()
	_test_abandoned_house_approach()
	_test_border_fort_props()
	if failures > 0:
		push_error("%d physical map presentation verification test(s) failed." % failures)
		quit(1)
		return
	print("Physical map site presentation verification tests passed.")
	quit(0)


func _test_wolf_den_chunk_ownership() -> void:
	var data := TERRAIN_DATA.new() as Campaign2WorldTerrainData
	var site := data.encounter_site("farm_wolf_den")
	_check(String(site.get("kind", "")) == "wolf_den", "Old Mac's Wolf Den must resolve from the canonical site registry")
	var anchor := Vector2i(int(site.get("q", 0)), int(site.get("r", 0)))
	_check(anchor == Vector2i(-59, 204), "Old Mac's Wolf Den must retain its source axial anchor")
	var owner := Node3D.new()
	root.add_child(owner)
	var result := WOLF_DEN.present_chunk(owner, data, Vector2i(-72, 192), 24, HexGrid.DEFAULT_RADIUS_M)
	_check(bool(result.get("ok", false)) and int(result.get("features", 0)) == 1, "The owning chunk must emit one natural wolf-den entrance")
	_check(result.get("anchor") == anchor, "Wolf-den dressing must report the canonical source anchor")
	var den := owner.get_node_or_null("OldMacWolfDenPresentation") as Node3D
	_check(den != null, "Wolf den must have a stable presentation root")
	if den != null:
		_check(den.get_node_or_null("ShadowedDenMouth") != null, "Wolf den must have a dark natural cave mouth")
		_check(den.get_node_or_null("EntranceLeft") != null and den.get_node_or_null("EntranceRight") != null, "Wolf den must have both entrance rocks")
		_check(den.get_node_or_null("Overhang") != null, "Wolf den must retain its rock overhang")
		_check(den.get_child_count() == 7, "Wolf den must retain its overhang, mouth, two entrance rocks and three bones")
	_check(owner.get_node_or_null("Wolf") == null, "Map presentation must not spawn encounter wolves")
	owner.free()

	var neighbour := Node3D.new()
	root.add_child(neighbour)
	var other := WOLF_DEN.present_chunk(neighbour, data, Vector2i(-48, 192), 24, HexGrid.DEFAULT_RADIUS_M)
	_check(bool(other.get("ok", false)) and int(other.get("features", -1)) == 0, "A neighbouring chunk must not duplicate the wolf den")
	_check(neighbour.get_child_count() == 0, "Non-owning wolf-den chunks must remain empty")
	neighbour.free()


func _test_abandoned_house_approach() -> void:
	var data := TERRAIN_DATA.new() as Campaign2WorldTerrainData
	var site := data.encounter_site("abandoned_house")
	_check(String(site.get("kind", "")) == "haunted_house", "Abandoned House must resolve from canonical geography")
	var centre := Vector2i(int(site.get("q", 0)), int(site.get("r", 0)))
	var parent := Node3D.new()
	root.add_child(parent)
	var result := ABANDONED_APPROACH.present_chunk(parent, data, Vector2i(0, -192), 24, HexGrid.DEFAULT_RADIUS_M)
	_check(bool(result.get("ok", false)), "Abandoned House approach chunk must compose")
	_check(int(result.get("features", -1)) == 2, "The two source-painted approach cells must each be presented")
	_check(result.get("anchor") == centre, "Abandoned House approach must use its canonical anchor")
	_check(result.get("waypoint") == centre + Vector2i(-6, 0), "Abandoned House approach must preserve its source waypoint")
	_check(result.get("doorway") == centre + Vector2i(-3, 0), "Abandoned House approach must preserve its west doorway")
	var path := parent.get_node_or_null("AbandonedHouseApproach") as Node3D
	_check(path != null and path.get_child_count() == 6, "Both source path cells must have three worn-earth patches")
	parent.free()

	var neighbour := Node3D.new()
	root.add_child(neighbour)
	var other := ABANDONED_APPROACH.present_chunk(neighbour, data, Vector2i(24, -192), 24, HexGrid.DEFAULT_RADIUS_M)
	_check(bool(other.get("ok", false)) and int(other.get("features", -1)) == 0, "Abandoned House path dressing must remain chunk-owned")
	_check(neighbour.get_child_count() == 0, "Non-owning Abandoned House chunks must remain empty")
	neighbour.free()


func _test_border_fort_props() -> void:
	var data := TERRAIN_DATA.new() as Campaign2WorldTerrainData
	var parent := Node3D.new()
	root.add_child(parent)
	var result := BORDER_FORTS.present_chunk(parent, data, Vector2i(-1024, -1024), 2048, HexGrid.DEFAULT_RADIUS_M)
	_check(bool(result.get("ok", false)), "Both source border forts must compose in a full-world verification chunk")
	_check(parent.get_node_or_null("NorthwatchSiegeEngine") != null, "Northwatch must retain its source siege engine")
	_check(parent.get_node_or_null("NorthwatchGreenskinCatapult") != null, "Northwatch must retain the distant source catapult")
	_check(parent.get_node_or_null("NorthwatchOilBarrel_267_-6") != null and parent.get_node_or_null("NorthwatchOilBarrel_269_-6") != null, "Northwatch must retain both source oil barrels")
	_check(parent.get_node_or_null("BorderFortHearth_268_-21") != null, "Northwatch keep must retain its hearth")
	var ridgehold := parent.get_node_or_null("BorderFortHearth_426_43")
	_check(ridgehold != null, "Ridgehold keep must retain its hearth")
	var ladder_count := 0
	for child in parent.get_children():
		if String(child.name).begins_with("NorthwatchWallLadder_"):
			ladder_count += 1
	_check(ladder_count == 6, "Northwatch must present six source-derived wall ladders")
	_check(int(result.get("props", 0)) == parent.get_child_count(), "Border fort prop count must match the emitted stable roots")
	_check(parent.get_node_or_null("NorthwatchGarrison") == null, "Border fort map dressing must not create garrison actors")
	parent.free()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
