extends Node2D
class_name ShipPreviewFire
## 機体選択の画面で、プレビューの機体に「子機(オプション)付きで撃っている」様子をさせる見た目だけの部品。
## Clip Contents をオンにした Control(FireClip)の子に置き、Ship に PreviewShip(Sprite2D)を割り当てる。
## 当たり判定もゲームの処理もない。弾も子機もただの Sprite2D で、FireClip の外は切り取られる。
## FireClip を PreviewShip より上(先)に並べると、機体が弾より手前に描かれる。
##
## 大きさは、ゲーム中の見た目をプレビューの倍率で拡大したものになる。
##   倍率 = 機体の Preview Scale ÷ Ship Game Scale(ゲーム中の自機の Sprite2D の Scale)

## プレビューの機体。弾と子機は、この位置から出る
@export var ship : Sprite2D
## ゲーム中の自機の絵の Scale(player.tscn の Sprite2D と同じにする)
@export var ship_game_scale : float = 0.75
## 撃つかどうか
@export var firing : bool = true
## Lv1 と Lv5 の撃ち方を、この秒数ごとに切り替えて見せる
@export var level_swap_time : float = 5.0

@export_group("ショット(ゲーム中の値)")
## 弾の絵と、横に何コマ並んでいるか(コマは順に切り替わる)
@export var bullet_texture : Texture2D = preload("res://Assets/Bullet/Player/P1_Hyper_Bullet.png")
@export var bullet_hframes : int = 2
@export var bullet_scale : float = 0.4
@export var bullet_color : Color = Color.WHITE
## 撃つ間隔(秒)と、撃つ向き(度。0 で真上)
@export var fire_interval : float = 0.1
@export var shot_angles : Array[float] = [0.0, 3.0, -3.0]
## 弾が出る位置(機体の中心から)
@export var muzzle_offset : Vector2 = Vector2(0, -16)
## プレビューでの弾の速さ(px/秒、ゲーム中の大きさで)。ゲームより遅くして、弾が見えるようにする
@export var bullet_speed : float = 380.0

@export_group("子機(ゲーム中の値)")
## 子機の数(0 なら出さない)
@export_range(0, 4) var option_count : int = 2
@export var option_texture : Texture2D = preload("res://Assets/ship.png")
@export var option_hframes : int = 5
@export var option_vframes : int = 2
## 子機のアニメーションのコマ(順に繰り返す)と、1コマの時間
@export var option_frames : Array[int] = [0, 1, 2, 3, 4, 5, 6, 7, 8]
@export var option_frame_time : float = 0.1
## 子機の位置(自機からの相対位置)と、撃つ向き(度)。option.tscn の Slots / Slot Angles と同じ
@export var option_slots : Array[Vector2] = [Vector2(-26, 18), Vector2(26, 18), Vector2(-48, 34), Vector2(48, 34)]
@export var option_angles : Array[float] = [-15.0, 15.0, -25.0, 25.0]
## 子機の弾の色(option.tscn の Shot Color と同じ)
@export var option_bullet_color : Color = Color(0.6, 1.0, 0.8)
## 子機が自機に追いつく速さ(大きいほどぴったり付いてくる)
@export var option_follow : float = 14.0

## ショットガン(BASTION): 0 なら通常のショット。1回に撃つ弾の数・広がり(度)・撃つ間隔・消えるまでの時間(プレビューの速さで)
var _pellet_count : int = 0
var _pellet_spread : float = 60.0
var _pellet_interval : float = 0.2
var _pellet_life : float = 0.0
var _pellet_left : float = 0.0
## 機体に合わせる前の、PHOENIX の値(切り替えたときに戻す)
var _defaults : Dictionary = {}

## 見せているゲージの Lv(Lv1 と Lv5 を、Level Swap Time 秒ごとに切り替える)
var _level : int = 1
var _level_left : float = 0.0
## ショットガンの Lv ごとの連発の回数と間隔(BASTION)、連発の1発ごとの間隔
var _pellet_bursts : Array = [1]
var _pellet_intervals : Array = [0.2]
var _burst_gap : float = 0.04
## まだ撃っていない連発の残り時間(秒)
var _pending : Array[float] = []
## Lv5 でビームになる機体か(PHOENIX)と、ビームの半分の幅(ゲーム中の px)
## 子機が自機のまわりを回る機体(BASTION): 円の半径(ゲーム中の px)・回る速さ(度/秒)・2way の開き(度)。半径 0 なら回らない
var _orbit_radius : float = 0.0
var _orbit_speed : float = 150.0
var _orbit_spread : float = 14.0
var _has_beam : bool = false
var _beam_half : float = 14.0
var _label_font : Font = preload("res://Assets/Fonts/micronian.ttf")
var _options : Array[Sprite2D] = []
var _bullets : Array[Dictionary] = [] # { sprite, velocity } # { sprite, velocity, life }
var _fire_left : float = 0.0
var _time : float = 0.0

