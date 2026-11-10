class_name Hud
extends CanvasLayer
## Minimal debug HUD: control reference plus runtime status.
## The status text refreshes a few times per second, not every frame.

const REFRESH_INTERVAL := 0.25

@export var player: PlayerController
@export var instructions_label: Label
@export var status_label: Label
@export var capture_hint: Control

var _refresh_timer := 0.0
var _platform_name := ""
var _renderer_name := ""


func _ready() -> void:
	if instructions_label == null or status_label == null or capture_hint == null:
		push_error("Hud: label references are not assigned; HUD disabled.")
		set_process(false)
		return
	if player == null:
		push_warning("Hud: no player assigned; player status will not be shown.")

	_platform_name = "Web" if OS.has_feature("web") else OS.get_name()
	_renderer_name = "%s (%s)" % [
		ProjectSettings.get_setting("rendering/renderer/rendering_method", "?"),
		RenderingServer.get_video_adapter_name()]
	instructions_label.text = _build_instructions()
	_refresh_status()


func _process(delta: float) -> void:
	capture_hint.visible = Input.mouse_mode != Input.MOUSE_MODE_CAPTURED
	_refresh_timer -= delta
	if _refresh_timer <= 0.0:
		_refresh_timer = REFRESH_INTERVAL
		_refresh_status()


func _build_instructions() -> String:
	var jump_enabled := player != null and player.settings != null and player.settings.jump_enabled
	return "\n".join([
		"CONTROLES",
		"WASD / Stick izq. - Moverse",
		"Mouse / Stick der. - Camara",
		"Shift / L3 - Correr",
		"Espacio / A - Saltar" + ("" if jump_enabled else " (desactivado)"),
		"Esc - Liberar mouse   |   Clic - Capturar",
	])


func _refresh_status() -> void:
	var lines: PackedStringArray = [
		"ESTADO: en ejecucion",
		"FPS: %d" % Engine.get_frames_per_second(),
		"Plataforma: %s" % _platform_name,
		"Render: %s" % _renderer_name,
		"Mouse: %s" % ("capturado" if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else "libre"),
		"Gamepads: %d" % Input.get_connected_joypads().size(),
	]
	if is_instance_valid(player):
		lines.append("Velocidad: %.1f m/s" % player.get_horizontal_speed())
		lines.append("En suelo: %s   Corriendo: %s" % [
			_yes_no(player.is_on_floor()), _yes_no(player.is_sprinting())])
	status_label.text = "\n".join(lines)


static func _yes_no(value: bool) -> String:
	return "si" if value else "no"
