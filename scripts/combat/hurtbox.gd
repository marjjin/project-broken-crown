class_name Hurtbox
extends Area3D
## Damageable region of an entity. Hitboxes find it through physics layers;
## damage is forwarded to the linked HealthComponent.
##
## Expected setup: monitorable = true, monitoring = false, collision layer set
## to the entity's hurtbox layer (player_hurtbox / enemy_hurtbox).

signal hit_received(info: DamageInfo)

@export var health: HealthComponent
## Entity this hurtbox belongs to. Used to ignore self-hits and to make sure an
## entity with several hurtboxes is hit only once per attack.
@export var entity: Node

var _enabled := true


func _ready() -> void:
	if health == null:
		push_error("Hurtbox '%s': no HealthComponent assigned; it will ignore every hit." % get_path())
	if entity == null:
		entity = owner


func can_be_hit() -> bool:
	return _enabled and health != null and not health.is_dead()


## Returns true if damage was applied (false if dead, disabled or invulnerable).
func receive_hit(info: DamageInfo) -> bool:
	if not can_be_hit():
		return false
	var applied := health.apply_damage(info)
	if applied:
		hit_received.emit(info)
	return applied


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	# Physics state cannot change during a physics callback, hence deferred.
	set_deferred("monitorable", enabled)


func get_target_id() -> int:
	return entity.get_instance_id() if entity != null else get_instance_id()
