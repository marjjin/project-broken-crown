extends SceneTree
## Headless integration tests for the Corrupted Soldier AI (phase 3), run
## against the real test arena:
##   godot --headless --path . --script res://tests/enemy_tests.gd
## Exit code is the number of failed checks (0 = all passed).

const PHYSICS_HZ := 60.0
const ARENA := "res://scenes/test/enemy_test_arena.tscn"
const SOLDIER := "res://scenes/enemies/corrupted_soldier.tscn"

var _failures := 0
var _checks := 0
var _arena: Node
var _player: PlayerController
var _soldier: EnemyCharacter
var _brain: EnemyBrain
var _perception: EnemyPerception
var _attack: EnemyMeleeAttack
var _soldier_health: HealthComponent
var _player_health: HealthComponent
var _player_actions: PlayerActionController


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_arena = (load(ARENA) as PackedScene).instantiate()
	root.add_child(_arena)
	await _frames(20)
	_player = _arena.get_node("Player") as PlayerController
	_soldier = _arena.get_node("CorruptedSoldier") as EnemyCharacter
	_brain = _soldier.get_node("Brain") as EnemyBrain
	_perception = _soldier.get_node("Perception") as EnemyPerception
	# Keep the console clean during tests.
	(_soldier.get_node("DebugView") as EnemyDebugView).log_transitions = false

	# Stage 1: patrol and detection.
	_test_spawn()
	await _test_patrol_between_points()
	await _test_detects_in_field_of_view()
	await _test_no_detection_through_walls()
	await _test_no_detection_behind_back()
	await _test_proximity_detection()
	await _test_idle_without_patrol_points()

	# Stage 2: chase and navigation.
	await _test_navigates_around_walls()
	await _test_chase_closes_distance()
	await _test_gives_up_and_returns_to_patrol()
	await _test_unreachable_target_does_not_lock_ai()

	# Stage 3: combat, damage and death.
	_player_health = HealthComponent.find_in(_player)
	_player_actions = _player.get_node("ActionController") as PlayerActionController
	_attack = _soldier.get_node("MeleeAttack") as EnemyMeleeAttack
	_soldier_health = _soldier.get_node("HealthComponent") as HealthComponent
	await _test_attacks_player_in_range()
	await _test_no_hit_out_of_reach()
	await _test_no_attack_through_walls()
	await _test_dodge_avoids_enemy_hit()
	await _test_enemy_takes_player_damage()
	await _test_hit_interrupts_enemy_attack()
	await _test_stops_when_player_dies()
	await _test_enemy_death()

	print("\n%d/%d checks passed" % [_checks - _failures, _checks])
	quit(_failures)


# --- Stage 1 ------------------------------------------------------------------

func _test_spawn() -> void:
	print("\n[spawn]")
	_check(is_instance_valid(_soldier) and _soldier.is_inside_tree(), "soldier is in the arena")
	_check(_soldier.data != null and _soldier.data.id == &"corrupted_soldier", "soldier uses the Corrupted Soldier data")
	_check(_brain.get_patrol_points().size() == 4, "four patrol points collected from the route")
	_check(_perception.target == _player, "perception found the player through the 'player' group")


func _test_patrol_between_points() -> void:
	print("\n[patrol]")
	_hide_player()
	await _place_soldier(_brain.get_patrol_points()[0], Vector3.FORWARD)
	var reached: Array[int] = []
	var on_reached := func(index: int) -> void: reached.append(index)
	_brain.patrol_point_reached.connect(on_reached)
	var saw_patrol := false
	var frames := int(16.0 * PHYSICS_HZ)
	while reached.size() < 2 and frames > 0:
		await physics_frame
		saw_patrol = saw_patrol or _brain.get_state() == EnemyBrain.State.PATROL
		frames -= 1
	_brain.patrol_point_reached.disconnect(on_reached)
	_check(saw_patrol, "soldier enters Patrol after waiting")
	_check(reached.size() >= 2, "soldier walks between patrol points (reached %s)" % [reached])
	_check(reached.size() >= 2 and reached[1] == (reached[0] + 1) % 4, "points are visited in order")


