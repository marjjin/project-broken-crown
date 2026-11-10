class_name DamagePulseTrap
extends Node3D
## Test hazard that periodically damages whatever stands on it. It exists to
## verify dodge invulnerability and player damage/death, reusing the same
## Hitbox pipeline that enemies will use.
##
## Cycle: idle -> warning (pad glows) -> active (hitbox on) -> idle ...

@export var hitbox: Hitbox
@export var pad_mesh: MeshInstance3D
@export_range(0.0, 500.0, 1.0) var damage: float = 15.0
@export_range(0.2, 20.0, 0.1, "suffix:s") var cycle_time: float = 2.5
@export_range(0.0, 5.0, 0.05, "suffix:s") var warning_time: float = 0.6
@export_range(0.02, 2.0, 0.01, "suffix:s") var active_time: float = 0.15

@export_group("Colors")
@export var idle_color: Color = Color(0.25, 0.05, 0.05)
@export var warning_color: Color = Color(0.9, 0.45, 0.05)
@export var active_color: Color = Color(1.0, 0.1, 0.05)

var _time := 0.0
var _material: StandardMaterial3D


func _ready() -> void:
	if hitbox == null:
		push_error("DamagePulseTrap '%s': no hitbox assigned; trap disabled." % get_path())
		set_physics_process(false)
		return
	hitbox.hit_detected.connect(_on_hit_detected)
	if pad_mesh != null:
		_material = StandardMaterial3D.new()
		_material.emission_enabled = true
		pad_mesh.material_override = _material
	_apply_color(idle_color)


func _physics_process(delta: float) -> void:
	_time = fmod(_time + delta, cycle_time)
	var active_start := cycle_time - active_time
	var warning_start := active_start - warning_time
	if _time >= active_start:
		if not hitbox.is_active():
			hitbox.activate()
			_apply_color(active_color)
	else:
		if hitbox.is_active():
			hitbox.deactivate()
		_apply_color(warning_color if _time >= warning_start else idle_color)


func _on_hit_detected(target: Hurtbox) -> void:
	target.receive_hit(DamageInfo.new(damage, self, &"trap_pulse"))


func _apply_color(color: Color) -> void:
	if _material == null or _material.albedo_color == color:
		return
	_material.albedo_color = color
	_material.emission = color
