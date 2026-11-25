extends Node2D
class_name PlayerBeam
## 自機のショットの見た目のビーム(イグナイト Lv4 から)。Player が自分の子として作る。
## 見た目だけで、当たり判定は Player が撃つ見えない弾(Lv3 の5発と同じ)が受け持つ。
##   Lv4: 砲口から、波打つ炎の色の帯を重ねたビームが伸びる(絵は使わず描く)。砲口には十字の光が出る。
##        ビームの通り道に敵がいれば、いちばん手前の敵のところで止まり、そこに光の玉・輪・光の筋と火花が出る
##        (見えない弾も、いちばん手前の敵に当たって消えるので、見た目とダメージが合う)
##   Lv5: ビームのまわりを、Lv1 の弾がらせんを描いて回りながら昇っていく
## 撃っているあいだ(fire() が呼ばれ続けているあいだ)だけ出て、撃つのをやめると、すっと消える。

## 自機(Player が入れる)と、ビームの出る位置(自機からの相対位置)
var player : Node2D
var muzzle_offset : Vector2 = Vector2(0, -16)


## 敵を探すレイヤー(自機の弾と同じ: 敵の Hurtbox)
const ENEMY_MASK : int = 64
## 最後に撃ってから、この秒数たったら消え始める
const HOLD_TIME : float = 0.16
## らせんの弾の数・昇る速さ(px/秒)・回る速さ(回/秒)・らせんの半径の倍率(ビームの幅に対して)
const HELIX_COUNT : int = 7
const HELIX_SPEED : float = 480.0
const HELIX_TURN : float = 2.0
const HELIX_RADIUS : float = 1.1

var _since_fire : float = 999.0
var _alpha : float = 0.0
var _half_width : float = 14.0
var _helix : bool = false
var _time : float = 0.0
## ビームの先(自機からの相対の y)と、敵に当たっているか
var _end_y : float = -400.0
var _hitting : bool = false
var _spark_wait : float = 0.0
var _lost_time : float = 0.0
var _query_shape := RectangleShape2D.new()
## らせんの弾の絵(自機の弾のシーンから取る)
var _bullet_texture : Texture2D
var _bullet_region : Rect2
var _bullet_scale : float = 0.7
var _helix_back : _HelixLayer
var _helix_front : _HelixLayer

func _ready() -> void:
	z_as_relative = false
	z_index = 1 # 自機の弾と同じ(空の敵より奥)
	_load_bullet_look()
	# らせんの弾: 奥の弾はビームの後ろ、手前の弾はビームの前に描く
	_helix_back = _HelixLayer.new()
	_helix_back.beam = self
	_helix_back.front = false
	_helix_back.show_behind_parent = true
	add_child(_helix_back)
	_helix_front = _HelixLayer.new()
	_helix_front.beam = self
	_helix_front.front = true
	add_child(_helix_front)

## 撃った: half_width はビームの半分の幅(いちばん外側の弾の位置)、helix は Lv5 のらせん
func fire(helix : bool, half_width : float) -> void:
	_since_fire = 0.0
	_helix = helix
	_half_width = maxf(half_width, 4.0)

## 自機が回っていても(エンディングの脱出で下を向くなど)、ビームはいつも上へ伸ばす(自機のショットはいつも上へ飛ぶので、それに合わせる)
func _process(_delta : float) -> void:
	global_rotation = 0.0

func _physics_process(delta : float) -> void:
	global_rotation = 0.0
	_time += delta
	_since_fire += delta
	var target := 1.0 if _since_fire < HOLD_TIME else 0.0
	_alpha = move_toward(_alpha, target, delta * (14.0 if target > _alpha else 7.0))
	if _alpha > 0.01 and player:
		_find_end()
		_spark_wait -= delta
		if _hitting and _since_fire < HOLD_TIME and _spark_wait <= 0.0:
			_spark_wait = 0.07
			SparkBurst.spawn(get_tree().current_scene, player.global_position + Vector2(muzzle_offset.x, _end_y), 5, Color(1.0, 0.7, 0.25))
	queue_redraw()
	_helix_back.queue_redraw()
	_helix_front.queue_redraw()

