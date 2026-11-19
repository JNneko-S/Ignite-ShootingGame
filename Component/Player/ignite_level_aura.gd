extends Node2D
class_name IgniteLevelAura
## 自機のまわりにまとうオーラ。イグナイトのレベルで色と強さが変わる(Lv0 では何も出ない)。
## ゲージを見なくても、いまのレベルが分かるようにするためのもの。
## GameManager が自機の子として付ける(IgniteLevelAura.attach)

## レベルごとの色(1〜5)
const LEVEL_COLORS : Array[Color] = [
	Color(0.0, 0.0, 0.0),
	Color(0.30, 0.75, 1.00), # Lv1 青
	Color(0.35, 1.00, 0.55), # Lv2 緑
	Color(1.00, 0.90, 0.30), # Lv3 黄
	Color(1.00, 0.52, 0.15), # Lv4 橙
	Color(1.00, 0.22, 0.38), # Lv5 赤
]

## オーラの半径(Lv1)。レベルが上がるごとに少しずつ大きくなる
@export var base_radius : float = 27.0
@export var radius_per_level : float = 1.5
## 炎の数(Lv1)。レベルごとに増える
@export var base_flames : int = 6
@export var flames_per_level : int = 2
## 全体の明るさ(弾が見えにくくならない程度に)
@export_range(0.0, 1.0, 0.05) var intensity : float = 0.9

var gauge : IgniteGauge
var _level : int = 0
## いまの見た目の強さ(0 で消えている)。レベルが変わるとなめらかに追いつく
var _strength : float = 0.0
var _color : Color = Color.BLACK
var _time : float = 0.0
## レベルが上がった瞬間に広がる輪(1 → 0)
var _burst : float = 0.0
var _burst_color : Color = Color.WHITE

## 自機の子として付ける。すでに付いていれば、それを使う
static func attach(player : Node2D, ignite_gauge : IgniteGauge) -> IgniteLevelAura:
	if player == null or ignite_gauge == null:
		return null
	var aura := player.get_node_or_null("IgniteLevelAura") as IgniteLevelAura
	if aura == null:
		aura = IgniteLevelAura.new()
		aura.name = "IgniteLevelAura"
		player.add_child(aura)
	aura.bind(ignite_gauge)
	return aura

func _ready() -> void:
	show_behind_parent = true # 機体の絵の後ろに出す
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat

func bind(ignite_gauge : IgniteGauge) -> void:
	if gauge and gauge.level_changed.is_connected(_on_level_changed):
		gauge.level_changed.disconnect(_on_level_changed)
	gauge = ignite_gauge
	gauge.level_changed.connect(_on_level_changed)
	_level = gauge.level
	_strength = _target_strength()
	if _level > 0:
		_color = LEVEL_COLORS[clampi(_level, 1, 5)]

func _on_level_changed(level : int) -> void:
	if level > _level and level > 0:
		_burst = 1.0
		_burst_color = LEVEL_COLORS[clampi(level, 1, 5)]
	_level = level

func _target_strength() -> float:
	if _level <= 0:
		return 0.0
	return 0.55 + 0.45 * float(_level - 1) / 4.0

func _process(delta : float) -> void:
	_time += delta
	_strength = move_toward(_strength, _target_strength(), delta * 2.5)
	if _level > 0:
		_color = _color.lerp(LEVEL_COLORS[clampi(_level, 1, 5)], minf(1.0, delta * 8.0))
	_burst = maxf(0.0, _burst - delta * 2.2)
	queue_redraw()

func _draw() -> void:
	if _burst > 0.0:
		var t := 1.0 - _burst
		draw_arc(Vector2.ZERO, base_radius + 50.0 * t, 0.0, TAU, 48,
			Color(_burst_color, 0.8 * _burst), 3.0 * _burst + 1.0, true)
	if _strength <= 0.01:
		return
	var s := _strength * intensity
	var lv := maxi(_level, 1)
	var radius := base_radius + radius_per_level * float(lv - 1)
	var pulse := 0.5 + 0.5 * sin(_time * (3.0 + lv * 0.6))

	# やわらかい光(中心ほど明るい)
	for i in 5:
		var k := 1.0 - float(i) / 5.0
		draw_circle(Vector2.ZERO, radius * (0.5 + 0.5 * k),
			Color(_color, 0.09 * s * (0.8 + 0.2 * pulse)))

	# まわりをなめる炎(根元が明るく、先が消える)。少し上へ流れる
	var flames := base_flames + flames_per_level * (lv - 1)
	var spin := _time * (0.6 + 0.15 * lv)
	for i in flames:
		var a := TAU * float(i) / float(flames) + spin
		var flick := 0.55 + 0.45 * sin(_time * 9.0 + float(i) * 2.3) * sin(_time * 5.3 + float(i) * 1.1)
		# 上(進行方向の反対ではなく、炎が立ちのぼる向き)ほど長い
		var up := 0.5 + 0.5 * maxf(0.0, -sin(a))
		var length := radius * (0.28 + 0.25 * flick) * (0.7 + 0.6 * up) * (0.8 + 0.08 * lv)
		var dir := Vector2(cos(a), sin(a))
		var side := dir.orthogonal() * radius * 0.14
		var root := dir * radius * 0.85
		var tip := dir * (radius * 0.85 + length) + Vector2(0, -length * 0.35 * up)
		var points := PackedVector2Array([root - side, root + side, tip])
		var base_col := Color(_color.lerp(Color.WHITE, 0.25), 0.7 * s)
		var colors := PackedColorArray([base_col, base_col, Color(_color, 0.0)])
		draw_polygon(points, colors)

	# ふちの輪(脈打つ)
	draw_arc(Vector2.ZERO, radius * (0.95 + 0.04 * pulse), 0.0, TAU, 40,
		Color(_color.lerp(Color.WHITE, 0.4), (0.45 + 0.3 * pulse) * s), 2.0, true)

	# Lv4〜5: まわりを回る火の粉
	if lv >= 4:
		var sparks := 4 if lv == 4 else 7
		for i in sparks:
			var a2 := -_time * (2.0 + 0.3 * i) + TAU * float(i) / float(sparks)
			var r2 := radius * (1.25 + 0.15 * sin(_time * 4.0 + i))
			var p := Vector2(cos(a2), sin(a2)) * r2
			draw_circle(p, 2.2, Color(_color.lerp(Color.WHITE, 0.6), 0.7 * s))
