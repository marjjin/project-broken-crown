class_name MovementSettings
extends Resource
## Tunable movement parameters, kept as a Resource so they can be edited,
## duplicated per character and swapped without touching controller code.

@export_group("Ground")
@export_range(0.0, 20.0, 0.1, "suffix:m/s") var walk_speed: float = 4.5
@export_range(0.0, 30.0, 0.1, "suffix:m/s") var sprint_speed: float = 7.5
@export_range(0.0, 200.0, 0.5, "suffix:m/s²") var acceleration: float = 30.0
@export_range(0.0, 200.0, 0.5, "suffix:m/s²") var deceleration: float = 40.0
## Fraction of acceleration/deceleration available while airborne.
@export_range(0.0, 1.0, 0.05) var air_control: float = 0.35

@export_group("Rotation")
## Higher values turn the character toward its movement direction faster.
@export_range(0.0, 40.0, 0.5) var rotation_speed: float = 12.0

@export_group("Gravity")
## Multiplier over the project/area gravity. >1 gives snappier, less floaty jumps.
@export_range(0.0, 5.0, 0.05) var gravity_scale: float = 1.6
@export_range(0.0, 100.0, 0.5, "suffix:m/s") var max_fall_speed: float = 40.0

@export_group("Jump")
## Set to false to remove jumping without touching any code.
@export var jump_enabled: bool = true
## Desired apex height; the launch velocity is derived from gravity.
@export_range(0.0, 5.0, 0.05, "suffix:m") var jump_height: float = 1.1
