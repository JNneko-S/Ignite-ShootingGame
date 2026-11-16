extends Node2D
class_name DeflectSpark
## 弾が装甲に「はじかれた」ときの火花。DeflectSpark.spawn(tree, 位置, はね返る向き) で出し、すぐ消える。
## 白〜水色の短い火花が、はね返る向きへ扇に散り、当たった所に小さな六角形の光(装甲の面)が一瞬出る。
## ダメージがほとんど入っていないことが分かるように、炎や爆発(オレンジ)とは色を変えてある。

const LIFE : float = 0.22
## 描く順番。敵弾(5)より手前
const Z_INDEX : int = 6
## 同時に出せる数(撃ち続けても増えすぎないように)
const MAX_ACTIVE : int = 120

const CORE := Color(1.0, 1.0, 1.0)
const GLOW := Color(0.45, 0.85, 1.0)

static var _active : int = 0
static var _material : CanvasItemMaterial

var _age : float = 0.0
var _direction : Vector2 = Vector2.DOWN
## 火花: [向き, 速さ, 長さ]
var _sparks : Array = []

## at(画面の座標)に出す。direction は火花がはね返る向き
static func spawn(tree : SceneTree, at : Vector2, direction : Vector2 = Vector2.DOWN) -> void:
	if tree == null or tree.current_scene == null or _active >= MAX_ACTIVE:
		return
	var spark := DeflectSpark.new()
	spark._direction = direction.normalized() if direction.length_squared() > 0.0001 else Vector2.DOWN
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
	for i in 7:
		_sparks.append([_direction.rotated(randf_range(-0.9, 0.9)), randf_range(90.0, 180.0), randf_range(5.0, 10.0)])

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
	# 装甲の面: 小さな六角形が光って広がる
	var hex := PackedVector2Array()
	var r := lerpf(6.0, 14.0, out)
	for i in 7:
		hex.append(Vector2.from_angle(TAU * i / 6.0 + PI / 6.0) * r)
	draw_polyline(hex, Color(GLOW, 0.8 * fade), 1.5)
	if t < 0.3:
		draw_circle(Vector2.ZERO, 3.0 * (1.0 - t / 0.3), CORE)
	# はね返る火花
	for spark in _sparks:
		var dir : Vector2 = spark[0]
		var pos : Vector2 = dir * float(spark[1]) * _age
		var tail : Vector2 = pos - dir * float(spark[2])
		draw_line(tail, pos, Color(GLOW, 0.6 * fade), 2.0)
		draw_line(tail.lerp(pos, 0.5), pos, Color(CORE, fade), 1.0)
