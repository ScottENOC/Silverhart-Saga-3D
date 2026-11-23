class_name SpellEffectRules
extends RefCounted

## Executable effects for the official 12-spell player catalogue.
## Validation is deliberately separate from application so failed casts never
## spend mana, health or Time Points.

func target_hex_for(simulation: Variant, request: SimulationActionRequest, target: CharacterState) -> Vector2i:
	var saved: Variant = request.options.get("target_hex", {})
	if saved is Dictionary and saved.has("q") and saved.has("r"):
		return Vector2i(int(saved.get("q", 0)), int(saved.get("r", 0)))
	if request.destination != Vector2i.ZERO or target == null:
		return request.destination
	return target.axial


func validate(
	simulation: Variant,
	caster: CharacterState,
	target: CharacterState,
	prepared: PreparedSpell,
	variant: Dictionary,
	request: SimulationActionRequest
) -> Dictionary:
	var spell_id := prepared.base_spell_id
	if spell_id == "counterspell":
		return {"ok": false, "reason": "counterspell_is_reaction_only"}
	var base := SpellRules.get_base_spell(spell_id)
	var target_hex := target_hex_for(simulation, request, target)
	if target != null and not target.can_be_targeted():
		return {"ok": false, "reason": "target_unavailable"}
	var self_target := spell_id in ["disguise_self", "feather_fall"]
	var area_spell := String(variant.get("type", "")) in ["aoe_damage", "aoe_heal", "aoe_debuff"]
	if self_target:
		if target != null and target != caster:
			return {"ok": false, "reason": "spell_requires_self_target"}
		target = caster
	elif spell_id != "summon_animal" and not area_spell and target == null:
		return {"ok": false, "reason": "target_required"}

	if spell_id in ["firebolt", "counterspell", "curse"] and target != null:
		if target.side == caster.side:
			return {"ok": false, "reason": "spell_requires_opponent"}
	if spell_id in ["heal", "divine_protection", "divine_strength"] and target != null:
		if target.side != caster.side:
			return {"ok": false, "reason": "spell_requires_ally"}
	if spell_id == "wild_fury":
		if target == null or (target != caster and target.summoned_by_id != caster.id):
			return {"ok": false, "reason": "wild_fury_requires_self_or_own_companion"}
	if spell_id == "calm_animal":
		if target == null:
			return {"ok": false, "reason": "target_required"}
		var animal := _calm_animal_target(simulation, target)
		if animal == null:
			return {"ok": false, "reason": "target_not_calmable_animal"}
		target = animal
	if spell_id == "summon_animal":
		var summon_id := String(prepared.modifiers.get("summon_id", "wolf"))
		if summon_id == "unicorn":
			if int(caster.skills.get("learn_unicorn_summon", 0)) <= 0 or int(caster.skills.get("animal_companion", 0)) <= 0:
				return {"ok": false, "reason": "unicorn_summon_locked"}
			for value in simulation.characters.values():
				var existing := value as CharacterState
				if existing != null and existing.summoned_by_id == caster.id and existing.is_animal_companion:
					return {"ok": false, "reason": "animal_companion_already_exists"}
		if HexGrid.distance(caster.axial, target_hex) > maxi(1, int(variant.get("range", 1))):
			return {"ok": false, "reason": "target_out_of_range"}
		if not simulation.map_data.is_walkable(target_hex) or simulation.is_hex_occupied(target_hex):
			return {"ok": false, "reason": "summon_hex_unavailable"}
	elif spell_id in ["dragon_breath", "entangle"] or area_spell:
		if HexGrid.distance(caster.axial, target_hex) > maxi(1, int(variant.get("range", 1))):
			return {"ok": false, "reason": "target_out_of_range"}
		if not simulation.map_data.is_walkable(target_hex):
			return {"ok": false, "reason": "area_hex_unavailable"}
	else:
		if target != null and HexGrid.distance(caster.axial, target_hex) > maxi(1, int(variant.get("range", 1))):
			return {"ok": false, "reason": "target_out_of_range"}

	var target_ids: Array = request.options.get("target_ids", [])
	if not target_ids.is_empty():
		if spell_id in ["summon_animal", "entangle", "calm_animal", "disguise_self", "feather_fall", "counterspell"]:
			return {"ok": false, "reason": "multi_target_not_supported_for_spell"}
		if target_ids.size() > int(variant.get("extra_targets", 0)) + 1:
			return {"ok": false, "reason": "too_many_targets"}
		for target_id_value in target_ids:
			var selected: CharacterState = simulation.get_character(String(target_id_value)) as CharacterState
			if selected == null or not selected.can_be_targeted():
				return {"ok": false, "reason": "target_unavailable"}
			if spell_id in ["firebolt", "curse"] and selected.side == caster.side:
				return {"ok": false, "reason": "spell_requires_opponent"}
			if spell_id in ["heal", "divine_protection", "divine_strength"] and selected.side != caster.side:
				return {"ok": false, "reason": "spell_requires_ally"}
			if spell_id == "wild_fury" and (selected.side != caster.side or not selected.tags.has("animal") or selected.tags.has("fey") or selected.tags.has("dragon")):
				return {"ok": false, "reason": "wild_fury_requires_ally_animal"}
			if HexGrid.distance(caster.axial, selected.axial) > maxi(1, int(variant.get("range", 1))):
				return {"ok": false, "reason": "target_out_of_range"}
	if spell_id == "counterspell" and target != null:
		if target.side == caster.side:
			return {"ok": false, "reason": "counterspell_requires_opponent"}
		if target.spell_effects.is_empty() and not target.is_summoned:
			return {"ok": false, "reason": "no_spell_effect_to_dispel"}
	return {"ok": true, "target": target, "target_hex": target_hex}


