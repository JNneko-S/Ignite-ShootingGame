extends Node2D
class_name BlackWave
## 丸・輪・線をためて、1回の描画命令でまとめて描く道具
var _mesh = preload("res://GameScene/Effect/batch_mesh.gd").new()
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
	_fill_mesh()
	_mesh.flush(get_canvas_item())

## 描く形を _mesh にためる(1回の描画命令でまとめて描くため)
func _fill_mesh() -> void:
	_mesh.clear() # 丸・輪・線をためて、最後に1回で描く
	var k := clampf(_t / life, 0.0, 1.0)
	var r := max_radius * (1.0 - pow(1.0 - k, 3.0)) # 速く広がって、ゆるむ
	var fade := 1.0 - k
	var w := width * (0.4 + 0.6 * fade)
	# 内側をうっすら暗くする
	_mesh.circle(Vector2.ZERO, r, Color(0.0, 0.0, 0.0, 0.18 * fade))
	# 黒い輪と、暗い紫・赤の縁
	_mesh.ring(Vector2.ZERO, r, w, Color(0.0, 0.0, 0.0, 0.85 * fade), 48)
	_mesh.ring(Vector2.ZERO, r + w * 0.5, 3.0, Color(0.35, 0.0, 0.3, 0.7 * fade), 48)
	_mesh.ring(Vector2.ZERO, r - w * 0.5, 2.0, Color(0.8, 0.05, 0.12, 0.6 * fade), 48)
	# ゆがんだ筋(黒い稲妻のような線)
	for i in 10:
		var a := TAU * i / 10.0 + k * 1.3
		var p1 := Vector2.from_angle(a) * r * 0.55
		var p2 := Vector2.from_angle(a + 0.09) * r
		_mesh.line(p1, p2, 2.0, Color(0.05, 0.0, 0.06, 0.6 * fade))
