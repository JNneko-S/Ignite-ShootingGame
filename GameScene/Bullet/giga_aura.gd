extends Node2D
## 丸・輪・線をためて、1回の描画命令でまとめて描く道具
var _mesh = preload("res://GameScene/Effect/batch_mesh.gd").new()
## 超巨大弾の見た目を派手にする部品(E_Giga の子)。弾と一緒に大きくなるので、大きさは弾の絵の px で決める。
##   ・脈打つ赤橙の光の輪(何重にも重ねる)
##   ・逆に回る2本の稲妻の輪と、外へ伸び縮みする光のとげ
##   ・白く燃える芯
##   ・飛びながら、まわりに火の粉を散らす(BurnPuff。画面の座標で出す)

const _BurnPuff := preload("res://GameScene/Effect/burn_puff.gd")

## 光の輪の半径(弾の絵の px。絵は 13px)
@export var glow_radius : float = 13.0
@export var ring_radius : float = 9.0
@export var spikes : int = 10
## 火の粉を出す間隔(秒)
@export var ember_interval : float = 0.05

const HOT := Color(1.0, 0.92, 0.6)
const FIRE := Color(1.0, 0.45, 0.1)
const DEEP := Color(0.9, 0.12, 0.05)

var _t : float = 0.0
var _ember_in : float = 0.0
var _seed : float = 0.0

func _ready() -> void:
	_seed = randf() * 100.0
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	show_behind_parent = false

func _process(delta : float) -> void:
	_t += delta
	_ember_in -= delta
	var parent := get_parent() as Node2D
	if _ember_in <= 0.0 and parent and parent.visible:
		_ember_in = ember_interval
		var r := glow_radius * absf(parent.global_scale.x) * 0.8
		_BurnPuff.spawn(get_tree(), parent.global_position + Vector2.from_angle(randf() * TAU) * randf_range(0.3, 1.0) * r)
	rotation = -get_parent().rotation # 弾の向きで回らない(輪は自分で回る)
	queue_redraw()

func _draw() -> void:
	_fill_mesh()
	_mesh.flush(get_canvas_item())

## 描く形を _mesh にためる(1回の描画命令でまとめて描くため)
func _fill_mesh() -> void:
	_mesh.clear() # 丸・輪・線をためて、最後に1回で描く
	var pulse := 0.5 + 0.5 * sin(_t * 7.0 + _seed)
	# 光の輪(外ほど薄く、赤く)
	for i in 5:
		var k := float(i) / 4.0
		var r := glow_radius * lerpf(1.25, 0.55, k) * (1.0 + 0.08 * pulse)
		var c := DEEP.lerp(FIRE, k)
		c.a = lerpf(0.10, 0.32, k)
		_mesh.circle(Vector2.ZERO, r, c)
	# 外へ伸び縮みする光のとげ
	for i in spikes:
		var a := TAU * float(i) / spikes + _t * 0.8
		var len := glow_radius * (1.05 + 0.35 * sin(_t * 9.0 + i * 1.7 + _seed))
		var dir := Vector2.from_angle(a)
		_mesh.line(dir * ring_radius * 0.9, dir * len, 0.9, Color(FIRE, 0.55))
		_mesh.line(dir * ring_radius * 0.9, dir * len * 0.85, 0.4, Color(HOT, 0.7))
	# 逆に回る2本の稲妻の輪
	for ring in 2:
		var dirsign := 1.0 if ring == 0 else -1.0
		var rr := ring_radius * (1.0 if ring == 0 else 1.22)
		var pts := PackedVector2Array()
		var n := 28
		for j in n + 1:
			var a := TAU * j / n + _t * 2.2 * dirsign
			var jitter := 0.6 * sin(j * 3.1 + _t * 23.0 + ring * 5.0 + _seed)
			pts.append(Vector2.from_angle(a) * (rr + jitter))
		_mesh.polyline(pts, 0.6, Color(HOT, 0.75 - 0.25 * ring))
	# 白く燃える芯
	_mesh.circle(Vector2.ZERO, ring_radius * (0.55 + 0.1 * pulse), Color(HOT, 0.55))
	_mesh.circle(Vector2.ZERO, ring_radius * 0.3, Color(1, 1, 1, 0.7))