func apply(
	simulation: Variant,
	caster: CharacterState,
	target: CharacterState,
	prepared: PreparedSpell,
	variant: Dictionary,
	request: SimulationActionRequest,
	cast_id: String
) -> Dictionary:
	var spell_id := prepared.base_spell_id
	var target_hex: Vector2i = target_hex_for(simulation, request, target)
	var radius := maxi(0, int(variant.get("radius", 0)))
	var magnitude_value: Variant = variant.get("magnitude", 0)
	var magnitude := maxi(1, roundi(float(magnitude_value))) if magnitude_value is int or magnitude_value is float else 0
	var affected := _characters_in_radius(simulation, target_hex, radius)
	var selected_targets := _selected_targets(simulation, request, target)
	var payload := {"effect": spell_id, "target_hex": target_hex, "affected_ids": []}
	if not request.options.get("target_ids", []).is_empty():
		var selected_ids: Array[String] = []
		for selected in selected_targets:
			selected_ids.append(selected.id)
		payload["affected_ids"] = selected_ids

	match spell_id:
		"firebolt", "smite_evil":
			if bool(variant.get("type", "") == "aoe_damage"):
				var hit_ids: Array[String] = []
				for victim in affected:
					if victim.side == caster.side:
						continue
					if spell_id == "smite_evil" and not _has_any_tag(victim, ["undead", "demon"]):
						continue
					var damage := _apply_spell_damage(victim, magnitude)
					hit_ids.append(victim.id)
					payload["damage_%s" % victim.id] = damage
				payload["affected_ids"] = hit_ids
			elif target != null:
				var hit_ids: Array[String] = []
				for victim in selected_targets:
					var hit_chance := _spell_hit_chance(caster, victim, spell_id)
					var rng := RandomNumberGenerator.new()
					rng.seed = int((cast_id + victim.id).hash())
					var hit := float(rng.randi_range(0, 99)) < hit_chance
					if hit:
						hit_ids.append(victim.id)
						payload["damage_%s" % victim.id] = _apply_spell_damage(victim, magnitude)
				payload["hit"] = not hit_ids.is_empty()
				payload["affected_ids"] = hit_ids
				payload["magnitude"] = magnitude
			payload["magnitude"] = magnitude
		"heal":
			if String(variant.get("type", "")) == "aoe_heal":
				var healed: Array[String] = []
				for ally in affected:
					if ally.side != caster.side:
						continue
					var heal_amount := _effective_healing_amount(ally, magnitude)
					if heal_amount > 0 and ally.apply_healing(heal_amount) != "unchanged":
						healed.append(ally.id)
				payload["affected_ids"] = healed
			elif target != null:
				var healed_ids: Array[String] = []
				for ally in selected_targets:
					var before := ally.health
					var heal_amount := _effective_healing_amount(ally, magnitude)
					if ally.apply_healing(heal_amount) != "unchanged":
						healed_ids.append(ally.id)
					payload["healing_%s" % ally.id] = ally.health - before
				payload["affected_ids"] = healed_ids
			payload["magnitude"] = magnitude
		"divine_protection":
			for ally in selected_targets:
				_add_effect(ally, spell_id, caster.id, {"magnitude": maxi(1, magnitude)})
			payload["magnitude"] = maxi(1, magnitude)
		"divine_strength":
			for ally in selected_targets:
				_add_effect(ally, spell_id, caster.id, {"magnitude": magnitude, "ticks_remaining": 20.0})
			payload["magnitude"] = magnitude
			payload["duration_ticks"] = 20
		"curse":
			var duration := 20 + maxi(0, int(caster.skills.get("extended_sentence", 0))) * 2
			var damage_reduction := mini(3, maxi(0, int(caster.skills.get("cleric_trigger_dmg_red", 0))))
			var healing_reduction := mini(100, maxi(0, int(caster.skills.get("cleric_trigger_heal_red", 0))) * 50)
			var vision_penalty := mini(3, maxi(0, int(caster.skills.get("cleric_trigger_vision", 0))))
			for cursed_target in selected_targets:
				_add_effect(cursed_target, "curse", caster.id, {
					"magnitude": magnitude,
					"ticks_remaining": float(duration),
					"damage_reduction": damage_reduction,
					"healing_reduction_percent": healing_reduction,
					"vision_penalty": vision_penalty,
					"armistice_next_attack_tp": 5 if int(caster.skills.get("armistice", 0)) > 0 else 0
				})
				var trigger_damage := maxi(0, int(caster.skills.get("cleric_trigger_damage", 0)))
				if trigger_damage > 0:
					payload["trigger_damage_%s" % cursed_target.id] = _apply_spell_damage(cursed_target, trigger_damage)
				var mana_drain := maxi(0, int(caster.skills.get("cleric_trigger_mana", 0)))
				if mana_drain > 0:
					var drained := mini(cursed_target.current_mana, mana_drain)
					cursed_target.current_mana -= drained
					payload["mana_drained_%s" % cursed_target.id] = drained
			payload["magnitude"] = magnitude
			payload["duration_ticks"] = duration
			payload["trigger"] = "next hostile action by the target"
		"summon_animal":
			var summon := _create_summon(simulation, caster, prepared, target_hex)
			payload["summoned_id"] = summon.id if summon != null else ""
			payload["summon_kind"] = String(prepared.modifiers.get("summon_id", "wolf"))
		"counterspell":
			var removed := ""
			if target != null:
				if target.is_summoned:
					target.alive = false
					simulation.occupied_hexes.erase(target.axial)
					removed = "summon"
				elif not target.spell_effects.is_empty():
					var effect: Dictionary = target.spell_effects.pop_back()
					removed = String(effect.get("effect_id", "spell_effect"))
			payload["dispelled"] = removed
		"dragon_breath":
			var damaged: Array[String] = []
			for victim in affected:
				if victim.side == caster.side:
					continue
				var dealt := _apply_spell_damage(victim, magnitude)
				damaged.append(victim.id)
				payload["damage_%s" % victim.id] = dealt
			payload["affected_ids"] = damaged
			payload["magnitude"] = magnitude
		"entangle":
			var entangled: Array[String] = []
			for victim in affected:
				if victim.side == caster.side:
					continue
				_add_effect(victim, "entangled", caster.id, {"ticks_remaining": 20, "zone_id": cast_id})
				entangled.append(victim.id)
			var affected_hexes: Array[Vector2i] = simulation.apply_entangle_zone(target_hex, radius, caster.id, 20, cast_id)
			payload["affected_ids"] = entangled
			payload["affected_hexes"] = affected_hexes
			payload["radius"] = radius
			payload["duration_ticks"] = 20
			payload["zone_id"] = cast_id
		"wild_fury":
			for animal in selected_targets:
				_add_effect(animal, "wild_fury", caster.id, {"magnitude": magnitude, "ticks_remaining": 200.0})
			payload["magnitude"] = magnitude
			payload["duration_ticks"] = 200
		"calm_animal":
			var calm_target := _calm_animal_target(simulation, target)
			_add_effect(calm_target, "calmed", caster.id, {"mode": String(prepared.modifiers.get("calm_mode", "stay"))})
			payload["calmed_id"] = calm_target.id
			payload["mode"] = String(prepared.modifiers.get("calm_mode", "stay"))
		"disguise_self":
			var copy_character_id := String(prepared.presentation.get("copy_character_id", ""))
			_add_effect(caster, "disguise_self", caster.id, {
				"profile_id": prepared.presentation.get("profile_id", ""),
				"copy_character_id": copy_character_id
			})
			payload["disguise_profile_id"] = String(prepared.presentation.get("profile_id", ""))
			payload["copy_character_id"] = copy_character_id
		"temporal_rift":
			var previous_tp := target.time_points
			target.time_points = 0.0
			payload["time_points_drained"] = previous_tp
		"feather_fall":
			_add_effect(caster, "feather_fall", caster.id, {"ticks_remaining": 30.0})
			payload["duration_ticks"] = 30
	return payload


