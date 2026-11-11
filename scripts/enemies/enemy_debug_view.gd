class_name EnemyDebugView
extends Node3D
## Optional debug overlay: state label, detection radius, field of view and
## (if a navigation agent is assigned) the current path. Toggle with F3.
## Drawing is throttled and transitions are logged once each (never per frame).

const REDRAW_INTERVAL := 0.1
const RING_SEGMENTS := 48
const STATE_COLORS := {
	EnemyBrain.State.IDLE: Color(0.4, 0.9, 0.4),
	EnemyBrain.State.PATROL: Color(0.4, 0.9, 0.4),
	EnemyBrain.State.CHASE: Color(1.0, 0.85, 0.2),
	EnemyBrain.State.RETURN: Color(0.4, 0.7, 1.0),
	EnemyBrain.State.ATTACK: Color(1.0, 0.25, 0.2),
	EnemyBrain.State.HURT: Color(1.0, 0.5, 0.9),
	EnemyBrain.State.DEAD: Color(0.5, 0.5, 0.5),
}

@export var brain: EnemyBrain
@export var body: EnemyCharacter
@export var perception: EnemyPerception
## Optional: draws the current navigation path.
@export var navigation_agent: NavigationAgent3D
@export var show_on_start: bool = false
## Prints one line per state transition.
@export var log_transitions: bool = false

var _shown := false
var _redraw_timer := 0.0
var _label: Label3D
var _lines: MeshInstance3D
var _mesh: ImmediateMesh


func _ready() -> void:
	if brain == null or body == null or perception == null:
		push_warning("EnemyDebugView '%s': brain, body and perception are required; debug view disabled." % get_path())
		set_process(false)
		set_process_unhandled_input(false)
		return
	_build_nodes()
	brain.state_changed.connect(_on_state_changed)
	_set_shown(show_on_start)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(InputActions.TOGGLE_ENEMY_DEBUG):
		_set_shown(not _shown)


func _process(delta: float) -> void:
	_redraw_timer -= delta
	if _redraw_timer > 0.0:
		return
	_redraw_timer = REDRAW_INTERVAL
	_refresh_label()
	_redraw_lines()


func _set_shown(shown: bool) -> void:
	_shown = shown
	_label.visible = shown
	_lines.visible = shown
	set_process(shown)
	_redraw_timer = 0.0


func _on_state_changed(previous: EnemyBrain.State, current: EnemyBrain.State) -> void:
	if log_transitions:
		print("[%s] %s -> %s" % [body.name, EnemyBrain.STATE_NAMES[previous], EnemyBrain.STATE_NAMES[current]])
	if _shown:
		_refresh_label()


func _refresh_label() -> void:
	var seen := "VE AL JUGADOR" if perception.can_see_target() else ""
	var hp := ""
	if brain.health != null:
		hp = "HP %d/%d" % [ceili(brain.health.get_current()), ceili(brain.health.max_health)]
	_label.text = "%s  %s\n%s" % [brain.get_state_name(), hp, seen]
	_label.modulate = STATE_COLORS[brain.get_state()]


func _redraw_lines() -> void:
	var data := body.data
	var color: Color = STATE_COLORS[brain.get_state()]
	var center := body.global_position + Vector3.UP * 0.05
	_mesh.clear_surfaces()
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES)

	# Detection radius.
	_mesh.surface_set_color(color)
	for i in RING_SEGMENTS:
		var a := TAU * i / RING_SEGMENTS
		var b := TAU * (i + 1) / RING_SEGMENTS
		_mesh.surface_add_vertex(center + Vector3(cos(a), 0.0, sin(a)) * data.detection_radius)
		_mesh.surface_add_vertex(center + Vector3(cos(b), 0.0, sin(b)) * data.detection_radius)

	# Field of view edges.
	var facing := body.get_facing_direction()
	var half_fov := deg_to_rad(data.field_of_view_degrees * 0.5)
	for side: float in [-1.0, 1.0]:
		_mesh.surface_add_vertex(center)
		_mesh.surface_add_vertex(center + facing.rotated(Vector3.UP, half_fov * side) * data.detection_radius)

	# Navigation path.
	if navigation_agent != null:
		var path := navigation_agent.get_current_navigation_path()
		_mesh.surface_set_color(Color(0.3, 0.8, 1.0))
		for i in range(1, path.size()):
			_mesh.surface_add_vertex(path[i - 1] + Vector3.UP * 0.1)
			_mesh.surface_add_vertex(path[i] + Vector3.UP * 0.1)

	_mesh.surface_end()


func _build_nodes() -> void:
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = 36
	_label.outline_size = 8
	add_child(_label)

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = true

	_mesh = ImmediateMesh.new()
	_lines = MeshInstance3D.new()
	_lines.mesh = _mesh
	_lines.material_override = material
	_lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Lines are drawn in world space, so the instance must not follow the body.
	_lines.top_level = true
	add_child(_lines)
	_lines.global_transform = Transform3D.IDENTITY