## ビームの先: 通り道にいる敵のうち、いちばん手前(下)の敵のところ。いなければ画面の上の端の外
func _find_end() -> void:
	var view := CameraView.visible_rect(player)
	var top := view.position.y - player.global_position.y - 30.0
	var bottom := muzzle_offset.y
	var last_end := _end_y if _hitting else top
	var was_hitting := _hitting
	_end_y = top
	_hitting = false
	var length := bottom - top
	if length <= 0.0:
		return
	_query_shape.size = Vector2(_half_width * 2.0 + 8.0, length)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _query_shape
	query.transform = Transform2D(0.0, player.global_position + Vector2(muzzle_offset.x, (top + bottom) * 0.5))
	query.collision_mask = ENEMY_MASK
	query.collide_with_areas = true
	query.collide_with_bodies = false
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 32):
		var area := hit["collider"] as Area2D
		if area == null or not area.monitorable or _is_dying(area):
			continue
		var y := area.global_position.y - player.global_position.y
		if y < bottom - 8.0 and y > _end_y:
			_end_y = y
			_hitting = true
	# 当たっていたのに、このフレームだけ見つからないときは、少しのあいだ前の位置を保つ(ちらつかないように)
	if _hitting:
		_lost_time = 0.0
	elif was_hitting and _lost_time < 0.08:
		_lost_time += get_physics_process_delta_time()
		_end_y = last_end
		_hitting = true