func _test_detects_in_field_of_view() -> void:
	print("\n[detection: field of view]")
	# Soldier faces +Z toward the player, 5 m away, nothing in between.
	await _setup(Vector3(0, 0.1, -6), Vector3.BACK, Vector3(0, 0.1, -1))
	await _seconds(0.4)
	_check(_perception.can_see_target(), "player in front and in range is seen")
	_check(_brain.get_state() == EnemyBrain.State.CHASE, "seeing the player switches to Chase")


func _test_no_detection_through_walls() -> void:
	print("\n[detection: walls]")
	# CoverWall spans z 1.6..2.4 between them; distance 8 m, inside the FOV.
	await _setup(Vector3(0, 0.1, -2), Vector3.BACK, Vector3(0, 0.1, 6))
	var ever_seen := false
	for i in int(1.0 * PHYSICS_HZ):
		await physics_frame
		ever_seen = ever_seen or _perception.can_see_target()
	_check(not ever_seen, "player behind a wall is never seen")
	_check(_brain.get_state() == EnemyBrain.State.IDLE, "soldier stays calm (%s)" % _brain.get_state_name())


func _test_no_detection_behind_back() -> void:
	print("\n[detection: behind]")
	# Soldier faces -Z; player 5 m behind it (outside FOV and proximity).
	await _setup(Vector3(0, 0.1, -6), Vector3.FORWARD, Vector3(0, 0.1, -1))
	await _seconds(0.6)
	_check(not _perception.can_see_target(), "player behind the soldier is not seen")


func _test_proximity_detection() -> void:
	print("\n[detection: proximity]")
	await _setup(Vector3(0, 0.1, -6), Vector3.FORWARD, Vector3(0, 0.1, -4.6))
	await _seconds(0.4)
	_check(_perception.can_see_target(), "player very close behind is noticed (proximity %.1f m)" % _soldier.data.proximity_radius)


func _test_idle_without_patrol_points() -> void:
	print("\n[no patrol route]")
	_hide_player()
	var lone := (load(SOLDIER) as PackedScene).instantiate() as EnemyCharacter
	lone.name = "LoneSoldier"
	_arena.add_child(lone)
	lone.global_position = Vector3(-15, 0.1, 15)
	await _frames(2)
	var lone_brain := lone.get_node("Brain") as EnemyBrain
	(lone.get_node("DebugView") as EnemyDebugView).log_transitions = false
	var start := lone.global_position
	await _seconds(_soldier.data.patrol_wait_time + 1.0)
	_check(lone_brain.get_state() == EnemyBrain.State.IDLE, "without patrol points the soldier stays Idle")
	_check(lone.flat_distance_to(start) < 0.1, "and does not wander")
	lone.queue_free()
	await _frames(2)


# --- Stage 2 ------------------------------------------------------------------

func _test_navigates_around_walls() -> void:
	print("\n[navigation around walls]")
	_hide_player()
	# South of CoverWall (x -5..5, z 1.6..2.4); P4 (-8, 0, -4) is north of it:
	# the straight line crosses the wall, so only a real path gets there.
	await _place_soldier(Vector3(0, 0.1, 6), Vector3.FORWARD)
	_brain.restart_patrol(3)
	var max_corners := 0
	var entered_wall := false
	# Lambdas capture locals by value, so the flag lives in an Array.
	var reached_flag := [false]
	var on_reached := func(index: int) -> void: reached_flag[0] = reached_flag[0] or index == 3
	_brain.patrol_point_reached.connect(on_reached)
	var frames := int(20.0 * PHYSICS_HZ)
	while not reached_flag[0] and frames > 0:
		await physics_frame
		frames -= 1
		max_corners = maxi(max_corners, _navigator().get_current_navigation_path().size())
		var p := _soldier.global_position
		entered_wall = entered_wall or (absf(p.x) < 5.0 and p.z > 1.6 and p.z < 2.4)
	_brain.patrol_point_reached.disconnect(on_reached)
	var reached: bool = reached_flag[0]
	_check(reached, "soldier reaches a patrol point behind a wall (state %s, at %s, next point %d)" % [_brain.get_state_name(), _soldier.global_position.snapped(Vector3.ONE * 0.1), _brain.get_patrol_index()])
	_check(max_corners >= 3, "the route bends around the wall (%d path points)" % max_corners)
	_check(not entered_wall, "soldier never overlaps the wall")


