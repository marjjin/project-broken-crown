class_name EnemyMeleeAttack
extends Node
## One melee attack with windup -> active -> recovery, then a cooldown.
## Damage goes through the shared combat pipeline: the Hitbox detects (once
## per target per swing, only during the active window) and the target's
## Hurtbox/HealthComponent decide the result (i-frames included). This node
## never modifies health directly.

signal attack_started
signal active_window_opened
signal attack_finished

enum Phase { NONE, WINDUP, ACTIVE, RECOVERY }

## Height on attacker and target used for the hit-time line-of-sight check.
const LINE_CHECK_HEIGHT := 1.1

@export var body: EnemyCharacter
@export var hitbox: Hitbox
@export var animator: ActionAnimator
## Layers that block a swing (a target behind a wall is never hit).
@export_flags_3d_physics var occlusion_mask: int = 1

var _data: EnemyData
var _phase := Phase.NONE
var _phase_time := 0.0
var _cooldown_left := 0.0
var _target: Node3D


func _ready() -> void:
	if body == null or body.data == null or hitbox == null:
		push_error("EnemyMeleeAttack '%s': body (with data) and hitbox are required; attack disabled." % get_path())
		set_physics_process(false)
		return
	_data = body.data
	var reach := _data.attack_reach
	hitbox.configure_box(
		Vector3(_data.attack_width, _data.attack_height, reach),
		Vector3(0.0, 1.0, -(0.35 + reach * 0.5)))
	hitbox.hit_detected.connect(_on_hit_detected)


func can_start() -> bool:
	return _data != null and _phase == Phase.NONE and _cooldown_left <= 0.0


func is_attacking() -> bool:
	return _phase != Phase.NONE


func get_phase() -> Phase:
	return _phase


func start(target: Node3D) -> bool:
	if not can_start():
		return false
	_target = target
	_set_phase(Phase.WINDUP)
	if animator != null:
		animator.play_attack(_data.attack_windup, _data.attack_active, _data.attack_recovery)
	attack_started.emit()
	return true


## Interrupts the swing (stagger, death). The cooldown still applies so an
## interrupted enemy cannot instantly swing again.
func cancel() -> void:
	if _phase == Phase.NONE:
		return
	hitbox.deactivate()
	_phase = Phase.NONE
	_cooldown_left = _data.attack_cooldown
	if animator != null:
		animator.reset_pose()


func _physics_process(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	if _phase == Phase.NONE:
		return
	_phase_time += delta
	match _phase:
		Phase.WINDUP:
			if _data.track_target_during_windup and is_instance_valid(_target):
				body.face_point(_target.global_position)
			if _phase_time >= _data.attack_windup:
				_set_phase(Phase.ACTIVE)
				hitbox.activate()
				active_window_opened.emit()
		Phase.ACTIVE:
			if _phase_time >= _data.attack_active:
				hitbox.deactivate()
				_set_phase(Phase.RECOVERY)
		Phase.RECOVERY:
			if _phase_time >= _data.attack_recovery:
				_phase = Phase.NONE
				_cooldown_left = _data.attack_cooldown
				attack_finished.emit()


func _set_phase(phase: Phase) -> void:
	_phase = phase
	_phase_time = 0.0


func _on_hit_detected(hurtbox: Hurtbox) -> void:
	if not _has_clear_line(hurtbox):
		return
	hurtbox.receive_hit(DamageInfo.new(_data.attack_damage, body, StringName("%s_slash" % _data.id)))


func _has_clear_line(hurtbox: Hurtbox) -> bool:
	var from := body.global_position + Vector3.UP * LINE_CHECK_HEIGHT
	var to := hurtbox.global_position + Vector3.UP * LINE_CHECK_HEIGHT
	var query := PhysicsRayQueryParameters3D.create(from, to, occlusion_mask, [body.get_rid()])
	return body.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
