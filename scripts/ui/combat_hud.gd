class_name CombatHud
extends CanvasLayer
## Health/stamina bars and action state. Purely signal-driven: nothing here
## runs per frame except short feedback tweens.

const FEEDBACK_TIME := 1.2

@export var health: HealthComponent
@export var stamina: StaminaComponent
@export var actions: PlayerActionController

@export_group("Widgets")
@export var health_bar: ProgressBar
@export var stamina_bar: ProgressBar
@export var state_label: Label
@export var feedback_label: Label

var _state_text := ""
var _invulnerable := false
var _feedback_tween: Tween
var _stamina_tween: Tween


func _ready() -> void:
	if health_bar == null or stamina_bar == null or state_label == null or feedback_label == null:
		push_error("CombatHud: widget references are not assigned; HUD disabled.")
		return
	feedback_label.modulate.a = 0.0

	if health != null:
		health.health_changed.connect(_on_health_changed)
		health.invulnerability_changed.connect(_on_invulnerability_changed)
		health.damage_prevented.connect(_on_damage_prevented)
		health.died.connect(_show_feedback.bind("Has caido. Reapareciendo...", Color(1, 0.35, 0.3)))
		_on_health_changed(health.get_current(), health.max_health)
	else:
		push_warning("CombatHud: no HealthComponent assigned.")

	if stamina != null:
		stamina.stamina_changed.connect(_on_stamina_changed)
		stamina.consume_failed.connect(_on_stamina_failed)
		_on_stamina_changed(stamina.get_current(), stamina.max_stamina)
	else:
		push_warning("CombatHud: no StaminaComponent assigned.")

	if actions != null:
		actions.state_changed.connect(_on_state_changed)
		_on_state_changed(actions.get_state(), actions.get_state_label())
	else:
		push_warning("CombatHud: no PlayerActionController assigned.")


func _on_health_changed(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current


func _on_stamina_changed(current: float, maximum: float) -> void:
	stamina_bar.max_value = maximum
	stamina_bar.value = current


func _on_stamina_failed(_requested: float) -> void:
	if _stamina_tween != null:
		_stamina_tween.kill()
	stamina_bar.modulate = Color(1.0, 0.3, 0.3)
	_stamina_tween = create_tween()
	_stamina_tween.tween_property(stamina_bar, "modulate", Color.WHITE, 0.4)
	_show_feedback("Stamina insuficiente", Color(1.0, 0.75, 0.3))


func _on_state_changed(_state: int, label: String) -> void:
	_state_text = label
	_refresh_state_label()


func _on_invulnerability_changed(active: bool) -> void:
	_invulnerable = active
	_refresh_state_label()


func _on_damage_prevented(_info: DamageInfo) -> void:
	_show_feedback("Golpe evitado (invulnerable)", Color(0.5, 0.9, 1.0))


func _refresh_state_label() -> void:
	state_label.text = "Estado: %s%s" % [_state_text, "  [INVULNERABLE]" if _invulnerable else ""]


func _show_feedback(text: String, color: Color) -> void:
	if _feedback_tween != null:
		_feedback_tween.kill()
	feedback_label.text = text
	feedback_label.modulate = color
	_feedback_tween = create_tween()
	_feedback_tween.tween_interval(FEEDBACK_TIME * 0.6)
	_feedback_tween.tween_property(feedback_label, "modulate:a", 0.0, FEEDBACK_TIME * 0.4)
