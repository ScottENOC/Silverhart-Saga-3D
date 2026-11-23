extends SceneTree

const REGISTRY = preload("res://scripts/world/campaign2_character_definition_registry.gd")

func _initialize() -> void:
	var registry = REGISTRY.new()
	if not registry.validation_errors.is_empty():
		push_error("Character definition registry failed: %s" % registry.validation_errors)
		quit(1)
		return
	var petra := registry.get_character("petra_hollis")
	var quartermaster := registry.get_character("border_war_quartermaster")
	var reyna := registry.get_character("reyna_fletcher")
	if petra.is_empty() or quartermaster.is_empty() or reyna.is_empty():
		push_error("Millbrook character-owned profiles must resolve independently of settlement placements.")
		quit(1)
		return
	if String(petra.get("name", "")) != "Petra Hollis":
		push_error("Petra's character identity was not preserved.")
		quit(1)
		return
	if String(quartermaster.get("name", "")) != "Quartermaster Rurik Voss":
		push_error("Quartermaster identity was not preserved.")
		quit(1)
		return
	if petra.get("appearance", {}).is_empty() or quartermaster.get("appearance", {}).is_empty() or reyna.get("appearance", {}).is_empty():
		push_error("Character appearance must remain in character-owned definitions.")
		quit(1)
		return
	var reyna_appearance: Dictionary = reyna.get("appearance", {})
	if String(reyna.get("dialogue_id", "")) != "reyna_fletcher" or String(reyna_appearance.get("hair_style", "")) != "braid01":
		push_error("Reyna's source dialogue and appearance profile must be preserved at her new location.")
		quit(1)
		return
	print("Campaign 2 character definition registry tests passed.")
	quit(0)
