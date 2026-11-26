extends Node2D
class_name VanishPuff
## 弾消しで消えた敵弾の、消滅のエフェクト。EnemyBullet.vanish() が、消える瞬間に弾の位置へ出す。
## 白く光る輪が広がり、細かい光の粒が散って消える。点にならない弾消しなので、焼却(BurnPuff)の炎とは色を変えてある。
##
## 軽量化: エフェクト1つごとにノードを作らず、場面に1つだけ置いた VanishPuff(まとめ役)が、全部のエフェクトを描く。
## 描くときは「丸 → 輪 → 線」の種類ごとにまとめて描く(種類が切り替わるたびに描画命令が分かれるので、
## まとめると、何十個出ても描画命令は数回で済む)。
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

## 今の場面のまとめ役
static var _layer : VanishPuff

## エフェクトごとの、位置・経過時間・色・粒の向きの始まり(同じ番号が1つのエフェクト)
var _pos : PackedVector2Array = []
var _age : PackedFloat32Array = []
var _tint : PackedColorArray = []
var _angle0 : PackedFloat32Array = []
var _mesh = preload("res://GameScene/Effect/batch_mesh.gd").new()

## at(画面の座標)にエフェクトを出す。color は消えた弾の色
static func spawn(tree : SceneTree, at : Vector2, color : Color = Color(0.7, 0.85, 1.0)) -> void:
	if tree == null or tree.current_scene == null:
		return
	if not is_instance_valid(_layer) or _layer.is_queued_for_deletion():
		_layer = VanishPuff.new()
		tree.current_scene.add_child.call_deferred(_layer) # 物理の処理中に呼ばれることが多いので、後で足す
	_layer._add(at, color.lerp(Color.WHITE, 0.35))

func _add(at : Vector2, tint : Color) -> void:
	if _pos.size() >= MAX_ACTIVE:
		return
	_pos.append(at)
	_age.append(0.0)
	_tint.append(tint)
	_angle0.append(randf() * TAU)

func _ready() -> void:
	z_as_relative = false
	z_index = Z_INDEX
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive

func _process(delta : float) -> void:
	if _pos.is_empty():
		return
	# 時間を進めて、消えたものを外す(後ろから消すと、番号がずれない)
	for i in range(_pos.size() - 1, -1, -1):
		_age[i] += delta
		if _age[i] >= LIFE:
			_pos.remove_at(i)
			_age.remove_at(i)
			_tint.remove_at(i)
			_angle0.remove_at(i)
	queue_redraw() # 空になったときも1回描き直して、残りを消す

func _draw() -> void:
	# 全部のエフェクトの丸・輪・線を、1つの三角形の集まりにためて、1回で描く
	_mesh.clear()
	for i in _pos.size():
		var t := clampf(_age[i] / LIFE, 0.0, 1.0)
		var out := 1.0 - (1.0 - t) * (1.0 - t)
		var fade := 1.0 - t
		var at := to_local(_pos[i])
		# 真ん中の光(すぐ消える)
		var flash := maxf(1.0 - t * 3.0, 0.0)
		if flash > 0.0:
			_mesh.circle(at, lerpf(5.0, 8.0, out), Color(CORE, 0.8 * flash))
		# 広がる輪
		_mesh.ring(at, lerpf(3.0, RING_RADIUS, out), lerpf(2.5, 0.8, t), Color(_tint[i], 0.9 * fade))
		# 十字に散る光の粒
		var size := 2.2 * fade
		var color := Color(_tint[i], fade)
		for k in SPARKLES:
			var pos := at + Vector2.from_angle(_angle0[i] + TAU * k / SPARKLES) * SPARKLE_DISTANCE * out
			_mesh.line(pos - Vector2(size * 1.6, 0), pos + Vector2(size * 1.6, 0), 1.0, color)
			_mesh.line(pos - Vector2(0, size * 1.6), pos + Vector2(0, size * 1.6), 1.0, color)
			_mesh.circle(pos, size * 0.6, Color(CORE, fade), 6)
	_mesh.flush(get_canvas_item())
