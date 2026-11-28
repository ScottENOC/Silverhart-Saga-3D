extends SceneTree

const SAVE_DIFFS := preload("res://scripts/campaign/campaign_character_save_diffs.gd")

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var simulation := WorldSimulation.new()
	var player := CharacterState.new("player", "Hero", Vector2i.ZERO)
	player.side = "player"
	simulation.register_character(player)
	var baselines := SAVE_DIFFS.capture_character_baselines(simulation)
	_check(baselines.has("player"), "Initial character baselines include registered characters.")

	player.health -= 3
	var changed := CharacterState.new("traveller", "Traveller", Vector2i(1, 0))
	changed.side = "neutral"
	simulation.register_character(changed)
	var diffs := SAVE_DIFFS.build_character_diffs(simulation, baselines)
	_check(int(diffs.get("player", {}).get("health", -1)) == player.health, "Changed character fields are saved as a compact delta.")
	_check(diffs.get("traveller", {}).has("__full_record"), "Characters added after the baseline are saved as full records.")
	_check(not diffs.get("player", {}).has("display_name"), "Unchanged character fields are omitted.")

	var npc := Node3D.new()
	npc.set_meta("base_appearance_profile", {"hair":"short","skin":"warm"})
	npc.set_meta("appearance_profile", {"hair":"long","skin":"warm","scar":true})
	var appearance := SAVE_DIFFS.build_appearance_diffs({"player":Node3D.new(),"traveller":npc})
	_check(appearance.size() == 1 and appearance.has("traveller"), "Only non-player actors with appearance changes are included.")
	_check(appearance.traveller == {"hair":"long","scar":true}, "Appearance deltas omit unchanged profile fields.")

	npc.free()
	simulation.free()
	if failures > 0:
		push_error("%d campaign character save diff assertion(s) failed." % failures)
		quit(1)
	else:
		print("Campaign character save diff tests passed.")
		quit(0)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("FAIL: " + message)
