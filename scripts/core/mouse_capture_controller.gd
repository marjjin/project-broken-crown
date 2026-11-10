class_name MouseCaptureController
extends Node
## Owns the mouse capture state: Escape releases it, left click captures it.
##
## Browsers only grant pointer lock in response to a user gesture, so on the
## web build we never try to capture on startup; the HUD asks for a click.

@export var capture_on_start: bool = true


func _ready() -> void:
	if capture_on_start and not OS.has_feature("web"):
		_set_captured(true)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(InputActions.RELEASE_MOUSE):
		_set_captured(false)
		get_viewport().set_input_as_handled()
		return

	var mouse_button := event as InputEventMouseButton
	if mouse_button != null and mouse_button.pressed \
			and mouse_button.button_index == MOUSE_BUTTON_LEFT \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_set_captured(true)
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	# Avoid a "stuck" cursor when the user alt-tabs or switches browser tabs.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_set_captured(false)


func _set_captured(captured: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE
