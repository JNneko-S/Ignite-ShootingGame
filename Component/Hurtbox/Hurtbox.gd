extends Area2D
class_name Hurtbox

@export var character : CharacterBody2D

@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D
@onready var cool_down: Timer = $Timer

var current_area : Area2D

signal recieved_damage(damage : int)

func _apply_damage(hitbox : Hitbox) -> void:
	if hitbox:
		recieved_damage.emit(hitbox.damage)
		hitbox.damage_dealt.emit(self)

func apply_extra_damage(amount : float) -> void:
	recieved_damage.emit(amount, Vector2.ZERO)

func _on_area_entered(area: Area2D) -> void:
	if area is Hitbox:
		current_area = area
		_apply_damage(area)

func _on_area_exited(area: Area2D) -> void:
	if area == current_area:
		current_area = null
		cool_down.stop()

func _on_cool_down_timeout() -> void:
	if current_area == null:
		return
	
	_apply_damage(current_area)
