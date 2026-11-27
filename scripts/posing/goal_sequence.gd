extends RefCounted
## Timeline for a touch: reach -> press -> hold -> release.
## Produces normalised motion; positions come from ContactResolver so the same
## timeline works on any body, with or without armour.

var start_distance_m := 0.12   # pad height above the surface when the motion starts
var reach_s := 0.6
var press_s := 0.25
var hold_s := 0.3
var release_s := 0.3
var peak_force_n := 4.0


func total_duration_s() -> float:
	return reach_s + press_s + hold_s + release_s


static func smoothstep01(x: float) -> float:
	var c := clampf(x, 0.0, 1.0)
	return c * c * (3.0 - 2.0 * c)


## Minimum-jerk blend: zero velocity and acceleration at both ends.
static func smootherstep01(x: float) -> float:
	var c := clampf(x, 0.0, 1.0)
	return c * c * c * (c * (c * 6.0 - 15.0) + 10.0)


## Returns {phase: StringName, approach_m: float, force_n: float}.
## approach_m is the pad's height above the contact surface (>= 0).
func sample(t: float) -> Dictionary:
	var time := maxf(0.0, t)
	if time < reach_s:
		return _state(&"reach", start_distance_m * (1.0 - smootherstep01(time / reach_s)), 0.0)
	time -= reach_s
	if time < press_s:
		return _state(&"press", 0.0, peak_force_n * smoothstep01(time / press_s))
	time -= press_s
	if time < hold_s:
		return _state(&"hold", 0.0, peak_force_n)
	time -= hold_s
	if time < release_s:
		var unload_fraction := 0.4
		var u := time / release_s
		if u < unload_fraction:
			return _state(&"release", 0.0, peak_force_n * (1.0 - smoothstep01(u / unload_fraction)))
		return _state(&"release", start_distance_m * smootherstep01((u - unload_fraction) / (1.0 - unload_fraction)), 0.0)
	return _state(&"done", start_distance_m, 0.0)


func _state(phase: StringName, approach_m: float, force_n: float) -> Dictionary:
	return {"phase": phase, "approach_m": approach_m, "force_n": force_n}
