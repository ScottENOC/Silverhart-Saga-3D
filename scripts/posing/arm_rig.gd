extends RefCounted
## Everything the arm solver needs to know about one character's arm, in plain data.
## Built from a Skeleton3D by arm_rig_builder.gd; tests build it by hand.
## All positions are in rig space (docs/posing/POSING_CONTRACT.md).

const JointLimitsScript := preload("res://scripts/posing/joint_limits.gd")

var side: StringName = &"right"
var shoulder := Vector3.ZERO      # upper-arm joint position
var upper_len := 0.30             # shoulder -> elbow
var fore_len := 0.26              # elbow -> wrist
var hand_len := 0.18              # wrist -> fingertip bone tip, straight
var frame_right := Vector3.RIGHT
var frame_up := Vector3.UP
var frame_forward := Vector3.FORWARD   # must equal frame_up.cross(frame_right)
var rest_pole := Vector3.DOWN     # preferred elbow direction (swivel 0)
var upper_radius := 0.04
var fore_radius := 0.035
var hand_radius := 0.03
var root_skip_m := 0.06           # shoulder sits inside the torso; ignore this much of the upper arm
var proxies: Array = []           # BodyProxy dictionaries for the rest of the body
var limits: RefCounted = JointLimitsScript.new()


func reach_m() -> float:
	return upper_len + fore_len
