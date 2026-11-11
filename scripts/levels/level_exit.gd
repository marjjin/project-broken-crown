class_name LevelExit
extends Area3D
## Provisional end of a level: when the player walks in, the level is marked
## completed and a closing message is shown. The player stays in the scene
## (the next region is not loaded yet).
##
## Expected setup: collision mask = player layer (2), monitoring on.

signal exit_reached

@export var level_id: StringName = &"level"
@export var title: String = "Fin del nivel"
@export_multiline var message: String = ""

var _triggered := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if _triggered or not body.is_in_group(&"player"):
		return
	_triggered = true
	GameSessionState.instance().complete_level(level_id)
	GameSessionState.instance().notify(title, message)
	exit_reached.emit()
