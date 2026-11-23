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
	var mirabel := registry.get_character("mirabel_quill")
	var nessa := registry.get_character("elder_nessa_wren")
	var fenn := registry.get_character("fenn_oakheart")
	if petra.is_empty() or quartermaster.is_empty() or mirabel.is_empty() or nessa.is_empty() or fenn.is_empty():
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
	if petra.get("appearance", {}).is_empty() or quartermaster.get("appearance", {}).is_empty() or mirabel.get("appearance", {}).is_empty() or nessa.get("appearance", {}).is_empty() or fenn.get("appearance", {}).is_empty():
		push_error("Character appearance must remain in character-owned definitions.")
		quit(1)
		return
	var mirabel_appearance: Dictionary = mirabel.get("appearance", {})
	if String(mirabel.get("dialogue_id", "")) != "mirabel_quill" or String(mirabel_appearance.get("hair_style", "")) != "long01":
		push_error("Mirabel identity, dialogue and long hairstyle must be preserved at the Reddale ruin.")
		quit(1)
		return
	var nessa_appearance: Dictionary = nessa.get("appearance", {})
	var fenn_appearance: Dictionary = fenn.get("appearance", {})
	if String(nessa_appearance.get("hair_style", "")) != "short03" or String(fenn_appearance.get("hair_style", "")) != "short02":
		push_error("Elder Nessa and Fenn must retain their authored Ara hairstyles.")
		quit(1)
		return
	print("Campaign 2 character definition registry tests passed.")
	quit(0)