func _selected_targets(simulation: Variant, request: SimulationActionRequest, fallback: CharacterState) -> Array[CharacterState]:
	var result: Array[CharacterState] = []
	var target_ids: Array = request.options.get("target_ids", [])
	if target_ids.is_empty():
		if fallback != null:
			result.append(fallback)
		return result
	for target_id_value in target_ids:
		var selected: CharacterState = simulation.get_character(String(target_id_value)) as CharacterState
		if selected != null:
			result.append(selected)
	return result


func _effective_healing_amount(target: CharacterState, base_amount: int) -> int:
	if target == null:
		return 0
	var curse := target.get_spell_effect("curse")
	var reduction := clampi(int(curse.get("healing_reduction_percent", 0)), 0, 100)
	return maxi(0, floori(float(base_amount) * (1.0 - float(reduction) / 100.0)))


func _add_effect(target: CharacterState, effect_id: String, source_id: String, data: Dictionary = {}) -> void:
	if target == null:
		return
	var effect := {"effect_id": effect_id, "source_id": source_id}
	effect.merge(data, true)
	target.add_spell_effect(effect)


func _characters_in_radius(simulation: Variant, center: Vector2i, radius: int) -> Array[CharacterState]:
	var result: Array[CharacterState] = []
	for value in simulation.characters.values():
		var state := value as CharacterState
		if state != null and state.can_be_targeted() and HexGrid.distance(center, state.axial) <= radius:
			result.append(state)
	return result


