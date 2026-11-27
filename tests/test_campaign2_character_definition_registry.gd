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
	var reyna := registry.get_character("reyna_fletcher")
	if petra.is_empty() or quartermaster.is_empty() or mirabel.is_empty() or reyna.is_empty():
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
	if petra.get("appearance", {}).is_empty() or quartermaster.get("appearance", {}).is_empty() or mirabel.get("appearance", {}).is_empty() or reyna.get("appearance", {}).is_empty():
		push_error("Character appearance must remain in character-owned definitions.")
		quit(1)
		return
	var mirabel_appearance: Dictionary = mirabel.get("appearance", {})
	if String(mirabel.get("dialogue_id", "")) != "mirabel_quill" or String(mirabel_appearance.get("hair_style", "")) != "long01":
		push_error("Mirabel identity, dialogue and long hairstyle must be preserved at the Reddale ruin.")
		quit(1)
		return
	var reyna_appearance: Dictionary = reyna.get("appearance", {})
	if String(reyna.get("dialogue_id", "")) != "reyna_fletcher" or String(reyna_appearance.get("hair_style", "")) != "braid01":
		push_error("Reyna identity, dialogue and braid hairstyle must be preserved at Old Mac’s Farmstead.")
		quit(1)
		return
	var brokk := registry.get_character("ambassador_brokk_stonehammer")
	var toren := registry.get_character("ambassador_toren_aldwyn")
	if brokk.is_empty() or toren.is_empty():
		push_error("Brokk and Toren must resolve from the authored Silverhart NPC catalogue.")
		quit(1)
		return
	if String(brokk.get("dialogue_id", "")) != "dwarven_ambassador" or String(toren.get("dialogue_id", "")) != "corvane_ambassador":
		push_error("The Silverhart ambassador profiles must preserve their source dialogue IDs.")
		quit(1)
		return
	var cassia := registry.get_character("ambassador_cassia_wren")
	var cassia_appearance: Dictionary = cassia.get("appearance", {})
	if cassia.is_empty() or String(cassia.get("dialogue_id", "")) != "aldenreach_ambassador":
		push_error("Cassia must remain an authored Silverhart ambassador with her dialogue route.")
		quit(1)
		return
	if String(cassia_appearance.get("hair_style", "")) != "cornrows" or String(cassia_appearance.get("hair_colour", "")) != "#241A16" or String(cassia_appearance.get("eye_colour", "")) != "hazel":
		push_error("Cassia's source-authored Ara hair, eye and colour profile must be applied to her streamed actor.")
		quit(1)
		return
	if not is_equal_approx(float(cassia_appearance.get("height", -1.0)), 0.46) or not is_equal_approx(float(cassia_appearance.get("muscle", -1.0)), 0.83):
		push_error("Cassia's source-authored Ara body proportions must be retained.")
		quit(1)
		return
	var elarion := registry.get_character("ambassador_elarion")
	if elarion.is_empty():
		push_error("Elarion must resolve from the Silverhart envoy catalogue.")
		quit(1)
		return
	var envoy_hair_styles := {
		"ambassador_elarion": "box_braids",
		"ambassador_brokk_stonehammer": "long01",
		"ambassador_toren_aldwyn": "buzz"
	}
	for envoy_id in envoy_hair_styles:
		var envoy := registry.get_character(envoy_id)
		var envoy_appearance: Dictionary = envoy.get("appearance", {})
		if String(envoy_appearance.get("hair_style", "")) != String(envoy_hair_styles[envoy_id]):
			push_error("Source-authored Ara hair profile missing for %s." % envoy_id)
			quit(1)
			return
	if String(brokk.get("appearance", {}).get("eye_colour", "")) != "green" or String(toren.get("appearance", {}).get("eye_colour", "")) != "darkbrown":
		push_error("Brokk and Toren must retain their source-authored eye colours.")
		quit(1)
		return
	var settlement_registry := Campaign2SettlementDefinitionRegistry.new()
	if not settlement_registry.validation_errors.is_empty():
		push_error("Settlement definitions failed while checking ambassador placements: %s" % settlement_registry.validation_errors)
		quit(1)
		return
	var silverhart := settlement_registry.get_definition("silverhart")
	if silverhart.is_empty():
		push_error("The canonical Silverhart settlement definition must resolve.")
		quit(1)
		return
	var placement_data: Dictionary = silverhart.get("placements", {})
	var placed_ids: Array[String] = []
	for placement_value in placement_data.get("characters", []):
		if not placement_value is Dictionary:
			continue
		var placement: Dictionary = placement_value
		placed_ids.append(String(placement.get("character_id", placement.get("id", ""))))
	if not placed_ids.has("ambassador_brokk_stonehammer") or not placed_ids.has("ambassador_toren_aldwyn"):
		push_error("Brokk and Toren must remain authored NPC placements in Silverhart.")
		quit(1)
		return
	var tavern_source := FileAccess.get_file_as_string("res://scripts/world/hollow_tankard.gd")
	for route in [
		'if dialogue_id == "dwarven_ambassador":',
		'if dialogue_id == "corvane_ambassador":'
	]:
		if not tavern_source.contains(route):
			push_error("Missing live streamed ambassador interaction route: %s" % route)
			quit(1)
			return
	var ambassador_service := FileAccess.get_file_as_string("res://scripts/quests/campaign_ambassador_dialogue_service.gd")
	for route in [
		'if choice_id.begins_with("brokk_"):',
		'elif choice_id.begins_with("toren_"):'
	]:
		if not ambassador_service.contains(route):
			push_error("Missing shared ambassador quest choice route: %s" % route)
			quit(1)
			return
	print("Campaign 2 character definition registry tests passed.")
	quit(0)
