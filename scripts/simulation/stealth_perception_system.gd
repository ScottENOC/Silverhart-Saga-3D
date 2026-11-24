class_name StealthPerceptionSystem
extends RefCounted
## Shared, presentation-neutral perception rules for characters and world entities.
## Sight reports confidence, not a binary visible/hidden flag. Sound deliberately
## reports only a bearing and distance band; it never leaks an exact source hex.

const VISUAL_NONE := 0
const VISUAL_SUSPICIOUS := 1
const VISUAL_VAGUE := 2
const VISUAL_SILHOUETTE := 3
const VISUAL_RECOGNISED := 4
const VISUAL_IDENTIFIED := 5

const SOUND_UNHEARD := 0
const SOUND_SUSPICIOUS := 1
const SOUND_HEARD := 2

const DETAIL_THRESHOLDS := {
	"vague": 0.08,
	"silhouette": 0.22,
	"recognised": 0.48,
	"identified": 0.76
}


static func assess(
	observer: Dictionary,
	target: Dictionary,
	map_cells: Dictionary,
	environment: Dictionary = {}
) -> Dictionary:
	var observer_hex: Vector2i = observer.get("hex", Vector2i.ZERO)
	var target_hex: Vector2i = target.get("hex", Vector2i.ZERO)
	var distance := _hex_distance(observer_hex, target_hex)
	var obstruction := _trace_visual_path(observer, target, map_cells)
	var target_profile := _visual_profile(target)
	var terrain_profile: Dictionary = _cell_at(map_cells, target_hex)
	var camouflage := _camouflage_score(target_profile, terrain_profile)
	var lighting := _target_illumination(target, target_hex, map_cells, environment)
	var atmosphere := _atmospheric_visibility(environment)
	var movement_exposure := clampf(float(target.get("movement_exposure", 0.0)), 0.0, 1.0)
	var reflective_exposure := clampf(float(target_profile.get("reflectivity", 0.0)), 0.0, 1.0)
	var emitted_light := clampf(float(target_profile.get("light_emission", 0.0)), 0.0, 1.0)

	# Light sources have their own long-range low-detail visibility. This is
	# intentionally independent of whether the person carrying one is visible.
	var light_signal := maxf(emitted_light, lighting * 0.35)
	var light_visibility := clampf(light_signal * atmosphere / (1.0 + float(distance) * 0.055), 0.0, 1.0)
	var ambient_visibility := clampf(
		(float(environment.get("ambient_light", 1.0)) + lighting * 0.8)
		* atmosphere
		/ (1.0 + float(distance) * 0.11),
		0.0,
		1.0
	)
	var contrast_penalty := (1.0 - camouflage) * 0.58
	var exposure_bonus := movement_exposure * 0.28 + reflective_exposure * 0.24
	var cover := clampf(float(target_profile.get("cover", terrain_profile.get("cover", 0.0))), 0.0, 1.0)
	var visual_signal := clampf(
		ambient_visibility * (0.92 - contrast_penalty - cover * 0.48 + exposure_bonus)
		+ light_visibility * 0.9,
		0.0,
		1.0
	)
	visual_signal *= float(obstruction.get("transmission", 1.0))
	var visual_level := _visual_level(visual_signal, distance, emitted_light, light_visibility)
	var result := {
		"visual_level": visual_level,
		"visual_label": visual_level_name(visual_level),
		"visual_confidence": visual_signal,
		"distance": distance,
		"camouflage": camouflage,
		"reflective_exposure": reflective_exposure,
		"light_visibility": light_visibility,
		"obstruction": obstruction,
		"target_hex": target_hex if visual_level >= VISUAL_RECOGNISED else null,
		"hex_known": visual_level >= VISUAL_RECOGNISED,
		"target_identified": visual_level >= VISUAL_IDENTIFIED
	}
	return result


static func assess_sound(
	observer_hex: Vector2i,
	sound_event: Dictionary,
	map_cells: Dictionary,
	environment: Dictionary = {}
) -> Dictionary:
	var source_hex: Vector2i = sound_event.get("hex", Vector2i.ZERO)
	var distance := _hex_distance(observer_hex, source_hex)
	var loudness := clampf(float(sound_event.get("loudness", 0.0)), 0.0, 1.0)
	var source_noise := clampf(float(sound_event.get("equipment_noise", 0.0)), 0.0, 1.0)
	var wind_factor := clampf(float(environment.get("sound_wind_factor", 0.0)), -0.5, 0.5)
	var attenuation := _sound_path_transmission(observer_hex, source_hex, map_cells)
	var signal_strength := clampf(
		(loudness + source_noise * 0.55 + wind_factor)
		* attenuation
		/ (1.0 + float(distance) * 0.075),
		0.0,
		1.0
	)
	var level := SOUND_UNHEARD
	if signal_strength >= 0.12:
		level = SOUND_SUSPICIOUS
	if signal_strength >= 0.27:
		level = SOUND_HEARD
	var bearing := _bearing_sector(observer_hex, source_hex) if level > SOUND_UNHEARD else -1
	return {
		"sound_level": level,
		"heard": level > SOUND_UNHEARD,
		"confidence": signal_strength,
		"bearing_sector": bearing,
		"distance_band": _distance_band(distance) if level > SOUND_UNHEARD else "",
		"sound_kind": String(sound_event.get("kind", "unknown")) if level == SOUND_HEARD else "unidentified",
		# Never return source_hex or source identity from an acoustic-only result.
		"source_identified": false
	}


