extends Node2D
class_name PowerUpItem
## パワーアップアイテム。敵を倒すと出て(Enemy の Drop Item Scene)、ゆっくり落ちてくる。自機が触れると拾える。
## シーン(GameScene/Item/power_up_option.tscn など)で使う。種類は Kind で決める。
##
## 見た目: 子の Sprite2D の Texture を差し替える。Texture が空のあいだは、カプセルを描いて代わりにする。

enum Kind {
	OPTION,     ## 子機(オプション)が1つ増える(最大 Player の Max Options まで)
	LOCK_SPEED, ## ロックするまでの時間が短くなる(最大 Player の Lock Time Scales の段階まで)
	RATE,       ## (ANOTHER)連射速度UP。5 段階まで。自爆しても失わない
	POWER,      ## (ANOTHER)威力UP。5 段階まで。自爆しても失わない
	HEAL,       ## 回復: イグナイトのレベル(体力)が Heal Level より低ければ、そこまで戻す
	OPTION_PAIR, ## 子機(オプション)が2つ増える
}

## 回復(HEAL)で戻すイグナイトのレベル
@export var heal_level : int = 3

signal collected(kind : Kind)

@export var kind : Kind = Kind.OPTION

@export_group("拾う")
## 自機との距離がこれ以下になったら拾える(px)
@export var pickup_radius : float = 28.0
## 自機がこの距離まで近づくと、自機へ吸い寄せられる(px)。0 なら寄らない
@export var magnet_radius : float = 72.0
## 吸い寄せの加速(px/秒²)と最高速(px/秒)
@export var magnet_accel : float = 1400.0
@export var magnet_max_speed : float = 600.0
## 出てから拾えるようになるまでの時間(秒)
@export var pickup_delay : float = 0.3

@export_group("動き")
## 出た瞬間に、上へ跳ねる速さ(px/秒)
@export var pop_speed : float = 120.0
## 落ちる速さ(px/秒)
@export var fall_speed : float = 45.0
## 左右に揺れる大きさ(px)と速さ(回/秒)
@export var sway_amount : float = 14.0
@export var sway_frequency : float = 0.7
## 上下にふわふわ浮く大きさ(px)
@export var bob_amount : float = 3.0
## 画面の下から出たら消える。画面の左右の端からは出ない(px の余白)
@export var screen_margin : float = 12.0
## 出てからこの秒数たっても拾われず、画面に残っていたら、点滅して消える(画面に残り続けないように)。
## 物理の処理が止まっていても数えるように、ゲームの時間のタイマーで数える
@export var max_lifetime : float = 18.0

@export_group("見た目")
## Sprite2D の hframes が 2 以上なら、コマを順番に送る(コマ/秒。0 なら送らない)
@export var frame_rate : float = 0.0

var _age : float = 0.0
var _rise : float = 0.0
var _push_x : float = 0.0 # 横に散らばる勢い(だんだん弱まる)
var _base_x : float = NAN # 揺れの中心。最初の物理フレームで、今の位置から決める
var _phase : float = 0.0
var _done : bool = false
var _magnet_speed : float = 0.0 # 吸い寄せの今の速さ(0 なら吸い寄せていない)

@onready var _sprite : Sprite2D = get_node_or_null("Sprite2D") as Sprite2D

func _ready() -> void:
	add_to_group("power_up_item")
	z_as_relative = false
	z_index = 3 # 敵弾(5)より奥に描く(アイテムで弾が隠れないように)
	_rise = maxf(_rise, pop_speed)
	_phase = randf() * TAU
	scale = Vector2.ZERO
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.2)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if max_lifetime > 0.0:
		get_tree().create_timer(max_lifetime, false).timeout.connect(_expire)

## 寿命が来た: 拾われていなければ、点滅して消える
func _expire() -> void:
	if _done or not is_inside_tree():
		return
	if _age < max_lifetime * 0.5:
		# 物理の処理が止まっていて、落ちずに残っていた(原因を調べるための知らせ)
		push_warning("PowerUpItem: 動かないまま残っていたので消します(age=%.1f / pos=%s / done=%s)" % [_age, global_position, _done])
	_done = true
	var tween := create_tween()
	for i in 6:
		tween.tween_property(self, "modulate:a", 0.15, 0.08)
		tween.tween_property(self, "modulate:a", 1.0, 0.08)
	tween.tween_callback(queue_free)

## 散らばらせる(add_child の前でも後でもよい)。x は横の速さ、up は上へ跳ねる速さ(px/秒)
func launch(x : float, up : float) -> void:
	_push_x = x
	_rise = up

## 出す位置を決める(add_child のあとに呼ぶ)
func place(position_in_world : Vector2) -> void:
	global_position = position_in_world
	_base_x = position_in_world.x

