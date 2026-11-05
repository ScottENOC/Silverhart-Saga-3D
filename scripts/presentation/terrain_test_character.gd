extends CharacterBody3D
## Lightweight physics proxy used to validate terrain grounding before production
## character scenes are ready. Replace the capsule mesh with a character scene later.

@export var tint: Color = Color(0.35, 0.62, 0.82)
@export var walks_across_ridge: bool = false
@export var walk_speed: float = 1.6

var walk_direction: float = 1.0
var gravity_strength: float = 18.0

func _ready() -> void:
	name = "TerrainTestCharacter"
	floor_snap_length = 0.4
	floor_max_angle = deg_to_rad(55.0)
	floor_stop_on_slope = true
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED

	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.7
	var collision := CollisionShape3D.new()
	collision.name = "CharacterCollision"
	collision.shape = capsule
	collision.position.y = 0.85
	add_child(collision)

	var mesh := CapsuleMesh.new()
	mesh.radius = 0.32
	mesh.height = 1.7
	var visual := MeshInstance3D.new()
	visual.name = "CapsuleProxy"
	visual.mesh = mesh
	visual.position.y = 0.85
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.78
	visual.material_override = material
	add_child(visual)

func _physics_process(delta: float) -> void:
	velocity.y -= gravity_strength * delta
	velocity.x = walk_direction * walk_speed if walks_across_ridge else 0.0
	velocity.z = 0.0
	move_and_slide()

	if is_on_floor() and velocity.y < 0.0:
		velocity.y = 0.0
	if walks_across_ridge and is_on_wall():
		walk_direction *= -1.0