func _test_chase_closes_distance() -> void:
	print("\n[chase]")
	await _setup(Vector3(0, 0.1, -12), Vector3.BACK, Vector3(0, 0.1, -3))
	var start_distance := _soldier.flat_distance_to(_player.global_position)
	var frames := int(4.0 * PHYSICS_HZ)
	while _soldier.flat_distance_to(_player.global_position) > _soldier.data.attack_range + 0.2 and frames > 0:
		await physics_frame
		frames -= 1
	var end_distance := _soldier.flat_distance_to(_player.global_position)
	_check(_brain.get_state() == EnemyBrain.State.CHASE, "soldier is chasing")
	_check(end_distance <= _soldier.data.attack_range + 0.2, "soldier closes from %.1f m to attack range (%.2f m)" % [start_distance, end_distance])
	await _seconds(0.5)
	_check(_soldier.flat_distance_to(_player.global_position) > 0.7, "soldier stops at attack range instead of pushing into the player")


func _test_gives_up_and_returns_to_patrol() -> void:
	print("\n[give up / return]")
	# Continues from the chase above: the player vanishes behind the wall.
	_hide_player()
	var frames := int((_soldier.data.lose_sight_time + 1.5) * PHYSICS_HZ)
	while _brain.get_state() != EnemyBrain.State.RETURN and frames > 0:
		await physics_frame
		frames -= 1
	_check(_brain.get_state() == EnemyBrain.State.RETURN, "soldier gives up the chase after losing sight")
	# Once returning, it must not bounce back into Chase on stale sight data.
	var re_chases := [0]
	var on_changed := func(_a: EnemyBrain.State, b: EnemyBrain.State) -> void:
		if b == EnemyBrain.State.CHASE:
			re_chases[0] += 1
	_brain.state_changed.connect(on_changed)
	await _seconds(0.5)
	_brain.state_changed.disconnect(on_changed)
	_check(re_chases[0] == 0 and _brain.get_state() == EnemyBrain.State.RETURN, "giving up is stable: no Return/Chase flip-flop (%d re-chases)" % re_chases[0])
	frames = int(20.0 * PHYSICS_HZ)
	while _brain.get_state() == EnemyBrain.State.RETURN and frames > 0:
		await physics_frame
		frames -= 1
	var near_route := false
	for point in _brain.get_patrol_points():
		near_route = near_route or _soldier.flat_distance_to(point) <= _soldier.data.arrival_tolerance + 0.3
	_check(_brain.get_state() in [EnemyBrain.State.IDLE, EnemyBrain.State.PATROL], "soldier goes back to its routine (%s)" % _brain.get_state_name())
	_check(near_route, "soldier is back on its patrol route")


func _test_unreachable_target_does_not_lock_ai() -> void:
	print("\n[unreachable target]")
	# LedgePlatform: 0.9 m high, the player can jump on it, the soldier cannot climb it.
	await _setup(Vector3(-14, 0.1, -7), Vector3.FORWARD, Vector3(-14, 0.95, -14))
	var transitions := [0]
	var on_changed := func(_a: EnemyBrain.State, _b: EnemyBrain.State) -> void: transitions[0] += 1
	_brain.state_changed.connect(on_changed)
	await _seconds(4.0)
	_check(_brain.get_state() == EnemyBrain.State.CHASE, "soldier keeps watching a visible but unreachable player")
	_check(transitions[0] <= 1, "no Chase/Return flip-flopping (%d transitions)" % transitions[0])
	_check(_soldier.global_position.y < 0.5, "soldier did not climb the ledge")
	_check(Vector2(_soldier.velocity.x, _soldier.velocity.z).length() < 0.3, "soldier waits at the edge instead of pushing")
	_hide_player()
	var frames := int((_soldier.data.lose_sight_time + 1.5) * PHYSICS_HZ)
	while _brain.get_state() == EnemyBrain.State.CHASE and frames > 0:
		await physics_frame
		frames -= 1
	_brain.state_changed.disconnect(on_changed)
	_check(_brain.get_state() == EnemyBrain.State.RETURN, "after losing sight it returns instead of getting stuck")


# --- Stage 3 ------------------------------------------------------------------

## Soldier at z = -6 facing +Z, player 1.5 m in front of it, facing it.
func _setup_duel() -> void:
	await _ready_player()
	await _setup(Vector3(0, 0.1, -6), Vector3.BACK, Vector3(0, 0.1, -4.5))
	_player.face_toward(Vector3.FORWARD)


