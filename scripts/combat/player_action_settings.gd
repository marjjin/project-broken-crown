class_name PlayerActionSettings
extends Resource
## Tunables for non-weapon actions: dodge, hit stun and respawn.

@export_group("Dodge")
@export_range(0.0, 200.0, 1.0) var dodge_stamina_cost: float = 20.0
@export_range(0.05, 2.0, 0.01, "suffix:s") var dodge_duration: float = 0.42
@export_range(0.0, 15.0, 0.1, "suffix:m") var dodge_distance: float = 4.2
## Invulnerability window, in seconds from the start of the dodge.
@export_range(0.0, 2.0, 0.01, "suffix:s") var dodge_invulnerability_start: float = 0.04
@export_range(0.0, 2.0, 0.01, "suffix:s") var dodge_invulnerability_end: float = 0.3
## Minimum time after a dodge ends before another one can start.
@export_range(0.0, 2.0, 0.01, "suffix:s") var dodge_cooldown: float = 0.2
## Without movement input: true = step backwards, false = roll forward.
@export var neutral_dodge_backwards: bool = true

@export_group("Reactions")
## Time the player loses control after taking a hit.
@export_range(0.0, 2.0, 0.01, "suffix:s") var stagger_duration: float = 0.4
@export_range(0.0, 30.0, 0.1, "suffix:s") var respawn_delay: float = 3.0


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if dodge_invulnerability_start >= dodge_invulnerability_end:
		errors.append("dodge invulnerability window must satisfy start < end")
	if dodge_invulnerability_end > dodge_duration:
		errors.append("dodge invulnerability must end before the dodge does")
	return errors
