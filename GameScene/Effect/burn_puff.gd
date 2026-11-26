extends Node2D
class_name BurnPuff
## イグナイトで焼いた弾が燃え尽きる瞬間の、小さな炎。EnemyBullet が、焼かれたときに自分の位置へ出す。
## 白く光って、輪が広がり、火の粉が上へ舞って消える(そのあと、その場にスコアアイテムが残る)。
##
## 軽量化: 炎1つごとにノードを作らず、場面に1つだけ置いた BurnPuff(まとめ役)が、全部の炎を描く。
## 描くときは「丸 → 輪」の種類ごとにまとめて描く(何十個焼いても、描画命令は数回で済む)。
## 見た目を変えるときは、下の const を変える。

## 消えるまでの時間(秒)
const LIFE : float = 0.38
## 輪が広がりきったときの半径(px)
const RING_RADIUS : float = 20.0
## 真ん中の光の半径(px)
const FLASH_RADIUS : float = 13.0
## 火の粉の数と、飛ぶ距離(px)
const EMBERS : int = 5
const EMBER_DISTANCE : float = 26.0
## 描く順番。スコアアイテム(3)より上、敵弾(5)より下
const Z_INDEX : int = 4
## 同時に出せる数(超えた分は出さない)
const MAX_ACTIVE : int = 260

const WHITE := Color(1.0, 0.98, 0.85)
const YELLOW := Color(1.0, 0.82, 0.3)
const ORANGE := Color(1.0, 0.5, 0.12)
const RED := Color(0.95, 0.2, 0.1)

## 今の場面のまとめ役
static var _layer : BurnPuff

## 炎ごとの、位置と経過時間(同じ番号が1つの炎)
var _pos : PackedVector2Array = []
var _age : PackedFloat32Array = []
## 火の粉ごとの、飛ぶ向きと大きさ(炎1つにつき EMBERS 個ずつ並べる)
var _dirs : PackedVector2Array = []
var _sizes : PackedFloat32Array = []
var _mesh = preload("res://GameScene/Effect/batch_mesh.gd").new()

## at(画面の座標)に炎を出す
static func spawn(tree : SceneTree, at : Vector2) -> void:
	if tree == null or tree.current_scene == null:
		return
	if not is_instance_valid(_layer) or _layer.is_queued_for_deletion():
		_layer = BurnPuff.new()
		tree.current_scene.add_child.call_deferred(_layer) # 物理の処理中に呼ばれるので、後で足す
	_layer._add(at)

func _add(at : Vector2) -> void:
	if _pos.size() >= MAX_ACTIVE:
		return
	_pos.append(at)
	_age.append(0.0)
	for i in EMBERS:
		# 上へ舞い上がる向き(少し左右にばらす)
		_dirs.append(Vector2.from_angle(-PI / 2.0 + randf_range(-1.25, 1.25)) * randf_range(0.5, 1.0))
		_sizes.append(randf_range(2.2, 3.8))

func _ready() -> void:
	z_as_relative = false
	z_index = Z_INDEX
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD # 重なったところが明るくなる
	material = additive

func _process(delta : float) -> void:
	if _pos.is_empty():
		return
	for i in range(_pos.size() - 1, -1, -1):
		_age[i] += delta
		if _age[i] >= LIFE:
			_pos.remove_at(i)
			_age.remove_at(i)
			for k in EMBERS:
				_dirs.remove_at(i * EMBERS)
				_sizes.remove_at(i * EMBERS)
	queue_redraw() # 空になったときも1回描き直して、残りを消す

func _draw() -> void:
	# 全部の炎の丸・輪を、1つの三角形の集まりにためて、1回で描く
	_mesh.clear()
	for i in _pos.size():
		var t := clampf(_age[i] / LIFE, 0.0, 1.0)
		var out := 1.0 - (1.0 - t) * (1.0 - t) # 始めに速く、あとはゆっくり
		var at := to_local(_pos[i])
		# 真ん中の光: ぱっと光って、すぐ消える
		var flash := maxf(1.0 - t * 2.2, 0.0)
		if flash > 0.0:
			_mesh.circle(at, lerpf(FLASH_RADIUS * 0.6, FLASH_RADIUS, out), Color(ORANGE, 0.45 * flash), 12)
			_mesh.circle(at, lerpf(FLASH_RADIUS * 0.35, FLASH_RADIUS * 0.6, out), Color(WHITE, 0.9 * flash), 10)
		# 広がる輪
		_mesh.ring(at, lerpf(4.0, RING_RADIUS, out), lerpf(3.0, 1.0, t), Color(YELLOW.lerp(RED, t), 0.85 * (1.0 - t)), 18)
		# 火の粉: 上へ舞いながら、黄 → 橙 → 赤 と色を変えて小さくなる
		var ember_color := YELLOW.lerp(ORANGE, smoothstep(0.1, 0.5, t)).lerp(RED, smoothstep(0.5, 1.0, t))
		ember_color.a = 1.0 - smoothstep(0.6, 1.0, t)
		for k in EMBERS:
			var j := i * EMBERS + k
			_mesh.circle(at + _dirs[j] * EMBER_DISTANCE * out + Vector2(0.0, -10.0 * t), _sizes[j] * (1.0 - t * 0.8), ember_color, 6)
	_mesh.flush(get_canvas_item())
