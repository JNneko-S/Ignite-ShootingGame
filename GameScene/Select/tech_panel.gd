extends Control
class_name TechPanel
## 機体選択の画面の、枠の付いた板。形を選んで、大きさ(Size)いっぱいに描く。
##   ROUNDED     : 角の丸い四角
##   LEFT_BRACKET: 左の画面の端から出ている、右の角を落とした板(左の辺は開いている)
##   TRAPEZOID   : 下の画面の端から出ている、上の角を落とした台形(下の辺は開いている)
## Show Grid をオンにすると、うすい方眼と、上から下へ流れる走査線を描く(プレビューの画面らしく)。

enum Shape { ROUNDED, LEFT_BRACKET, TRAPEZOID }

@export var shape : Shape = Shape.ROUNDED:
	set(value):
		shape = value
		queue_redraw()
## 中の色と、枠の線の色・太さ
@export var fill_color : Color = Color(0.03, 0.06, 0.1, 0.9)
@export var line_color : Color = Color(0.35, 0.85, 1.0)
@export var line_width : float = 2.0
## 角を落とす大きさ(px)と、丸い角の半径(px)
@export var cut : float = 26.0
@export var corner_radius : float = 14.0
## うすい方眼と走査線
@export var show_grid : bool = false
@export var grid_spacing : float = 12.0
@export var scan_speed : float = 45.0

var _time : float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(show_grid)

func _process(delta : float) -> void:
	_time += delta
	queue_redraw()

## 枠の点(閉じた形)。open が true の辺は、線を引かない
func _points() -> PackedVector2Array:
	var w := size.x
	var h := size.y
	match shape:
		Shape.LEFT_BRACKET:
			return PackedVector2Array([Vector2(0, 0), Vector2(w - cut, 0), Vector2(w, cut), Vector2(w, h - cut), Vector2(w - cut, h), Vector2(0, h)])
		Shape.TRAPEZOID:
			return PackedVector2Array([Vector2(0, h), Vector2(cut, 0), Vector2(w - cut, 0), Vector2(w, h)])
	# 角の丸い四角
	var points := PackedVector2Array()
	var r := minf(corner_radius, minf(w, h) * 0.5)
	var centers := [Vector2(w - r, r), Vector2(w - r, h - r), Vector2(r, h - r), Vector2(r, r)]
	for i in 4:
		for s in 7:
			var angle := -PI / 2.0 + PI / 2.0 * i + PI / 2.0 * s / 6.0
			points.append(centers[i] + Vector2.from_angle(angle) * r)
	return points

func _draw() -> void:
	var points := _points()
	draw_colored_polygon(points, fill_color)
	if show_grid:
		_draw_grid()
	# 枠の線。開いている辺(画面の端に付いている辺)は引かない
	var outline := points.duplicate()
	if shape == Shape.ROUNDED:
		outline.append(points[0])
	draw_polyline(outline, Color(line_color, 0.35), line_width + 3.0)
	draw_polyline(outline, line_color, line_width)
	# 内側の細い線(少し内側に、うすく)
	if shape == Shape.ROUNDED:
		var inner := PackedVector2Array()
		var center := size * 0.5
		for p in outline:
			inner.append(p + (center - p).normalized() * 5.0)
		draw_polyline(inner, Color(line_color, 0.25), 1.0)

func _draw_grid() -> void:
	var inset := 6.0
	var rect := Rect2(Vector2(inset, inset), size - Vector2(inset, inset) * 2.0)
	var grid := Color(line_color, 0.08)
	var x := rect.position.x + grid_spacing
	while x < rect.end.x:
		draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), grid, 1.0)
		x += grid_spacing
	var y := rect.position.y + grid_spacing
	while y < rect.end.y:
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), grid, 1.0)
		y += grid_spacing
	# 走査線: 上から下へ流れる、光る線と、そのうしろのぼんやりした光
	var scan := rect.position.y + fmod(_time * scan_speed, rect.size.y)
	for i in 6:
		var yy := scan - i * 3.0
		if yy > rect.position.y:
			draw_line(Vector2(rect.position.x, yy), Vector2(rect.end.x, yy), Color(line_color, 0.18 * (1.0 - i / 6.0)), 2.0)
