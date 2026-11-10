class_name PlayerActionController
extends Node
## Small enum-based state machine that decides which action the player is
## performing (locomotion, attacks, dodge, stagger, death) and which inputs are
## allowed. It coordinates components but owns no physics or presentation:
##   - movement -> PlayerController API (input lock / velocity override)
##   - costs    -> StaminaComponent
##   - hits     -> Hitbox (detection) + Hurtbox (damage application)
##   - visuals  -> ActionAnimator
##
## Runs its physics step before PlayerController (process_physics_priority in
## the scene) so velocity overrides apply on the same frame.

enum State { LOCOMOTION, LIGHT_ATTACK, HEAVY_ATTACK, DODGE, STAGGER, DEAD }
enum Action { NONE, LIGHT_ATTACK, HEAVY_ATTACK, DODGE }

signal state_changed(state: State, label: String)

const STATE_LABELS := {
	State.LOCOMOTION: "Locomocion",
	State.LIGHT_ATTACK: "Ataque ligero",
	State.HEAVY_ATTACK: "Ataque fuerte",
	State.DODGE: "Esquiva",
	State.STAGGER: "Aturdido",
	State.DEAD: "Muerto",
}

@export var player: PlayerController
@export var health: HealthComponent
@export var stamina: StaminaComponent
@export var hitbox: Hitbox
@export var animator: ActionAnimator
@export var weapon: WeaponData
@export var settings: PlayerActionSettings

var _state := State.LOCOMOTION
var _state_time := 0.0
var _combo_index := 0
var _buffered := Action.NONE
var _dodge_cooldown_left := 0.0
var _dodge_velocity := Vector3.ZERO
var _attack_damage := 0.0
var _attack_name: StringName = &""
var _hit_window_opened := false
var _recovery_started := false
## Tracks analog triggers so holding one does not repeat the action.
var _held_axis_actions: Dictionary = {}


func _ready() -> void:
	if not _validate_configuration():
		set_physics_process(false)
		set_process_unhandled_input(false)
		return
	_configure_hitbox()
	hitbox.hit_detected.connect(_on_hit_detected)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	_set_state(State.LOCOMOTION)


func get_state() -> State:
	return _state


func get_state_label() -> String:
	match _state:
		State.LIGHT_ATTACK:
			return "%s %d/%d" % [STATE_LABELS[_state], _combo_index + 1, weapon.get_combo_length()]
		_:
			return STATE_LABELS[_state]


func get_combo_index() -> int:
	return _combo_index


## Entry point for every action request (player input today; tests or replays
## can call it too). Returns true if the action started immediately.
func request_action(action: Action) -> bool:
	match _state:
		State.LOCOMOTION:
			return _try_start(action)
		State.LIGHT_ATTACK, State.HEAVY_ATTACK:
			if _is_in_recovery():
				return _try_start(action)
			if _state_time >= weapon.combo_input_open:
				_buffered = action
			return false
		_:
			# Dodge, stagger and death are uninterruptible by player input.
			return false


func _unhandled_input(event: InputEvent) -> void:
	# A click that captures the mouse must not also swing the sword.
	if event is InputEventMouseButton and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if _is_fresh_press(event, InputActions.ATTACK_LIGHT):
		request_action(Action.LIGHT_ATTACK)
	elif _is_fresh_press(event, InputActions.ATTACK_HEAVY):
		request_action(Action.HEAVY_ATTACK)
	elif _is_fresh_press(event, InputActions.DODGE):
		request_action(Action.DODGE)


func _physics_process(delta: float) -> void:
	_dodge_cooldown_left = maxf(_dodge_cooldown_left - delta, 0.0)
	_state_time += delta
	match _state:
		State.LIGHT_ATTACK:
			_update_attack(weapon.light_duration, weapon.light_hit_start, weapon.light_hit_end)
		State.HEAVY_ATTACK:
			_update_attack(weapon.heavy_duration, weapon.heavy_hit_start, weapon.heavy_hit_end)
		State.DODGE:
			_update_dodge()
		State.STAGGER:
			if _state_time >= settings.stagger_duration:
				_enter_locomotion()
		State.DEAD:
			if _state_time >= settings.respawn_delay:
				_respawn()


# --- Transitions -------------------------------------------------------------

func _try_start(action: Action) -> bool:
	if not player.is_on_floor():
		return false
	match action:
		Action.LIGHT_ATTACK:
			_start_light_attack()
			return true
		Action.HEAVY_ATTACK:
			if not stamina.try_consume(weapon.heavy_stamina_cost):
				return false
			_start_attack(State.HEAVY_ATTACK, weapon.heavy_damage, &"heavy")
			animator.play_heavy_attack(weapon.heavy_duration)
			return true
		Action.DODGE:
			if _dodge_cooldown_left > 0.0 or not stamina.try_consume(settings.dodge_stamina_cost):
				return false
			_start_dodge()
			return true
	return false


func _start_light_attack() -> void:
	# Continue the combo only when chaining from a light attack's recovery.
	var next_index := 0
	if _state == State.LIGHT_ATTACK:
		next_index = (_combo_index + 1) % weapon.get_combo_length()
	_combo_index = next_index
	_start_attack(State.LIGHT_ATTACK, weapon.get_light_damage(next_index), StringName("light_%d" % (next_index + 1)))
	animator.play_light_attack(next_index, weapon.light_duration)


