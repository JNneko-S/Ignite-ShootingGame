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
		recieved_damage.emit(_scaled_damage(hitbox))
		hitbox.damage_dealt.emit(self)

## 自機のショットは、自機が近くにいるほど強くなる(Player.close_damage_scale_at)。
## ダメージは整数なので、端数は確率で切り上げて、平均が倍率どおりになるようにする
func _scaled_damage(hitbox : Hitbox) -> int:
	var damage := hitbox.damage
	if hitbox is EnemyBullet and hitbox.damage_source_type == Hitbox.DamageSourceType.Player:
		# イグナイトの反射弾: ANOTHER のボス・中ボスには、効きにくい(端数は確率で切り上げ)
		var scale := HazardRank.reflect_damage_scale(self)
		if scale < 1.0:
			var scaled_reflect := damage * scale
			var whole_reflect := floori(scaled_reflect)
			return maxi(whole_reflect + (1 if randf() < scaled_reflect - whole_reflect else 0), 1)
		return damage
	if not (hitbox is Bullet) or hitbox.damage_source_type != Hitbox.DamageSourceType.Player:
		return damage
	var base : float = (hitbox as Bullet).damage_against(self) # 中心ねらいの弾は、当たった所で威力が変わる
	var player := get_tree().get_first_node_in_group("player")
	if player == null or not player.has_method("close_damage_scale_at"):
		return maxi(roundi(base), 1)
	var bonus : float = player.close_damage_scale_at(global_position)
	var scaled := base * bonus
	var whole := floori(scaled)
	return maxi(whole + (1 if randf() < scaled - whole else 0), 1)

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
