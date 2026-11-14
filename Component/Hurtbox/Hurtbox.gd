extends Area2D
class_name Hurtbox

@export var character : CharacterBody2D

@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D
@onready var cool_down: Timer = $Timer

var current_area : Area2D
## 最後にダメージを与えてきた Hitbox(被弾の向きを調べるのに使う)。もう消えていることもある
var last_hitbox : Hitbox

signal recieved_damage(damage : int)

func _apply_damage(hitbox : Hitbox) -> void:
	if hitbox:
		last_hitbox = hitbox
		recieved_damage.emit(hitbox.damage)
		hitbox.damage_dealt.emit(self)

func apply_extra_damage(amount : float) -> void:
	recieved_damage.emit(amount, Vector2.ZERO)

## 持ち主(Character)が ignores_hit(area) で true を返したら、その弾には当たらない(自機の、理不尽な被弾を防ぐ)
func _ignored(area : Area2D) -> bool:
	return character != null and character.has_method("ignores_hit") and character.ignores_hit(area)

func _on_area_entered(area: Area2D) -> void:
	if area is Hitbox and not _ignored(area):
		current_area = area
		_apply_damage(area)

func _on_area_exited(area: Area2D) -> void:
	if area == current_area:
		current_area = null
		cool_down.stop()

func _on_cool_down_timeout() -> void:
	if current_area == null or _ignored(current_area):
		return
	
	_apply_damage(current_area)
