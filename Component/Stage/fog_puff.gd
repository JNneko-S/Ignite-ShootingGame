extends Node2D
class_name FogPuff
## 霧に突っ込んだときの「ぼふっ」。霧の色のかたまりが、ぼわっと広がって消える(StageTransition が作る)。
## かたまりは、上と左右へ押しのけられるように広がる。ドット絵に合わせて、円は少しカクカクに描く。

## 広がって消えるまでの時間(秒)
@export var life : float = 0.55
## かたまりの数・最後の大きさ(px)
@export var count : int = 14
@export var size : float = 34.0
## 霧の色(FogOverlay のシェーダーの色に合わせる)
@export var light_color : Color = Color(0.92, 0.94, 0.96)
@export var shadow_color : Color = Color(0.66, 0.70, 0.74)

var _age : float = 0.0
var _blobs : Array[Vector4] = [] # 向き(x, y)、遠さの倍率、大きさの倍率

## at に「ぼふっ」を出す
static func spawn(tree : SceneTree, at : Vector2, scale_mul : float = 1.0) -> FogPuff:
	var puff := FogPuff.new()
	puff.size *= scale_mul
	puff.z_as_relative = false
	puff.z_index = 60 # 霧(50)より手前
	tree.current_scene.add_child(puff)
	puff.global_position = at
	return puff

func _ready() -> void:
	for i in count:
		# 上と左右へ広がる(下へはあまり広がらない)
		var angle := randf_range(-PI, 0.0) + randf_range(-0.35, 0.35)
		var dir := Vector2.from_angle(angle)
		_blobs.append(Vector4(dir.x, dir.y, randf_range(0.6, 1.3), randf_range(0.5, 1.0)))

func _process(delta : float) -> void:
	_age += delta
	if _age >= life:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var t := clampf(_age / life, 0.0, 1.0)
	var spread := 1.0 - pow(1.0 - t, 3.0) # 最初に勢いよく広がって、ゆっくり止まる
	var alpha := 1.0 - t * t
	# まんなかの白いかたまり
	draw_circle(Vector2.ZERO, size * (0.5 + 0.6 * spread), Color(light_color, 0.9 * alpha))
	for b in _blobs:
		var center := Vector2(b.x, b.y) * size * 1.6 * b.z * spread
		var r := size * 0.45 * b.w * (0.6 + 0.8 * spread)
		draw_circle(center + Vector2(2, 3), r, Color(shadow_color, 0.8 * alpha), true, -1.0, false)
		draw_circle(center, r, Color(light_color, 0.95 * alpha), true, -1.0, false)
	# 一瞬の輪(押し出された空気)
	if t < 0.4:
		draw_arc(Vector2.ZERO, size * (0.6 + 2.2 * t / 0.4), 0.0, TAU, 24, Color(1, 1, 1, 0.7 * (1.0 - t / 0.4)), 3.0, false)
