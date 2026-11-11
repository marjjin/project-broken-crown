class_name EnemyNavigator
extends NavigationAgent3D
## NavigationAgent3D with throttled path requests. Moving targets (the player)
## would otherwise trigger a new path query every frame; here a new query is
## only issued when the destination moved more than `repath_distance` and at
## most once every `repath_interval` seconds.
##
## Must be a direct child of the moving CharacterBody3D (the agent follows its
## parent's position).

@export_range(0.05, 10.0, 0.05, "suffix:m") var repath_distance: float = 0.75
@export_range(0.0, 5.0, 0.05, "suffix:s") var repath_interval: float = 0.3

var _requested_destination := Vector3.INF
var _cooldown_left := 0.0
var _parent_body: Node3D


func _ready() -> void:
	_parent_body = get_parent() as Node3D
	if _parent_body == null:
		push_error("EnemyNavigator '%s': must be a child of a Node3D." % get_path())


func _physics_process(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)


## False until the navigation map has synchronized at least once (first frames).
func is_map_ready() -> bool:
	return NavigationServer3D.map_get_iteration_id(get_navigation_map()) > 0


func request_destination(point: Vector3) -> void:
	var moved := _requested_destination.distance_to(point)
	if moved < repath_distance:
		return
	# A brand new destination is applied at once; a drifting one is throttled.
	if _cooldown_left > 0.0 and moved < repath_distance * 4.0:
		return
	target_position = point
	_requested_destination = point
	_cooldown_left = repath_interval


## Flat direction toward the next path corner, or ZERO when the path is done.
func get_next_direction() -> Vector3:
	if _parent_body == null or is_navigation_finished():
		return Vector3.ZERO
	var next := get_next_path_position() - _parent_body.global_position
	next.y = 0.0
	return next.normalized() if next.length_squared() > 0.0001 else Vector3.ZERO


## Drops the current destination so the next request is always applied.
func clear_destination() -> void:
	_requested_destination = Vector3.INF
	_cooldown_left = 0.0
	if _parent_body != null:
		target_position = _parent_body.global_position
