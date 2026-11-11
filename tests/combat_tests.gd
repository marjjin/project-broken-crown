extends SceneTree
## Headless integration tests for phase 2 combat, run against the real level:
##   godot --headless --path . --script res://tests/combat_tests.gd
## Exit code is the number of failed checks (0 = all passed).

const PHYSICS_HZ := 60.0

var _failures := 0
var _checks := 0
var _main: Node
var _player: PlayerController
var _actions: PlayerActionController
var _health: HealthComponent
var _stamina: StaminaComponent
var _dummy: TrainingDummy
var _weapon: WeaponData
var _settings: PlayerActionSettings
var _combat_hud: CombatHud


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_main = (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	await _frames(30)

	_player = _main.get_node("Player") as PlayerController
	_actions = _player.get_node("ActionController") as PlayerActionController
	_health = _player.get_node("HealthComponent") as HealthComponent
	_stamina = _player.get_node("StaminaComponent") as StaminaComponent
	_dummy = _main.get_node("Level/CombatArea/DummyFront") as TrainingDummy
	_combat_hud = _main.get_node("CombatHUD") as CombatHud
	_weapon = _actions.weapon
	_settings = _actions.settings

	await _test_movement_still_works()
	await _test_light_attack_hits_once()
	await _test_combo_three_hits()
	await _test_combo_window_rules()
	await _test_heavy_attack_consumes_stamina()
	await _test_heavy_blocked_without_stamina()
	await _test_actions_blocked_while_committed()
	await _test_move_while_attacking()
	await _test_dodge_stamina_and_invulnerability()
	await _test_dodge_respects_walls()
	await _test_dummy_dies_and_respawns()
	await _test_player_stagger_and_respawn()
	await _test_trap_damages_player()
	await _test_real_input_events()
	_test_hud_bars_follow_signals()

	print("\n%d/%d checks passed" % [_checks - _failures, _checks])
	quit(_failures)


# --- Tests --------------------------------------------------------------------

func _test_movement_still_works() -> void:
	print("\n[movement]")
	await _place_player(Vector3(0, 0.05, 10), Vector3.FORWARD)
	var start := _player.global_position
	Input.action_press(InputActions.MOVE_FORWARD)
	await _seconds(0.5)
	Input.action_release(InputActions.MOVE_FORWARD)
	_check(start.z - _player.global_position.z > 1.0, "W moves the player forward (-Z)")
	await _seconds(0.4)
	_check(_player.get_horizontal_speed() < 0.1, "player decelerates to a stop")

	# Camera-facing mode: S walks backwards and A strafes, without turning around.
	start = _player.global_position
	Input.action_press(InputActions.MOVE_BACK)
	await _seconds(0.5)
	Input.action_release(InputActions.MOVE_BACK)
	_check(_player.global_position.z - start.z > 1.0, "S moves the player backwards (+Z)")
	_check(_player.get_facing_direction().dot(Vector3.FORWARD) > 0.99, "and the character keeps facing the camera direction")
	start = _player.global_position
	Input.action_press(InputActions.MOVE_LEFT)
	await _seconds(0.5)
	Input.action_release(InputActions.MOVE_LEFT)
	_check(start.x - _player.global_position.x > 1.0, "A strafes left (-X)")
	_check(_player.get_facing_direction().dot(Vector3.FORWARD) > 0.99, "while still facing forward")
	await _seconds(0.4)


func _test_light_attack_hits_once() -> void:
	print("\n[light attack]")
	await _reset_for_dummy_test()
	var before := _dummy.health.get_current()
	_check(_actions.request_action(PlayerActionController.Action.LIGHT_ATTACK), "light attack starts from locomotion")
	_check(_stamina.get_current() == _stamina.max_stamina, "light attack costs no stamina")
	await _wait_for_locomotion()
	_check_near(before - _dummy.health.get_current(), _weapon.get_light_damage(0), "one light hit = one damage application (no duplicates)")


func _test_combo_three_hits() -> void:
	print("\n[combo]")
	await _reset_for_dummy_test()
	var before := _dummy.health.get_current()
	var max_index := 0
	_actions.request_action(PlayerActionController.Action.LIGHT_ATTACK)
	for step in 2:
		# Press again inside the buffer window of the current hit.
		await _seconds(_weapon.combo_input_open + 0.1)
		_actions.request_action(PlayerActionController.Action.LIGHT_ATTACK)
		await _seconds(_weapon.light_duration - _weapon.combo_input_open - 0.1 + 0.05)
		max_index = maxi(max_index, _actions.get_combo_index())
	await _wait_for_locomotion()
	var expected := _weapon.get_light_damage(0) + _weapon.get_light_damage(1) + _weapon.get_light_damage(2)
	_check(max_index == 2, "combo reaches the third hit (index %d)" % max_index)
	_check_near(before - _dummy.health.get_current(), expected, "three combo hits deal 12 + 12 + 18")


func _test_combo_window_rules() -> void:
	print("\n[combo windows]")
	await _reset_for_dummy_test()
	var before := _dummy.health.get_current()
	_actions.request_action(PlayerActionController.Action.LIGHT_ATTACK)
	await _seconds(0.05) # Before combo_input_open: must be ignored.
	_actions.request_action(PlayerActionController.Action.LIGHT_ATTACK)
	await _wait_for_locomotion()
	_check_near(before - _dummy.health.get_current(), _weapon.get_light_damage(0), "press before the combo window is ignored")

	_actions.request_action(PlayerActionController.Action.LIGHT_ATTACK)
	_check(_actions.get_combo_index() == 0, "after the recovery window expires the combo restarts at hit 1")
	await _wait_for_locomotion()


func _test_heavy_attack_consumes_stamina() -> void:
	print("\n[heavy attack]")
	await _reset_for_dummy_test()
	var before := _dummy.health.get_current()
	_check(_actions.request_action(PlayerActionController.Action.HEAVY_ATTACK), "heavy attack starts with enough stamina")
	_check_near(_stamina.max_stamina - _stamina.get_current(), _weapon.heavy_stamina_cost, "heavy attack consumes its stamina cost")
	await _wait_for_locomotion()
	_check_near(before - _dummy.health.get_current(), _weapon.heavy_damage, "heavy attack deals heavy damage once")
	await _seconds(_stamina.regen_delay + 0.5)
	_check(_stamina.get_current() > _stamina.max_stamina - _weapon.heavy_stamina_cost, "stamina regenerates after the delay")


func _test_heavy_blocked_without_stamina() -> void:
	print("\n[heavy without stamina]")
	await _reset_for_dummy_test()
	_stamina.try_consume(_stamina.max_stamina - 10.0)
	var started := _actions.request_action(PlayerActionController.Action.HEAVY_ATTACK)
	_check(not started and _actions.get_state() == PlayerActionController.State.LOCOMOTION, "heavy attack refused with 10 stamina")
	_check_near(_stamina.get_current(), 10.0, "refused heavy attack spends nothing")
	_stamina.refill()


func _test_actions_blocked_while_committed() -> void:
	print("\n[state rules]")
	await _reset_for_dummy_test()
	_actions.request_action(PlayerActionController.Action.LIGHT_ATTACK)
	await _frames(2)
	_actions.request_action(PlayerActionController.Action.HEAVY_ATTACK)
	_actions.request_action(PlayerActionController.Action.DODGE)
	_check(_actions.get_state() == PlayerActionController.State.LIGHT_ATTACK, "heavy/dodge cannot interrupt a committed light attack")
	_check(_stamina.get_current() == _stamina.max_stamina, "blocked actions spend no stamina")
	await _wait_for_locomotion()


func _test_move_while_attacking() -> void:
	print("\n[move while attacking]")
	await _place_player(Vector3(0, 0.05, 12), Vector3.FORWARD)
	Input.action_press(InputActions.MOVE_FORWARD)
	await _seconds(0.3)
	_actions.request_action(PlayerActionController.Action.LIGHT_ATTACK)
	var start := _player.global_position
	await _seconds(0.3) # Still inside the committed part of the swing.
	_check(_actions.get_state() == PlayerActionController.State.LIGHT_ATTACK, "still attacking")
	var moved := start.z - _player.global_position.z
	var expected := _player.settings.walk_speed * _weapon.attack_move_speed_multiplier * 0.3
	_check(moved > expected * 0.8, "player keeps moving during the swing (%.2f m, expected ~%.2f)" % [moved, expected])
	Input.action_press(InputActions.JUMP)
	await _frames(3)
	Input.action_release(InputActions.JUMP)
	_check(_player.is_on_floor(), "jumping is blocked during the swing")
	Input.action_release(InputActions.MOVE_FORWARD)
	await _wait_for_locomotion()


func _test_dodge_stamina_and_invulnerability() -> void:
	print("\n[dodge]")
	await _place_player(Vector3(0, 0.05, 12), Vector3.FORWARD)
	_stamina.refill()
	var start := _player.global_position
	_check(_actions.request_action(PlayerActionController.Action.DODGE), "dodge starts")
	_check_near(_stamina.max_stamina - _stamina.get_current(), _settings.dodge_stamina_cost, "dodge consumes stamina")
	await _seconds(0.12)
	_check(_health.is_invulnerable(), "invulnerable inside the i-frame window")
	var hp := _health.get_current()
	_check(not _health.apply_damage(DamageInfo.new(10.0)), "damage during i-frames is rejected")
	_check_near(_health.get_current(), hp, "health unchanged during i-frames")
	await _seconds(_settings.dodge_invulnerability_end - 0.12 + 0.05)
	_check(not _health.is_invulnerable(), "invulnerability ends at its configured time")
	await _wait_for_locomotion()
	var travelled := Vector2(_player.global_position.x - start.x, _player.global_position.z - start.z).length()
	_check(travelled > _settings.dodge_distance * 0.8, "dodge travels ~%.1f m (%.2f m)" % [_settings.dodge_distance, travelled])
	_check(not _actions.request_action(PlayerActionController.Action.DODGE), "dodge cooldown prevents an instant repeat")
	await _seconds(_settings.dodge_cooldown + 0.05)


func _test_dodge_respects_walls() -> void:
	print("\n[dodge vs walls]")
	# North wall inner face is at z = -30; start 1.5 m away and roll into it.
	await _place_player(Vector3(0, 0.05, -28.5), Vector3.FORWARD)
	_stamina.refill()
	Input.action_press(InputActions.MOVE_FORWARD)
	await _frames(2)
	_actions.request_action(PlayerActionController.Action.DODGE)
	await _wait_for_locomotion()
	Input.action_release(InputActions.MOVE_FORWARD)
	_check(_player.global_position.z > -30.0 + 0.3, "dodge stops at the wall (z = %.2f)" % _player.global_position.z)


func _test_dummy_dies_and_respawns() -> void:
	print("\n[dummy death]")
	await _reset_for_dummy_test()
	_dummy.hurtbox.receive_hit(DamageInfo.new(_dummy.health.max_health - 5.0))
	_actions.request_action(PlayerActionController.Action.LIGHT_ATTACK)
	await _wait_for_locomotion()
	_check(_dummy.health.is_dead(), "dummy dies when health reaches zero")
	await _frames(2)
	_check(not _dummy.hurtbox.can_be_hit(), "dead dummy cannot be hit")
	_check(_dummy.body_collision.disabled, "dead dummy collision is disabled")
	await _seconds(_dummy.respawn_delay + 0.2)
	_check_near(_dummy.health.get_current(), _dummy.health.max_health, "dummy respawns with full health")


func _test_player_stagger_and_respawn() -> void:
	print("\n[player damage]")
	await _place_player(Vector3(0, 0.05, 12), Vector3.FORWARD)
	_health.apply_damage(DamageInfo.new(10.0))
	_check(_actions.get_state() == PlayerActionController.State.STAGGER, "taking damage staggers the player")
	await _seconds(_settings.stagger_duration + 0.05)
	_check(_actions.get_state() == PlayerActionController.State.LOCOMOTION, "stagger ends after its duration")
	_health.apply_damage(DamageInfo.new(1000.0))
	_check(_actions.get_state() == PlayerActionController.State.DEAD, "lethal damage kills the player")
	_check(not _actions.request_action(PlayerActionController.Action.LIGHT_ATTACK), "dead player cannot act")
	await _seconds(_settings.respawn_delay + 0.1)
	_check(_actions.get_state() == PlayerActionController.State.LOCOMOTION and not _health.is_dead(), "player respawns")


func _test_trap_damages_player() -> void:
	print("\n[trap]")
	var trap := _main.get_node("Level/CombatArea/DamagePulseTrap") as DamagePulseTrap
	_health.revive()
	# Sync to the end of a pulse so the observation window holds exactly one.
	while not trap.hitbox.is_active():
		await physics_frame
	while trap.hitbox.is_active():
		await physics_frame
	await _place_player(trap.global_position + Vector3(0, 0.05, 0), Vector3.FORWARD)
	var hp := _health.get_current()
	# Next pulse starts (cycle_time - active_time) after the previous one ended.
	await _seconds(trap.cycle_time)
	_check_near(hp - _health.get_current(), trap.damage, "trap pulse hits the player exactly once per cycle")
	await _place_player(Vector3(0, 0.05, 12), Vector3.FORWARD)
	_health.revive()


func _test_real_input_events() -> void:
	print("\n[input events]")
	await _place_player(Vector3(0, 0.05, 12), Vector3.FORWARD)
	_stamina.refill()
	var ctrl := InputEventKey.new()
	ctrl.physical_keycode = KEY_CTRL
	ctrl.pressed = true
	Input.parse_input_event(ctrl)
	await _frames(2)
	_check(_actions.get_state() == PlayerActionController.State.DODGE, "Ctrl key triggers a dodge")
	ctrl = ctrl.duplicate() as InputEventKey
	ctrl.pressed = false
	Input.parse_input_event(ctrl)
	await _wait_for_locomotion()
	await _seconds(_settings.dodge_cooldown + 0.05)

	# Holding the right trigger emits many motion events: only one heavy attack.
	_stamina.refill()
	for value: float in [0.6, 0.8, 1.0, 0.9]:
		var trigger := InputEventJoypadMotion.new()
		trigger.axis = JOY_AXIS_TRIGGER_RIGHT
		trigger.axis_value = value
		Input.parse_input_event(trigger)
		await _frames(1)
	_check(_actions.get_state() == PlayerActionController.State.HEAVY_ATTACK, "right trigger triggers a heavy attack")
	_check_near(_stamina.max_stamina - _stamina.get_current(), _weapon.heavy_stamina_cost, "held trigger does not repeat the heavy attack")
	var release := InputEventJoypadMotion.new()
	release.axis = JOY_AXIS_TRIGGER_RIGHT
	release.axis_value = 0.0
	Input.parse_input_event(release)
	await _wait_for_locomotion()


func _test_hud_bars_follow_signals() -> void:
	print("\n[hud]")
	_stamina.try_consume(25.0)
	_health.apply_damage(DamageInfo.new(7.0))
	_check_near(_combat_hud.health_bar.value, _health.get_current(), "health bar tracks HealthComponent")
	_check_near(_combat_hud.stamina_bar.value, _stamina.get_current(), "stamina bar tracks StaminaComponent")


# --- Helpers ------------------------------------------------------------------

func _reset_for_dummy_test() -> void:
	_dummy.health.revive()
	_dummy.hurtbox.set_enabled(true)
	_stamina.refill()
	_health.revive()
	# Dummy at z = 2.5; stand 1.5 m in front of it, facing it.
	await _place_player(_dummy.global_position + Vector3(0, 0.05, 1.5), Vector3.FORWARD)


func _place_player(position: Vector3, facing: Vector3) -> void:
	await _wait_for_locomotion()
	_player.global_position = position
	_player.velocity = Vector3.ZERO
	_player.face_toward(facing)
	await _frames(10)


func _wait_for_locomotion(max_seconds: float = 6.0) -> void:
	var frames := int(max_seconds * PHYSICS_HZ)
	while _actions.get_state() != PlayerActionController.State.LOCOMOTION and frames > 0:
		await physics_frame
		frames -= 1


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


func _check_near(actual: float, expected: float, label: String) -> void:
	_check(absf(actual - expected) < 0.01, "%s (got %.2f, expected %.2f)" % [label, actual, expected])
