extends RefCounted
## Analytic two-bone IK (shoulder-elbow-wrist) with an explicit swivel angle.
## Pure maths. The swivel is the free parameter: rotation of the elbow about the root->target axis.

## Solve for the middle joint. `pole_dir` picks which side of the root->target axis the middle joint
## starts on (it need not be perpendicular). `swivel_rad` rotates the result about that axis.
## Returns {mid, end, reached, flexion_deg, distance_error_m}.
## When the target is out of reach the chain points straight at it and `reached` is false.
static func solve(root: Vector3, target: Vector3, upper_len: float, lower_len: float, pole_dir: Vector3, swivel_rad: float = 0.0) -> Dictionary:
	var to_target := target - root
	var distance := to_target.length()
	var min_reach := absf(upper_len - lower_len) + 1e-5
	var max_reach := upper_len + lower_len - 1e-5
	var dir := to_target / distance if distance > 1e-9 else Vector3.UP
	var reached := distance >= min_reach and distance <= max_reach
	var d := clampf(distance, min_reach, max_reach)

	var perp := pole_dir - dir * pole_dir.dot(dir)
	if perp.length_squared() < 1e-10:
		perp = dir.cross(Vector3.RIGHT)
		if perp.length_squared() < 1e-10:
			perp = dir.cross(Vector3.UP)
	perp = perp.normalized()

	var cos_root := clampf((upper_len * upper_len + d * d - lower_len * lower_len) / (2.0 * upper_len * d), -1.0, 1.0)
	var sin_root := sqrt(maxf(0.0, 1.0 - cos_root * cos_root))
	var offset := dir * (upper_len * cos_root) + perp * (upper_len * sin_root)
	if absf(swivel_rad) > 1e-9:
		offset = offset.rotated(dir, swivel_rad)
	var mid := root + offset
	var end := root + dir * d

	var cos_interior := clampf((upper_len * upper_len + lower_len * lower_len - d * d) / (2.0 * upper_len * lower_len), -1.0, 1.0)
	var flexion := 180.0 - rad_to_deg(acos(cos_interior))
	return {
		"mid": mid,
		"end": end,
		"reached": reached,
		"flexion_deg": flexion,
		"distance_error_m": maxf(0.0, distance - max_reach) + maxf(0.0, min_reach - distance),
	}
