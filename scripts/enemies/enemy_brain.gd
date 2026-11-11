class_name EnemyBrain
extends Node
## Enemy decision making: a single enum state machine. Every transition goes
## through _change_state(), which is the only place that enforces the global
## rules (no leaving DEAD, enter side effects, the state_changed signal).
##
## The brain only *decides*. It delegates to:
##   EnemyCharacter   -> moving / facing
##   EnemyPerception  -> seeing the target
##   EnemyNavigator   -> paths around obstacles
##   EnemyMeleeAttack -> attack timing and hits (via the shared Hitbox pipeline)
##   HealthComponent  -> damage and death (the brain only reacts to its signals)

enum State { IDLE, PATROL, CHASE, ATTACK, RETURN, HURT, DEAD }

signal state_changed(previous: State, current: State)
signal patrol_point_reached(index: int)

const STATE_NAMES := {
	State.IDLE: "Idle",
	State.PATROL: "Patrol",
	State.CHASE: "Chase",
	State.ATTACK: "Attack",
	State.RETURN: "Return",
	State.HURT: "Hurt",
	State.DEAD: "Dead",
}
## The enemy must face the target within this angle before starting a swing.
const ATTACK_FACING_TOLERANCE_DEGREES := 25.0

@export var body: EnemyCharacter
@export var perception: EnemyPerception
@export var navigator: EnemyNavigator
@export var attack: EnemyMeleeAttack
@export var health: HealthComponent
@export var hurtbox: Hurtbox
@export var animator: ActionAnimator
## Node whose Node3D children (e.g. Marker3D) are the patrol points, in order.
## Optional: without it the enemy stays in Idle at its spawn point.
@export var patrol_route: Node3D

var _data: EnemyData
var _state := State.IDLE
var _state_time := 0.0
var _patrol_points := PackedVector3Array()
var _patrol_index := 0
var _home_position := Vector3.ZERO
var _chase_origin := Vector3.ZERO
## Time spent unable to make progress toward the current destination.
var _unreachable_time := 0.0
var _stagger_immunity_left := 0.0
var _target_health: HealthComponent


func _ready() -> void:
	var missing := PackedStringArray()
	for pair: Array in [["body", body], ["perception", perception], ["navigator", navigator],
			["attack", attack], ["health", health], ["hurtbox", hurtbox]]:
		if pair[1] == null:
			missing.append(pair[0])
	if not missing.is_empty():
		push_error("EnemyBrain '%s': missing %s; AI disabled." % [get_path(), ", ".join(missing)])
		set_physics_process(false)
		return
	_data = body.data if body.data != null else EnemyData.new()
	# EnemyData is the single source of truth for max health.
	health.set_max_health(_data.max_health)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	_home_position = body.global_position
	_collect_patrol_points()


# --- Public API -----------------------------------------------------------------

func get_state() -> State:
	return _state


func get_state_name() -> String:
	return STATE_NAMES[_state]


func get_patrol_points() -> PackedVector3Array:
	return _patrol_points


func get_patrol_index() -> int:
	return _patrol_index


func is_dead() -> bool:
	return _state == State.DEAD


## Back to a calm Idle (tests, future respawns). Does nothing once dead.
func reset_ai() -> void:
	if _state == State.DEAD:
		return
	attack.cancel()
	perception.forget_target()
	body.stop()
	navigator.clear_destination()
	_home_position = body.global_position
	_stagger_immunity_left = 0.0
	_change_state(State.IDLE)
	_state_time = 0.0


## Makes the next patrol leg head to `index` (wraps around the route).
func restart_patrol(index: int = 0) -> void:
	if not _patrol_points.is_empty():
		_patrol_index = posmod(index, _patrol_points.size())


# --- State machine --------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_state_time += delta
	_stagger_immunity_left = maxf(_stagger_immunity_left - delta, 0.0)
	match _state:
		State.IDLE:
			_tick_idle()
		State.PATROL:
			_tick_patrol(delta)
		State.CHASE:
			_tick_chase(delta)
		State.ATTACK:
			_tick_attack()
		State.RETURN:
			_tick_return(delta)
		State.HURT:
			_tick_hurt()


