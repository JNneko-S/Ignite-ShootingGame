extends Node2D
## 裏ボス Union の、禍々しい黒いオーラ。Union の姿(UnionView)の後ろに置く。
##   ・暗い光が脈打つ
##   ・黒から紫へ色の変わる触手が、うねりながら伸び縮みする
##   ・黒い粒が、ゆっくり外へ漂い出て消える
## 暴走(BossRampage)のときは、強く・速くなる(Intensity を上げる)

## オーラの大きさ(px)
@export var radius : float = 150.0
## 触手の数と長さ(px)
@export var tendrils : int = 12
@export var tendril_length : float = 95.0
## 強さ(1 がふつう。暴走で上げる)
@export var intensity : float = 1.0
## オンなら、Union の姿の手前に重ねる「まとう炎」: 体のふち(Radius の約 85%)から、黒い炎の舌がちらちら伸びる
@export var front : bool = false
@export var flame_count : int = 22

const MOTES := 26

var _t : float = 0.0
var _motes : Array[Vector3] = [] # x, y = 位置、z = 年齢(0〜1)
var _mote_dirs : Array[Vector2] = []

func _ready() -> void:
	z_as_relative = true
	for i in MOTES:
		_motes.append(Vector3(0.0, 0.0, randf()))
		_mote_dirs.append(Vector2.from_angle(randf() * TAU) * randf_range(25.0, 60.0))

func _process(delta : float) -> void:
	_t += delta * (0.8 + 0.5 * intensity)
	for i in MOTES:
		var m := _motes[i]
		m.z += delta * 0.45 * (0.7 + 0.3 * intensity)
		if m.z >= 1.0:
			m = Vector3(0.0, 0.0, 0.0)
			_mote_dirs[i] = Vector2.from_angle(randf() * TAU) * randf_range(25.0, 60.0)
		var p := Vector2.from_angle(atan2(_mote_dirs[i].y, _mote_dirs[i].x)) * radius * 0.45 + _mote_dirs[i] * m.z * 2.0
		_motes[i] = Vector3(p.x, p.y, m.z)
	queue_redraw()

func _draw() -> void:
	if front:
		_draw_front()
		return
	var pulse := 0.5 + 0.5 * sin(_t * 2.4)
	# 脈打つ暗い光(外ほど薄い)
	for i in 6:
		var k := float(i) / 5.0
		var r := radius * (0.55 + 0.55 * k) * (0.95 + 0.08 * pulse * intensity)
		draw_circle(Vector2.ZERO, r, Color(0.06, 0.0, 0.08, (0.2 - 0.028 * i) * clampf(intensity, 0.6, 1.6)))
	draw_arc(Vector2.ZERO, radius * (0.62 + 0.05 * pulse), 0.0, TAU, 64, Color(0.45, 0.0, 0.35, 0.35 * intensity), 3.0)
	# うねる触手
	for i in tendrils:
		var base_a := TAU * i / tendrils + _t * 0.25
		var length := tendril_length * (0.7 + 0.3 * sin(_t * 1.7 + i * 1.3)) * (0.8 + 0.25 * intensity)
		var points := PackedVector2Array()
		var colors := PackedColorArray()
		var segs := 10
		for s in segs + 1:
			var f := float(s) / segs
			var a := base_a + sin(_t * 3.0 + i + f * 4.0) * 0.35 * f
			var d := radius * 0.5 + length * f
			points.append(Vector2.from_angle(a) * d)
			colors.append(Color(0.0, 0.0, 0.0, 0.85).lerp(Color(0.5, 0.0, 0.4, 0.0), f))
		draw_polyline_colors(points, colors, 5.0 * (1.0 - 0.3 * pulse) + 1.0, true)
	# 漂う黒い粒
	for m in _motes:
		var a := 1.0 - m.z
		draw_circle(Vector2(m.x, m.y), 2.5 + 2.0 * a, Color(0.02, 0.0, 0.04, 0.8 * a))
		draw_circle(Vector2(m.x, m.y), 1.2, Color(0.6, 0.05, 0.25, 0.6 * a))

## 手前の、まとう黒い炎(体のふちに沿って、黒い炎の舌がちらちら伸び縮みする。ふちは暗い紫)
func _draw_front() -> void:
	var r0 := radius * 0.85
	# 体のふちに沿った、暗い輪(黒い靄)
	draw_arc(Vector2.ZERO, r0, 0.0, TAU, 96, Color(0.0, 0.0, 0.0, 0.45 * clampf(intensity, 0.6, 1.6)), 14.0)
	draw_arc(Vector2.ZERO, r0 + 7.0, 0.0, TAU, 96, Color(0.4, 0.0, 0.35, 0.35 * intensity), 2.0)
	for i in flame_count:
		var a := TAU * i / flame_count + sin(_t * 0.6 + i) * 0.08
		var flick := 0.5 + 0.5 * sin(_t * (5.0 + i % 4) + i * 2.1)
		var length := (16.0 + 26.0 * flick) * (0.8 + 0.3 * intensity)
		var half := 0.07 + 0.03 * flick
		var sway := sin(_t * 4.0 + i * 1.7) * 0.12
		var base_l := Vector2.from_angle(a - half) * r0
		var base_r := Vector2.from_angle(a + half) * r0
		var tip := Vector2.from_angle(a + sway) * (r0 + length)
		draw_colored_polygon(PackedVector2Array([base_l, tip, base_r]), Color(0.0, 0.0, 0.0, 0.8))
		draw_polyline(PackedVector2Array([base_l, tip, base_r]), Color(0.5, 0.0, 0.42, 0.55 * clampf(intensity, 0.6, 1.6)), 1.5, true)
