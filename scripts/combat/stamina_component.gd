class_name StaminaComponent
extends Node
## Stamina pool with delayed regeneration. Actions must succeed in
## try_consume() before starting, so costs are always paid in full.

signal stamina_changed(current: float, maximum: float)
## Emitted when an action is rejected for lack of stamina (useful for UI feedback).
signal consume_failed(requested: float)

@export_range(1.0, 1000.0, 1.0) var max_stamina: float = 100.0
@export_range(0.0, 500.0, 1.0, "suffix:/s") var regen_per_second: float = 30.0
## Pause after spending stamina before regeneration starts again.
@export_range(0.0, 5.0, 0.05, "suffix:s") var regen_delay: float = 0.8

var _current := 0.0
var _delay_left := 0.0


func _ready() -> void:
	_current = max_stamina
	# Processing only runs while regenerating, so a full bar costs nothing.
	set_process(false)


## Finds the StaminaComponent among `node`'s direct children (null if none).
static func find_in(node: Node) -> StaminaComponent:
	if node == null:
		return null
	for child in node.get_children():
		if child is StaminaComponent:
			return child
	return null


func get_current() -> float:
	return _current


func has_enough(amount: float) -> bool:
	return _current >= amount


func try_consume(amount: float) -> bool:
	if amount <= 0.0:
		return true
	if _current < amount:
		consume_failed.emit(amount)
		return false
	_current -= amount
	_delay_left = regen_delay
	set_process(true)
	stamina_changed.emit(_current, max_stamina)
	return true


func refill() -> void:
	_current = max_stamina
	_delay_left = 0.0
	set_process(false)
	stamina_changed.emit(_current, max_stamina)


func _process(delta: float) -> void:
	if _delay_left > 0.0:
		_delay_left -= delta
		return
	_current = minf(_current + regen_per_second * delta, max_stamina)
	stamina_changed.emit(_current, max_stamina)
	if _current >= max_stamina:
		set_process(false)
