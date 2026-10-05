extends Area2D
class_name Hitbox

@export var damage : int = 0 : set = _set_damage , get = _get_damage

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

@export var is_active : bool = true :
	set(value):
		is_active = value
		if collision_shape:
			collision_shape.disabled = not value

@export var damage_source_type : DamageSourceType = DamageSourceType.Enemy

signal damage_dealt(hurtbox : Hurtbox)

enum DamageSourceType {
	Player,
	Enemy,
	Trap,
}

var is_body_inside : bool = false

func _set_damage(new_dmg : int) -> void:
	damage = new_dmg

func _get_damage() -> int:
	return damage
