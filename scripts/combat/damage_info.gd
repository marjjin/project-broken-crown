class_name DamageInfo
extends RefCounted
## Immutable-by-convention description of a single hit, passed from the
## attacker to the target. Extend with knockback, damage type, etc. later.

var amount: float
## Entity that dealt the damage (may be null for environmental damage).
var source: Node
## Debug/analytics name of the attack, e.g. &"light_2".
var attack_name: StringName


func _init(p_amount: float = 0.0, p_source: Node = null, p_attack_name: StringName = &"") -> void:
	amount = p_amount
	source = p_source
	attack_name = p_attack_name
