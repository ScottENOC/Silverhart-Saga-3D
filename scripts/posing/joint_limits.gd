extends RefCounted
## Anatomical limits for one arm chain. Angles in degrees.
## Defaults live in data/posing/arm_joint_limits.json; characters may override.

var elbow_flexion_min_deg := 0.0
var elbow_flexion_max_deg := 150.0
var shoulder_extension_max_deg := 60.0
var wrist_deviation_max_deg := 80.0


func apply_dict(data: Dictionary) -> RefCounted:
	elbow_flexion_min_deg = float(data.get("elbow_flexion_min_deg", elbow_flexion_min_deg))
	elbow_flexion_max_deg = float(data.get("elbow_flexion_max_deg", elbow_flexion_max_deg))
	shoulder_extension_max_deg = float(data.get("shoulder_extension_max_deg", shoulder_extension_max_deg))
	wrist_deviation_max_deg = float(data.get("wrist_deviation_max_deg", wrist_deviation_max_deg))
	return self


func load_json(path: String) -> bool:
	if not FileAccess.file_exists(path):
		push_error("JointLimits: missing file %s" % path)
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("JointLimits: %s is not a JSON object" % path)
		return false
	apply_dict(parsed)
	return true


## How far the upper arm points behind the coronal plane, in degrees (0 when at or in front of it).
## `upper_dir` is shoulder->elbow; `frame_forward` is the character's forward axis.
func shoulder_extension_deg(upper_dir: Vector3, frame_forward: Vector3) -> float:
	var behind := -upper_dir.normalized().dot(frame_forward.normalized())
	if behind <= 0.0:
		return 0.0
	return rad_to_deg(asin(clampf(behind, 0.0, 1.0)))


## Returns the names of violated limits (empty when the pose is allowed).
func violations(elbow_flexion_deg: float, shoulder_extension: float, wrist_deviation_deg: float) -> Array[String]:
	var result: Array[String] = []
	if elbow_flexion_deg < elbow_flexion_min_deg - 0.01 or elbow_flexion_deg > elbow_flexion_max_deg + 0.01:
		result.append("elbow_flexion")
	if shoulder_extension > shoulder_extension_max_deg + 0.01:
		result.append("shoulder_extension")
	if wrist_deviation_deg > wrist_deviation_max_deg + 0.01:
		result.append("wrist_deviation")
	return result
