class_name Collectible
extends Node3D
## Provisional pickup: interacting records it in GameSession (session only;
## there is no inventory yet), shows a banner and removes the object.
## A pickup already collected this session never spawns again.

@export var item_id: StringName = &"item"
@export var display_name: String = "Objeto"
@export_multiline var description: String = ""
@export var interactable: Interactable
## Visual that bobs and spins to draw attention (optional).
@export var visual: Node3D

const BOB_HEIGHT := 0.12
const BOB_TIME := 1.4
const SPIN_TIME := 4.0


func _ready() -> void:
	if GameSessionState.instance().has_collected(item_id):
		queue_free()
		return
	if interactable == null:
		push_error("Collectible '%s': no interactable assigned." % get_path())
		return
	interactable.prompt = "Recoger"
	interactable.interacted.connect(_on_interacted)
	_start_idle_animation()


func _on_interacted(_interactor: Node) -> void:
	if not GameSessionState.instance().collect(item_id, display_name):
		return
	GameSessionState.instance().notify("Obtenido: %s" % display_name, description)
	queue_free()


func _start_idle_animation() -> void:
	if visual == null:
		return
	# Engine-driven looping tweens: no per-frame script work.
	var rest_y := visual.position.y
	var bob := create_tween().set_loops()
	bob.tween_property(visual, "position:y", rest_y + BOB_HEIGHT, BOB_TIME * 0.5).set_trans(Tween.TRANS_SINE)
	bob.tween_property(visual, "position:y", rest_y, BOB_TIME * 0.5).set_trans(Tween.TRANS_SINE)
	var spin := create_tween().set_loops()
	spin.tween_property(visual, "rotation:y", TAU, SPIN_TIME).from(0.0)
