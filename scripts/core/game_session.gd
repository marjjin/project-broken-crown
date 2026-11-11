class_name GameSessionState
extends Node
## Autoload (registered as "GameSession"): in-memory state of the current play
## session and the event hub for level-wide events. Nothing here is written to
## disk yet; a future save system can serialize these fields.
##
## Objects announce what happened (checkpoint used, item picked up, level
## finished) and the UI listens, so gameplay objects never reference the HUD.
##
## Access it with GameSessionState.instance() rather than the global autoload
## identifier: the static accessor resolves at runtime, so scripts compile even
## when the autoload list is not loaded yet (editor just changed, --script tests).

const AUTOLOAD_PATH := ^"/root/GameSession"

signal notification_requested(title: String, body: String)
signal checkpoint_activated(checkpoint_id: StringName)
signal item_collected(item_id: StringName, display_name: String)
signal level_completed(level_id: StringName)

var current_level: StringName = &""
var active_checkpoint: StringName = &""
var _collected: Dictionary = {}
var _completed_levels: Dictionary = {}


static func instance() -> GameSessionState:
	var tree := Engine.get_main_loop() as SceneTree
	var session: GameSessionState = null
	if tree != null:
		session = tree.root.get_node_or_null(AUTOLOAD_PATH) as GameSessionState
	if session == null:
		push_error("GameSessionState: the 'GameSession' autoload is missing (Project Settings > Globals).")
	return session


func start_level(level_id: StringName) -> void:
	current_level = level_id


func notify(title: String, body: String = "") -> void:
	notification_requested.emit(title, body)


func activate_checkpoint(checkpoint_id: StringName) -> void:
	active_checkpoint = checkpoint_id
	checkpoint_activated.emit(checkpoint_id)


## Returns false if the item was already collected this session.
func collect(item_id: StringName, display_name: String) -> bool:
	if _collected.has(item_id):
		return false
	_collected[item_id] = true
	item_collected.emit(item_id, display_name)
	return true


func has_collected(item_id: StringName) -> bool:
	return _collected.has(item_id)


func complete_level(level_id: StringName) -> void:
	if _completed_levels.has(level_id):
		return
	_completed_levels[level_id] = true
	level_completed.emit(level_id)


func is_level_completed(level_id: StringName) -> bool:
	return _completed_levels.has(level_id)


## Clears the session (new game, tests).
func reset() -> void:
	current_level = &""
	active_checkpoint = &""
	_collected.clear()
	_completed_levels.clear()
