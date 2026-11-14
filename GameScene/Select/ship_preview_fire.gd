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

var _options : Array[Sprite2D] = []
var _bullets : Array[Dictionary] = [] # { sprite, velocity }
var _fire_left : float = 0.0
var _time : float = 0.0

func _ready() -> void:
	_build_options()

## 機体を切り替えたとき: 飛んでいる弾を消して、子機を機体の位置に戻す
func reset() -> void:
	for b in _bullets:
		b["sprite"].queue_free()
	_bullets.clear()
	_fire_left = 0.0
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
	if option_slots.is_empty():
		return _ship_position()
	return _ship_position() + option_slots[i % option_slots.size()] * _world_scale()

func _process(delta : float) -> void:
	_time += delta
	var k := _world_scale()
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
	# 弾を動かす(パネルの外に出たら消す)
	var limit := _limit()
	for i in range(_bullets.size() - 1, -1, -1):
		var b := _bullets[i]
		var sprite : Sprite2D = b["sprite"]
		sprite.position += b["velocity"] * delta
		sprite.frame = frame_index % sprite.hframes
		if not limit.has_point(sprite.position):
			sprite.queue_free()
			_bullets.remove_at(i)

func _volley(k : float) -> void:
	var from := _ship_position() + muzzle_offset * k
	for angle in shot_angles:
		_spawn_bullet(from, angle, bullet_color, k)
	for i in _options.size():
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