func _test_attacks_player_in_range() -> void:
	print("\n[enemy attack]")
	await _setup_duel()
	var hp := _player_health.get_current()
	var saw_attack := false
	var frames := int(3.0 * PHYSICS_HZ)
	while _player_health.get_current() == hp and frames > 0:
		await physics_frame
		saw_attack = saw_attack or _brain.get_state() == EnemyBrain.State.ATTACK
		frames -= 1
	_check(saw_attack, "soldier enters Attack with the player in range")
	_check_near(hp - _player_health.get_current(), _soldier.data.attack_damage, "one swing deals its damage exactly once")
	await _wait_attack_end()


func _test_no_hit_out_of_reach() -> void:
	print("\n[out of reach]")
	await _setup_duel()
	await _wait_attack_start()
	# Step well outside the weapon reach during the windup.
	_player.global_position = Vector3(0, 0.1, -1.5)
	var hp := _player_health.get_current()
	await _wait_attack_end()
	_check_near(_player_health.get_current(), hp, "a swing does not hit a player 4.5 m away")


func _test_no_attack_through_walls() -> void:
	print("\n[attack vs walls]")
	await _ready_player()
	# CoverWall (z 1.6..2.4) between them; the player is inside the hitbox volume.
	await _setup(Vector3(0, 0.1, 1.0), Vector3.BACK, Vector3(0, 0.1, 3.0))
	var hp := _player_health.get_current()
	var attacked := false
	for i in int(2.0 * PHYSICS_HZ):
		await physics_frame
		attacked = attacked or _brain.get_state() == EnemyBrain.State.ATTACK
	_check(not attacked, "soldier does not start attacks without line of sight")
	# Force a swing anyway: the hit-time line check must still block it.
	while not _attack.can_start():
		await physics_frame
	_attack.start(_player)
	await _wait_attack_end()
	_check_near(_player_health.get_current(), hp, "a forced swing through the wall deals no damage")


func _test_dodge_avoids_enemy_hit() -> void:
	print("\n[dodge vs enemy]")
	await _setup_duel()
	var prevented := [0]
	var on_prevented := func(_info: DamageInfo) -> void: prevented[0] += 1
	_player_health.damage_prevented.connect(on_prevented)
	# Roll *into* the soldier so only the i-frames (not distance) can save the player.
	Input.action_press(InputActions.MOVE_FORWARD)
	await _wait_attack_start()
	var hp := _player_health.get_current()
	await _seconds(_soldier.data.attack_windup - 0.08)
	_check(_player_actions.request_action(PlayerActionController.Action.DODGE), "player dodges right before the active window")
	await _wait_attack_end()
	Input.action_release(InputActions.MOVE_FORWARD)
	_player_health.damage_prevented.disconnect(on_prevented)
	_check(prevented[0] >= 1, "the enemy hit landed during i-frames and was prevented")
	_check_near(_player_health.get_current(), hp, "player takes no damage")


func _test_enemy_takes_player_damage() -> void:
	print("\n[enemy takes damage]")
	await _setup_duel()
	_soldier_health.revive()
	var hp := _soldier_health.get_current()
	var hurt := [false]
	var on_changed := func(_a: EnemyBrain.State, b: EnemyBrain.State) -> void: hurt[0] = hurt[0] or b == EnemyBrain.State.HURT
	_brain.state_changed.connect(on_changed)
	_player_actions.request_action(PlayerActionController.Action.LIGHT_ATTACK)
	await _wait_player_locomotion()
	_check_near(hp - _soldier_health.get_current(), 12.0, "a light attack removes 12 HP")
	_check(hurt[0], "the hit staggers the soldier (Hurt)")
	_brain.state_changed.disconnect(on_changed)
	hp = _soldier_health.get_current()
	_player_actions.request_action(PlayerActionController.Action.HEAVY_ATTACK)
	await _wait_player_locomotion()
	_check_near(hp - _soldier_health.get_current(), 30.0, "a heavy attack removes 30 HP")


func _test_hit_interrupts_enemy_attack() -> void:
	print("\n[interrupt]")
	await _setup_duel()
	_soldier_health.revive()
	await _wait_attack_start()
	var hp := _player_health.get_current()
	# Player light hit lands ~0.14 s later, well before the 0.6 s windup ends.
	_player_actions.request_action(PlayerActionController.Action.LIGHT_ATTACK)
	await _seconds(0.25)
	_check(_brain.get_state() == EnemyBrain.State.HURT, "soldier is staggered mid-windup")
	_check(not _attack.is_attacking(), "its attack was cancelled")
	await _seconds(0.6)
	_check_near(_player_health.get_current(), hp, "the cancelled swing never deals damage")


