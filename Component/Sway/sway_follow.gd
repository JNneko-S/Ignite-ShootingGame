extends Node
class_name SwayFollow
## 背景の横揺れ(BackgroundSway)に、敵の位置を合わせる部品。敵(Enemy)の子に置く。
## 地面の上にいる敵(戦車のボスなど)が、背景と一緒に横へずれるので、地面に乗っているように見える。
## 移動パターンで動いている途中でも効く(Enemy の Sway Offset に入れる)。
##
## GroundUnit(地上の雑魚)は、地面に乗って自分でついていくので、これは要らない。

## 背景の横揺れに対する倍率。地面の層(BackgroundSway の Depth Scales で地面に入れた値)と同じにすると、地面とぴったり動く
@export var depth : float = 0.7

var _sway : BackgroundSway
var _enemy : Enemy

func _ready() -> void:
	_enemy = get_parent() as Enemy
	if _enemy == null:
		push_warning("SwayFollow: 親が Enemy ではありません")

func _process(_delta : float) -> void:
	if _enemy == null:
		return
	if not is_instance_valid(_sway):
		_sway = get_tree().get_first_node_in_group("background_sway") as BackgroundSway
		if _sway == null:
			return
	_enemy.sway_offset = Vector2(_sway.current_offset * depth, 0.0)
