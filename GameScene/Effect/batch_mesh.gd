extends RefCounted
## 丸・輪・線を、1つの三角形の集まりにためて、最後に1回の描画命令でまとめて描く道具。
## Godot は draw_circle や draw_arc を1つ呼ぶたびに描画命令を1回出すので、たくさんの小さなエフェクトを描くと重い。
## ここにためて flush() すれば、何百個あっても1回で済む。
##   var mesh := BatchMesh.new()
##   mesh.circle(at, 5.0, color) / mesh.ring(at, 16.0, 2.0, color) / mesh.line(a, b, 1.0, color)
##   mesh.flush(canvas_item)   … _draw() の中で呼ぶ

var points := PackedVector2Array()
var colors := PackedColorArray()
var indices := PackedInt32Array()

func clear() -> void:
	points.clear()
	colors.clear()
	indices.clear()

## 塗りつぶした丸(segments 角形)
func circle(at : Vector2, radius : float, color : Color, segments : int = 10) -> void:
	if radius <= 0.0 or color.a <= 0.0:
		return
	var center := points.size()
	points.append(at)
	colors.append(color)
	for k in segments:
		points.append(at + Vector2.from_angle(TAU * k / segments) * radius)
		colors.append(color)
	for k in segments:
		indices.append_array([center, center + 1 + k, center + 1 + (k + 1) % segments])

## 輪(半径 radius、太さ width)
func ring(at : Vector2, radius : float, width : float, color : Color, segments : int = 16) -> void:
	if radius <= 0.0 or color.a <= 0.0:
		return
	var inner := maxf(radius - width * 0.5, 0.0)
	var outer := radius + width * 0.5
	var first := points.size()
	for k in segments:
		var dir := Vector2.from_angle(TAU * k / segments)
		points.append(at + dir * inner)
		points.append(at + dir * outer)
		colors.append(color)
		colors.append(color)
	for k in segments:
		var a := first + k * 2
		var b := first + ((k + 1) % segments) * 2
		indices.append_array([a, a + 1, b + 1, a, b + 1, b])

## 輪の一部(from から to までの弧。角度はラジアン)
func arc(at : Vector2, radius : float, from : float, to : float, width : float, color : Color, segments : int = 12) -> void:
	if radius <= 0.0 or color.a <= 0.0 or segments < 1:
		return
	var inner := maxf(radius - width * 0.5, 0.0)
	var outer := radius + width * 0.5
	var first := points.size()
	for k in segments + 1:
		var dir := Vector2.from_angle(lerpf(from, to, float(k) / segments))
		points.append(at + dir * inner)
		points.append(at + dir * outer)
		colors.append(color)
		colors.append(color)
	for k in segments:
		var a := first + k * 2
		indices.append_array([a, a + 1, a + 3, a, a + 3, a + 2])

## 折れ線(points の点を順につなぐ)
func polyline(pts : PackedVector2Array, width : float, color : Color) -> void:
	for k in pts.size() - 1:
		line(pts[k], pts[k + 1], width, color)

## 太さ width の線
func line(from : Vector2, to : Vector2, width : float, color : Color) -> void:
	var d := to - from
	if d.length_squared() < 0.0001 or color.a <= 0.0:
		return
	var side := d.normalized().orthogonal() * width * 0.5
	var first := points.size()
	points.append_array([from + side, from - side, to - side, to + side])
	colors.append_array([color, color, color, color])
	indices.append_array([first, first + 1, first + 2, first, first + 2, first + 3])

## ためた形を、1回で描く(_draw の中で呼ぶ)
func flush(canvas_item : RID) -> void:
	if not indices.is_empty():
		RenderingServer.canvas_item_add_triangle_array(canvas_item, indices, points, colors)