static func character_visual_profile(character: Variant, appearance: Dictionary = {}) -> Dictionary:
	var profile := appearance.duplicate(true)
	var colours: Array = profile.get("colours", profile.get("colors", [])).duplicate()
	var reflectivity := float(profile.get("reflectivity", 0.0))
	var light_emission := float(profile.get("light_emission", 0.0))
	var equipment_noise := float(profile.get("equipment_noise", 0.0))
	var cover := float(profile.get("cover", 0.0))
	if character is CharacterState:
		var state := character as CharacterState
		for slot_value in state.equipped_item_data:
			var item: Dictionary = state.equipped_item_data[slot_value]
			var item_colours: Array = item.get("colours", item.get("colors", [])).duplicate()
			if item.has("colour"):
				item_colours.append(item.colour)
			if item.has("color"):
				item_colours.append(item.color)
			colours.append_array(item_colours)
			var material := String(item.get("material", "")).to_lower()
			var item_type := String(item.get("type", "")).to_lower()
			var metal := material in ["iron", "steel", "silver", "mithril", "bronze", "metal"] or bool(item.get("metallic", false))
			if metal:
				reflectivity = maxf(reflectivity, float(item.get("reflectivity", 0.72)))
			equipment_noise += float(item.get("noise", item.get("noise_rating", 0.22 if metal else 0.0)))
			if String(item.get("weight_class", "")).to_lower() == "heavy":
				equipment_noise += 0.12
			var item_id := String(item.get("id", "")).to_lower()
			if bool(item.get("is_light_source", false)) or item_type == "torch" or item_id.contains("torch") or item_id.contains("lantern"):
				light_emission = maxf(light_emission, float(item.get("light_emission", 0.85)))
			if item.has("cover"):
				cover = maxf(cover, float(item.cover))
		for tag_value in state.tags:
			var tag := String(tag_value).to_lower()
			if tag in ["torch_lit", "lantern_lit"]:
				light_emission = maxf(light_emission, 0.8)
	profile["colours"] = colours
	profile["reflectivity"] = clampf(reflectivity, 0.0, 1.0)
	profile["light_emission"] = clampf(light_emission, 0.0, 1.0)
	profile["equipment_noise"] = clampf(equipment_noise, 0.0, 1.0)
	profile["cover"] = clampf(cover, 0.0, 1.0)
	return profile


static func visual_level_name(level: int) -> String:
	match level:
		VISUAL_SUSPICIOUS: return "suspicious"
		VISUAL_VAGUE: return "vague"
		VISUAL_SILHOUETTE: return "silhouette"
		VISUAL_RECOGNISED: return "recognised"
		VISUAL_IDENTIFIED: return "identified"
		_: return "unseen"


static func character_equipment_noise(character: Variant) -> float:
	return float(character_visual_profile(character).get("equipment_noise", 0.0))


static func make_character_sound_event(character: Variant, kind: String, loudness: float, movement_noise: float = 0.0) -> Dictionary:
	if not character is CharacterState:
		return {}
	var state := character as CharacterState
	var profile := character_visual_profile(state)
	return {
		"source_id": state.id,
		"hex": state.axial,
		"kind": kind,
		"loudness": clampf(loudness + movement_noise, 0.0, 1.0),
		"equipment_noise": float(profile.get("equipment_noise", 0.0))
	}


