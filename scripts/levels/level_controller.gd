class_name LevelController
extends Node3D
## Level-wide setup: places the player at the start point and announces the
## level. Gameplay objects (doors, checkpoints, exits) are self-contained and
## talk through GameSession, so this script stays small.

@export var level_id: StringName = &"level"
@export var display_name: String = "Nivel"
@export_multiline var intro_text: String = ""
@export var player: PlayerController
@export var player_start: Node3D
## Seconds before the intro banner is shown (lets the scene settle first).
@export_range(0.0, 10.0, 0.1, "suffix:s") var intro_delay: float = 0.8


func _ready() -> void:
	if player == null or player_start == null:
		push_error("LevelController '%s': player and player_start must be assigned." % name)
		return
	player.set_spawn_point(player_start.global_transform)
	player.respawn()
	GameSessionState.instance().start_level(level_id)
	if not intro_text.is_empty():
		get_tree().create_timer(intro_delay).timeout.connect(
			func() -> void: GameSessionState.instance().notify(display_name, intro_text))
