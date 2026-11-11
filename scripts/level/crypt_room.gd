@tool
class_name CryptRoom
extends Node3D
## Generates a room or corridor (floor, walls with openings, lintels, ceiling)
## from a few parameters, using BoxObstacle pieces. Sectors are assembled from
## these instead of hundreds of hand-placed boxes, and the whole room can later
## be swapped for a modeled mesh without touching gameplay logic.
##
## Coordinates: the node sits at the room's floor center; `inner_size` is the
## walkable X/Z area. Walls are built *outside* it, so a corridor placed from
## one room's outer wall face to the next room's outer wall face joins cleanly.
##
## Each opening is Vector3(side, offset, width):
##   side   0 = north (-Z), 1 = south (+Z), 2 = east (+X), 3 = west (-X)
##   offset position along the side, from its center (X for N/S, Z for E/W)
##   width  opening width; a width >= the side length removes that wall entirely
## Openings are `opening_height` tall; a lintel fills the space above.
##
## Generated pieces are internal children: rebuilt on load, never saved.

enum Side { NORTH, SOUTH, EAST, WEST }

@export var inner_size: Vector2 = Vector2(6, 6):
	set(value):
		inner_size = value
		_queue_rebuild()
@export_range(2.0, 20.0, 0.5, "suffix:m") var height: float = 4.0:
	set(value):
		height = value
		_queue_rebuild()
@export_range(0.2, 3.0, 0.1, "suffix:m") var wall_thickness: float = 1.0:
	set(value):
		wall_thickness = value
		_queue_rebuild()
@export var openings: Array[Vector3] = []:
	set(value):
		openings = value
		_queue_rebuild()
@export_range(1.0, 10.0, 0.1, "suffix:m") var opening_height: float = 3.0:
	set(value):
		opening_height = value
		_queue_rebuild()
@export var has_floor: bool = true:
	set(value):
		has_floor = value
		_queue_rebuild()
@export var has_ceiling: bool = true:
	set(value):
		has_ceiling = value
		_queue_rebuild()

@export_group("Materials")
@export var floor_material: Material:
	set(value):
		floor_material = value
		_queue_rebuild()
@export var wall_material: Material:
	set(value):
		wall_material = value
		_queue_rebuild()
@export var ceiling_material: Material:
	set(value):
		ceiling_material = value
		_queue_rebuild()

const SLAB_THICKNESS := 0.5

var _rebuild_queued := false


func _ready() -> void:
	_rebuild()


func _queue_rebuild() -> void:
	if not is_inside_tree() or _rebuild_queued:
		return
	_rebuild_queued = true
	_rebuild.call_deferred()


func _rebuild() -> void:
	_rebuild_queued = false
	for child in get_children(true):
		if child is BoxObstacle and _is_generated(child):
			remove_child(child)
			child.queue_free()

	var outer := inner_size + Vector2.ONE * wall_thickness * 2.0
	if has_floor:
		_add_box(Vector3(0, -SLAB_THICKNESS * 0.5, 0), Vector3(outer.x, SLAB_THICKNESS, outer.y), floor_material)
	if has_ceiling:
		_add_box(Vector3(0, height + SLAB_THICKNESS * 0.5, 0), Vector3(outer.x, SLAB_THICKNESS, outer.y), ceiling_material)
	for side in [Side.NORTH, Side.SOUTH, Side.EAST, Side.WEST]:
		_build_wall(side)


func _build_wall(side: Side) -> void:
	var along_x := side == Side.NORTH or side == Side.SOUTH
	# North/south walls also cover the corners.
	var length := (inner_size.x + wall_thickness * 2.0) if along_x else inner_size.y
	var inner_length := inner_size.x if along_x else inner_size.y
	var normal_offset := (inner_size.y if along_x else inner_size.x) * 0.5 + wall_thickness * 0.5
	var side_sign := -1.0 if side == Side.NORTH or side == Side.WEST else 1.0

	# Collect this side's openings as [start, end] along the wall.
	var gaps: Array[Vector2] = []
	for opening in openings:
		if int(opening.x) != side:
			continue
		if opening.z >= inner_length - 0.01:
			return # Fully open side (corridor end).
		gaps.append(Vector2(opening.y - opening.z * 0.5, opening.y + opening.z * 0.5))
	gaps.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)

	var normal_pos := side_sign * normal_offset
	var cursor := -length * 0.5
	for gap in gaps:
		_add_wall_segment(along_x, normal_pos, cursor, gap.x, 0.0, height)
		_add_wall_segment(along_x, normal_pos, gap.x, gap.y, opening_height, height)
		cursor = gap.y
	_add_wall_segment(along_x, normal_pos, cursor, length * 0.5, 0.0, height)


func _add_wall_segment(along_x: bool, normal_pos: float, from: float, to: float, bottom: float, top: float) -> void:
	var span := to - from
	if span <= 0.01 or top - bottom <= 0.01:
		return
	var mid := (from + to) * 0.5
	var y := (bottom + top) * 0.5
	if along_x:
		_add_box(Vector3(mid, y, normal_pos), Vector3(span, top - bottom, wall_thickness), wall_material)
	else:
		_add_box(Vector3(normal_pos, y, mid), Vector3(wall_thickness, top - bottom, span), wall_material)


func _add_box(center: Vector3, box_size: Vector3, material: Material) -> void:
	var box := BoxObstacle.new()
	box.size = box_size
	box.surface_material = material
	box.position = center
	box.set_meta(&"crypt_room_generated", true)
	add_child(box, false, Node.INTERNAL_MODE_BACK)


func _is_generated(node: Node) -> bool:
	return node.has_meta(&"crypt_room_generated")
