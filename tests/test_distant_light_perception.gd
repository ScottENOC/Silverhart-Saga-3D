extends SceneTree

const VISION = preload("res://scripts/simulation/vision_rules.gd")

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
    print("Distant light perception tests passed.")
    quit(0)
