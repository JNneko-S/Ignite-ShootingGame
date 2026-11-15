extends Node2D
class_name LaneWarning
## 列車のボスが線路を移って入り直す前に、入ってくる線路に出す予告。
## 赤い帯が点滅し、列車が進んでくる向きへ矢印(＞)が流れる。画面の縦いっぱいに出て、決まった時間で消える。
## 位置: x はワールドの座標(線路の位置)のまま。y は画面(Camera2D に映っている範囲)に合わせる。

## 帯の色
@export var color : Color = Color(1.0, 0.25, 0.15)

var _width : float = 120.0
var _up : bool = true
var _life : float = 1.4
var _age : float = 0.0

## enemy の近く(シーンの直下)に、x の線路の予告を出す。up: 列車が画面の下から上へ進んでくるか
static func spawn(enemy : Node, x : float, width : float, up : bool, time : float) -> LaneWarning:
	if enemy == null or not enemy.is_inside_tree():
		return null
	var warning := LaneWarning.new()
	warning._width = width
	warning._up = up
	warning._life = time
	warning.z_as_relative = false
	warning.z_index = 4 # 弾(5)より奥、敵や地面より手前
	enemy.get_tree().current_scene.add_child(warning)
	warning.global_position = Vector2(x, 0.0)
	warning._follow_view()
	return warning

func _process(delta : float) -> void:
	_age += delta
	if _age >= _life:
		queue_free()
		return
	_follow_view()
	queue_redraw()

func _follow_view() -> void:
	var view := CameraView.visible_rect(self)
	global_position.y = view.position.y

func _draw() -> void:
	var view := CameraView.visible_rect(self)
	var h := view.size.y
	var half := _width * 0.5
	# 出はじめと消える前は、薄くする
	var fade := clampf(_age / 0.15, 0.0, 1.0) * clampf((_life - _age) / 0.25, 0.0, 1.0)
	var blink := 0.55 + 0.45 * absf(sin(_age * TAU * 2.5))
	var band := Color(color, 0.16 * fade * blink)
	draw_rect(Rect2(-half, 0.0, _width, h), band)
	var edge := Color(color, 0.7 * fade * blink)
	draw_line(Vector2(-half, 0.0), Vector2(-half, h), edge, 2.0)
	draw_line(Vector2(half, 0.0), Vector2(half, h), edge, 2.0)
	# 進んでくる向きへ流れる矢印
	var step := 70.0
	var flow := fmod(_age * 260.0, step)
	var dir := -1.0 if _up else 1.0
	var size := minf(half * 0.6, 28.0)
	var arrow := Color(color.lightened(0.3), 0.85 * fade)
	var y := -step + (step - flow if _up else flow)
	while y < h + step:
		var tip := Vector2(0.0, y + dir * size * 0.5)
		draw_polyline(PackedVector2Array([tip + Vector2(-size, -dir * size), tip, tip + Vector2(size, -dir * size)]), arrow, 4.0)
		y += step