## ビームのふち(左右)の点。y ごとに、ゆらゆら波打つ。scale は幅の倍率
func _edge(from_y : float, to_y : float, half : float, wave : float, scale : float, side : float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var y := from_y
	while y > to_y:
		var ripple := 1.0 + wave * sin(y * 0.09 + _time * 34.0) + wave * 0.6 * sin(y * 0.23 - _time * 21.0)
		points.append(Vector2(muzzle_offset.x + side * half * scale * ripple, y))
		y -= 6.0
	points.append(Vector2(muzzle_offset.x + side * half * scale * 0.6, to_y))
	return points

## 帯(左のふち → 先 → 右のふち)を1枚描く
func _band(from_y : float, to_y : float, half : float, wave : float, scale : float, color : Color) -> void:
	var left := _edge(from_y, to_y, half, wave, scale, -1.0)
	var right := _edge(from_y, to_y, half, wave, scale, 1.0)
	right.reverse()
	var shape := PackedVector2Array()
	shape.append_array(left)
	shape.append(Vector2(muzzle_offset.x, to_y - half * scale * 0.5)) # 先はとがらせる
	shape.append_array(right)
	draw_colored_polygon(shape, color)

func _draw() -> void:
	if _alpha <= 0.01 or player == null:
		return
	var from := muzzle_offset
	var end := _end_y + 4.0
	if from.y - end <= 4.0:
		return
	var a := _alpha
	var half := (_half_width + 6.0) * (1.0 + 0.05 * sin(_time * 53.0))
	# 帯を外から重ねる: 赤い外のふち → オレンジ → 黄 → 白い芯
	_band(from.y, end, half, 0.10, 1.35, Color(0.85, 0.12, 0.05, 0.35 * a))
	_band(from.y, end, half, 0.08, 1.0, Color(1.0, 0.38, 0.06, 0.95 * a))
	_band(from.y, end, half, 0.06, 0.68, Color(1.0, 0.75, 0.2, a))
	_band(from.y, end, half, 0.04, 0.32, Color(1.0, 0.98, 0.85, a))
	# ふちの細い線(ビームの輪郭をくっきり)
	draw_polyline(_edge(from.y, end, half, 0.08, 1.0, -1.0), Color(1.0, 0.85, 0.5, 0.8 * a), 1.0)
	draw_polyline(_edge(from.y, end, half, 0.08, 1.0, 1.0), Color(1.0, 0.85, 0.5, 0.8 * a), 1.0)
	# 上へ走るエネルギーの帯(山形の光)
	var span := from.y - end
	for i in 5:
		var y := from.y - fmod(_time * 1100.0 + i * span / 5.0, span)
		var w := half * 0.95
		var chevron := PackedVector2Array([Vector2(from.x - w, y + 7.0), Vector2(from.x, y), Vector2(from.x + w, y + 7.0),
			Vector2(from.x + w, y + 10.0), Vector2(from.x, y + 3.0), Vector2(from.x - w, y + 10.0)])
		draw_colored_polygon(chevron, Color(1.0, 1.0, 0.9, 0.55 * a))
	_draw_muzzle(from, half, a)
	if _hitting:
		_draw_impact(Vector2(from.x, _end_y), half, a)

## 砲口: ふくらむ光と、回る十字の光(レンズフレア)
func _draw_muzzle(at : Vector2, half : float, a : float) -> void:
	var pulse := 1.0 + 0.15 * sin(_time * 40.0)
	draw_circle(at, half * 1.5 * pulse, Color(1.0, 0.4, 0.08, 0.35 * a))
	draw_circle(at, half * 1.0 * pulse, Color(1.0, 0.75, 0.25, 0.85 * a))
	draw_circle(at, half * 0.55, Color(1.0, 1.0, 0.92, a))
	_draw_star(at, half * 3.2 * pulse, half * 0.22, _time * 1.5, Color(1.0, 0.9, 0.6, 0.85 * a))

## 当たっているところ: 光の玉、広がる輪、放射状の光の筋、十字の光
func _draw_impact(at : Vector2, half : float, a : float) -> void:
	var pulse := 1.0 + 0.2 * sin(_time * 55.0)
	draw_circle(at, half * 2.2 * pulse, Color(1.0, 0.35, 0.05, 0.3 * a))
	draw_circle(at, half * 1.4 * pulse, Color(1.0, 0.7, 0.2, 0.85 * a))
	draw_circle(at, half * 0.8 * pulse, Color(1.0, 1.0, 0.9, a))
	for i in 2:
		var t := fmod(_time * 4.0 + i * 0.5, 1.0)
		draw_arc(at, half * lerpf(1.2, 3.4, t), 0.0, TAU, 28, Color(1.0, 0.8, 0.4, (1.0 - t) * 0.8 * a), 2.0)
	# 放射状の光の筋(下半分へ、はじける向き)
	for i in 9:
		var angle := PI * (i + 0.5) / 9.0 + 0.25 * sin(_time * 13.0 + i)
		var length := half * (2.2 + 1.2 * absf(sin(_time * 29.0 + i * 1.7)))
		var tip := at + Vector2.from_angle(angle) * length
		draw_line(at, tip, Color(1.0, 0.85, 0.45, 0.75 * a), 2.0)
	_draw_star(at, half * 4.0 * pulse, half * 0.25, -_time * 2.0, Color(1.0, 0.95, 0.7, 0.9 * a))

## 十字の光(細いひし形を2本、十字に重ねる)
func _draw_star(at : Vector2, length : float, thickness : float, angle : float, color : Color) -> void:
	for k in 2:
		var dir := Vector2.from_angle(angle + PI * 0.5 * k)
		var side := dir.orthogonal() * thickness
		draw_colored_polygon(PackedVector2Array([at + dir * length, at + side, at - dir * length, at - side]), color)

## Lv5: Lv1 の弾が、ビームのまわりをらせんに回りながら昇る。front が true なら手前側の弾だけ、false なら奥側だけ描く
func _draw_helix_on(canvas : CanvasItem, front : bool) -> void:
	if not _helix or _bullet_texture == null or _alpha <= 0.01:
		return
	var from := muzzle_offset
	var length := from.y - _end_y
	if length <= 0.0:
		return
	var radius := (_half_width + 5.0) * HELIX_RADIUS
	for i in HELIX_COUNT:
		var travel := fmod(_time * HELIX_SPEED + i * length / HELIX_COUNT, length)
		var angle := (_time * HELIX_TURN + travel / 140.0) * TAU + i * 0.9
		var depth := cos(angle) # 正で手前、負で奥
		if (depth >= 0.0) != front:
			continue
		var pos := Vector2(from.x + sin(angle) * radius, from.y - travel)
		var shade := lerpf(0.5, 1.0, (depth + 1.0) * 0.5)
		var size := _bullet_region.size * _bullet_scale * lerpf(0.8, 1.1, (depth + 1.0) * 0.5)
		var fade := minf(1.0, travel / 40.0) * minf(1.0, (length - travel) / 30.0) # 根元と先では、ふわっと出入りする
		canvas.draw_texture_rect_region(_bullet_texture, Rect2(pos - size * 0.5, size), _bullet_region,
			Color(shade, shade, shade, _alpha * fade))

## 自機の弾のシーンから、弾の絵(1コマ目)を取る
func _load_bullet_look() -> void:
	var scene : PackedScene = player.get("bullet_scene") if player else null
	if scene == null:
		return
	var bullet := scene.instantiate()
	for node in bullet.find_children("*", "Sprite2D", true, false):
		var sprite := node as Sprite2D
		_bullet_texture = sprite.texture
		if _bullet_texture:
			var frame_size := _bullet_texture.get_size() / Vector2(maxi(sprite.hframes, 1), maxi(sprite.vframes, 1))
			_bullet_region = Rect2(Vector2.ZERO, frame_size)
			_bullet_scale = sprite.scale.x
		break
	bullet.free()

## らせんの弾を描く子ノード(手前側か奥側の、どちらか)
class _HelixLayer extends Node2D:
	var beam : PlayerBeam
	var front : bool = true
	func _draw() -> void:
		if beam:
			beam._draw_helix_on(self, front)

## 倒されて爆発しているところの敵(もう当たらないことにする)
func _is_dying(area : Area2D) -> bool:
	var node : Node = area.get_parent()
	while node:
		if node is Enemy:
			return node._is_dead
		node = node.get_parent()
	return false
