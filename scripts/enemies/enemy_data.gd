class_name EnemyData
extends Resource
## All design-facing numbers for an enemy type. Scripts read from here; new
## enemy variants are new .tres files.
##
## Attack timeline (seconds):  windup ── active (hitbox on) ── recovery ── then cooldown

@export var id: StringName = &"enemy"
@export var display_name: String = "Enemigo"

@export_group("Health")
@export_range(1.0, 10000.0, 1.0) var max_health: float = 80.0

@export_group("Movement")
@export_range(0.0, 20.0, 0.1, "suffix:m/s") var patrol_speed: float = 1.8
@export_range(0.0, 20.0, 0.1, "suffix:m/s") var chase_speed: float = 4.0
@export_range(0.0, 200.0, 0.5, "suffix:m/s²") var acceleration: float = 20.0
@export_range(0.0, 40.0, 0.5) var rotation_speed: float = 8.0

@export_group("Attack")
@export_range(0.0, 1000.0, 0.5) var attack_damage: float = 20.0
## Distance (center to center) at which the enemy starts an attack.
@export_range(0.3, 10.0, 0.05, "suffix:m") var attack_range: float = 1.8
## Depth of the weapon hit area in front of the body.
@export_range(0.2, 10.0, 0.05, "suffix:m") var attack_reach: float = 1.7
@export_range(0.2, 5.0, 0.05, "suffix:m") var attack_width: float = 1.2
@export_range(0.2, 5.0, 0.05, "suffix:m") var attack_height: float = 1.4
@export_range(0.0, 3.0, 0.01, "suffix:s") var attack_windup: float = 0.6
@export_range(0.01, 3.0, 0.01, "suffix:s") var attack_active: float = 0.18
@export_range(0.0, 3.0, 0.01, "suffix:s") var attack_recovery: float = 0.6
## Minimum time between the end of one attack and the start of the next.
@export_range(0.0, 10.0, 0.05, "suffix:s") var attack_cooldown: float = 1.2
## Keep turning toward the target during the windup (false = committed aim).
@export var track_target_during_windup: bool = true

@export_group("Perception")
@export_range(0.0, 100.0, 0.5, "suffix:m") var detection_radius: float = 12.0
## Full horizontal field of view.
@export_range(1.0, 360.0, 1.0, "suffix:°") var field_of_view_degrees: float = 110.0
## Within this distance the target is noticed regardless of facing (line of
## sight is still required). 0 disables proximity detection.
@export_range(0.0, 20.0, 0.1, "suffix:m") var proximity_radius: float = 2.0
@export_range(0.0, 3.0, 0.05, "suffix:m") var eye_height: float = 1.6
## Seconds between vision checks (raycasts are not done every frame).
@export_range(0.02, 1.0, 0.01, "suffix:s") var perception_interval: float = 0.15

@export_group("Chase")
## Give up when the target gets farther than this from the enemy.
@export_range(0.0, 200.0, 0.5, "suffix:m") var lose_target_distance: float = 18.0
## Give up when the enemy gets farther than this from its home/patrol area.
@export_range(0.0, 200.0, 0.5, "suffix:m") var leash_distance: float = 25.0
## Seconds without seeing the target before giving up (it keeps heading to the last known position meanwhile).
@export_range(0.0, 30.0, 0.1, "suffix:s") var lose_sight_time: float = 3.0
## Seconds an unreachable destination is tolerated before giving up.
@export_range(0.0, 30.0, 0.1, "suffix:s") var unreachable_give_up_time: float = 2.0

@export_group("Patrol")
@export_range(0.0, 30.0, 0.1, "suffix:s") var patrol_wait_time: float = 1.5
@export_range(0.1, 5.0, 0.05, "suffix:m") var arrival_tolerance: float = 0.6

@export_group("Hit Reactions")
@export var can_be_staggered: bool = true
## Hits below this damage never interrupt.
@export_range(0.0, 1000.0, 0.5) var stagger_damage_threshold: float = 0.0
## If true, hits during an attack do not interrupt it (hyper armor).
@export var armored_while_attacking: bool = false
@export_range(0.0, 5.0, 0.01, "suffix:s") var hurt_duration: float = 0.45
## After being staggered, further hits cannot stagger for this long (anti stun-lock).
@export_range(0.0, 10.0, 0.05, "suffix:s") var stagger_immunity_time: float = 1.2
## Seconds the body stays after death; 0 keeps it forever.
@export_range(0.0, 120.0, 0.5, "suffix:s") var corpse_duration: float = 6.0


func get_attack_duration() -> float:
	return attack_windup + attack_active + attack_recovery


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if attack_range > attack_reach + 0.35 + 0.4:
		errors.append("attack_range is larger than what the hitbox can reach")
	if proximity_radius > detection_radius:
		errors.append("proximity_radius should not exceed detection_radius")
	if lose_target_distance < detection_radius:
		errors.append("lose_target_distance below detection_radius causes chase flicker")
	return errors
