extends SceneTree

const FOG_OF_WAR_SCRIPT = preload("res://scripts/presentation/fog_of_war.gd")

var failures: int = 0

func _initialize() -> void:
	var observer := CharacterState.new("fog_test_player", "Fog Test Player", Vector2i.ZERO)
	var fog: Variant = FOG_OF_WAR_SCRIPT.new()
	fog.call("initialize", observer, {}, {}, null)

	_check(bool(fog.call("is_hex_visible", Vector2i.ZERO)), "The observer's starting hex should be visible")
	_check(bool(fog.call("is_explored", Vector2i.ZERO)), "The observer's starting hex should be marked explored")
	_check(
		(fog.get("fog_multimesh") as MultiMesh).instance_count == (fog.get("hexes") as Array).size(),
		"The fog MultiMesh should contain one instance per authored map hex"
	)

	var fog_mesh: MultiMesh = fog.get("fog_multimesh")
	var far_hex := Vector2i(0, HollowmereVillageData.MAP_RADIUS)
	var far_index: int = fog.get("hex_to_instance")[far_hex]
	var far_transform := fog_mesh.get_instance_transform(far_index)
	_check(
		fog_mesh.custom_aabb.has_point(far_transform.origin),
		"The fog MultiMesh culling bounds should include the far edge of the whole village"
	)
	_check(
		far_transform.origin.y >= 0.08,
		"Outdoor fog should sit above the village ground and road ribbons"
	)

	observer.axial = Vector2i(26, 0)
	fog.call("update_visibility", observer)

	_check(bool(fog.call("is_hex_visible", observer.axial)), "The observer's new hex should become visible after movement")
	_check(not bool(fog.call("is_hex_visible", Vector2i.ZERO)), "A hex outside live vision should no longer be currently visible")
	_check(bool(fog.call("is_explored", Vector2i.ZERO)), "Previously explored terrain should remain explored after movement")

	fog.free()
	if failures > 0:
		push_error("%d fog-of-war test assertion(s) failed." % failures)
		quit(1)
		return
	print("Fog-of-war tests passed.")
	quit(0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
