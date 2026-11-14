extends Node2D
class_name PlayerOption
## 自機の子機(オプション)。パワーアップアイテムで増える。シーン(GameScene/Player/option.tscn)で使う。
## 自機の隣の決まった位置(スロット)へ追いかけて動き、自機が撃つのに合わせて弾を撃つ。
## 低速移動中は自機に寄る。ロックショット中は、ロックした敵を追いかける弾を撃つ。
##
## 見た目: 子の Sprite2D の Texture を差し替える。Texture が空のあいだは、丸を描いて代わりにする。

## 何番目の子機か(0 から)。位置(スロット)を決める
var slot : int = 0

## 子機の位置(自機からの相対位置)と、撃つ向き(度。0 で真上、マイナスで左、プラスで右)。番号の順に増える
## 通常: 自機の斜め後ろに V 字に並び、外側へ広げて撃つ
@export var slots : Array[Vector2] = [Vector2(-26, 18), Vector2(26, 18), Vector2(-48, 34), Vector2(48, 34)]
@export var slot_angles : Array[float] = [-15.0, 15.0, -25.0, 25.0]
## 低速移動中(ロックしていないとき): 自機の横に並び、真上に撃つ
@export var focus_slots : Array[Vector2] = [Vector2(-16, -12), Vector2(16, -12), Vector2(-34, 2), Vector2(34, 2)]
@export var focus_slot_angles : Array[float] = [0.0, 0.0, 0.0, 0.0]
## ロックオン中(低速移動中に、敵を1体以上ロックしているとき)。空なら Focus と同じ。
## 弾は向きどおりに撃ち出してから、ロックした敵へ曲がっていく
@export var lock_slots : Array[Vector2] = [Vector2(-16, -12), Vector2(16, -12), Vector2(-34, 2), Vector2(34, 2)]
@export var lock_slot_angles : Array[float] = [0.0, 0.0, 0.0, 0.0]
## 位置へ追いつく速さ(大きいほどぴったり付いてくる)
@export var follow_sharpness : float = 14.0
## 子機が撃つ弾のシーン。空なら、自機と同じ弾(Player の Bullet Scene)を使う
@export var bullet_scene : PackedScene
## 弾1発の威力の、自機のショットに対する倍率
@export var damage_scale : float = 0.6
## 弾の色(自機と同じ弾を使うときだけ掛ける。Bullet Scene を指定したら、そのシーンの見た目のまま)
@export var shot_color : Color = Color(1.0, 0.78, 0.5)
## 回転の速さ(ラジアン/秒)。0 なら回らない
@export var spin_speed : float = 0.0

@export_group("フォーメーション変更の動き")
## 位置が変わるときに、自機の周りの輪(土星の輪のような横長の楕円)を回ってから、次の位置へ移る。
## 回る周数。0 なら、今までどおりスッと移る
@export var ring_laps : float = 3.0
## 1周にかける時間(秒)
@export var ring_lap_time : float = 0.16
## 輪の大きさ(横の半径, 縦の半径)(px)
@export var ring_radius : Vector2 = Vector2(52, 12)
## 輪の傾き(度)。0 で水平
@export var ring_tilt_deg : float = -8.0
## 輪の奥側(上半分)で小さく・暗くなる度合い(0 なら変わらない)
@export_range(0.0, 1.0, 0.05) var ring_depth : float = 0.35
## 今の位置から輪へ乗るまでの時間と、輪から次の位置へ移るまでの時間(秒)
@export var ring_enter_time : float = 0.08
@export var ring_exit_time : float = 0.2
## 残像を出す間隔(秒)と、消えるまでの時間(秒)。間隔 0 なら残像なし
@export var afterimage_interval : float = 0.025
@export var afterimage_life : float = 0.18

var _player : Player
var _mode_now : int = -1
var _changing : bool = false
var _change_age : float = 0.0
var _change_from : Vector2
var _exit_from : Vector2
var _afterimage_timer : float = 0.0

@onready var _sprite : Sprite2D = get_node_or_null("Sprite2D") as Sprite2D

func setup(player : Player, index : int) -> void:
	_player = player
	slot = index
	top_level = true # 自機の回転や点滅の影響を受けない(位置は自分で追いかける)
	global_position = player.global_position

func _ready() -> void:
	scale = Vector2.ZERO
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.25)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _physics_process(delta : float) -> void:
	if not is_instance_valid(_player):
		return
	visible = _player.visible
	var mode := _mode()
	if mode != _mode_now:
		# 位置が変わるときだけ回る(低速移動中 → ロックオンのように、位置が同じなら回らない)
		if _mode_now >= 0 and ring_laps > 0.0 and not _changing and _offset_for(_mode_now) != _offset_for(mode):
			_change_from = global_position - _player.global_position
			_change_age = 0.0
			_changing = true
		_mode_now = mode
	if _changing:
		_update_change(delta)
		return
	var target := _player.global_position + target_offset()
	global_position = global_position.lerp(target, 1.0 - exp(-follow_sharpness * delta))
	rotation += spin_speed * delta

