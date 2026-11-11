class_name Checkpoint
extends Node3D
## Guard Royal statue that acts as a rest point. Resting:
##   - makes it the active checkpoint (GameSession),
##   - moves the player's respawn point to `spawn_point`,
##   - restores health and stamina through the existing components.
## Death and respawn themselves stay in PlayerActionController; this script
## only changes *where* the player comes back. Session-only (no disk save yet).

@export var checkpoint_id: StringName = &"checkpoint"
@export var display_name: String = "Estatua de la Guardia Real"
@export var interactable: Interactable
## Where (and facing where) the player reappears.
@export var spawn_point: Node3D
## Optional light that brightens when this checkpoint is the active one.
@export var light: OmniLight3D
## Optional mesh shown only while active (e.g. a flame at the statue's feet).
@export var active_indicator: Node3D

@export_group("Light")
@export var inactive_energy: float = 0.5
@export var active_energy: float = 2.6
@export var inactive_color: Color = Color(0.55, 0.65, 0.9)
@export var active_color: Color = Color(1.0, 0.78, 0.45)

var _active := false


func _ready() -> void:
	if interactable == null or spawn_point == null:
		push_error("Checkpoint '%s': interactable and spawn_point must be assigned." % get_path())
		return
	interactable.prompt = "Descansar"
	interactable.interacted.connect(_on_interacted)
	GameSessionState.instance().checkpoint_activated.connect(_on_checkpoint_activated)
	_apply_visual_state(GameSessionState.instance().active_checkpoint == checkpoint_id, false)


func is_active() -> bool:
	return _active


func _on_interacted(interactor: Node) -> void:
	var player := interactor as PlayerController
	if player == null:
		return
	player.set_spawn_point(spawn_point.global_transform)
	var health := HealthComponent.find_in(player)
	if health != null:
		health.revive()
	var stamina := StaminaComponent.find_in(player)
	if stamina != null:
		stamina.refill()
	GameSessionState.instance().activate_checkpoint(checkpoint_id)
	GameSessionState.instance().notify("Punto de descanso", "%s vela por vos. Vida y stamina restauradas." % display_name)


func _on_checkpoint_activated(id: StringName) -> void:
	_apply_visual_state(id == checkpoint_id, true)


func _apply_visual_state(active: bool, animate: bool) -> void:
	_active = active
	if active_indicator != null:
		active_indicator.visible = active
	if light == null:
		return
	var energy := active_energy if active else inactive_energy
	var color := active_color if active else inactive_color
	if not animate:
		light.light_energy = energy
		light.light_color = color
		return
	var tween := create_tween().set_parallel(true)
	tween.tween_property(light, "light_energy", energy, 0.8)
	tween.tween_property(light, "light_color", color, 0.8)
