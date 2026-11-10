class_name InputActions
## Central catalogue of input action names.
##
## Gameplay code references these constants instead of raw strings so a typo
## becomes a parse error instead of a silently dead binding.

const MOVE_FORWARD: StringName = &"move_forward"
const MOVE_BACK: StringName = &"move_back"
const MOVE_LEFT: StringName = &"move_left"
const MOVE_RIGHT: StringName = &"move_right"

const LOOK_LEFT: StringName = &"look_left"
const LOOK_RIGHT: StringName = &"look_right"
const LOOK_UP: StringName = &"look_up"
const LOOK_DOWN: StringName = &"look_down"

const SPRINT: StringName = &"sprint"
const JUMP: StringName = &"jump"
const RELEASE_MOUSE: StringName = &"release_mouse"
