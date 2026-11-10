class_name PlaceholderActionAnimator
extends ActionAnimator
## Provisional, tween-based animations for primitive meshes. Used by the
## player and by training dummies until real animated models exist.
##
## `rig` should be a pivot placed at the body's center: it is tilted/rolled.
## `weapon_pivot` (optional) is swung for attacks.

@export var rig: Node3D
@export var weapon_pivot: Node3D
## Mesh that flashes when hit (optional).
@export var flash_target: GeometryInstance3D
@export var flash_color: Color = Color(1.0, 0.15, 0.1, 0.75)
## How far the rig sinks when lying down on death (center height - radius).
@export_range(0.0, 2.0, 0.05, "suffix:m") var death_drop: float = 0.5

var _pose_tween: Tween
var _flash_tween: Tween
var _flash_material: StandardMaterial3D
var _rig_rest_position := Vector3.ZERO
var _weapon_rest_rotation := Vector3.ZERO


func _ready() -> void:
	if rig == null:
		push_error("PlaceholderActionAnimator '%s': 'rig' is not assigned; animations disabled." % get_path())
		return
	_rig_rest_position = rig.position
	if weapon_pivot != null:
		_weapon_rest_rotation = weapon_pivot.rotation
	if flash_target != null:
		_flash_material = StandardMaterial3D.new()
		_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_flash_material.albedo_color = Color(flash_color, 0.0)


func play_light_attack(combo_index: int, duration: float) -> void:
	if weapon_pivot == null:
		return
	var tween := _restart_pose_tween()
	if tween == null:
		return
	# Alternate right-to-left / left-to-right slashes, third hit overhead.
	var from: Vector3
	var to: Vector3
	match combo_index % 3:
		0:
			from = Vector3(0.0, deg_to_rad(-80.0), 0.0)
			to = Vector3(0.0, deg_to_rad(80.0), 0.0)
		1:
			from = Vector3(0.0, deg_to_rad(80.0), 0.0)
			to = Vector3(0.0, deg_to_rad(-80.0), 0.0)
		_:
			from = Vector3(deg_to_rad(100.0), 0.0, 0.0)
			to = Vector3(deg_to_rad(-60.0), 0.0, 0.0)
	tween.tween_property(weapon_pivot, "rotation", from, duration * 0.3) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(weapon_pivot, "rotation", to, duration * 0.3) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(weapon_pivot, "rotation", _weapon_rest_rotation, duration * 0.4)


func play_heavy_attack(duration: float) -> void:
	var tween := _restart_pose_tween()
	if tween == null:
		return
	var windup := duration * 0.5
	var strike := duration * 0.2
	var settle := duration * 0.3
	tween.set_parallel(true)
	if weapon_pivot != null:
		tween.tween_property(weapon_pivot, "rotation", Vector3(deg_to_rad(130.0), 0.0, 0.0), windup) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(rig, "rotation", Vector3(deg_to_rad(12.0), 0.0, 0.0), windup)
	tween.chain()
	if weapon_pivot != null:
		tween.tween_property(weapon_pivot, "rotation", Vector3(deg_to_rad(-75.0), 0.0, 0.0), strike) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.tween_property(rig, "rotation", Vector3(deg_to_rad(-18.0), 0.0, 0.0), strike)
	tween.chain()
	if weapon_pivot != null:
		tween.tween_property(weapon_pivot, "rotation", _weapon_rest_rotation, settle)
	tween.tween_property(rig, "rotation", Vector3.ZERO, settle)


func play_dodge(duration: float, backwards: bool) -> void:
	var tween := _restart_pose_tween()
	if tween == null:
		return
	if backwards:
		tween.tween_property(rig, "rotation", Vector3(deg_to_rad(20.0), 0.0, 0.0), duration * 0.4)
		tween.tween_property(rig, "rotation", Vector3.ZERO, duration * 0.6)
	else:
		# Full forward roll around the body center.
		tween.tween_property(rig, "rotation", Vector3(-TAU, 0.0, 0.0), duration * 0.9) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_callback(func() -> void: rig.rotation = Vector3.ZERO)


func play_hit() -> void:
	_flash()
	var tween := _restart_pose_tween()
	if tween == null:
		return
	tween.tween_property(rig, "rotation", Vector3(deg_to_rad(15.0), 0.0, deg_to_rad(6.0)), 0.06)
	tween.tween_property(rig, "rotation", Vector3.ZERO, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func play_death() -> void:
	_flash()
	var tween := _restart_pose_tween()
	if tween == null:
		return
	tween.set_parallel(true)
	tween.tween_property(rig, "rotation", Vector3(0.0, 0.0, deg_to_rad(90.0)), 0.45) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_property(rig, "position", _rig_rest_position - Vector3(0.0, death_drop, 0.0), 0.45) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func reset_pose() -> void:
	if _pose_tween != null:
		_pose_tween.kill()
	if rig != null:
		rig.rotation = Vector3.ZERO
		rig.position = _rig_rest_position
	if weapon_pivot != null:
		weapon_pivot.rotation = _weapon_rest_rotation


func _restart_pose_tween() -> Tween:
	if rig == null:
		return null
	reset_pose()
	_pose_tween = create_tween()
	return _pose_tween


func _flash() -> void:
	if _flash_material == null:
		return
	if _flash_tween != null:
		_flash_tween.kill()
	flash_target.material_overlay = _flash_material
	_flash_material.albedo_color = flash_color
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash_material, "albedo_color:a", 0.0, 0.25)
	_flash_tween.tween_callback(func() -> void: flash_target.material_overlay = null)
