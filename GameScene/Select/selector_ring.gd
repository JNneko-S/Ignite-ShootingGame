extends Control
class_name SelectorRing
## 機体選択の、真ん中の丸い枠と、左右の矢印。中の機体の絵は、子の Sprite2D(Icon)。
## pulse(-1 / 1) を呼ぶと、押した側の矢印が光って外へはねる。
## Active がオフのあいだ(難易度を選んでいるあいだ)は、矢印が暗くなり、輪の回転が止まる。

## 輪の半径(px)
@export var radius : float = 44.0
@export var ring_color : Color = Color(0.35, 0.85, 1.0)
@export var fill_color : Color = Color(0.03, 0.06, 0.1, 0.92)
## 矢印の色・大きさ(px)・輪からのすき間(px)
@export var arrow_color : Color = Color(0.2, 0.75, 1.0)
@export var arrow_size : float = 14.0
@export var arrow_gap : float = 8.0
## 選び終わったあとの、輪の色(決まった感じ)
@export var locked_color : Color = Color(1.0, 0.7, 0.2)

var active : bool = true:
	set(value):
		active = value
		queue_redraw()
var _time : float = 0.0
var _pulse_left : float = 0.0
var _pulse_right : float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta : float) -> void:
	_time += delta
	_pulse_left = maxf(_pulse_left - delta * 5.0, 0.0)
	_pulse_right = maxf(_pulse_right - delta * 5.0, 0.0)
	queue_redraw()

## 矢印を光らせる(-1 で左、1 で右)
func pulse(direction : int) -> void:
	if direction < 0:
		_pulse_left = 1.0
	else:
		_pulse_right = 1.0

func _draw() -> void:
	var center := size * 0.5
	var color := ring_color if active else locked_color
	draw_circle(center, radius, fill_color)
	draw_arc(center, radius, 0.0, TAU, 48, Color(color, 0.35), 5.0)
	draw_arc(center, radius, 0.0, TAU, 48, color, 2.0)
	# 内側の目盛り: 選んでいるあいだはゆっくり回る
	var turn := _time * 0.6 if active else 0.0
	for i in 24:
		var angle := turn + TAU * i / 24.0
		var length := 6.0 if i % 6 == 0 else 3.0
		var from := center + Vector2.from_angle(angle) * (radius - 4.0)
		draw_line(from, from - Vector2.from_angle(angle) * length, Color(color, 0.7 if i % 6 == 0 else 0.35), 1.0)
	# 左右の矢印
	for side in [-1, 1]:
		var pulse_amount : float = _pulse_left if side < 0 else _pulse_right
		var base_x : float = center.x + side * (radius + arrow_gap + pulse_amount * 5.0)
		var tip := Vector2(base_x + side * arrow_size, center.y)
		var points := PackedVector2Array([tip, Vector2(base_x, center.y - arrow_size), Vector2(base_x, center.y + arrow_size)])
		var arrow := arrow_color.lerp(Color.WHITE, pulse_amount * 0.7)
		if not active:
			arrow = Color(arrow_color, 0.2)
		else:
			arrow.a = 0.75 + 0.25 * sin(_time * 4.0)
		draw_colored_polygon(points, Color(arrow, arrow.a * 0.25))
		var outline := points.duplicate()
		outline.append(points[0])
		draw_polyline(outline, arrow, 2.0)
