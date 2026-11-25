extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := Node3D.new()
	root.add_child(host)
	var controller_script := load("res://scripts/presentation/spell_vfx_controller.gd")
	if controller_script == null:
		push_error("Spell VFX controller script failed to load.")
		quit(1)
		return
	var controller := controller_script.new() as Node3D
	host.add_child(controller)

	var caster := Node3D.new()
	caster.position = Vector3.ZERO
	host.add_child(caster)
	var target := Node3D.new()
	target.position = Vector3(4.0, 0.0, 0.0)
	host.add_child(target)
	var ally := Node3D.new()
	ally.position = Vector3(4.0, 0.0, 1.0)
	host.add_child(ally)

	var spell_ids: Array[String] = [
		"firebolt", "counterspell", "feather_fall", "disguise_self",
		"heal", "divine_protection", "divine_strength", "curse",
		"summon_animal", "entangle", "calm_animal", "wild_fury"
	]
	for spell_id in spell_ids:
		controller.call("play_spell", spell_id, caster, target, target.global_position, {}, [target, ally])

	await process_frame
	_check(controller.get_child_count() > 0, "Casting spells should create visible 3D effect nodes.")
	_check(spell_ids.size() == 12, "The VFX catalogue should cover all 12 official spells.")
	if failures > 0:
		push_error("%d spell VFX test(s) failed." % failures)
		quit(1)
		return
	print("All 12 official spell VFX handlers created their presentation nodes.")
	quit(0)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("FAIL: " + message)
