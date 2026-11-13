extends Node2D
class_name VanishPuff
## 弾消しで消えた敵弾の、消滅のエフェクト。EnemyBullet.vanish() が、消える瞬間に弾の位置へ出す。
## 白く光る輪が広がり、細かい光の粒が散って消える。点にならない弾消しなので、焼却(BurnPuff)の炎とは色を変えてある。
## 一度にたくさん(画面全体の弾)消しても重くならないように、絵やパーティクルは使わず、輪と粒を数個描くだけ。
## 見た目を変えるときは、下の const を変える。

## 消えるまでの時間(秒)
const LIFE : float = 0.32
## 輪が広がりきったときの半径(px)
const RING_RADIUS : float = 16.0
## 光の粒の数と、飛ぶ距離(px)
const SPARKLES : int = 4
const SPARKLE_DISTANCE : float = 18.0
## 描く順番。スコアアイテム(3)より上、敵弾(5)より下
const Z_INDEX : int = 4
## 同時に出せる数(超えた分は出さない)
const MAX_ACTIVE : int = 400

const CORE := Color(1.0, 1.0, 1.0)

static var _active : int = 0
static var _material : CanvasItemMaterial

## 弾の色(輪と粒の色。白に寄せて使う)
var tint : Color = Color(0.7, 0.85, 1.0)
var _age : float = 0.0
var _angle0 : float = 0.0

## at(画面の座標)にエフェクトを出す。color は消えた弾の色
static func spawn(tree : SceneTree, at : Vector2, color : Color = Color(0.7, 0.85, 1.0)) -> void:
	if tree == null or tree.current_scene == null or _active >= MAX_ACTIVE:
		return
	var puff := VanishPuff.new()
	puff.tint = color.lerp(Color.WHITE, 0.35)
	tree.current_scene.add_child.call_deferred(puff)
	puff.position = at

func _ready() -> void:
	_active += 1
	z_as_relative = false
	z_index = Z_INDEX
	if _material == null:
		_material = CanvasItemMaterial.new()
		_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = _material
	_angle0 = randf() * TAU

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
	var out := 1.0 - (1.0 - t) * (1.0 - t)
	var fade := 1.0 - t
	# 真ん中の光(すぐ消える)
	var flash := maxf(1.0 - t * 3.0, 0.0)
	if flash > 0.0:
		draw_circle(Vector2.ZERO, lerpf(5.0, 8.0, out), Color(CORE, 0.8 * flash))
	# 広がる輪
	draw_arc(Vector2.ZERO, lerpf(3.0, RING_RADIUS, out), 0.0, TAU, 18, Color(tint, 0.9 * fade), lerpf(2.5, 0.8, t))
	# 十字に散る光の粒
	for i in SPARKLES:
		var pos := Vector2.from_angle(_angle0 + TAU * i / SPARKLES) * SPARKLE_DISTANCE * out
		var size := 2.2 * fade
		draw_line(pos - Vector2(size * 1.6, 0), pos + Vector2(size * 1.6, 0), Color(tint, fade), 1.0)
		draw_line(pos - Vector2(0, size * 1.6), pos + Vector2(0, size * 1.6), Color(tint, fade), 1.0)
		draw_circle(pos, size * 0.6, Color(CORE, fade))