func _ready() -> void:
	_level_left = level_swap_time
	_label = _LabelLayer.new()
	_label.preview = self
	_label.z_index = 5 # 弾・子機より手前
	add_child(_label)
	_defaults = {"ship_game_scale": ship_game_scale, "fire_interval": fire_interval, "shot_angles": shot_angles.duplicate(),
		"option_angles": option_angles.duplicate()}
	_build_options()

## 選んだ機体の撃ち方に合わせる(機体の自機のシーンから、ゲーム中の値を読む)。
## BASTION(ショットガンを持つ機体)なら、ショットガンと、左右に開く子機の向きにする
func configure(ship_data : ShipData) -> void:
	ship_game_scale = _defaults.get("ship_game_scale", ship_game_scale)
	fire_interval = _defaults.get("fire_interval", fire_interval)
	shot_angles.assign(_defaults.get("shot_angles", shot_angles))
	option_angles.assign(_defaults.get("option_angles", option_angles))
	_orbit_radius = 0.0
	_pellet_count = 0
	if ship_data == null or ship_data.player_scene == null:
		return
	var player := ship_data.player_scene.instantiate()
	var sprite := player.get_node_or_null("Sprite2D") as Sprite2D
	if sprite:
		ship_game_scale = sprite.scale.x
	_has_beam = "parallel_offsets_5" in player and not ("pellet_count" in player)
	if _has_beam and not player.parallel_offsets_5.is_empty():
		_beam_half = absf(float(player.parallel_offsets_5[0]))
	if "pellet_count" in player:
		_pellet_count = player.pellet_count
		_pellet_spread = player.pellet_spread
		_pellet_bursts = Array(player.pellet_bursts)
		_pellet_intervals = Array(player.pellet_intervals)
		_burst_gap = player.pellet_burst_gap
		_pellet_interval = float(player.pellet_intervals[0]) if not player.pellet_intervals.is_empty() else 0.2
		# 届く距離はゲームと同じにする(プレビューの弾は遅いので、そのぶん長く飛ばす)
		_pellet_life = player.pellet_life * player.pellet_speed / maxf(bullet_speed, 1.0)
		fire_interval = player.option_interval
		if "orbit_radius" in player:
			_orbit_radius = player.orbit_radius
			_orbit_speed = player.orbit_speed
			_orbit_spread = player.option_way_spread
		option_angles.assign(player.option_angles)
	player.free()

## 機体を切り替えたとき: 飛んでいる弾を消して、子機を機体の位置に戻す
func reset() -> void:
	for b in _bullets:
		b["sprite"].queue_free()
	_bullets.clear()
	_fire_left = 0.0
	_pending.clear()
	_level = 1
	_level_left = level_swap_time
	_build_options()

func _world_scale() -> float:
	if ship == null or ship_game_scale <= 0.0:
		return 1.0
	return ship.scale.x / ship_game_scale

func _build_options() -> void:
	for o in _options:
		o.queue_free()
	_options.clear()
	for i in option_count:
		var sprite := Sprite2D.new()
		sprite.texture = option_texture
		sprite.hframes = maxi(option_hframes, 1)
		sprite.vframes = maxi(option_vframes, 1)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.position = _ship_position()
		sprite.z_index = 1 # 機体より手前
		add_child(sprite)
		_options.append(sprite)

func _ship_position() -> Vector2:
	return to_local(ship.global_position) if ship else Vector2.ZERO

func _option_target(i : int) -> Vector2:
	if _orbit_radius > 0.0:
		return _ship_position() + Vector2.from_angle(_orbit_angle(i)) * _orbit_radius * _world_scale()
	if option_slots.is_empty():
		return _ship_position()
	return _ship_position() + option_slots[i % option_slots.size()] * _world_scale()

