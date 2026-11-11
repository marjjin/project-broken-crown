extends Node
## Autoload that registers the default keyboard + gamepad bindings.
##
## Bindings live in code (instead of project.godot) so they are readable,
## diff-friendly and can later feed a rebinding menu. Any action already
## defined in Project Settings > Input Map is left untouched, so designers can
## still override bindings from the editor without editing this file.
##
## Keys use physical keycodes: WASD stays in the same place on AZERTY/QWERTZ.

const DEFAULT_DEADZONE := 0.2


func _enter_tree() -> void:
	# _enter_tree runs before the main scene exists, so every gameplay node
	# sees the actions already registered in its own _ready().
	_register(InputActions.MOVE_FORWARD, [_key(KEY_W), _axis(JOY_AXIS_LEFT_Y, -1.0)])
	_register(InputActions.MOVE_BACK, [_key(KEY_S), _axis(JOY_AXIS_LEFT_Y, 1.0)])
	_register(InputActions.MOVE_LEFT, [_key(KEY_A), _axis(JOY_AXIS_LEFT_X, -1.0)])
	_register(InputActions.MOVE_RIGHT, [_key(KEY_D), _axis(JOY_AXIS_LEFT_X, 1.0)])

	# Mouse look is read from raw motion events; these cover the right stick.
	_register(InputActions.LOOK_LEFT, [_axis(JOY_AXIS_RIGHT_X, -1.0)])
	_register(InputActions.LOOK_RIGHT, [_axis(JOY_AXIS_RIGHT_X, 1.0)])
	_register(InputActions.LOOK_UP, [_axis(JOY_AXIS_RIGHT_Y, -1.0)])
	_register(InputActions.LOOK_DOWN, [_axis(JOY_AXIS_RIGHT_Y, 1.0)])

	_register(InputActions.SPRINT, [_key(KEY_SHIFT), _button(JOY_BUTTON_LEFT_STICK)])
	_register(InputActions.JUMP, [_key(KEY_SPACE), _button(JOY_BUTTON_A)])
	_register(InputActions.RELEASE_MOUSE, [_key(KEY_ESCAPE)])

	_register(InputActions.ATTACK_LIGHT, [_mouse(MOUSE_BUTTON_LEFT), _button(JOY_BUTTON_RIGHT_SHOULDER)])
	_register(InputActions.ATTACK_HEAVY, [_mouse(MOUSE_BUTTON_RIGHT), _axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)])
	_register(InputActions.DODGE, [_key(KEY_CTRL), _button(JOY_BUTTON_B)])
	_register(InputActions.TOGGLE_ENEMY_DEBUG, [_key(KEY_F3)])


func _register(action: StringName, events: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, DEFAULT_DEADZONE)
	for event: InputEvent in events:
		InputMap.action_add_event(action, event)


static func _key(physical_keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = physical_keycode
	return event


static func _axis(axis: JoyAxis, direction: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = direction
	return event


static func _mouse(button: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	return event


static func _button(button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	return event
