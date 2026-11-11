class_name TorchFlicker
extends OmniLight3D
## Cheap fire flicker: a looping tween between a few random energies, built
## once at startup and run by the engine (no per-frame script).

@export_range(0.0, 1.0, 0.01) var flicker_amount: float = 0.22
@export_range(2, 12) var steps: int = 6


func _ready() -> void:
	var base := light_energy
	var tween := create_tween().set_loops()
	for i in steps:
		var energy := base * (1.0 + randf_range(-flicker_amount, flicker_amount))
		tween.tween_property(self, "light_energy", energy, randf_range(0.08, 0.22))
	tween.tween_property(self, "light_energy", base, 0.15)