static func _visual_profile(target: Dictionary) -> Dictionary:
	var appearance: Dictionary = target.get("appearance", {}).duplicate(true)
	if target.has("light_emission"):
		appearance["light_emission"] = maxf(float(appearance.get("light_emission", 0.0)), float(target.light_emission))
	if target.has("colours") or target.has("colors"):
		appearance["colours"] = target.get("colours", target.get("colors", [])).duplicate(true)
	if target.has("reflectivity"):
		appearance["reflectivity"] = maxf(float(appearance.get("reflectivity", 0.0)), float(target.reflectivity))
	var result := appearance.duplicate(true)
	var colours: Array = result.get("colours", result.get("colors", [])).duplicate()
	var reflectivity := float(result.get("reflectivity", 0.0))
	var light_emission := float(result.get("light_emission", 0.0))
	var equipment_noise := float(result.get("equipment_noise", 0.0))
	var equipment: Array = target.get("equipment", [])
	for item_value in equipment:
		if not item_value is Dictionary:
			continue
		var item: Dictionary = item_value
		colours.append_array(item.get("colours", item.get("colors", [])))
		if item.has("colour"):
			colours.append(item.colour)
		if item.has("color"):
			colours.append(item.color)
		var material := String(item.get("material", "")).to_lower()
		if material in ["iron", "steel", "silver", "mithril", "bronze", "metal"] or bool(item.get("metallic", false)):
			reflectivity = maxf(reflectivity, float(item.get("reflectivity", 0.72)))
		equipment_noise += float(item.get("noise", item.get("noise_rating", 0.22 if material in ["iron", "steel", "silver", "mithril", "bronze", "metal"] or bool(item.get("metallic", false)) else 0.0)))
		if String(item.get("weight_class", "")).to_lower() == "heavy":
			equipment_noise += 0.12
		var item_id := String(item.get("id", "")).to_lower()
		if bool(item.get("is_light_source", false)) or item_id.contains("torch") or item_id.contains("lantern"):
			light_emission = maxf(light_emission, float(item.get("light_emission", 0.85)))
	result["colours"] = colours
	result["reflectivity"] = clampf(reflectivity, 0.0, 1.0)
	result["light_emission"] = clampf(light_emission, 0.0, 1.0)
	result["equipment_noise"] = clampf(equipment_noise, 0.0, 1.0)
	return result


static func _camouflage_score(target_profile: Dictionary, terrain_profile: Dictionary) -> float:
	var target_colours: Array = target_profile.get("colours", target_profile.get("colors", target_profile.get("palette", [])))
	var terrain_colours: Array = terrain_profile.get("colours", terrain_profile.get("colors", terrain_profile.get("palette", terrain_profile.get("colour_palette", terrain_profile.get("color_palette", [])))))
	if target_colours.is_empty() or terrain_colours.is_empty():
		return clampf(float(target_profile.get("terrain_camouflage", 0.5)), 0.0, 1.0)
	var total := 0.0
	var samples := 0
	for target_colour_value in target_colours:
		var target_colour := _as_colour(target_colour_value)
		if not target_colour is Color:
			continue
		var nearest := 10.0
		for terrain_colour_value in terrain_colours:
			var terrain_colour := _as_colour(terrain_colour_value)
			if terrain_colour is Color:
				nearest = minf(nearest, _colour_distance(target_colour, terrain_colour))
		if nearest < 10.0:
			total += clampf(nearest / 0.72, 0.0, 1.0)
			samples += 1
	if samples == 0:
		return clampf(float(target_profile.get("terrain_camouflage", 0.0)), 0.0, 1.0)
	return 1.0 - clampf(total / float(samples), 0.0, 1.0)


static func _as_colour(value: Variant) -> Variant:
	if value is Color:
		return value
	if value is Vector3:
		return Color(value.x, value.y, value.z)
	if value is String:
		return Color.from_string(value, Color.BLACK)
	return null


static func _colour_distance(a: Color, b: Color) -> float:
	var dr := a.r - b.r
	var dg := a.g - b.g
	var db := a.b - b.b
	return sqrt(dr * dr + dg * dg + db * db)


static func _target_illumination(target: Dictionary, target_hex: Vector2i, map_cells: Dictionary, environment: Dictionary) -> float:
	var illumination := float(target.get("appearance", {}).get("ambient_illumination", 0.0))
	var sources: Array = environment.get("light_sources", [])
	for source_value in sources:
		if not source_value is Dictionary:
			continue
		var source: Dictionary = source_value
		var source_hex: Vector2i = source.get("hex", Vector2i.ZERO)
		var distance := _hex_distance(target_hex, source_hex)
		var radius := maxf(0.1, float(source.get("radius", 1.0)))
		if distance <= radius:
			illumination = maxf(illumination, float(source.get("intensity", 0.0)) * (1.0 - float(distance) / (radius + 1.0)))
	return clampf(illumination, 0.0, 1.0)


static func _atmospheric_visibility(environment: Dictionary) -> float:
	var visibility := 1.0
	for key in ["fog", "smoke", "heavy_rain", "dust"]:
		visibility *= 1.0 - clampf(float(environment.get(key, 0.0)), 0.0, 0.95) * 0.82
	return clampf(visibility, 0.02, 1.0)


