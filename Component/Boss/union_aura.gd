extends Node2D
## 裏ボス Union の、黒い太陽のオーラ。Union の姿(UnionView)の後ろに置く。
##   ・真ん中は真っ黒に塗りつぶした円(黒い太陽の本体)。ふちが、日食のように暗い深紅に光る
##   ・ふちから、黒い棘が放射状に突き出る。細く鋭く、長さも曲がり方もばらばらで、ゆっくり回りながら、うごめくように伸び縮みする
##   ・まわりに、暗い紫の光の輪(コロナ)がにじむ。黒い粒が、ゆっくり外へ漂い出て消える
## 暴走(BossRampage)のときは、強く・速くなる(Intensity を上げる)

## オーラの大きさ(px)
@export var radius : float = 150.0
## 棘の数(長い棘。その間に、同じ数の短い棘がはさまる)と、長い棘のいちばん長い長さ(px)
@export var tendrils : int = 18
@export var tendril_length : float = 105.0
## 強さ(1 がふつう。暴走で上げる)
@export var intensity : float = 1.0
## オンなら、Union の姿の手前に重ねる「まとう棘」: 体のふち(Radius の約 85%)から、鋭く曲がった黒い棘がうごめく
@export var front : bool = false
@export var flame_count : int = 16

const MOTES := 26
## 黒い太陽の本体(塗りつぶす円)の大きさ(Radius に対する割合)
const CORE_RATIO := 0.64

const BLACK := Color(0.0, 0.0, 0.0, 1.0)
const RIM := Color(0.62, 0.0, 0.14)
const CORONA := Color(0.32, 0.0, 0.2)

var _t : float = 0.0
var _motes : Array[Vector3] = [] # x, y = 位置、z = 年齢(0〜1)
var _mote_dirs : Array[Vector2] = []
## 丸と輪をまとめて1回で描く道具
var _mesh = preload("res://GameScene/Effect/batch_mesh.gd").new()
## 棘ごとの、ばらばらの性質 [長さの割合, 曲がり(ラジアン), うごめく速さ, うごめく位相, 太さ(ラジアン)]
var _spikes : Array[PackedFloat32Array] = []

