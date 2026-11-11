class_name PlayerInteractor
extends Area3D
## Finds the best Interactable in reach and triggers it with the interact
## action. Candidates arrive through area signals (no polling while nothing
## is near); while some are near, focus is re-evaluated a few times per second.
##
## Interaction is refused while the player is dead or busy (attacking,
## dodging, staggered): only the Locomotion state may interact.

signal focus_changed(target: Interactable)

const REFRESH_INTERVAL := 0.1

@export var player: PlayerController
@export var health: HealthComponent
@export var actions: PlayerActionController

var _candidates: Array[Interactable] = []
var _focus: Interactable
var _refresh_left := 0.0


func _ready() -> void:
	if player == null:
		push_error("PlayerInteractor '%s': 'player' is not assigned; interaction disabled." % get_path())
		set_process_unhandled_input(false)
		monitoring = false
		return
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	set_physics_process(false)


func get_focus() -> Interactable:
	return _focus


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(InputActions.INTERACT):
		return
	_refresh_focus()
	if _focus != null:
		_focus.interact(player)
		get_viewport().set_input_as_handled()
		_refresh_focus()


func _physics_process(delta: float) -> void:
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		_refresh_left = REFRESH_INTERVAL
		_refresh_focus()


func _on_area_entered(area: Area3D) -> void:
	var interactable := area as Interactable
	if interactable != null and not _candidates.has(interactable):
		_candidates.append(interactable)
		set_physics_process(true)
		_refresh_focus()


func _on_area_exited(area: Area3D) -> void:
	var interactable := area as Interactable
	if interactable == null:
		return
	_candidates.erase(interactable)
	if _candidates.is_empty():
		set_physics_process(false)
	_refresh_focus()


func _refresh_focus() -> void:
	var best: Interactable = null
	if _can_act():
		var best_score := INF
		var facing := player.get_facing_direction()
		for candidate in _candidates:
			if not is_instance_valid(candidate) or not candidate.can_interact(player):
				continue
			var to := candidate.global_position - player.global_position
			to.y = 0.0
			var distance := to.length()
			# Prefer what the character is facing; distance breaks ties.
			var alignment := facing.dot(to / distance) if distance > 0.01 else 1.0
			var score := distance - alignment * 1.5
			if score < best_score:
				best_score = score
				best = candidate
	if best != _focus:
		_focus = best
		focus_changed.emit(_focus)


func _can_act() -> bool:
	if health != null and health.is_dead():
		return false
	return actions == null or actions.get_state() == PlayerActionController.State.LOCOMOTION