func _process(delta : float) -> void:
	_time += delta
	var k := _world_scale()
	# Lv1 と Lv5 を、決まった秒数ごとに切り替える
	if level_swap_time > 0.0:
		_level_left -= delta
		if _level_left <= 0.0:
			_level_left += level_swap_time
			_level = 5 if _level == 1 else 1
			_pending.clear()
	queue_redraw()
	# 子機: 自機の隣の位置へ、少し遅れて付いていく
	var frame_index := int(_time / maxf(option_frame_time, 0.01))
	for i in _options.size():
		var o := _options[i]
		o.scale = Vector2.ONE * k
		o.position = o.position.lerp(_option_target(i), 1.0 - exp(-option_follow * delta))
		if not option_frames.is_empty():
			o.frame = clampi(option_frames[frame_index % option_frames.size()], 0, o.hframes * o.vframes - 1)
	# 撃つ
	if firing and ship and ship.visible:
		_fire_left -= delta
		while _fire_left <= 0.0:
			_fire_left += maxf(fire_interval, 0.02)
			_volley(k)
		if _pellet_count > 0:
			_pellet_left -= delta
			while _pellet_left <= 0.0:
				_pellet_left += maxf(float(_at(_pellet_intervals, _level, _pellet_interval)), 0.02)
				_shotgun(k)
				# 連発(Lv3 から): 同じショットガンを、少しずつ遅らせて撃つ
				for n in range(1, int(_at(_pellet_bursts, _level, 1))):
					_pending.append(_burst_gap * n)
			for j in range(_pending.size() - 1, -1, -1):
				_pending[j] -= delta
				if _pending[j] <= 0.0:
					_pending.remove_at(j)
					_shotgun(k)
	# 弾を動かす(パネルの外に出たら消す)
	var limit := _limit()
	for i in range(_bullets.size() - 1, -1, -1):
		var b := _bullets[i]
		var sprite : Sprite2D = b["sprite"]
		sprite.position += b["velocity"] * delta
		sprite.frame = frame_index % sprite.hframes
		var life : float = b.get("life", 0.0)
		if life > 0.0:
			life -= delta
			b["life"] = life
			if life < 0.08:
				sprite.modulate.a = maxf(life / 0.08, 0.0)
		if not limit.has_point(sprite.position) or (b.has("life") and life <= 0.0):
			sprite.queue_free()
			_bullets.remove_at(i)

func _volley(k : float) -> void:
	var from := _ship_position() + muzzle_offset * k
	if _pellet_count <= 0 and not (_has_beam and _level >= 5): # Lv5 の PHOENIX はビーム(_draw で描く)
		for angle in shot_angles:
			_spawn_bullet(from, angle, bullet_color, k)
	for i in _options.size():
		if _orbit_radius > 0.0:
			# 回る子機: 外向きに 2way
			var out := rad_to_deg(_orbit_angle(i)) + 90.0 # 0 で真上の向きに直す
			for side in [-0.5, 0.5]:
				_spawn_bullet(_options[i].position, out + _orbit_spread * side, option_bullet_color, k)
			continue
		var angle : float = option_angles[i % option_angles.size()] if not option_angles.is_empty() else 0.0
		_spawn_bullet(_options[i].position, angle, option_bullet_color, k)

## 子機より奥に弾を描く(子機は先に足してあるので、弾は子機の前に並べ替える)
func _spawn_bullet(at : Vector2, angle_deg : float, color : Color, k : float) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = bullet_texture
	sprite.hframes = maxi(bullet_hframes, 1)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.modulate = color
	sprite.scale = Vector2.ONE * bullet_scale * k
	sprite.position = at
	var direction := Vector2.UP.rotated(deg_to_rad(angle_deg))
	sprite.rotation = direction.angle() + PI * 0.5
	add_child(sprite)
	move_child(sprite, 0)
	_bullets.append({"sprite": sprite, "velocity": direction * bullet_speed * k})

## 弾を消す範囲(パネルの大きさより少し広く)
func _limit() -> Rect2:
	var parent := get_parent() as Control
	var size := parent.size if parent else Vector2(512, 512)
	return Rect2(Vector2.ZERO, size).grow(40.0)

## ショットガン(BASTION): 大きく広がって、すぐ消える弾
func _shotgun(k : float) -> void:
	var from := _ship_position() + muzzle_offset * k
	for i in _pellet_count:
		var t := 0.5 if _pellet_count <= 1 else float(i) / (_pellet_count - 1)
		var angle := lerpf(-_pellet_spread * 0.5, _pellet_spread * 0.5, t) + randf_range(-2.0, 2.0)
		_spawn_bullet(from, angle, Color(1.0, 1.0, 1.0, 0.8), k)
		_bullets.back()["life"] = _pellet_life

func _at(values : Array, index : int, fallback) :
	if values.is_empty():
		return fallback
	return values[clampi(index, 0, values.size() - 1)]

# ---------------------------------------------------------------- Lv の表示と、PHOENIX の Lv5 のビーム

func _draw() -> void:
	if ship == null:
		return
	var k := _world_scale()
	if _has_beam and _level >= 5 and firing and ship.visible:
		_draw_beam(_ship_position() + muzzle_offset * k, k)
	if _label:
		_label.queue_redraw()

