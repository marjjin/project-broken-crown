class_name ActionAnimator
extends Node
## Presentation contract used by combat logic. Gameplay timing (hit windows,
## i-frames) is driven by data, not by these methods, so swapping this for an
## AnimationPlayer/AnimationTree implementation will not change game rules.
##
## Subclasses override what they support; unsupported calls are no-ops.


func play_light_attack(_combo_index: int, _duration: float) -> void:
	pass


func play_heavy_attack(_duration: float) -> void:
	pass


func play_dodge(_duration: float, _backwards: bool) -> void:
	pass


## Generic three-phase attack (used by enemies): wind up, strike, settle.
func play_attack(_windup: float, _active: float, _recovery: float) -> void:
	pass


## `interrupting` = false is a hit that does not break the current action
## (hyper armor / stagger immunity): flash only, keep the pose.
func play_hit(_interrupting: bool = true) -> void:
	pass


func play_death() -> void:
	pass


## Returns to the neutral pose immediately (interruptions, respawn).
func reset_pose() -> void:
	pass