func _start_attack(state: State, damage: float, attack_name: StringName) -> void:
	hitbox.deactivate()
	_attack_damage = damage
	_attack_name = attack_name
	_hit_window_opened = false
	_recovery_started = false
	_buffered = Action.NONE
	player.set_input_enabled(false)
	player.clear_horizontal_override()
	# Attacks snap toward the held direction, otherwise keep the current facing.
	player.face_toward(player.get_move_direction())
	_set_state(state)


func _update_attack(duration: float, hit_start: float, hit_end: float) -> void:
	if not _hit_window_opened and _state_time >= hit_start:
		_hit_window_opened = true
		hitbox.activate()
	if hitbox.is_active() and _state_time >= hit_end:
		hitbox.deactivate()

	if _state_time < duration:
		return
	if not _recovery_started:
		_recovery_started = true
		# Recovery: the player may move again; the combo window stays open.
		player.set_input_enabled(true)
		if _buffered != Action.NONE:
			var action := _buffered
			_buffered = Action.NONE
			if _try_start(action):
				return
	if _state_time >= duration + weapon.recovery_time:
		_enter_locomotion()


func _start_dodge() -> void:
	hitbox.deactivate()
	_buffered = Action.NONE
	var direction := player.get_move_direction()
	var backwards := direction == Vector3.ZERO and settings.neutral_dodge_backwards
	if direction == Vector3.ZERO:
		direction = -player.get_facing_direction() if backwards else player.get_facing_direction()
	else:
		player.face_toward(direction)
	_dodge_velocity = direction.normalized()
	player.set_input_enabled(false)
	_set_state(State.DODGE)
	animator.play_dodge(settings.dodge_duration, backwards)


func _update_dodge() -> void:
	var duration := settings.dodge_duration
	var progress := clampf(_state_time / duration, 0.0, 1.0)
	# Linearly decaying speed: v(t) = 2d/T * (1 - t/T) integrates to exactly d.
	var speed := 2.0 * settings.dodge_distance / duration * (1.0 - progress)
	player.set_horizontal_override(_dodge_velocity * speed)

	var invulnerable := _state_time >= settings.dodge_invulnerability_start \
		and _state_time < settings.dodge_invulnerability_end
	health.set_invulnerable(invulnerable)

	if _state_time >= duration:
		_dodge_cooldown_left = settings.dodge_cooldown
		_enter_locomotion()


func _enter_locomotion() -> void:
	_reset_action_side_effects()
	player.set_input_enabled(true)
	_combo_index = 0
	_set_state(State.LOCOMOTION)


func _respawn() -> void:
	player.respawn()
	health.revive()
	stamina.refill()
	animator.reset_pose()
	_enter_locomotion()


func _reset_action_side_effects() -> void:
	hitbox.deactivate()
	player.clear_horizontal_override()
	health.set_invulnerable(false)
	_buffered = Action.NONE


func _set_state(state: State) -> void:
	_state = state
	_state_time = 0.0
	state_changed.emit(state, get_state_label())


func _is_in_recovery() -> bool:
	return _recovery_started


# --- Signal handlers ----------------------------------------------------------

func _on_hit_detected(target: Hurtbox) -> void:
	target.receive_hit(DamageInfo.new(_attack_damage, player, _attack_name))


func _on_damaged(_info: DamageInfo) -> void:
	if _state == State.DEAD or health.is_dead():
		return # The died signal handles this case.
	_reset_action_side_effects()
	player.set_input_enabled(false)
	animator.play_hit()
	_set_state(State.STAGGER)


func _on_died() -> void:
	_reset_action_side_effects()
	player.set_input_enabled(false)
	animator.play_death()
	_set_state(State.DEAD)


# --- Helpers ------------------------------------------------------------------

func _is_fresh_press(event: InputEvent, action: StringName) -> bool:
	if not event.is_action(action):
		return false
	if event is InputEventJoypadMotion:
		# Analog triggers send many motion events while held; fire once per pull.
		var pressed := event.is_action_pressed(action)
		var was_held: bool = _held_axis_actions.get(action, false)
		_held_axis_actions[action] = pressed
		return pressed and not was_held
	return event.is_action_pressed(action)


func _configure_hitbox() -> void:
	var size := Vector3(weapon.hit_width, weapon.hit_height, weapon.reach)
	# Starts just in front of the capsule (radius ~0.4) and extends `reach` forward.
	var center := Vector3(0.0, 1.0, -(0.35 + weapon.reach * 0.5))
	hitbox.configure_box(size, center)


func _validate_configuration() -> bool:
	var missing := PackedStringArray()
	if player == null: missing.append("player")
	if health == null: missing.append("health")
	if stamina == null: missing.append("stamina")
	if hitbox == null: missing.append("hitbox")
	if animator == null: missing.append("animator")
	if weapon == null: missing.append("weapon")
	if settings == null: missing.append("settings")
	if not missing.is_empty():
		push_error("PlayerActionController: missing references (%s); combat disabled." % ", ".join(missing))
		return false
	var errors := weapon.validate()
	errors.append_array(settings.validate())
	for message in errors:
		push_warning("PlayerActionController: %s" % message)
	return true