## 左上に、今見せている Lv と、切り替わるまでの残り時間(細いバー)を描く。弾より手前に出すため、子のノード(_label)から呼ぶ
func _draw_label(canvas : CanvasItem) -> void:
	var text := "Lv%d" % _level
	var color := Color(1.0, 0.6, 0.2) if _level >= 5 else Color(0.45, 0.85, 1.0)
	canvas.draw_string_outline(_label_font, Vector2(6, 16), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, Color.BLACK)
	canvas.draw_string(_label_font, Vector2(6, 16), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)
	if level_swap_time > 0.0:
		var w := 40.0 * clampf(_level_left / level_swap_time, 0.0, 1.0)
		canvas.draw_rect(Rect2(6, 20, w, 2), Color(color, 0.7))

## ゲームのビーム(PlayerBeam)と同じ形: 波打つ帯を外から重ね、山形の光が上へ走る。
## まわりを Lv1 の弾がらせんに回る(奥の弾はビームの後ろ、手前の弾はビームの前)
func _draw_beam(from : Vector2, k : float) -> void:
	var top := -40.0
	var half := (_beam_half + 6.0) * k * (1.0 + 0.05 * sin(_time * 53.0))
	_draw_helix(from, top, half, k, false)
	_band(from, top, half, 0.10, 1.35, Color(0.85, 0.12, 0.05, 0.35))
	_band(from, top, half, 0.08, 1.0, Color(1.0, 0.38, 0.06, 0.95))
	_band(from, top, half, 0.06, 0.68, Color(1.0, 0.75, 0.2))
	_band(from, top, half, 0.04, 0.32, Color(1.0, 0.98, 0.85))
	var span := from.y - top
	for i in 4:
		var y := from.y - fmod(_time * 1100.0 * k + i * span / 4.0, span)
		var w := half * 0.95
		draw_colored_polygon(PackedVector2Array([Vector2(from.x - w, y + 7.0), Vector2(from.x, y), Vector2(from.x + w, y + 7.0),
			Vector2(from.x + w, y + 10.0), Vector2(from.x, y + 3.0), Vector2(from.x - w, y + 10.0)]), Color(1.0, 1.0, 0.9, 0.55))
	draw_circle(from, half * 1.4, Color(1.0, 0.45, 0.1, 0.35))
	draw_circle(from, half * 0.9, Color(1.0, 0.8, 0.3, 0.9))
	_draw_helix(from, top, half, k, true)

func _band(from : Vector2, top : float, half : float, wave : float, scale : float, color : Color) -> void:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var y := from.y
	while y > top:
		var ripple := 1.0 + wave * sin(y * 0.09 + _time * 34.0) + wave * 0.6 * sin(y * 0.23 - _time * 21.0)
		left.append(Vector2(from.x - half * scale * ripple, y))
		right.append(Vector2(from.x + half * scale * ripple, y))
		y -= 6.0
	right.reverse()
	var shape := PackedVector2Array()
	shape.append_array(left)
	shape.append_array(right)
	if shape.size() >= 3:
		draw_colored_polygon(shape, color)

func _draw_helix(from : Vector2, top : float, half : float, k : float, front : bool) -> void:
	if bullet_texture == null:
		return
	var length := from.y - top
	var frame_w := bullet_texture.get_width() / float(maxi(bullet_hframes, 1))
	var region := Rect2(0, 0, frame_w, bullet_texture.get_height())
	for i in 6:
		var travel := fmod(_time * 420.0 * k + i * length / 6.0, length)
		var angle := (_time * 2.0 + travel / 140.0) * TAU + i * 0.9
		var depth := cos(angle)
		if (depth >= 0.0) != front:
			continue
		var pos := Vector2(from.x + sin(angle) * half * 1.1, from.y - travel)
		var shade := lerpf(0.5, 1.0, (depth + 1.0) * 0.5)
		var size := region.size * bullet_scale * k * lerpf(0.8, 1.1, (depth + 1.0) * 0.5)
		draw_texture_rect_region(bullet_texture, Rect2(pos - size * 0.5, size), region, Color(shade, shade, shade))

var _label : _LabelLayer

## Lv の表示を描く子ノード(弾より手前)
class _LabelLayer extends Node2D:
	var preview : ShipPreviewFire
	func _draw() -> void:
		if preview:
			preview._draw_label(self)

## 回る子機の、今の角度(ラジアン。ゲームの PlayerOption.orbit_angle と同じ式)
func _orbit_angle(i : int) -> float:
	return deg_to_rad(_orbit_speed) * _time + TAU * i / maxf(_options.size(), 1.0) - PI / 2.0
