extends Node
class_name TurretAim
## 砲塔を自機へ向ける部品。敵の子に置く。
## Muzzle(EnemyShooterComponent など)を砲身の先へ動かすので、弾は砲口から出る。

## 回す砲塔の絵
@export var turret : Node2D
## 絵の砲身の向き(度)。0 で右、90 で下
@export var art_angle_deg : float = 0.0
## 回る速さ(度/秒)。0 ならすぐに向く。遅いほど、よけたあとで狙いが遅れてくる
@export var turn_speed : float = 120.0
## 自機がいないときに向ける向き(度。90 で下)
@export var idle_angle_deg : float = 90.0
## 砲身の先へ動かすノード(空なら動かさない)と、砲塔の中心から砲口までの長さ(px)
@export var muzzle : Node2D
@export var barrel_length : float = 12.0

var _angle : float

func _ready() -> void:
	_angle = deg_to_rad(idle_angle_deg)

func _process(delta : float) -> void:
	if turret == null:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var wanted := deg_to_rad(idle_angle_deg)
	if player and player.visible:
		wanted = turret.global_position.direction_to(player.global_position).angle()
	if turn_speed <= 0.0:
		_angle = wanted
	else:
		_angle = rotate_toward(_angle, wanted, deg_to_rad(turn_speed) * delta)
	# 左右反転された絵は、砲身の向きも左右反転している
	var art := deg_to_rad(art_angle_deg)
	var sprite := turret as Sprite2D
	if sprite and sprite.flip_h:
		art = PI - art
	turret.global_rotation = _angle - art
	if muzzle:
		muzzle.global_position = turret.global_position + Vector2.from_angle(_angle) * barrel_length
