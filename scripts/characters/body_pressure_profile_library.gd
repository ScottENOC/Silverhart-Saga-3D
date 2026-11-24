extends RefCounted
class_name BodyPressureProfileLibrary
## Mechanical defaults for the canonical CharacterSurfaceRegionMask vocabulary.
## Region identity is owned by the anatomy system; this library only assigns
## provisional game-tuning material behaviour. Values are not measurements.

const ANATOMY_MASK_SCRIPT_PATH := "res://scripts/characters/character_surface_region_mask.gd"

static func get_anatomy_region_ids() -> Array[StringName]:
	if not ResourceLoader.exists(ANATOMY_MASK_SCRIPT_PATH):
		return []
	var mask_script := load(ANATOMY_MASK_SCRIPT_PATH)
	if mask_script == null:
		return []
	var ids: Array = mask_script.REGION_IDS
	var result: Array[StringName] = []
	for value in ids:
		result.append(StringName(str(value)))
	return result

static func create_profile(region_id: StringName) -> BodyRegionProfile:
	var key := String(region_id).to_lower()
	var values := _profile_values_for_region(key)
	var profile := BodyRegionProfile.new()
	profile.stiffness_n_per_m = values[0]
	profile.damping_ns_per_m = values[1]
	profile.effective_mass_kg = values[2]
	profile.max_compression_m = values[3]
	profile.sanitise()
	return profile

static func register_anatomy_regions(controller: BodyPressureController, region_ids: Array = []) -> int:
	if controller == null:
		return 0
	var canonical_ids: Array = region_ids
	if canonical_ids.is_empty():
		canonical_ids = get_anatomy_region_ids()
	var registered := 0
	for value in canonical_ids:
		var region_id := StringName(str(value))
		if region_id == StringName() or controller.has_region(region_id):
			continue
		controller.register_region(region_id, create_profile(region_id))
		registered += 1
	return registered

static func _profile_values_for_region(key: String) -> Array[float]:
	# Soft, compliant tissue groups. Finer anatomy IDs retain their own identity
	# while sharing a material starting point until character-specific tuning exists.
	if _contains_any(key, ["breast", "areola", "nipple", "buttock", "gluteal", "abdomen", "flank", "thigh", "calf"]):
		return [850.0, 30.0, 0.22, 0.032]
	if _contains_any(key, ["waist", "hip", "inguinal", "groin", "pectoral", "ribcage"]):
		return [1450.0, 38.0, 0.28, 0.022]
	if _contains_any(key, ["hand", "finger", "thumb", "palm", "wrist", "elbow", "knee", "ankle", "foot", "heel", "toes", "instep"]):
		return [3900.0, 68.0, 0.14, 0.010]
	if _contains_any(key, ["head", "face", "eye", "eyelid", "nose", "jaw", "chin", "ear", "brow", "temple"]):
		return [4700.0, 76.0, 0.30, 0.008]
	if _contains_any(key, ["neck", "throat", "nape"]):
		return [2300.0, 52.0, 0.16, 0.014]
	if _contains_any(key, ["shoulder", "clavicle", "scapula", "back", "spine", "sternum"]):
		return [2600.0, 56.0, 0.30, 0.016]
	if _contains_any(key, ["arm", "bicep", "tricep", "forearm"]):
		return [2200.0, 50.0, 0.22, 0.018]
	if _contains_any(key, ["pelvis", "sacrum", "perineum"]):
		return [2100.0, 46.0, 0.30, 0.018]
	return [1800.0, 42.0, 0.24, 0.018]

static func _contains_any(value: String, tokens: Array) -> bool:
	for token in tokens:
		if value.contains(str(token)):
			return true
	return false
