class_name SpellEffectRules
extends RefCounted

## Executable effects for the complete 15-spell source catalogue.
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

    if spell_id in ["firebolt", "smite_evil", "divine_silence", "temporal_rift", "counterspell"] and target != null:
        if target.side == caster.side:
            return {"ok": false, "reason": "spell_requires_opponent"}
    if spell_id in ["heal", "sanctuary", "divine_protection"] and target != null:
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
    var payload := {"effect": spell_id, "target_hex": target_hex, "affected_ids": []}

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
                if spell_id == "smite_evil" and not _has_any_tag(target, ["undead", "demon"]):
                    payload["hit"] = false
                    payload["reason"] = "invalid_target_tag"
                    payload["damage"] = 0
                else:
                    var hit_chance := _spell_hit_chance(caster, target, spell_id)
                    var rng := RandomNumberGenerator.new()
                    rng.seed = int(cast_id.hash())
                    var hit := float(rng.randi_range(0, 99)) < hit_chance
                    payload["hit"] = hit
                    payload["hit_chance"] = hit_chance
                    payload["damage"] = _apply_spell_damage(target, magnitude) if hit else 0
            payload["magnitude"] = magnitude
        "heal":
            if String(variant.get("type", "")) == "aoe_heal":
                var healed: Array[String] = []
                for ally in affected:
                    if ally.side == caster.side and ally.apply_healing(magnitude) != "unchanged":
                        healed.append(ally.id)
                payload["affected_ids"] = healed
            elif target != null:
                var before := target.health
                var lifecycle := target.apply_healing(magnitude)
                payload["healing"] = target.health - before
                payload["target_lifecycle"] = lifecycle
                payload["target_health"] = target.health
            payload["magnitude"] = magnitude
        "divine_silence":
            _add_effect(target, "divine_silence", caster.id, {"magnitude": magnitude})
            payload["magnitude"] = magnitude
            payload["duration"] = "until the target casts a spell or the effect is dispelled"
        "sanctuary", "divine_protection":
            _add_effect(target, spell_id, caster.id, {"magnitude": maxi(1, magnitude)})
            payload["magnitude"] = maxi(1, magnitude)
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
                _add_effect(victim, "entangled", caster.id)
                entangled.append(victim.id)
            payload["affected_ids"] = entangled
            payload["radius"] = radius
        "wild_fury":
            _add_effect(target, "wild_fury", caster.id, {"magnitude": magnitude, "ticks_remaining": 200.0})
            payload["magnitude"] = magnitude
            payload["duration_ticks"] = 200
        "calm_animal":
            var calm_target := _calm_animal_target(simulation, target)
            _add_effect(calm_target, "calmed", caster.id, {"mode": String(prepared.modifiers.get("calm_mode", "stay"))})
            payload["calmed_id"] = calm_target.id
            payload["mode"] = String(prepared.modifiers.get("calm_mode", "stay"))
        "disguise_self":
            _add_effect(caster, "disguise_self", caster.id, {"profile_id": prepared.presentation.get("profile_id", "")})
            payload["disguise_profile_id"] = String(prepared.presentation.get("profile_id", ""))
        "temporal_rift":
            var previous_tp := target.time_points
            target.time_points = 0.0
            payload["time_points_drained"] = previous_tp
        "feather_fall":
            _add_effect(caster, "feather_fall", caster.id, {"ticks_remaining": 30.0})
            payload["duration_ticks"] = 30
    return payload


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
        var mount: CharacterState = simulation.get_character(target.mounted_animal_id)
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
    var kind := String(prepared.modifiers.get("summon_id", "wolf"))
    var profiles := {
        "wolf": {"health": 18, "damage": 4, "tags": ["animal"], "flying": false},
        "boar": {"health": 24, "damage": 3, "tags": ["animal"], "flying": false},
        "tiger": {"health": 22, "damage": 6, "tags": ["animal"], "flying": false},
        "eagle": {"health": 14, "damage": 4, "tags": ["animal"], "flying": true},
        "unicorn": {"health": 30, "damage": 7, "tags": ["animal", "fey"], "flying": false}
    }
    var profile: Dictionary = profiles.get(kind, profiles["wolf"])
    var summon_id := "summon_%s_%d_%d" % [caster.id, simulation.clock.tick_index, simulation.characters.size()]
    var summon := CharacterState.new(summon_id, "Summoned %s" % kind.capitalize(), hex)
    summon.side = caster.side
    summon.race = kind
    summon.creature_kind = kind
    summon.health = int(profile["health"])
    summon.max_health = int(profile["health"])
    summon.base_damage = int(profile["damage"])
    for tag in profile["tags"]:
        summon.tags.append(String(tag))
    summon.is_flying = bool(profile["flying"])
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
    simulation.register_character(summon)
    return summon


func consume_feather_fall(target: CharacterState) -> bool:
    return target != null and target.remove_spell_effect("feather_fall")