func _test_stops_when_player_dies() -> void:
	print("\n[player death]")
	await _setup_duel()
	_player_health.apply_damage(DamageInfo.new(1000.0))
	await _seconds(1.0)
	_check(_brain.get_state() == EnemyBrain.State.RETURN, "soldier stops fighting a dead player (%s)" % _brain.get_state_name())
	# Wait for the player's respawn before continuing.
	await _wait_player_locomotion(6.0)


func _test_enemy_death() -> void:
	print("\n[enemy death]")
	await _setup_duel()
	_soldier.get_node("Hurtbox").receive_hit(DamageInfo.new(1000.0, _player))
	await _frames(3)
	_check(_brain.get_state() == EnemyBrain.State.DEAD, "lethal damage kills the soldier")
	_check(not _attack.is_attacking() and not _brain.is_physics_processing(), "AI and attacks stop")
	_check(not _perception.is_physics_processing() and not _perception.can_see_target(), "perception is disabled")
	_check(not (_soldier.get_node("Hurtbox") as Hurtbox).can_be_hit(), "the corpse cannot be hit again")
	_check((_soldier.get_node("CollisionShape3D") as CollisionShape3D).disabled, "the corpse no longer blocks movement")
	var hp := _player_health.get_current()
	await _seconds(2.5)
	_check_near(_player_health.get_current(), hp, "a dead soldier never damages the player")
	await _seconds(_soldier.data.corpse_duration)
	_check(not is_instance_valid(_soldier), "the corpse is removed after corpse_duration")


func _ready_player() -> void:
	await _wait_player_locomotion()
	_player_health.revive()
	(_player.get_node("StaminaComponent") as StaminaComponent).refill()


func _wait_player_locomotion(max_seconds: float = 3.0) -> void:
	var frames := int(max_seconds * PHYSICS_HZ)
	while _player_actions.get_state() != PlayerActionController.State.LOCOMOTION and frames > 0:
		await physics_frame
		frames -= 1


func _wait_attack_start(max_seconds: float = 4.0) -> void:
	var frames := int(max_seconds * PHYSICS_HZ)
	while _attack.get_phase() != EnemyMeleeAttack.Phase.WINDUP and frames > 0:
		await physics_frame
		frames -= 1


func _wait_attack_end(max_seconds: float = 3.0) -> void:
	var frames := int(max_seconds * PHYSICS_HZ)
	while _attack.is_attacking() and frames > 0:
		await physics_frame
		frames -= 1


func _check_near(actual: float, expected: float, label: String) -> void:
	_check(absf(actual - expected) < 0.01, "%s (got %.2f, expected %.2f)" % [label, actual, expected])


# --- Helpers ------------------------------------------------------------------

func _navigator() -> EnemyNavigator:
	return _soldier.get_node("Navigator") as EnemyNavigator


func _place_soldier(position: Vector3, facing: Vector3) -> void:
	_soldier.global_position = position
	_soldier.velocity = Vector3.ZERO
	_soldier.snap_facing(facing)
	_brain.reset_ai()
	await _frames(3)


## Places both actors on the same frame, then resets the AI, so perception
## never samples a half-finished setup.
func _setup(soldier_position: Vector3, facing: Vector3, player_position: Vector3) -> void:
	_player.global_position = player_position
	_player.velocity = Vector3.ZERO
	_soldier.global_position = soldier_position
	_soldier.velocity = Vector3.ZERO
	_soldier.snap_facing(facing)
	_brain.reset_ai()
	await _frames(3)


func _place_player(position: Vector3) -> void:
	_player.global_position = position
	_player.velocity = Vector3.ZERO
	await _frames(3)


## Far away behind the cover wall, out of every detection radius.
func _hide_player() -> void:
	_player.global_position = Vector3(0, 0.1, 18)
	_player.velocity = Vector3.ZERO


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _seconds(seconds: float) -> void:
	await _frames(ceili(seconds * PHYSICS_HZ))


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("  PASS  ", label)
	else:
		_failures += 1
		print("  FAIL  ", label)
