@tool
class_name BoxObstacle
extends StaticBody3D
## Reusable static box whose mesh and collision are generated from one `size`,
## so the visual and the physics shape can never drift apart.
##
## Generated children are added as *internal* nodes: they are not saved into
## the scene and are not duplicated when the node is copied in the editor.

const MIN_SIZE := 0.05

@export var size: Vector3 = Vector3.ONE:
	set(value):
		size = Vector3(maxf(value.x, MIN_SIZE), maxf(value.y, MIN_SIZE), maxf(value.z, MIN_SIZE))
		_apply_size()

@export var color: Color = Color(0.42, 0.41, 0.4):
	set(value):
		color = value
		_apply_material()

## Optional material; when set it replaces the flat `color` material.
@export var surface_material: Material:
	set(value):
		surface_material = value
		_apply_material()

## false = collision only (invisible walls that keep the player in bounds).
@export var mesh_visible: bool = true:
	set(value):
		mesh_visible = value
		if _mesh_instance != null:
			_mesh_instance.visible = value

var _mesh: BoxMesh
var _shape: BoxShape3D
var _mesh_instance: MeshInstance3D
var _flat_material: StandardMaterial3D


func _ready() -> void:
	_mesh = BoxMesh.new()
	_shape = BoxShape3D.new()

	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = _mesh
	_mesh_instance.visible = mesh_visible
	add_child(_mesh_instance, false, Node.INTERNAL_MODE_FRONT)

	var collision := CollisionShape3D.new()
	collision.shape = _shape
	add_child(collision, false, Node.INTERNAL_MODE_FRONT)

	_apply_size()
	_apply_material()


func _apply_size() -> void:
	# Setters run while the scene is loading, before _ready() builds the children.
	if _mesh == null:
		return
	_mesh.size = size
	_shape.size = size


func _apply_material() -> void:
	if _mesh_instance == null:
		return
	if surface_material != null:
		_mesh_instance.material_override = surface_material
		return
	if _flat_material == null:
		_flat_material = StandardMaterial3D.new()
		_flat_material.roughness = 0.9
	_flat_material.albedo_color = color
	_mesh_instance.material_override = _flat_material
