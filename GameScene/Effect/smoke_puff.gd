extends Node2D
class_name SmokePuff
## 黒っぽい煙のかたまり。SmokePuff.spawn(tree, 位置, 大きさ, 流れる向き) で出し、ふくらみながら薄れて消える。
## 壊れたボスの残骸から立ちのぼる煙や、墜ちていく機体の煙の尾に使う。

const MAX_ACTIVE : int = 160
static var _active : int = 0

var _age : float = 0.0
var _life : float = 1.4
var _size : float = 10.0
var _velocity : Vector2 = Vector2(0, -20)
var _color : Color = Color(0.16, 0.15, 0.15, 0.55)
var _blobs : Array = [] # [ずれ, 大きさの倍率]

static func spawn(tree : SceneTree, at : Vector2, size : float = 10.0, velocity : Vector2 = Vector2(0, -20),
		life : float = 1.4, color : Color = Color(0.16, 0.15, 0.15, 0.55), z : int = 3) -> void:
	if tree == null or tree.current_scene == null or _active >= MAX_ACTIVE:
		return
	var puff := SmokePuff.new()
	puff._size = size
	puff._velocity = velocity
	puff._life = life
	puff._color = color
	puff.z_as_relative = false
	puff.z_index = z
	puff.position = at
	tree.current_scene.add_child.call_deferred(puff)

func _ready() -> void:
	_active += 1
	for i in 4:
		_blobs.append([Vector2(randf_range(-0.6, 0.6), randf_range(-0.6, 0.6)) * _size, randf_range(0.55, 1.0)])

func _exit_tree() -> void:
	_active -= 1

func _process(delta : float) -> void:
	_age += delta
	if _age >= _life:
		queue_free()
		return
	position += _velocity * delta
	_velocity *= 1.0 - minf(delta * 0.8, 0.5)
	queue_redraw()

func _draw() -> void:
	var t := _age / _life
	var grow := lerpf(0.6, 1.8, 1.0 - (1.0 - t) * (1.0 - t))
	var c := _color
	c.a *= 1.0 - t
	for b in _blobs:
		draw_circle(b[0] * grow, _size * float(b[1]) * grow, c)