## フォーメーション変更の動き: 輪に乗る → 輪を ring_laps 周する → 次の位置へ少し行きすぎて止まる。残像を残す
func _update_change(delta : float) -> void:
	_change_age += delta
	var orbit_time := ring_laps * ring_lap_time
	var offset : Vector2
	if _change_age < orbit_time:
		var t := _change_age / orbit_time
		var on_ring := _ring_point(_ring_angle(t))
		var enter := clampf(_change_age / maxf(ring_enter_time, 0.001), 0.0, 1.0)
		enter = 1.0 - pow(1.0 - enter, 3.0)
		offset = _change_from.lerp(on_ring, enter)
		_exit_from = on_ring
		_apply_depth(_ring_angle(t), enter)
	else:
		var u := clampf((_change_age - orbit_time) / maxf(ring_exit_time, 0.001), 0.0, 1.0)
		offset = _exit_from.lerp(target_offset(), _ease_out_back(u))
		_apply_depth(_ring_angle(1.0), 1.0 - u)
		if u >= 1.0:
			_changing = false
			_apply_depth(0.0, 0.0)
	global_position = _player.global_position + offset
	_afterimage_timer -= delta
	if afterimage_interval > 0.0 and _afterimage_timer <= 0.0 and _changing:
		_afterimage_timer = afterimage_interval
		_spawn_afterimage()

## 輪の上の角度。子機どうしは等間隔に並び、だんだん速く回り始め、最後はゆるむ
func _ring_angle(t : float) -> float:
	var count := maxi(_player.options.size(), 1)
	var start := PI * 0.5 + TAU * slot / count # 手前(下)から並べる
	var eased := t * t * (3.0 - 2.0 * t) # ゆっくり始まり、ゆっくり終わる
	return start + TAU * ring_laps * eased

## 輪の上の位置(自機からの相対位置)
func _ring_point(angle : float) -> Vector2:
	return Vector2(cos(angle) * ring_radius.x, sin(angle) * ring_radius.y).rotated(deg_to_rad(ring_tilt_deg))

## 奥(上半分)にいるときは、自機の後ろに描いて、小さく暗くする。amount は効き具合(0〜1)
func _apply_depth(angle : float, amount : float) -> void:
	var front := sin(angle) # 1 で一番手前、-1 で一番奥
	var shade := 1.0 - ring_depth * (1.0 - front) * 0.5 * amount
	scale = Vector2.ONE * shade
	modulate = Color(shade, shade, shade, 1.0)
	z_index = _player.z_index + (1 if front >= 0.0 or amount <= 0.0 else -1)

## 最後に少し行きすぎてから戻る
func _ease_out_back(t : float) -> float:
	var c1 := 1.4
	var u := t - 1.0
	return 1.0 + (c1 + 1.0) * u * u * u + c1 * u * u

## 今の見た目を写した、すぐ消える影を置く
func _spawn_afterimage() -> void:
	if _sprite == null or _sprite.texture == null or not visible:
		return
	var ghost := Sprite2D.new()
	ghost.texture = _sprite.texture
	ghost.hframes = _sprite.hframes
	ghost.vframes = _sprite.vframes
	ghost.frame = _sprite.frame
	ghost.flip_h = _sprite.flip_h
	ghost.offset = _sprite.offset
	ghost.centered = _sprite.centered
	ghost.global_transform = _sprite.global_transform
	ghost.modulate = Color(shot_color, 0.6)
	ghost.z_index = z_index - 1
	get_tree().current_scene.add_child(ghost)
	var tween := ghost.create_tween().set_parallel(true)
	tween.tween_property(ghost, "modulate:a", 0.0, afterimage_life)
	tween.tween_property(ghost, "scale", ghost.scale * 0.6, afterimage_life)
	tween.chain().tween_callback(ghost.queue_free)

## 今いるべき位置(自機からの相対位置)
func target_offset() -> Vector2:
	return _offset_for(_mode())

## その状態での位置(0: 通常 / 1: 低速移動中 / 2: ロックオン中)
func _offset_for(mode : int) -> Vector2:
	var list : Array[Vector2] = slots
	match mode:
		1: list = focus_slots
		2: list = lock_slots
	if list.is_empty():
		return Vector2.ZERO
	return list[slot % list.size()]

## 今撃つ向き(度。0 で真上)
func shot_angle() -> float:
	var list : Array[float] = slot_angles
	match _mode():
		1: list = focus_slot_angles
		2: list = lock_slot_angles
	if list.is_empty():
		return 0.0
	return list[slot % list.size()]

## 0: 通常 / 1: 低速移動中(ロックなし) / 2: ロックオン中
func _mode() -> int:
	if _player.is_locking_on() and not lock_slots.is_empty():
		return 2
	if _player.is_focusing:
		return 1
	return 0

## 1発撃つ。target があれば、追いかける弾にする。player_bullet は自機の弾(Bullet Scene が空のときに使う)
func fire(player_bullet : PackedScene, speed : float, damage : float, target : Node2D = null, turn_rate : float = 720.0) -> void:
	var scene := bullet_scene if bullet_scene else player_bullet
	if scene == null or not visible:
		return
	var bullet : Bullet = scene.instantiate()
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = global_position
	bullet.setup(Vector2.UP.rotated(deg_to_rad(shot_angle())), speed, damage * damage_scale, 0)
	if bullet_scene == null:
		bullet.modulate = shot_color
	if target:
		bullet.set_homing(target, turn_rate)

## 消える(自機が死んだとき)
func vanish() -> void:
	set_physics_process(false)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.2)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.chain().tween_callback(queue_free)

## Sprite2D に Texture がないときの、代わりの見た目
func _draw() -> void:
	if _sprite and _sprite.texture:
		return
	draw_circle(Vector2.ZERO, 6.0, Color(0.3, 1.0, 0.7, 0.3))
	draw_circle(Vector2.ZERO, 3.5, Color(0.7, 1.0, 0.9))
