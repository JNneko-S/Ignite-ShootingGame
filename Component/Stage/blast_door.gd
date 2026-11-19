extends Node2D
class_name BlastDoor
## 通路をふさぐ巨大な隔壁(上から見た絵を、コードで描く)。左右の扉が、横へ開いたり閉じたりする。
## 背景(BackgroundScroller)の子に置くので、背景と一緒に流れる。BreachSequence が作って動かす。

## 0 = 閉じている、1 = 開ききっている
var open_amount : float = 1.0:
	set(value):
		open_amount = value
		queue_redraw()
## 隔壁の半分の幅(中心から片側の端まで)と、扉の厚み(縦の大きさ)
@export var half_width : float = 330.0
@export var thickness : float = 92.0
## 閉まったあと、継ぎ目が赤く光る(1 → 0)
var seal_glow : float = 0.0:
	set(value):
		seal_glow = value
		queue_redraw()

const STEEL := Color(0.30, 0.32, 0.38)
const STEEL_LIGHT := Color(0.46, 0.49, 0.56)
const STEEL_DARK := Color(0.13, 0.14, 0.17)
const HAZARD := Color(0.95, 0.72, 0.12)

var _time : float = 0.0

func _process(delta : float) -> void:
	_time += delta
	queue_redraw() # 警告灯の点滅

func _draw() -> void:
	var h := thickness
	var w := half_width
	# 枠(扉が収まる溝)と、その影
	draw_rect(Rect2(-w - 20.0, -h * 0.5 - 14.0, (w + 20.0) * 2.0, h + 28.0), Color(0.0, 0.0, 0.0, 0.35))
	draw_rect(Rect2(-w - 20.0, -h * 0.5 - 10.0, (w + 20.0) * 2.0, 8.0), STEEL_DARK)
	draw_rect(Rect2(-w - 20.0, h * 0.5 + 2.0, (w + 20.0) * 2.0, 8.0), STEEL_DARK)
	draw_rect(Rect2(-w - 20.0, -h * 0.5 - 4.0, (w + 20.0) * 2.0, h + 8.0), Color(0.04, 0.03, 0.05))

	var slide := open_amount * w
	_draw_panel(-1.0, slide)
	_draw_panel(1.0, slide)

	# 閉じた継ぎ目の光
	if seal_glow > 0.01 and open_amount < 0.05:
		draw_rect(Rect2(-3.0 - 6.0 * seal_glow, -h * 0.5, 6.0 + 12.0 * seal_glow, h), Color(1.0, 0.35, 0.15, seal_glow))
		draw_rect(Rect2(-w, -2.0, w * 2.0, 4.0), Color(1.0, 0.5, 0.2, 0.5 * seal_glow))

	# 両端の警告灯(開いているあいだ点滅する)
	var blink := 0.5 + 0.5 * sin(_time * 12.0)
	for side in [-1.0, 1.0]:
		var p := Vector2(side * (w + 8.0), 0.0)
		draw_circle(p, 9.0, STEEL_DARK)
		draw_circle(p, 6.0, Color(1.0, 0.2, 0.1).lerp(Color(0.3, 0.05, 0.05), 1.0 - blink))
		draw_circle(p, 16.0, Color(1.0, 0.25, 0.1, 0.18 * blink))

## side: -1 = 左の扉、1 = 右の扉。slide だけ外へずれる
func _draw_panel(side : float, slide : float) -> void:
	var h := thickness
	var w := half_width
	# 扉の内側の端(閉じると中心で合わさる)
	var inner := side * slide
	var outer := side * (w + slide)
	var left := minf(inner, outer)
	var rect := Rect2(left, -h * 0.5, w, h)
	draw_rect(rect, STEEL)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 6.0)), STEEL_LIGHT) # 上の縁(光が当たる)
	draw_rect(Rect2(rect.position + Vector2(0.0, h - 6.0), Vector2(rect.size.x, 6.0)), STEEL_DARK)
	# 補強の縦の骨
	var rib := 48.0
	var x := rect.position.x + rib
	while x < rect.end.x - 8.0:
		draw_rect(Rect2(x - 3.0, -h * 0.5 + 6.0, 6.0, h - 12.0), STEEL_DARK)
		draw_circle(Vector2(x, -h * 0.5 + 12.0), 2.0, STEEL_LIGHT)
		draw_circle(Vector2(x, h * 0.5 - 12.0), 2.0, STEEL_LIGHT)
		x += rib
	# 合わさる側の端に、黄と黒の警告の縞
	var stripe_w := 40.0
	var edge_x := inner if side > 0.0 else inner - stripe_w
	draw_rect(Rect2(edge_x, -h * 0.5 + 6.0, stripe_w, h - 12.0), Color(0.08, 0.07, 0.05))
	var n := 6
	for i in n:
		var y0 := -h * 0.5 + 6.0 + (h - 12.0) * float(i) / float(n)
		var y1 := y0 + (h - 12.0) / float(n) * 0.5
		var bottom := h * 0.5 - 6.0
		var pts := PackedVector2Array([
			Vector2(edge_x, y0), Vector2(edge_x + stripe_w, minf(y0 + 6.0, bottom)),
			Vector2(edge_x + stripe_w, minf(y1 + 6.0, bottom)), Vector2(edge_x, y1)])
		draw_colored_polygon(pts, HAZARD)
