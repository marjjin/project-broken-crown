class_name HealthComponent
extends Node
## Health pool shared by the player, training dummies and future enemies.
## It only tracks numbers and emits signals; reactions live in the owner.

signal health_changed(current: float, maximum: float)
signal damaged(info: DamageInfo)
## Emitted when a hit is ignored because of invulnerability (e.g. dodge i-frames).
signal damage_prevented(info: DamageInfo)
signal invulnerability_changed(active: bool)
signal died
signal revived

@export_range(1.0, 10000.0, 1.0) var max_health: float = 100.0

var _current_health := 0.0
var _invulnerable := false


func _ready() -> void:
	_current_health = max_health


func get_current() -> float:
	return _current_health


func is_dead() -> bool:
	return _current_health <= 0.0


func is_invulnerable() -> bool:
	return _invulnerable


func set_invulnerable(active: bool) -> void:
	if _invulnerable == active:
		return
	_invulnerable = active
	invulnerability_changed.emit(active)


## Returns true only if damage was actually applied.
func apply_damage(info: DamageInfo) -> bool:
	if info == null or info.amount <= 0.0 or is_dead():
		return false
	if _invulnerable:
		damage_prevented.emit(info)
		return false

	_current_health = maxf(_current_health - info.amount, 0.0)
	health_changed.emit(_current_health, max_health)
	damaged.emit(info)
	if is_dead():
		died.emit()
	return true


func revive() -> void:
	_current_health = max_health
	set_invulnerable(false)
	health_changed.emit(_current_health, max_health)
	revived.emit()
