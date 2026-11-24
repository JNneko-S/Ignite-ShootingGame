extends Node2D
class_name HitSpark
## 敵に弾が当たったときの火花。HitSpark.spawn(tree, 位置, 散る向き) で出し、すぐ消える。
## 当たった所が白く一瞬光り、橙〜黄色の短い火花が、散る向き(撃った側)へ扇に飛ぶ。
## 装甲にはじかれたとき(DeflectSpark、青白い)とは色を変えて、ダメージが入ったことが分かるようにする。

const LIFE : float = 0.16
## 描く順番。敵(1〜2)より手前、敵弾(5)より奥
const Z_INDEX : int = 4
## 同時に出せる数(撃ち続けても増えすぎないように)
const MAX_ACTIVE : int = 90

const CORE := Color(1.0, 1.0, 0.92)
const HOT := Color(1.0, 0.78, 0.3)
const EMBER := Color(1.0, 0.42, 0.12)

static var _active : int = 0
static var _material : CanvasItemMaterial

var _age : float = 0.0
var _direction : Vector2 = Vector2.UP
var _size : float = 1.0
## 火花: [向き, 速さ, 長さ]
var _sparks : Array = []

## at(画面の座標)に出す。direction は火花が飛ぶ向き。size は大きさの倍率(強い弾ほど大きく)
static func spawn(tree : SceneTree, at : Vector2, direction : Vector2 = Vector2.UP, size : float = 1.0) -> void:
	if tree == null or tree.current_scene == null or _active >= MAX_ACTIVE:
		return
	var spark := HitSpark.new()
	spark._direction = direction.normalized() if direction.length_squared() > 0.0001 else Vector2.UP
	spark._size = clampf(size, 0.6, 2.0)
	tree.current_scene.add_child.call_deferred(spark)
	spark.position = at

func _ready() -> void:
	_active += 1
	z_as_relative = false
	z_index = Z_INDEX
	if _material == null:
		_material = CanvasItemMaterial.new()
		_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = _material
	for i in 5:
		_sparks.append([_direction.rotated(randf_range(-1.1, 1.1)), randf_range(70.0, 160.0), randf_range(4.0, 8.0)])

func _exit_tree() -> void:
	_active -= 1

func _process(delta : float) -> void:
	_age += delta
	if _age >= LIFE:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var t := clampf(_age / LIFE, 0.0, 1.0)
	var fade := 1.0 - t
	var out := 1.0 - (1.0 - t) * (1.0 - t)
	# 当たった所の光
	draw_circle(Vector2.ZERO, lerpf(5.0, 9.0, out) * _size, Color(EMBER, 0.35 * fade))
	if t < 0.45:
		draw_circle(Vector2.ZERO, 3.5 * _size * (1.0 - t / 0.45), CORE)
	# 飛び散る火花
	for spark in _sparks:
		var dir : Vector2 = spark[0]
		var pos : Vector2 = dir * float(spark[1]) * _age * _size
		var tail : Vector2 = pos - dir * float(spark[2]) * _size
		draw_line(tail, pos, Color(EMBER, 0.7 * fade), 2.0)
		draw_line(tail.lerp(pos, 0.5), pos, Color(HOT, fade), 1.0)
