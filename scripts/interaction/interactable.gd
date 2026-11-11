class_name Interactable
extends Area3D
## The single interaction contract. Doors, statues, inscriptions and pickups
## all own one Interactable and react to its `interacted` signal; none of them
## needs its own detection or input code.
##
## Expected setup: collision layer "interactable" (6), mask 0, monitorable on,
## monitoring off, plus a CollisionShape3D child defining the reachable area.

signal interacted(interactor: Node)
signal availability_changed(available: bool)

## Text shown next to the key hint, e.g. "Abrir", "Leer", "Descansar".
@export var prompt: String = "Interactuar"
@export var enabled: bool = true:
	set(value):
		if enabled == value:
			return
		enabled = value
		availability_changed.emit(value)
## Disable itself after the first successful interaction.
@export var one_shot: bool = false


func can_interact(_interactor: Node) -> bool:
	return enabled


## Returns true if the interaction happened.
func interact(interactor: Node) -> bool:
	if not can_interact(interactor):
		return false
	interacted.emit(interactor)
	if one_shot:
		enabled = false
	return true
