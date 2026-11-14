extends Control
class_name OffscreenArrows
## 画面の左右の外にいる敵と、画面の外から飛んでくる弾を、画面の端の矢印で知らせる UI。
## 横に広いステージ(ステージ2)で使う。CanvasLayer の子に、画面いっぱいの大きさで置く。
##   敵(と、ボスの砲台)… 赤い大きな矢印。その高さの、近い方の端に出る
##   弾 … 小さな橙色の矢印。画面に向かって飛んできていて、端の近く(Bullet Warn Distance 以内)にあるときだけ。
##         矢印は、弾が飛んでくる向き(自機の側)を指す
## 敵が多いときは、同じくらいの高さの矢印を1つにまとめる。通り過ぎるだけの列車(tag train)は出さない。

@export var enemy_color : Color = Color(0.95, 0.12, 0.12, 0.5)
@export var bullet_color : Color = Color(1.0, 0.55, 0.15, 0.45)
@export var outline_color : Color = Color(1.0, 1.0, 1.0, 0.4)
## 矢印の大きさ(px)
@export var enemy_size : float = 18.0
@export var bullet_size : float = 9.0
## 画面の端からの間(px)
@export var edge_margin : float = 6.0
## 弾の矢印を出す、画面の端からの距離(px、ワールド)
@export var bullet_warn_distance : float = 260.0
## この間隔(px)より近い高さの矢印は、1つにまとめる
@export var merge_distance : float = 34.0
## 弾の矢印の最大の数(片側)
@export var max_bullet_arrows : int = 6

var _time : float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

func _process(delta : float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var view := CameraView.visible_rect(camera)
	var screen := size
	# 敵: 左右の外にいて、高さが画面の中のもの
	var left : Array[float] = []
	var right : Array[float] = []
	for target in EnemyPart.targets(get_tree()):
		if target.is_in_group("stage_train") or not target.is_visible_in_tree():
			continue
		var p := target.global_position
		if p.y < view.position.y - 20.0 or p.y > view.end.y + 20.0:
			continue
		if p.x < view.position.x:
			_add_merged(left, p.y)
		elif p.x > view.end.x:
			_add_merged(right, p.y)
	var pulse := 0.93 + 0.07 * sin(_time * 6.0)
	for y in left:
		_arrow(Vector2(edge_margin, _screen_y(y, view, screen)), -1.0, enemy_size * pulse, enemy_color)
	for y in right:
		_arrow(Vector2(screen.x - edge_margin, _screen_y(y, view, screen)), 1.0, enemy_size * pulse, enemy_color)
	# 弾: 画面に向かって飛んできていて、端の近くにあるもの。矢印は弾の飛ぶ向き(自機の側)を指す
	var bl : Array[float] = []
	var br : Array[float] = []
	var bl_dir : Array[Vector2] = []
	var br_dir : Array[Vector2] = []
	for node in get_tree().get_nodes_in_group("enemy_bullet"):
		var bullet := node as EnemyBullet
		if bullet == null:
			continue
		var p := bullet.global_position
		if p.y < view.position.y or p.y > view.end.y:
			continue
		if p.x < view.position.x and p.x > view.position.x - bullet_warn_distance and bullet.direction.x > 0.1:
			if bl.size() < max_bullet_arrows and _add_merged(bl, p.y):
				bl_dir.append(bullet.direction)
		elif p.x > view.end.x and p.x < view.end.x + bullet_warn_distance and bullet.direction.x < -0.1:
			if br.size() < max_bullet_arrows and _add_merged(br, p.y):
				br_dir.append(bullet.direction)
	for i in bl.size():
		_arrow_toward(Vector2(edge_margin + enemy_size + bullet_size * 1.6, _screen_y(bl[i], view, screen)), bl_dir[i], bullet_size, bullet_color)
	for i in br.size():
		_arrow_toward(Vector2(screen.x - edge_margin - enemy_size - bullet_size * 1.6, _screen_y(br[i], view, screen)), br_dir[i], bullet_size, bullet_color)

## 近い高さの矢印がまだなければ足す(足したら true)
func _add_merged(list : Array[float], y : float) -> bool:
	for v in list:
		if absf(v - y) < merge_distance:
			return false
	list.append(y)
	return true

func _screen_y(world_y : float, view : Rect2, screen : Vector2) -> float:
	var y := (world_y - view.position.y) / maxf(view.size.y, 1.0) * screen.y
	return clampf(y, 30.0, screen.y - 20.0)

## center を中心に、dir の向きを指す三角
func _arrow_toward(center : Vector2, dir : Vector2, s : float, color : Color) -> void:
	var d := dir.normalized() if dir.length() > 0.001 else Vector2.RIGHT
	var n := Vector2(-d.y, d.x)
	var tip := center + d * s * 0.9
	var back := center - d * s * 0.7
	var points := PackedVector2Array([tip, back + n * s * 0.8, back - n * s * 0.8])
	draw_colored_polygon(points, color)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, outline_color, 1.5)

## 外を向いた三角(dir: -1 で左向き、1 で右向き)。先が tip
func _arrow(tip : Vector2, dir : float, s : float, color : Color) -> void:
	var back := tip + Vector2(-dir * s * 1.6, 0.0)
	var points := PackedVector2Array([tip, back + Vector2(0.0, -s * 0.8), back + Vector2(0.0, s * 0.8)])
	draw_colored_polygon(points, color)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, outline_color, 2.0)
