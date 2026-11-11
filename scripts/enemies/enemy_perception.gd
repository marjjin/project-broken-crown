class_name EnemyPerception
extends Node
## Vision sensor: distance + horizontal field of view + line of sight.
## Checks run every `data.perception_interval` seconds, not every frame, and
## the raycast is only cast when the cheaper distance/angle tests pass.
##
## The target is found through the "player" group unless assigned explicitly.

signal target_spotted(target: Node3D)
signal target_lost(target: Node3D)

const TARGET_GROUP: StringName = &"player"
## Point on the target that must be visible (roughly the chest).
const TARGET_AIM_HEIGHT := 1.2

@export var body: EnemyCharacter
## Physics layers that block vision (the "world" layer by default).
@export_flags_3d_physics var occlusion_mask: int = 1
@export var target: Node3D

var _data: EnemyData
var _enabled := true
var _timer := 0.0
var _can_see := false
var _last_known_position := Vector3.ZERO
var _time_since_seen := INF


func _ready() -> void:
	# Children are ready before their parent, so read the exported data directly.
	if body == null or body.data == null:
		push_error("EnemyPerception '%s': 'body' (with EnemyData) is not assigned; perception disabled." % get_path())
		set_physics_process(false)
		return
	_data = body.data
	# Stagger the first check so many enemies do not raycast on the same frame.
	_timer = randf() * _data.perception_interval
	if target == null:
		_find_target.call_deferred()


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	set_physics_process(enabled)
	if not enabled and _can_see:
		_can_see = false
		target_lost.emit(target)


func can_see_target() -> bool:
	return _can_see


func has_target() -> bool:
	return is_instance_valid(target)


func get_last_known_position() -> Vector3:
	return _last_known_position


func get_time_since_seen() -> float:
	return _time_since_seen


## Called when the enemy learns where the target is without seeing it
## (e.g. it was hit from behind).
func notify_target_position(position: Vector3) -> void:
	_last_known_position = position
	_time_since_seen = 0.0


func forget_target() -> void:
	_time_since_seen = INF
	if _can_see:
		_can_see = false
		target_lost.emit(target)


func _physics_process(delta: float) -> void:
	if not _can_see:
		_time_since_seen += delta
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = _data.perception_interval
	var seen := _evaluate_visibility()
	if seen:
		_last_known_position = target.global_position
		_time_since_seen = 0.0
	if seen != _can_see:
		_can_see = seen
		if seen:
			target_spotted.emit(target)
		else:
			target_lost.emit(target)


func _evaluate_visibility() -> bool:
	if not _enabled or not is_instance_valid(target):
		return false
	var eye := body.global_position + Vector3.UP * _data.eye_height
	var aim := target.global_position + Vector3.UP * TARGET_AIM_HEIGHT
	var to_target := aim - eye
	var flat := Vector2(to_target.x, to_target.z)
	var distance := flat.length()
	if distance > _data.detection_radius:
		return false

	var within_proximity := _data.proximity_radius > 0.0 and distance <= _data.proximity_radius
	if not within_proximity and distance > 0.001:
		var facing := body.get_facing_direction()
		var cos_angle := Vector2(facing.x, facing.z).normalized().dot(flat / distance)
		if cos_angle < cos(deg_to_rad(_data.field_of_view_degrees * 0.5)):
			return false

	return _has_line_of_sight(eye, aim)


func _has_line_of_sight(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, occlusion_mask, [body.get_rid()])
	query.collide_with_areas = false
	return body.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _find_target() -> void:
	target = get_tree().get_first_node_in_group(TARGET_GROUP) as Node3D
	if target == null:
		push_warning("EnemyPerception '%s': no node in group '%s'; the enemy will never detect anyone." % [get_path(), TARGET_GROUP])
