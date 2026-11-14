extends Node2D
class_name MeteorTrail
## 隕石が突っ込んでくるときのような、白い光の筋。猛スピードで登場する列車の先頭に付ける(TrainBossMover が作る)。
## 先頭のまん中あたりに筋が集まり、後ろへ向かって広がりながら、ゆらゆらと伸び縮みする。
## Intensity を 0 にすると消える(TrainBossMover が、止まるときにだんだん弱める)。

## 筋の数
@export var count : int = 28
## 先頭の位置(親から見た y)と、列車の幅の半分(px)
@export var front_y : float = 0.0
@export var half_width : float = 120.0
## 後ろの向き(1 なら下へ伸びる = 上へ進む列車、-1 なら上へ伸びる)
@export var back_dir : float = 1.0
## 筋のいちばん長いとき(px)
@export var max_length : float = 900.0
@export var color : Color = Color(1.0, 1.0, 1.0)
## 強さ(0〜1)。筋の長さと濃さが変わる
var intensity : float = 1.0

var _time : float = 0.0
var _seeds : Array[Vector3] = [] # 横の位置(-1〜1), 長さの倍率, ゆらぎの位相

func _ready() -> void:
	z_as_relative = false
	z_index = 7
	for i in count:
		var u := (float(i) / maxf(count - 1, 1)) * 2.0 - 1.0
		_seeds.append(Vector3(u, randf_range(0.45, 1.0), randf() * TAU))

func _process(delta : float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	if intensity <= 0.01:
		return
	# 先頭の光
	var head := Vector2(0.0, front_y)
	draw_circle(head, half_width * 0.5 * intensity, Color(color, 0.18 * intensity))
	draw_circle(head, half_width * 0.25 * intensity, Color(color, 0.35 * intensity))
	for s in _seeds:
		var u := s.x
		var wobble := 0.75 + 0.25 * sin(_time * 14.0 + s.z)
		var length := max_length * s.y * wobble * intensity
		# 先頭のまん中寄りから出て、後ろへ行くほど外へ広がる(隕石の尾のように、少し曲がる)
		var start := Vector2(u * half_width * 0.35, front_y)
		var bend := Vector2(u * half_width * 1.1, front_y + back_dir * length * 0.3)
		var end := Vector2(u * half_width * (1.3 + 0.4 * absf(u)), front_y + back_dir * length)
		var points := PackedVector2Array()
		for k in 9:
			var t := k / 8.0
			points.append(start.lerp(bend, t).lerp(bend.lerp(end, t), t))
		# 先は太く濃く、尾は細く薄く
		for k in points.size() - 1:
			var t := float(k) / (points.size() - 1)
			var a := (1.0 - t) * 0.75 * intensity * (1.0 - absf(u) * 0.35)
			draw_line(points[k], points[k + 1], Color(color, a), lerpf(4.0, 1.0, t))
