extends SceneTree

const VISION = preload("res://scripts/simulation/vision_rules.gd")
const CHARACTER = preload("res://scripts/simulation/character_state.gd")

func _initialize() -> void:
	# Ordinary visual detection remains bounded by the observer's vision.
	assert(not VISION.can_notice_distant_light(25, 25, 60, true, true))
	assert(not VISION.can_notice_distant_light(26, 25, 60, false, true))
	assert(not VISION.can_notice_distant_light(26, 25, 60, true, false))

	# At nightfall, an emitted light can be noticed beyond vision, but only
	# inside the caller-provided light-notice budget.
	assert(VISION.can_notice_distant_light(26, 25, 60, true, true))
	assert(VISION.can_notice_distant_light(60, 25, 60, true, true))
	assert(not VISION.can_notice_distant_light(61, 25, 60, true, true))

	# The light cue is intentionally separate from actor identification:
	# this helper accepts no actor or target state and returns only a boolean.

	# Stealth detection is a separate probability query. It does not decide
	# whether the target is spatially visible; can_see remains the hard gate.
	var observer := CHARACTER.new("observer", "Observer")
	observer.skills["keen_perception"] = 2
	var chance := VISION.stealth_detection_chance(observer, 10, 50.0, 0.2, false)
	assert(is_equal_approx(chance, 55.0))
	var lit_chance := VISION.stealth_detection_chance(observer, 10, 50.0, 0.2, true)
	assert(is_equal_approx(lit_chance, 100.0))
	assert(VISION.stealth_detection_chance(observer, 15, 150.0, 0.2, false) == 0.0)
	assert(VISION.stealth_detection_chance(observer, 15, 150.0, 1.0, false) == 5.0)
	assert(VISION.stealth_detection_chance(null, 5, 0.0) == 0.0)

	print("Distant light and stealth detection tests passed.")
	quit(0)
