extends Node2D
class_name FlankWarning
## 画面の横から弾幕が来る前に、来る側の画面の端に出す予告(FlankBarrage が作る)。
## 点滅する矢印(画面の内側を向く)。一直線の弾幕なら、通り道にも細い線を出す。
## 画面(カメラ)が動いても、画面の端に付いていく。

var _from_left : bool = true
var _y_ratio : float = 0.5
var _life : float = 0.8
var _age : float = 0.0
var _color : Color = Color(1.0, 0.3, 0.2)
var _line : bool = false

## enemy の近く(シーンの直下)に予告を出す。from_left: 左から来るか / y_ratio: 画面の上から 0〜1 の高さ / line: 通り道の線も出すか
static func spawn(enemy : Node, from_left : bool, y_ratio : float, time : float, color : Color, line : bool) -> FlankWarning:
	if enemy == null or not enemy.is_inside_tree():
		return null
	var warning := FlankWarning.new()
	warning._from_left = from_left
	warning._y_ratio = y_ratio
	warning._life = maxf(time, 0.1)
	warning._color = color
	warning._line = line
	warning.z_as_relative = false
	warning.z_index = 40 # 弾や敵より手前
	enemy.get_tree().current_scene.add_child(warning)
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
	global_position = Vector2(view.position.x if _from_left else view.end.x, view.position.y + view.size.y * _y_ratio)

func _draw() -> void:
	var view := CameraView.visible_rect(self)
	var blink := 0.45 + 0.55 * absf(sin(_age * TAU * 3.0))
	var dir := 1.0 if _from_left else -1.0 # 画面の内側の向き
	# 矢印(画面の端から内側を指す三角)
	var size := 18.0
	var base := 6.0 * dir
	var tip := Vector2(base + dir * size * 1.4, 0.0)
	var pts := PackedVector2Array([tip, Vector2(base, -size), Vector2(base, size)])
	draw_colored_polygon(pts, Color(_color, 0.85 * blink))
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), Color(1, 1, 1, 0.8 * blink), 2.0)
	# 一直線の弾幕: 通り道に細い線
	if _line:
		var t := clampf(_age / (_life * 0.6), 0.0, 1.0) # 線が端から伸びていく
		draw_line(Vector2(base, 0.0), Vector2(base + dir * view.size.x * t, 0.0), Color(_color, 0.55 * blink), 2.0)