func _change_state(new_state: State) -> void:
	if _state == State.DEAD or new_state == _state:
		return
	var previous := _state
	_state = new_state
	_state_time = 0.0
	_unreachable_time = 0.0
	navigator.clear_destination()
	_on_enter_state(new_state, previous)
	state_changed.emit(previous, new_state)


func _on_enter_state(state: State, previous: State) -> void:
	match state:
		State.CHASE:
			# The leash is measured from where the chase started, not from
			# re-entries after attacking or being hurt.
			if previous in [State.IDLE, State.PATROL, State.RETURN]:
				_chase_origin = body.global_position
		State.IDLE, State.ATTACK, State.HURT:
			body.stop()
		State.DEAD:
			_shut_down()


func _tick_idle() -> void:
	body.stop()
	if _should_engage():
		_change_state(State.CHASE)
	elif not _patrol_points.is_empty() and _state_time >= _data.patrol_wait_time:
		_change_state(State.PATROL)


func _tick_patrol(delta: float) -> void:
	if _should_engage():
		_change_state(State.CHASE)
		return
	var arrived := _travel_to(_patrol_points[_patrol_index], _data.patrol_speed, delta)
	if arrived or _unreachable_time > _data.unreachable_give_up_time:
		if arrived:
			patrol_point_reached.emit(_patrol_index)
		else:
			push_warning("EnemyBrain '%s': patrol point %d %s unreachable from %s; skipping it." % [
				get_path(), _patrol_index, _patrol_points[_patrol_index], body.global_position])
		_patrol_index = (_patrol_index + 1) % _patrol_points.size()
		_change_state(State.IDLE) # Idle doubles as the wait at each point.


func _tick_chase(delta: float) -> void:
	if _should_give_up_chase():
		_change_state(State.RETURN)
		return
	var sees := perception.can_see_target()
	# Without sight, only the last known position is used (no wall-hacks).
	var goal := perception.target.global_position if sees else perception.get_last_known_position()

	if sees and body.flat_distance_to(goal) <= _data.attack_range:
		body.stop()
		body.face_point(goal)
		if _is_facing(goal) and attack.start(perception.target):
			_change_state(State.ATTACK)
		return

	_travel_to(goal, _data.chase_speed, delta)
	if _unreachable_time > 0.0 and sees:
		# Visible but unreachable (e.g. on a ledge): wait at the edge watching,
		# instead of flip-flopping between Chase and Return.
		body.face_point(goal)
	elif _unreachable_time > _data.unreachable_give_up_time:
		_change_state(State.RETURN)


func _tick_attack() -> void:
	body.stop()
	if not attack.is_attacking():
		_change_state(State.CHASE)


func _tick_hurt() -> void:
	body.stop()
	if _state_time >= _data.hurt_duration:
		# A hit always reveals the attacker, so resume the fight.
		_change_state(State.CHASE)


func _tick_return(delta: float) -> void:
	var home := _get_return_point()
	# Re-engage only near home, otherwise the leash would make it ping-pong.
	if _should_engage() and body.flat_distance_to(home) < _data.leash_distance * 0.5:
		_change_state(State.CHASE)
		return
	var arrived := _travel_to(home, _data.patrol_speed, delta)
	if not arrived and _unreachable_time > _data.unreachable_give_up_time:
		# Cannot get home: settle here rather than pushing against a wall forever.
		push_warning("EnemyBrain '%s': home unreachable; staying at current position." % get_path())
		_home_position = body.global_position
		arrived = true
	if arrived:
		_change_state(State.IDLE)


# --- Damage and death -------------------------------------------------------------

func _on_damaged(info: DamageInfo) -> void:
	if _state == State.DEAD or health.is_dead():
		return # The died signal handles lethal hits.
	_aggro_on(info.source)
	if _can_be_interrupted(info):
		attack.cancel()
		_stagger_immunity_left = _data.stagger_immunity_time
		if animator != null:
			animator.play_hit(true)
		if _state == State.HURT:
			_state_time = 0.0 # Restart the reaction (only reachable with immunity 0).
		_change_state(State.HURT)
	else:
		if animator != null:
			animator.play_hit(false)
		if _state in [State.IDLE, State.PATROL, State.RETURN]:
			_change_state(State.CHASE)


