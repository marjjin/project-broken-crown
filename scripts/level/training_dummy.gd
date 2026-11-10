class_name TrainingDummy
extends Node3D
## Passive combat target (no AI): takes damage, reacts, falls when its health
## reaches zero and optionally stands back up after a delay.

## Seconds until the dummy is restored after dying; 0 keeps it down.
@export_range(0.0, 60.0, 0.5, "suffix:s") var respawn_delay: float = 4.0

@export var health: HealthComponent
@export var hurtbox: Hurtbox
@export var body_collision: CollisionShape3D
@export var animator: ActionAnimator
@export var health_label: Label3D

const DAMAGE_POPUP_RISE := 0.8
const DAMAGE_POPUP_TIME := 0.6


func _ready() -> void:
	if health == null or hurtbox == null:
		push_error("TrainingDummy '%s': health and hurtbox must be assigned." % get_path())
		return
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	health.health_changed.connect(_on_health_changed)
	_on_health_changed(health.get_current(), health.max_health)


func _on_damaged(info: DamageInfo) -> void:
	_spawn_damage_popup(info.amount)
	if not health.is_dead() and animator != null:
		animator.play_hit()


func _on_died() -> void:
	hurtbox.set_enabled(false)
	if body_collision != null:
		body_collision.set_deferred("disabled", true)
	if animator != null:
		animator.play_death()
	if respawn_delay > 0.0:
		get_tree().create_timer(respawn_delay).timeout.connect(_restore)


func _restore() -> void:
	if not is_inside_tree():
		return
	health.revive()
	hurtbox.set_enabled(true)
	if body_collision != null:
		body_collision.set_deferred("disabled", false)
	if animator != null:
		animator.reset_pose()


func _on_health_changed(current: float, maximum: float) -> void:
	if health_label != null:
		health_label.text = "%d / %d" % [ceili(current), ceili(maximum)]


func _spawn_damage_popup(amount: float) -> void:
	if health_label == null:
		return
	var popup := Label3D.new()
	popup.text = "-%d" % roundi(amount)
	popup.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	popup.no_depth_test = true
	popup.font_size = 48
	popup.outline_size = 10
	popup.modulate = Color(1.0, 0.85, 0.3)
	add_child(popup)
	popup.global_position = health_label.global_position + Vector3(randf_range(-0.3, 0.3), 0.2, 0.0)
	var tween := popup.create_tween().set_parallel(true)
	tween.tween_property(popup, "position:y", popup.position.y + DAMAGE_POPUP_RISE, DAMAGE_POPUP_TIME)
	tween.tween_property(popup, "modulate:a", 0.0, DAMAGE_POPUP_TIME).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(popup.queue_free)
