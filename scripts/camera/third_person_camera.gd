class_name ThirdPersonCamera
extends Node3D
## Orbit camera rig: this node handles yaw, `pitch_pivot` handles pitch and a
## SpringArm3D pulls the camera in when geometry is between it and the target.
##
## The SpringArm3D only collides with the "world" physics layer, so it never
## hits the player capsule (which lives on its own layer).

@export var pitch_pivot: Node3D
@export var spring_arm: SpringArm3D
@export var camera: Camera3D

@export_group("Sensitivity")
## Radians per pixel of mouse motion.
@export_range(0.0001, 0.02, 0.0001) var mouse_sensitivity: float = 0.0025
## Radians per second at full right-stick deflection.
@export_range(0.1, 10.0, 0.1) var gamepad_sensitivity: float = 3.0
@export var invert_y: bool = false

@export_group("Limits")
@export_range(-89.0, 0.0, 1.0, "suffix:°") var min_pitch_degrees: float = -70.0
@export_range(0.0, 89.0, 1.0, "suffix:°") var max_pitch_degrees: float = 40.0


func _ready() -> void:
	if pitch_pivot == null or spring_arm == null or camera == null:
		push_error("ThirdPersonCamera: pitch_pivot, spring_arm and camera must be assigned; camera input disabled.")
		set_process(false)
		set_process_unhandled_input(false)
		return
	camera.make_current()
	_rotate_view(0.0, 0.0) # Clamp whatever initial pitch the scene defines.


func _unhandled_input(event: InputEvent) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	var motion := event as InputEventMouseMotion
	if motion == null:
		return
	_rotate_view(-motion.relative.x * mouse_sensitivity, -motion.relative.y * mouse_sensitivity * _y_sign())


func _process(delta: float) -> void:
	var look := Input.get_vector(
		InputActions.LOOK_LEFT, InputActions.LOOK_RIGHT,
		InputActions.LOOK_UP, InputActions.LOOK_DOWN)
	if look == Vector2.ZERO:
		return
	var step := gamepad_sensitivity * delta
	_rotate_view(-look.x * step, -look.y * step * _y_sign())


func _rotate_view(yaw_delta: float, pitch_delta: float) -> void:
	rotation.y = wrapf(rotation.y + yaw_delta, -PI, PI)
	pitch_pivot.rotation.x = clampf(
		pitch_pivot.rotation.x + pitch_delta,
		deg_to_rad(min_pitch_degrees),
		deg_to_rad(max_pitch_degrees))


func _y_sign() -> float:
	return -1.0 if invert_y else 1.0