func _ready() -> void:
	z_as_relative = true
	for i in MOTES:
		_motes.append(Vector3(0.0, 0.0, randf()))
		_mote_dirs.append(Vector2.from_angle(randf() * TAU) * randf_range(25.0, 60.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 6661 if not front else 1666 # 毎回同じ形(戦うたびに形が変わらないように)
	var count := (flame_count if front else tendrils * 2)
	for i in count:
		var long := front or i % 2 == 0
		_spikes.append(PackedFloat32Array([
			rng.randf_range(0.55, 1.0) if long else rng.randf_range(0.18, 0.4),
			rng.randf_range(-0.55, 0.55),
			rng.randf_range(0.6, 1.8),
			rng.randf_range(0.0, TAU),
			rng.randf_range(0.035, 0.06) if long else rng.randf_range(0.025, 0.04),
		]))

func _process(delta : float) -> void:
	_t += delta * (0.8 + 0.5 * intensity)
	if not front:
		for i in MOTES:
			var m := _motes[i]
			m.z += delta * 0.45 * (0.7 + 0.3 * intensity)
			if m.z >= 1.0:
				m = Vector3(0.0, 0.0, 0.0)
				_mote_dirs[i] = Vector2.from_angle(randf() * TAU) * randf_range(25.0, 60.0)
			var p := Vector2.from_angle(atan2(_mote_dirs[i].y, _mote_dirs[i].x)) * radius * 0.7 + _mote_dirs[i] * m.z * 2.4
			_motes[i] = Vector3(p.x, p.y, m.z)
	queue_redraw()

func _draw() -> void:
	if front:
		_draw_front()
		return
	var pulse := 0.5 + 0.5 * sin(_t * 2.0)
	var power := clampf(intensity, 0.6, 1.8)
	var core := radius * CORE_RATIO
	# にじむコロナ(外ほど薄い暗い紫)。丸と輪は BatchMesh にためて、まとめて1回で描く
	_mesh.clear()
	for i in 7:
		var k := float(i) / 6.0
		var r := core * (1.05 + 0.75 * k) * (0.97 + 0.05 * pulse * intensity)
		_mesh.circle(Vector2.ZERO, r, Color(CORONA, (0.13 - 0.016 * i) * power), 48)
	_mesh.flush(get_canvas_item())
	# 黒い棘(本体の後ろから突き出す)。全部の棘を、塗り1回・縁取り1回にまとめて描く
	_begin_thorns()
	var spin := _t * 0.07
	for i in _spikes.size():
		var s := _spikes[i]
		var a := TAU * i / _spikes.size() + spin
		var writhe := 0.5 + 0.5 * sin(_t * s[2] + s[3])
		var length := tendril_length * s[0] * (0.72 + 0.4 * writhe) * (0.85 + 0.2 * intensity)
		_add_thorn(a, core * 0.96, length, s[4], s[1] * (0.7 + 0.5 * writhe), Color(RIM, 0.75 * power), s[3])
	_flush_thorns()
	# 黒い太陽の本体: 真っ黒に塗りつぶす
	_mesh.clear()
	_mesh.circle(Vector2.ZERO, core, BLACK, 64)
	# 日食のふち: 深紅の細い光と、その外のにじみ
	_mesh.ring(Vector2.ZERO, core + 3.0, 8.0, Color(CORONA, (0.35 + 0.2 * pulse) * power), 72)
	_mesh.ring(Vector2.ZERO, core, 2.0, Color(RIM, (0.65 + 0.3 * pulse) * minf(power, 1.2)), 72)
	# 漂う黒い粒
	for m in _motes:
		var fade := 1.0 - m.z
		_mesh.circle(Vector2(m.x, m.y), 2.5 + 2.0 * fade, Color(0.0, 0.0, 0.0, 0.85 * fade), 8)
		_mesh.circle(Vector2(m.x, m.y), 1.1, Color(RIM, 0.6 * fade), 5)
	_mesh.flush(get_canvas_item())

## 黒い棘を1本描く: ふち(base)から外へ。根元は太く、先は針のように鋭い。途中で曲がり(bend)、先は鉤のように反る。
## 棘は蛇のようにうねる(根元から先へ、波が伝わっていく)。ふちは深紅。phase: 棘ごとのうねりのずれ
## 軽量化: 棘を1本ずつ描くと、塗りと縁取りで1本につき3回の描画命令になる(36本で100回以上)。
## なので、全部の棘の塗りを1つの三角形の集まりに、縁取りを1つの線の集まりにためておき、最後にまとめて2回で描く
const THORN_SEGS : int = 12
var _tri_points := PackedVector2Array()
var _tri_colors := PackedColorArray()
var _tri_indices := PackedInt32Array()
var _edge_points := PackedVector2Array()
var _edge_colors := PackedColorArray()

func _begin_thorns() -> void:
	_tri_points.clear()
	_tri_colors.clear()
	_tri_indices.clear()
	_edge_points.clear()
	_edge_colors.clear()

func _add_thorn(angle : float, base : float, length : float, half_width : float, bend : float, edge : Color, phase : float = 0.0) -> void:
	var dir := Vector2.from_angle(angle)
	var side := dir.orthogonal()
	var first := _tri_points.size()
	var prev_l := Vector2.ZERO
	var prev_r := Vector2.ZERO
	var edge_dim := Color(edge, edge.a * 0.5)
	for k in THORN_SEGS + 1:
		var f := float(k) / THORN_SEGS
		# 根元は太く(内側を太く)、先へ行くほど急に細くなる(針のように)。曲がりは先ほど強い(鉤)
		var width := base * half_width * 1.8 * pow(1.0 - f, 1.9)
		var wave := sin(f * 7.0 - _t * 4.2 + phase) * length * 0.1 * f # 根元から先へ伝わるうねり(先ほど大きく振れる)
		var curl := bend * f * f * length + wave
		var center := dir * (base + length * f) + side * curl
		var l := center + side * width
		var r := center - side * width
		_tri_points.append(l)
		_tri_points.append(r)
		_tri_colors.append(BLACK)
		_tri_colors.append(BLACK)
		if k > 0:
			# 左右の点を2つずつ使って、四角(三角2つ)で塗る
			var i := first + k * 2
			_tri_indices.append_array([i - 2, i - 1, i, i - 1, i + 1, i])
			_edge_points.append_array([prev_l, l, prev_r, r])
			_edge_colors.append_array([edge, edge_dim])
		prev_l = l
		prev_r = r

func _flush_thorns() -> void:
	if not _tri_points.is_empty():
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), _tri_indices, _tri_points, _tri_colors)
	if not _edge_points.is_empty():
		draw_multiline_colors(_edge_points, _edge_colors, 1.2)

## 手前の、まとう棘(体のふちから、鋭く曲がった黒い棘がうごめく。ふちは深紅)
func _draw_front() -> void:
	var r0 := radius * 0.85
	var power := clampf(intensity, 0.6, 1.8)
	# 体のふちに沿った、黒い靄と深紅の細い線
	_mesh.clear()
	_mesh.ring(Vector2.ZERO, r0, 12.0, Color(0.0, 0.0, 0.0, 0.55 * power), 72)
	_mesh.ring(Vector2.ZERO, r0 + 5.0, 1.5, Color(RIM, 0.4 * power), 72)
	_mesh.flush(get_canvas_item())
	_begin_thorns()
	var spin := -_t * 0.1
	for i in _spikes.size():
		var s := _spikes[i]
		var a := TAU * i / _spikes.size() + spin + sin(_t * 0.5 + i) * 0.05
		var writhe := 0.5 + 0.5 * sin(_t * (s[2] * 2.2) + s[3])
		var length := (14.0 + 34.0 * s[0] * writhe) * (0.8 + 0.3 * intensity)
		_add_thorn(a, r0 - 2.0, length, s[4] * 0.8, s[1] * 1.4, Color(RIM, 0.7 * power), s[3])
	_flush_thorns()
