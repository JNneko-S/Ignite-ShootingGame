extends Node2D
class_name BurnPuff
## イグナイトで焼いた弾が燃え尽きる瞬間の、小さな炎。EnemyBullet が、焼かれたときに自分の位置へ出す。
## 白く光って、輪が広がり、火の粉が上へ舞って消える(そのあと、その場にスコアアイテムが残る)。
## 一度にたくさん(画面全体の弾)焼いても重くならないように、絵やパーティクルは使わず、丸と輪を数個描くだけにしてある。
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

static var _active : int = 0
static var _material : CanvasItemMaterial

var _age : float = 0.0
## 火の粉ごとの、飛ぶ向きと大きさ
var _dirs : PackedVector2Array = []
var _sizes : PackedFloat32Array = []

## at(画面の座標)に炎を出す
static func spawn(tree : SceneTree, at : Vector2) -> void:
	if tree == null or tree.current_scene == null or _active >= MAX_ACTIVE:
		return
	var puff := BurnPuff.new()
	tree.current_scene.add_child.call_deferred(puff) # 物理の処理中に呼ばれるので、後で足す
	puff.position = at

func _ready() -> void:
	_active += 1
	z_as_relative = false
	z_index = Z_INDEX
	if _material == null:
		_material = CanvasItemMaterial.new()
		_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD # 重なったところが明るくなる
	material = _material
	for i in EMBERS:
		# 上へ舞い上がる向き(少し左右にばらす)
		_dirs.append(Vector2.from_angle(-PI / 2.0 + randf_range(-1.25, 1.25)) * randf_range(0.5, 1.0))
		_sizes.append(randf_range(2.2, 3.8))

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
	var out := 1.0 - (1.0 - t) * (1.0 - t) # 始めに速く、あとはゆっくり
	# 真ん中の光: ぱっと光って、すぐ消える
	var flash := maxf(1.0 - t * 2.2, 0.0)
	if flash > 0.0:
		draw_circle(Vector2.ZERO, lerpf(FLASH_RADIUS * 0.6, FLASH_RADIUS, out), Color(ORANGE, 0.45 * flash))
		draw_circle(Vector2.ZERO, lerpf(FLASH_RADIUS * 0.35, FLASH_RADIUS * 0.6, out), Color(WHITE, 0.9 * flash))
	# 広がる輪
	var ring_color := YELLOW.lerp(RED, t)
	draw_arc(Vector2.ZERO, lerpf(4.0, RING_RADIUS, out), 0.0, TAU, 20, Color(ring_color, 0.85 * (1.0 - t)), lerpf(3.0, 1.0, t))
	# 火の粉: 上へ舞いながら、黄 → 橙 → 赤 と色を変えて小さくなる
	for i in _dirs.size():
		var pos := _dirs[i] * EMBER_DISTANCE * out + Vector2(0.0, -10.0 * t)
		var color := YELLOW.lerp(ORANGE, smoothstep(0.1, 0.5, t)).lerp(RED, smoothstep(0.5, 1.0, t))
		draw_circle(pos, _sizes[i] * (1.0 - t * 0.8), Color(color, 1.0 - smoothstep(0.6, 1.0, t)))