func _physics_process(delta : float) -> void:
	if _done:
		return
	_age += delta
	if is_nan(_base_x):
		_base_x = global_position.x
	# 自機が近くにいたら、吸い寄せられて拾われる(一度寄りはじめたら、離れても追いかける)
	if _age >= pickup_delay and magnet_radius > 0.0:
		var near := get_tree().get_first_node_in_group("player") as Player
		if near and near.visible and near._is_alive:
			var distance := global_position.distance_to(near.global_position)
			if _magnet_speed > 0.0 or distance <= magnet_radius:
				_magnet_speed = minf(_magnet_speed + magnet_accel * delta, magnet_max_speed)
				global_position = global_position.move_toward(near.global_position, _magnet_speed * delta)
				_base_x = global_position.x
				_rise = 0.0
				if global_position.distance_to(near.global_position) <= pickup_radius:
					_collect(near)
				return
		else:
			_magnet_speed = 0.0
	# 上へ跳ねてから、ゆっくり落ちる。左右に揺れる
	_rise = move_toward(_rise, -fall_speed * HazardRank.item_fall_scale(), 260.0 * delta) # ANOTHER: ランクで速く落ちる
	_base_x += _push_x * delta
	_push_x = move_toward(_push_x, 0.0, 160.0 * delta)
	var area := CameraView.visible_rect(self)
	_base_x = clampf(_base_x, area.position.x + screen_margin, area.end.x - screen_margin)
	var x := _base_x + sin(_age * TAU * sway_frequency + _phase) * sway_amount
	x = clampf(x, area.position.x + screen_margin, area.end.x - screen_margin)
	var y := global_position.y - _rise * delta
	global_position = Vector2(x, y)
	if _sprite:
		_sprite.position.y = sin(_age * 5.0) * bob_amount
		if frame_rate > 0.0 and _sprite.hframes * _sprite.vframes > 1:
			_sprite.frame = int(_age * frame_rate) % (_sprite.hframes * _sprite.vframes)
	if global_position.y > area.end.y + 20.0:
		queue_free() # 拾われずに画面の下へ落ちた
		return
	if _age >= pickup_delay:
		var player := get_tree().get_first_node_in_group("player") as Player
		if player and player.visible and global_position.distance_to(player.global_position) <= pickup_radius:
			_collect(player)

## その場で拾ったことにする(ボスが援護を呼ぶ演出の前の、全回収)
func collect_now() -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if not _done and player:
		_collect(player)

func _collect(player : Player) -> void:
	_done = true
	# 消える演出を先に始める(このあとの処理が途中で止まっても、絵がその場に残らないように)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(2.0, 2.0), 0.15)
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.chain().tween_callback(queue_free)
	get_tree().create_timer(0.5, true, false, true).timeout.connect(func(): if is_instance_valid(self): queue_free())
	if kind == Kind.HEAL:
		player.set_meta(&"heal_level", heal_level)
	player.apply_power_up(kind)
	collected.emit(kind)

## Sprite2D に Texture がないときの、代わりの見た目(子機は緑、ロックは赤)
func _draw() -> void:
	if _sprite and _sprite.texture:
		return
	var color := Color(0.4, 1.0, 0.6) if kind == Kind.OPTION else Color(1.0, 0.45, 0.4)
	if kind == Kind.RATE:
		color = Color(0.4, 0.8, 1.0)
	elif kind == Kind.POWER:
		color = Color(1.0, 0.75, 0.25)
	elif kind == Kind.HEAL:
		# 回復: 赤い十字
		draw_circle(Vector2.ZERO, 13.0, Color(1.0, 0.3, 0.35, 0.3))
		draw_circle(Vector2.ZERO, 10.0, Color(1.0, 1.0, 1.0, 0.9))
		draw_rect(Rect2(-2.5, -7, 5, 14), Color(0.95, 0.15, 0.2))
		draw_rect(Rect2(-7, -2.5, 14, 5), Color(0.95, 0.15, 0.2))
		return
	elif kind == Kind.OPTION_PAIR:
		color = Color(0.4, 1.0, 0.6)
		for x in [-8.0, 8.0]:
			draw_circle(Vector2(x, 0), 9.0, Color(color, 0.25))
			draw_rect(Rect2(x - 5, -5, 10, 10), color)
			draw_rect(Rect2(x - 5, -5, 10, 10), Color.WHITE, false, 1.0)
		return
	draw_circle(Vector2.ZERO, 10.0, Color(color, 0.25))
	draw_rect(Rect2(-6, -5, 12, 10), color)
	draw_rect(Rect2(-6, -5, 12, 10), Color.WHITE, false, 1.0)
