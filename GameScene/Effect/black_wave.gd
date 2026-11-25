extends Node2D
class_name BlackWave
## 黒い波動。中心から、黒い輪(縁は暗い紫と赤)が広がって消える。裏ボスが叫ぶときなどに使う。
##   BlackWave.spawn(tree, 位置, 最後の半径, 時間)

var max_radius : float = 420.0
var life : float = 1.1
var width : float = 46.0
var _t : float = 0.0

static func spawn(tree : SceneTree, at : Vector2, radius : float = 420.0, time : float = 1.1, ring_width : float = 46.0) -> Node2D:
	var root := tree.current_scene
	if root == null:
		return null
	var wave = (load("res://GameScene/Effect/black_wave.gd") as GDScript).new()
	wave.max_radius = radius
	wave.life = time
	wave.width = ring_width
	wave.z_as_relative = false
	wave.z_index = 40
	root.add_child(wave)
	wave.global_position = at
	return wave

func _process(delta : float) -> void:
	_t += delta
	if _t >= life:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var k := clampf(_t / life, 0.0, 1.0)
	var r := max_radius * (1.0 - pow(1.0 - k, 3.0)) # 速く広がって、ゆるむ
	var fade := 1.0 - k
	var w := width * (0.4 + 0.6 * fade)
	# 内側をうっすら暗くする
	draw_circle(Vector2.ZERO, r, Color(0.0, 0.0, 0.0, 0.18 * fade))
	# 黒い輪と、暗い紫・赤の縁
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 96, Color(0.0, 0.0, 0.0, 0.85 * fade), w)
	draw_arc(Vector2.ZERO, r + w * 0.5, 0.0, TAU, 96, Color(0.35, 0.0, 0.3, 0.7 * fade), 3.0)
	draw_arc(Vector2.ZERO, r - w * 0.5, 0.0, TAU, 96, Color(0.8, 0.05, 0.12, 0.6 * fade), 2.0)
	# ゆがんだ筋(黒い稲妻のような線)
	for i in 10:
		var a := TAU * i / 10.0 + k * 1.3
		var p1 := Vector2.from_angle(a) * r * 0.55
		var p2 := Vector2.from_angle(a + 0.09) * r
		draw_line(p1, p2, Color(0.05, 0.0, 0.06, 0.6 * fade), 2.0)