func _on_died() -> void:
	_change_state(State.DEAD)


func _can_be_interrupted(info: DamageInfo) -> bool:
	if not _data.can_be_staggered or info.amount < _data.stagger_damage_threshold:
		return false
	if _stagger_immunity_left > 0.0:
		return false
	return not (_state == State.ATTACK and _data.armored_while_attacking)


## Being hit reveals where the attacker is, even from behind or out of sight.
func _aggro_on(source: Node) -> void:
	var source_3d := source as Node3D
	if source_3d != null and source_3d == perception.target:
		perception.notify_target_position(source_3d.global_position)


## Turns everything off for good: no navigation, perception, hits or attacks.
func _shut_down() -> void:
	attack.cancel()
	navigator.clear_destination()
	perception.set_enabled(false)
	hurtbox.set_enabled(false)
	body.deactivate()
	if animator != null:
		animator.play_death()
	set_physics_process(false)
	if _data.corpse_duration > 0.0:
		get_tree().create_timer(_data.corpse_duration).timeout.connect(body.queue_free)


# --- Decisions ------------------------------------------------------------------

func _should_engage() -> bool:
	# Sight is sampled every perception_interval; the distance check is always
	# current. Requiring both, with lose_target_distance > detection_radius,
	# gives hysteresis so a stale "seen" can never undo a give-up decision.
	return perception.can_see_target() and _is_target_alive() \
		and body.flat_distance_to(perception.target.global_position) <= _data.detection_radius


func _should_give_up_chase() -> bool:
	if not perception.has_target() or not _is_target_alive():
		return true
	if not perception.can_see_target() and perception.get_time_since_seen() > _data.lose_sight_time:
		return true
	if body.flat_distance_to(perception.target.global_position) > _data.lose_target_distance:
		return true
	return body.flat_distance_to(_chase_origin) > _data.leash_distance


func _is_target_alive() -> bool:
	if not perception.has_target():
		return false
	if _target_health == null or not is_instance_valid(_target_health):
		_target_health = HealthComponent.find_in(perception.target)
	# Targets without health (none today) are treated as alive.
	return _target_health == null or not _target_health.is_dead()


func _is_facing(point: Vector3) -> bool:
	var to_point := Vector3(point.x - body.global_position.x, 0.0, point.z - body.global_position.z)
	if to_point.length_squared() < 0.0001:
		return true
	var cos_angle := body.get_facing_direction().dot(to_point.normalized())
	return cos_angle >= cos(deg_to_rad(ATTACK_FACING_TOLERANCE_DEGREES))


# --- Movement helpers -----------------------------------------------------------

## Follows the navigation path toward `point`; returns true once within the
## arrival tolerance. Accumulates `_unreachable_time` while no progress is
## possible (no path, path ends short of the goal) so callers can give up.
func _travel_to(point: Vector3, speed: float, delta: float) -> bool:
	if body.flat_distance_to(point) <= _data.arrival_tolerance:
		body.stop()
		_unreachable_time = 0.0
		return true
	if not navigator.is_map_ready():
		body.stop()
		return false
	navigator.request_destination(point)
	var direction := navigator.get_next_direction()
	var reachable := navigator.is_target_reachable()
	if direction == Vector3.ZERO and navigator.is_navigation_finished() and reachable:
		# The agent's path ends within its (3D) target distance; finish the
		# last stretch in a straight line, which the navmesh says is walkable.
		direction = point - body.global_position
	if direction == Vector3.ZERO:
		body.stop()
		_unreachable_time += delta
	else:
		body.move_in_direction(direction, speed)
		_unreachable_time = _unreachable_time + delta if not reachable else 0.0
	return false


func _get_return_point() -> Vector3:
	return _home_position if _patrol_points.is_empty() else _patrol_points[_patrol_index]


func _collect_patrol_points() -> void:
	_patrol_points.clear()
	if patrol_route == null:
		return
	for child in patrol_route.get_children():
		var marker := child as Node3D
		if marker != null:
			_patrol_points.append(marker.global_position)
	if _patrol_points.is_empty():
		push_warning("EnemyBrain '%s': patrol_route has no Node3D children; staying in Idle." % get_path())
