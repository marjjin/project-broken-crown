class_name WeaponData
extends Resource
## Data-only definition of a melee weapon. Combat logic reads these values;
## new weapons are new .tres files, not new code.
##
## Timeline of an attack (seconds from its start):
##   0 ── hit_start ══ hitbox active ══ hit_end ── duration ── duration + recovery_time
##   [ committed: no other action can start      ][ recovery: chain / cancel allowed ]

@export var id: StringName = &"weapon"
@export var display_name: String = "Arma"

@export_group("Damage")
@export_range(0.0, 1000.0, 0.5) var light_damage: float = 12.0
@export_range(0.0, 1000.0, 0.5) var heavy_damage: float = 30.0
@export_range(0.0, 200.0, 1.0) var heavy_stamina_cost: float = 30.0
## Damage multiplier per light-combo step; its size is the combo length.
@export var light_combo_multipliers: PackedFloat32Array = PackedFloat32Array([1.0, 1.0, 1.5])

@export_group("Reach")
## Depth of the hit area in front of the character.
@export_range(0.2, 5.0, 0.05, "suffix:m") var reach: float = 1.6
@export_range(0.2, 5.0, 0.05, "suffix:m") var hit_width: float = 1.4
@export_range(0.2, 5.0, 0.05, "suffix:m") var hit_height: float = 1.4

@export_group("Light Attack")
@export_range(0.05, 3.0, 0.01, "suffix:s") var light_duration: float = 0.45
@export_range(0.0, 3.0, 0.01, "suffix:s") var light_hit_start: float = 0.14
@export_range(0.0, 3.0, 0.01, "suffix:s") var light_hit_end: float = 0.3

@export_group("Heavy Attack")
@export_range(0.05, 3.0, 0.01, "suffix:s") var heavy_duration: float = 0.9
@export_range(0.0, 3.0, 0.01, "suffix:s") var heavy_hit_start: float = 0.5
@export_range(0.0, 3.0, 0.01, "suffix:s") var heavy_hit_end: float = 0.68

@export_group("Movement")
## Movement speed while attacking, as a fraction of normal speed
## (1 = move freely, 0 = rooted in place until the recovery window).
@export_range(0.0, 1.0, 0.05) var attack_move_speed_multiplier: float = 1.0

@export_group("Combo")
## From this time into an attack, a new attack/dodge input is buffered and
## executed as soon as the attack ends. Earlier presses are ignored.
@export_range(0.0, 3.0, 0.01, "suffix:s") var combo_input_open: float = 0.15
## Window after an attack ends during which the next light hit continues the
## combo (and any action can start). After it, the combo resets.
@export_range(0.0, 3.0, 0.01, "suffix:s") var recovery_time: float = 0.35


func get_combo_length() -> int:
	return maxi(light_combo_multipliers.size(), 1)


func get_light_damage(combo_index: int) -> float:
	if light_combo_multipliers.is_empty():
		return light_damage
	var index := clampi(combo_index, 0, light_combo_multipliers.size() - 1)
	return light_damage * light_combo_multipliers[index]


## Returns human-readable configuration errors (empty when valid).
func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if light_hit_start >= light_hit_end or light_hit_end > light_duration:
		errors.append("light hit window must satisfy start < end <= duration")
	if heavy_hit_start >= heavy_hit_end or heavy_hit_end > heavy_duration:
		errors.append("heavy hit window must satisfy start < end <= duration")
	return errors
