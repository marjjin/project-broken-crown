class_name Hitbox
extends Area3D
## Offensive region that only *detects* valid hurtboxes while active.
## It never applies damage itself: the owner listens to `hit_detected` and
## decides what happens, so the same hitbox works for players, enemies,
## bosses or traps.
##
## Each activation hits every target at most once; overlap alone outside an
## activation window never produces a hit.
##
## Expected setup: monitoring = true, monitorable = false, collision layer 0 and
## mask set to the hurtbox layer(s) this hitbox can hurt.

signal hit_detected(hurtbox: Hurtbox)

## Entity that owns this hitbox; its own hurtboxes are ignored.
@export var source: Node

var _active := false
var _already_hit: Dictionary = {}
var _collision_shape: CollisionShape3D


func _ready() -> void:
	for child in get_children():
		if child is CollisionShape3D:
			_collision_shape = child
			break
	if _collision_shape == null:
		push_error("Hitbox '%s': needs a CollisionShape3D child." % get_path())
	if source == null:
		source = owner
	set_physics_process(false)


func activate() -> void:
	_already_hit.clear()
	_active = true
	set_physics_process(true)


func deactivate() -> void:
	_active = false
	set_physics_process(false)


func is_active() -> bool:
	return _active


## Resizes the box shape, e.g. from a weapon's reach. The shape is duplicated
## so scenes instanced several times do not share (and overwrite) it.
func configure_box(size: Vector3, center: Vector3) -> void:
	if _collision_shape == null:
		return
	var box := _collision_shape.shape as BoxShape3D
	if box == null:
		push_warning("Hitbox '%s': configure_box() requires a BoxShape3D." % get_path())
		return
	box = box.duplicate() as BoxShape3D
	box.size = size
	_collision_shape.shape = box
	_collision_shape.position = center


func _physics_process(_delta: float) -> void:
	# Polling overlaps (instead of area_entered) also catches targets that were
	# already inside the shape when the window opened.
	for area in get_overlapping_areas():
		var hurtbox := area as Hurtbox
		if hurtbox == null or not hurtbox.can_be_hit():
			continue
		if source != null and hurtbox.entity == source:
			continue
		var target_id := hurtbox.get_target_id()
		if _already_hit.has(target_id):
			continue
		_already_hit[target_id] = true
		hit_detected.emit(hurtbox)
		if not _active:
			return # A listener may have closed the window.