static func _trace_visual_path(observer: Dictionary, target: Dictionary, map_cells: Dictionary) -> Dictionary:
	var start: Vector2i = observer.get("hex", Vector2i.ZERO)
	var finish: Vector2i = target.get("hex", Vector2i.ZERO)
	var observer_height := float(observer.get("eye_height", 1.6))
	var target_height := float(target.get("visual_height", 1.6))
	var transmission := 1.0
	var blocked := false
	var crossed: Array[Vector2i] = _hex_line(start, finish)
	for index in range(1, crossed.size() - 1):
		var cell: Dictionary = _cell_at(map_cells, crossed[index])
		var blocker_height := float(cell.get("vision_block_height", 0.0))
		if bool(cell.get("blocks_vision", false)) and blocker_height >= minf(observer_height, target_height):
			blocked = true
			transmission *= 0.06
		transmission *= 1.0 - clampf(float(cell.get("visual_dampening", cell.get("vegetation_density", 0.0) * 0.32)), 0.0, 0.85)
	var target_cell := _cell_at(map_cells, finish)
	transmission *= 1.0 - clampf(float(target_cell.get("visual_cover", 0.0)), 0.0, 0.9)
	return {"blocked": blocked, "transmission": clampf(transmission, 0.0, 1.0), "hexes_crossed": maxi(0, crossed.size() - 2)}


static func _sound_path_transmission(start: Vector2i, finish: Vector2i, map_cells: Dictionary) -> float:
	var transmission := 1.0
	var crossed: Array[Vector2i] = _hex_line(start, finish)
	for index in range(1, crossed.size() - 1):
		var cell: Dictionary = _cell_at(map_cells, crossed[index])
		transmission *= 1.0 - clampf(float(cell.get("sound_dampening", 0.0)), 0.0, 0.9)
		if bool(cell.get("blocks_sound", false)):
			transmission *= 0.35
	return clampf(transmission, 0.0, 1.0)


static func _visual_level(signal_strength: float, distance: int, emitted_light: float, light_visibility: float) -> int:
	if signal_strength < 0.045:
		return VISUAL_NONE
	if signal_strength < 0.09:
		return VISUAL_SUSPICIOUS
	if signal_strength < DETAIL_THRESHOLDS.vague:
		return VISUAL_VAGUE
	if signal_strength < DETAIL_THRESHOLDS.silhouette:
		return VISUAL_VAGUE
	if signal_strength < DETAIL_THRESHOLDS.recognised:
		return VISUAL_SILHOUETTE
	if signal_strength < DETAIL_THRESHOLDS.identified:
		return VISUAL_RECOGNISED
	if distance > 0 and emitted_light <= 0.0 and light_visibility < 0.1:
		return VISUAL_RECOGNISED
	return VISUAL_IDENTIFIED


static func _bearing_sector(observer_hex: Vector2i, source_hex: Vector2i) -> int:
	var dx := source_hex.x - observer_hex.x
	var dy := source_hex.y - observer_hex.y
	var screen_x := float(dx) + float(dy) * 0.5
	var screen_y := float(dy) * 0.8660254038
	var angle := atan2(screen_y, screen_x)
	return posmod(roundi(angle / (PI / 3.0)), 6)


static func _distance_band(distance: int) -> String:
	if distance <= 2: return "near"
	if distance <= 5: return "moderate"
	if distance <= 9: return "far"
	return "very_far"


static func _cell_at(map_cells: Dictionary, hex: Vector2i) -> Dictionary:
	var value: Variant = map_cells.get(hex, {})
	return value if value is Dictionary else {}


static func _hex_distance(a: Vector2i, b: Vector2i) -> int:
	var dq := a.x - b.x
	var dr := a.y - b.y
	return maxi(absi(dq), maxi(absi(dr), absi(dq + dr)))


static func _hex_line(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var distance := _hex_distance(a, b)
	var result: Array[Vector2i] = []
	if distance == 0:
		result.append(a)
		return result
	for index in range(distance + 1):
		var t := float(index) / float(distance)
		var q := lerpf(float(a.x), float(b.x), t)
		var r := lerpf(float(a.y), float(b.y), t)
		var s := lerpf(float(-a.x - a.y), float(-b.x - b.y), t)
		var rq := roundi(q)
		var rr := roundi(r)
		var rs := roundi(s)
		var q_diff := absf(float(rq) - q)
		var r_diff := absf(float(rr) - r)
		var s_diff := absf(float(rs) - s)
		if q_diff > r_diff and q_diff > s_diff:
			rq = -rr - rs
		elif r_diff > s_diff:
			rr = -rq - rs
		result.append(Vector2i(rq, rr))
	return result
