extends Node2D
class_name LockOnReticle
## ロックショットの照準。ロックした敵に、回る四隅の枠を描く。
## Player が自分の子として作る。top_level なので、画面(ワールド)の座標で描く。

## ロックしている敵(Player が毎フレーム設定する)
var targets : Array[Node2D] = []
## 照準の大きさ(px)
var size : float = 14.0
var color : Color = Color(1.0, 0.35, 0.3)

var _spin : float = 0.0
## ロックした瞬間の、枠が縮んでくる演出(敵ごとの経過時間)
var _lock_age : Dictionary = {}

func _ready() -> void:
	top_level = true
	z_index = 20

func _process(delta : float) -> void:
	_spin += delta * 3.0
	targets = targets.filter(func(t) -> bool: return is_instance_valid(t))
	for target in targets:
		_lock_age[target] = _lock_age.get(target, 0.0) + delta
	for key in _lock_age.keys():
		if not is_instance_valid(key) or not targets.has(key): # 倒された敵(消えたもの)も外す
			_lock_age.erase(key)
	queue_redraw()

func _draw() -> void:
	for target in targets:
		if not is_instance_valid(target):
			continue
		var age : float = _lock_age.get(target, 0.0)
		var grow := 1.0 + 1.5 * maxf(0.0, 1.0 - age / 0.15) # ロックした直後は大きく、すぐ縮む
		_draw_reticle(to_local(target.global_position), size * grow, _spin)

## 四隅のカギ型の枠と、中心の点
func _draw_reticle(center : Vector2, half : float, angle : float) -> void:
	var arm := half * 0.45
	for i in 4:
		var corner := Vector2(half, half).rotated(angle + PI / 2.0 * i)
		var along := corner.normalized().rotated(PI * 0.75)
		var across := corner.normalized().rotated(-PI * 0.75)
		draw_line(center + corner, center + corner + along * arm, color, 2.0)
		draw_line(center + corner, center + corner + across * arm, color, 2.0)
	draw_circle(center, 1.5, color)
