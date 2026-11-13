extends Node2D
class_name GrazeSparks
## グレイズしたことが、ひと目で分かるようにする火花。Player の子に置く(ノード名は GrazeSparks)。
## グレイズした瞬間に、次の2つを出す:
##   ・火花: 弾がかすめた側から、外へ向かって鋭い光の線が飛び散る(金属をこすったような火花)
##   ・弧  : 自機の周りの、弾がかすめた側にだけ、光の弧が一瞬出て広がる(どちら側をかすめたかが分かる)
## 炎(オレンジ)や敵弾(ピンク・青)と見分けやすいように、白〜水色にしてある。
## 絵は使わず、線で描く。敵弾より上に描くので、弾が重なっていても見える。

@export_group("火花")
## グレイズ1回で出す火花の数
@export var spark_count : int = 8
## 飛び散る速さ(px/秒)。いちばん遅い火花と、いちばん速い火花
@export var spark_speed_min : float = 160.0
@export var spark_speed_max : float = 420.0
## 火花が消えるまでの時間(秒)
@export var spark_life : float = 0.24
## 火花の線の長さ(速さに掛ける秒数。大きいほど長い線になる)と太さ(px)
@export var spark_length : float = 0.06
@export var spark_width : float = 2.0
## 広がり(度)。弾のある向きを中心に、±この角度へ飛ぶ
@export var spark_spread_deg : float = 55.0
## 火花が出る場所の、自機の中心からの距離(px)
@export var spark_origin_distance : float = 12.0
## 同時に出せる火花の数(弾幕の中でグレイズし続けても、増えすぎないように)
@export var max_sparks : int = 160

@export_group("弧")
## オフにすると、弧は出さない
@export var arc_enabled : bool = true
## 弧の半径(px)。出た瞬間 → 消えるとき
@export var arc_radius_start : float = 15.0
@export var arc_radius_end : float = 32.0
## 弧の広さ(度)と、消えるまでの時間(秒)、太さ(px)
@export var arc_angle_deg : float = 80.0
@export var arc_life : float = 0.2
@export var arc_width : float = 3.0

@export_group("色")
## 火花の芯の色と、まわりの色
@export var core_color : Color = Color(1.0, 1.0, 1.0)
@export var glow_color : Color = Color(0.45, 0.9, 1.0)
## 描く順番。敵弾(5)より上
@export var draw_z : int = 6

## 火花: [位置, 速度, 残り時間]
var _sparks : Array = []
## 弧: [向き(ラジアン), 経過時間]
var _arcs : Array = []
var _player : Node2D

func _ready() -> void:
	_player = get_parent() as Node2D
	top_level = true # 画面(ワールド)の座標で描く。自機が動いても、飛んだ火花はその場に残る
	global_position = Vector2.ZERO
	z_as_relative = false
	z_index = draw_z
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = add
	if _player and _player.has_signal("graze_hit"):
		_player.graze_hit.connect(_on_graze_hit)
	set_process(false)

func _on_graze_hit(bullet_position : Vector2, _density : int) -> void:
	if _player == null:
		return
	var center := _player.global_position
	var to_bullet := bullet_position - center
	var direction := to_bullet.normalized() if to_bullet.length() > 0.5 else Vector2.UP
	var origin := center + direction * spark_origin_distance
	var spread := deg_to_rad(spark_spread_deg)
	for i in spark_count:
		if _sparks.size() >= max_sparks:
			break
		var velocity := direction.rotated(randf_range(-spread, spread)) * randf_range(spark_speed_min, spark_speed_max)
		_sparks.append([origin, velocity, spark_life * randf_range(0.6, 1.0)])
	if arc_enabled and _arcs.size() < 12:
		_arcs.append([direction.angle(), 0.0])
	set_process(true)

func _process(delta : float) -> void:
	for i in range(_sparks.size() - 1, -1, -1):
		var spark : Array = _sparks[i]
		spark[2] -= delta
		if spark[2] <= 0.0:
			_sparks.remove_at(i)
			continue
		spark[0] += spark[1] * delta
		spark[1] *= maxf(1.0 - 5.0 * delta, 0.0) # だんだん遅くなる
	for i in range(_arcs.size() - 1, -1, -1):
		_arcs[i][1] += delta
		if _arcs[i][1] >= arc_life:
			_arcs.remove_at(i)
	queue_redraw()
	if _sparks.is_empty() and _arcs.is_empty():
		set_process(false)

func _draw() -> void:
	for spark in _sparks:
		var pos : Vector2 = spark[0]
		var velocity : Vector2 = spark[1]
		var alpha := clampf(spark[2] / (spark_life * 0.5), 0.0, 1.0)
		var tail := pos - velocity * spark_length
		draw_line(tail, pos, Color(glow_color, 0.55 * alpha), spark_width * 2.2)
		draw_line(tail.lerp(pos, 0.35), pos, Color(core_color, alpha), spark_width)
	if _player == null or not is_instance_valid(_player):
		return
	var center := _player.global_position
	var half := deg_to_rad(arc_angle_deg) * 0.5
	for arc in _arcs:
		var t := clampf(arc[1] / arc_life, 0.0, 1.0)
		var out := 1.0 - (1.0 - t) * (1.0 - t)
		var radius := lerpf(arc_radius_start, arc_radius_end, out)
		var alpha := 1.0 - t
		draw_arc(center, radius, arc[0] - half, arc[0] + half, 14, Color(glow_color, 0.6 * alpha), arc_width * 2.0)
		draw_arc(center, radius, arc[0] - half, arc[0] + half, 14, Color(core_color, alpha), arc_width)
