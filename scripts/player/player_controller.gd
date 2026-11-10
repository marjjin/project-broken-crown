class_name PlayerController
extends CharacterBody3D
## Third-person character locomotion: camera-relative movement, sprint,
## optional jump, gravity and smooth facing.
##
## The body itself never rotates; only `visual_root` turns toward the movement
## direction. This keeps child nodes (like the camera rig) free from inheriting
## the character's facing, and keeps the collision capsule orientation stable.
##
## Other systems (combat) never touch velocity directly. They use the small
## public API below: disable player input, or override horizontal velocity.
## Gravity and move_and_slide() always run here, so collisions are respected.

## Below this height the player is returned to its spawn point.
const FALL_RESET_HEIGHT := -25.0

@export var settings: MovementSettings
## Node whose yaw defines "forward" for movement input (usually the camera rig).
@export var orientation_reference: Node3D
## Visual-only node rotated toward the movement direction.
@export var visual_root: Node3D

var _sprinting := false
var _spawn_transform: Transform3D
var _input_enabled := true
var _horizontal_override := Vector3.ZERO
var _override_active := false
## Camera-relative input direction of the last physics frame, even while input
## is disabled, so actions (attacks, dodges) can aim with it.
var _move_direction := Vector3.ZERO


func _ready() -> void:
	if settings == null:
		push_warning("PlayerController: no MovementSettings assigned; using defaults.")
		settings = MovementSettings.new()
	if orientation_reference == null:
		push_error("PlayerController: 'orientation_reference' is not assigned; movement falls back to world axes.")
	if visual_root == null:
		push_warning("PlayerController: 'visual_root' is not assigned; the character will not turn visually.")
	_spawn_transform = global_transform


func _physics_process(delta: float) -> void:
	var input := Input.get_vector(
		InputActions.MOVE_LEFT, InputActions.MOVE_RIGHT,
		InputActions.MOVE_FORWARD, InputActions.MOVE_BACK)
	_move_direction = _get_wish_direction(input)
	var wish_direction := _move_direction if _input_enabled else Vector3.ZERO
	var input_strength := minf(input.length(), 1.0) if _input_enabled else 0.0

	_sprinting = input_strength > 0.0 and Input.is_action_pressed(InputActions.SPRINT)

	_apply_gravity(delta)
	if _input_enabled:
		_try_jump()
	if _override_active:
		velocity.x = _horizontal_override.x
		velocity.z = _horizontal_override.z
	else:
		_update_horizontal_velocity(wish_direction, input_strength, delta)
	move_and_slide()
	_rotate_visual(wish_direction, delta)
	_reset_if_fallen()


func is_sprinting() -> bool:
	return _sprinting


## When disabled, movement input, jumping and turning are ignored; the body
## decelerates normally (unless a velocity override is active).
func set_input_enabled(enabled: bool) -> void:
	_input_enabled = enabled


func set_horizontal_override(horizontal_velocity: Vector3) -> void:
	_horizontal_override = horizontal_velocity
	_override_active = true


func clear_horizontal_override() -> void:
	_override_active = false


func get_move_direction() -> Vector3:
	return _move_direction


## Flat forward direction of the visual model (-Z of `visual_root`).
func get_facing_direction() -> Vector3:
	if visual_root == null:
		return Vector3.FORWARD
	var forward := -visual_root.global_basis.z
	forward.y = 0.0
	return forward.normalized() if forward.length_squared() > 0.0001 else Vector3.FORWARD


func face_toward(direction: Vector3) -> void:
	if visual_root == null or Vector2(direction.x, direction.z).length_squared() < 0.0001:
		return
	visual_root.rotation.y = atan2(-direction.x, -direction.z)


func respawn() -> void:
	global_transform = _spawn_transform
	velocity = Vector3.ZERO
	clear_horizontal_override()


func get_horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func _get_wish_direction(input: Vector2) -> Vector3:
	if input == Vector2.ZERO:
		return Vector3.ZERO
	var yaw := 0.0
	if is_instance_valid(orientation_reference):
		yaw = orientation_reference.global_rotation.y
	# Input forward is -Y, which maps to -Z (Godot's forward) once rotated by the camera yaw.
	return Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, yaw).normalized()


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		return
	# get_gravity() includes Area3D overrides, so future gravity zones just work.
	velocity += get_gravity() * settings.gravity_scale * delta
	velocity.y = maxf(velocity.y, -settings.max_fall_speed)


func _try_jump() -> void:
	if not settings.jump_enabled or not is_on_floor():
		return
	if not Input.is_action_just_pressed(InputActions.JUMP):
		return
	# v = sqrt(2 * g * h) reaches exactly `jump_height` under the scaled gravity.
	var gravity_strength := get_gravity().length() * settings.gravity_scale
	velocity.y = sqrt(2.0 * gravity_strength * settings.jump_height)


func _update_horizontal_velocity(wish_direction: Vector3, input_strength: float, delta: float) -> void:
	var target_speed := settings.sprint_speed if _sprinting else settings.walk_speed
	var target_velocity := wish_direction * target_speed * input_strength

	var rate := settings.acceleration if input_strength > 0.0 else settings.deceleration
	if not is_on_floor():
		rate *= settings.air_control

	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(target_velocity, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z


func _rotate_visual(wish_direction: Vector3, delta: float) -> void:
	if visual_root == null or wish_direction == Vector3.ZERO:
		return
	var target_yaw := atan2(-wish_direction.x, -wish_direction.z)
	# Exponential smoothing keeps the turn rate frame-rate independent.
	var weight := 1.0 - exp(-settings.rotation_speed * delta)
	visual_root.rotation.y = lerp_angle(visual_root.rotation.y, target_yaw, weight)


func _reset_if_fallen() -> void:
	if global_position.y >= FALL_RESET_HEIGHT:
		return
	push_warning("PlayerController: fell out of the level; resetting to spawn.")
	respawn()
