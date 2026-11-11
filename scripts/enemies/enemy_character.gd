class_name EnemyCharacter
extends CharacterBody3D
## Physical body of an enemy: gravity, acceleration, collisions and facing.
## It never decides *where* to go; the AI (EnemyBrain) calls the small API
## below. Like the player, the body never rotates; only `visual_root` turns.

@export var data: EnemyData
@export var visual_root: Node3D
@export var body_shape: CollisionShape3D

var _desired_velocity := Vector3.ZERO
var _face_direction := Vector3.ZERO


func _ready() -> void:
	if data == null:
		push_error("EnemyCharacter '%s': no EnemyData assigned; using defaults." % name)
		data = EnemyData.new()
	for message in data.validate():
		push_warning("EnemyCharacter '%s' (%s): %s" % [name, data.id, message])
	if visual_root == null:
		push_warning("EnemyCharacter '%s': 'visual_root' not assigned; it will not turn." % name)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	var horizontal := Vector3(velocity.x, 0.0, velocity.z) \
		.move_toward(_desired_velocity, data.acceleration * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	move_and_slide()
	_update_facing(delta)


## Walks along `direction` (flattened) at `speed`, facing where it goes.
func move_in_direction(direction: Vector3, speed: float) -> void:
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length_squared() < 0.0001:
		stop()
		return
	flat = flat.normalized()
	_desired_velocity = flat * speed
	_face_direction = flat


func stop() -> void:
	_desired_velocity = Vector3.ZERO


func face_point(point: Vector3) -> void:
	var flat := Vector3(point.x - global_position.x, 0.0, point.z - global_position.z)
	if flat.length_squared() > 0.0001:
		_face_direction = flat.normalized()


## Instantly faces a direction (spawning, tests, scripted moments).
func snap_facing(direction: Vector3) -> void:
	var flat := Vector3(direction.x, 0.0, direction.z)
	if visual_root == null or flat.length_squared() < 0.0001:
		return
	_face_direction = flat.normalized()
	visual_root.rotation.y = atan2(-flat.x, -flat.z)


func get_facing_direction() -> Vector3:
	if visual_root == null:
		return Vector3.FORWARD
	var forward := -visual_root.global_basis.z
	forward.y = 0.0
	return forward.normalized() if forward.length_squared() > 0.0001 else Vector3.FORWARD


func flat_distance_to(point: Vector3) -> float:
	return Vector2(point.x - global_position.x, point.z - global_position.z).length()


## Freezes the body for good (death): no movement, no collisions.
func deactivate() -> void:
	stop()
	velocity = Vector3.ZERO
	set_physics_process(false)
	if body_shape != null:
		body_shape.set_deferred("disabled", true)


func _update_facing(delta: float) -> void:
	if visual_root == null or _face_direction == Vector3.ZERO:
		return
	var target_yaw := atan2(-_face_direction.x, -_face_direction.z)
	var weight := 1.0 - exp(-data.rotation_speed * delta)
	visual_root.rotation.y = lerp_angle(visual_root.rotation.y, target_yaw, weight)