func _has_any_tag(target: CharacterState, tags: Array) -> bool:
	for tag in tags:
		if target.tags.has(String(tag)):
			return true
	return false


func _calm_animal_target(simulation: Variant, target: CharacterState) -> CharacterState:
	if target == null:
		return null
	if target.tags.has("animal") and not target.tags.has("fey") and not target.tags.has("dragon"):
		return target
	if not target.mounted_animal_id.is_empty():
		var mount: CharacterState = simulation.get_character(target.mounted_animal_id) as CharacterState
		if mount != null and mount.tags.has("animal") and not mount.tags.has("fey") and not mount.tags.has("dragon"):
			return mount
	return null


func _apply_spell_damage(target: CharacterState, magnitude: int) -> int:
	if target == null:
		return 0
	var reduction := maxi(0, target.base_reduction + target.armour_reduction + target.shield_reduction + target.helmet_reduction + target.temp_reduction)
	var damage := maxi(1, magnitude - reduction)
	target.apply_damage(damage)
	return damage


func _spell_hit_chance(caster: CharacterState, target: CharacterState, spell_id: String) -> float:
	var bonus := int(caster.skills.get("%s_hit" % spell_id, 0)) * 5
	return clampf(50.0 + caster.to_hit_spell + float(bonus) - target.passive_dodge, 0.0, 100.0)


func _create_summon(simulation: Variant, caster: CharacterState, prepared: PreparedSpell, hex: Vector2i) -> CharacterState:
	var kind := String(prepared.modifiers.get("summon_id", "wolf")).to_lower()
	if not AnimalCatalog.has_profile(kind):
		push_error("Summon Animal has no AnimalCatalog profile for: %s" % kind)
		return null
	var summon_id := "summon_%s_%d_%d" % [caster.id, simulation.clock.tick_index, simulation.characters.size()]
	var summon := AnimalCatalog.create_state(kind, summon_id, "Summoned %s" % kind.capitalize(), hex)
	if summon == null:
		return null
	summon.side = caster.side
	# Preserve the existing Summon Animal combat balance while taking identity,
	# movement, tags, mountability and persistence from the shared catalogue.
	var summon_balance := {
		"wolf": [18, 4], "boar": [24, 3], "tiger": [22, 6],
		"eagle": [14, 4], "unicorn": [30, 7]
	}
	if summon_balance.has(kind):
		summon.max_health = int(summon_balance[kind][0])
		summon.health = summon.max_health
		summon.base_damage = int(summon_balance[kind][1])
	var has_companion := false
	for value in simulation.characters.values():
		var existing := value as CharacterState
		if existing != null and existing.summoned_by_id == caster.id and existing.is_animal_companion:
			has_companion = true
			break
	var becomes_companion := int(caster.skills.get("animal_companion", 0)) > 0 and not has_companion
	summon.is_animal_companion = becomes_companion
	summon.is_summoned = not becomes_companion
	summon.summoned_by_id = caster.id
	summon.time_points = 100.0
	var registration := simulation.register_animal(summon)
	if not bool(registration.get("ok", false)):
		push_error("Failed to register summoned animal: %s" % String(registration.get("reason", "unknown")))
		return null
	return summon


func consume_feather_fall(target: CharacterState) -> bool:
	return target != null and target.remove_spell_effect("feather_fall")
