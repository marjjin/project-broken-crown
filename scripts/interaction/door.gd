class_name Door
extends Node3D
## Reusable hinged door. While closed its panel (an AnimatableBody3D on the
## "world" layer) blocks the player and is baked into the navmesh as a wall.
## Opening swings the panel and enables a NavigationLink3D through the
## doorway, so enemies can path through without re-baking the region.

signal opened

@export var interactable: Interactable
## Pivot reference (only its position is used).
@export var hinge: Node3D
## The moving panel. It is animated directly (not through a parent): a physics
## body synced to physics does not follow transforms inherited from a parent.
@export var panel: Node3D
@export var navigation_link: NavigationLink3D

@export_group("Visual Leaves")
## Optional model whose leaves are animated instead of (or in addition to)
## the panel's own meshes. Leaves are found by name inside this node, must have
## their origin on their hinge, and are reset to a closed pose (rotation 0).
@export var visual_model: Node3D
@export var leaf_names: PackedStringArray = PackedStringArray()
## Per-leaf multiplier of the swing angle (e.g. 1 and -1 for a double door
## whose leaves open toward the same side around opposite hinges).
@export var leaf_angle_signs: PackedFloat32Array = PackedFloat32Array()

@export_group("Behaviour")
@export var starts_open: bool = false
## A locked door shows `locked_message` instead of opening (see unlock()).
@export var locked: bool = false
@export var locked_message: String = "Está trabada. No cede."
@export var prompt_open: String = "Abrir"
@export var prompt_locked: String = "Examinar"
## Swing angle. Positive opens toward local -Z (away from someone standing on
## the +Z side); negative opens toward +Z. 90° leaves the panel flush with the wall.
@export_range(-170.0, 170.0, 1.0, "suffix:°") var open_angle_degrees: float = 90.0
@export_range(0.05, 5.0, 0.05, "suffix:s") var open_duration: float = 0.9

var _open := false
var _closed_transform := Transform3D.IDENTITY
var _leaves: Array[Node3D] = []


func _ready() -> void:
	if interactable == null or hinge == null or panel == null:
		push_error("Door '%s': interactable, hinge and panel must be assigned." % get_path())
		return
	_closed_transform = panel.transform
	_collect_leaves()
	interactable.interacted.connect(_on_interacted)
	_refresh_prompt()
	if navigation_link != null:
		navigation_link.enabled = false
	if starts_open:
		_set_open_pose(true)


func is_open() -> bool:
	return _open


func unlock() -> void:
	locked = false
	_refresh_prompt()


func open() -> void:
	if _open:
		return
	_open = true
	interactable.enabled = false
	var tween := create_tween()
	# The panel is a physics body: animate it on the physics tick.
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_method(_apply_swing, 0.0, deg_to_rad(open_angle_degrees), open_duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_on_fully_open)
	opened.emit()


func _on_interacted(_interactor: Node) -> void:
	if locked:
		GameSessionState.instance().notify("Puerta", locked_message)
		return
	open()


func _on_fully_open() -> void:
	# Enemies may only path through once the doorway is actually clear.
	if navigation_link != null:
		navigation_link.enabled = true


## Rotates the panel `angle` radians around the hinge's vertical axis.
func _apply_swing(angle: float) -> void:
	var pivot := hinge.position
	panel.transform = Transform3D(Basis(Vector3.UP, angle), pivot) \
		* Transform3D(Basis.IDENTITY, -pivot) * _closed_transform
	# Visual-only leaves swing around their own hinges; collision stays the
	# single simple panel above.
	for i in _leaves.size():
		var leaf_sign := leaf_angle_signs[i] if i < leaf_angle_signs.size() else 1.0
		_leaves[i].rotation.y = angle * leaf_sign


func _collect_leaves() -> void:
	if visual_model == null:
		return
	for leaf_name in leaf_names:
		var leaf := visual_model.find_child(leaf_name, true, false) as Node3D
		if leaf == null:
			push_warning("Door '%s': leaf '%s' not found in the visual model." % [get_path(), leaf_name])
			continue
		leaf.rotation = Vector3.ZERO # Models may ship slightly ajar.
		_leaves.append(leaf)


func _set_open_pose(open_now: bool) -> void:
	_open = open_now
	_apply_swing(deg_to_rad(open_angle_degrees) if open_now else 0.0)
	interactable.enabled = not open_now
	if navigation_link != null:
		navigation_link.enabled = open_now


func _refresh_prompt() -> void:
	if interactable != null:
		interactable.prompt = prompt_locked if locked else prompt_open
