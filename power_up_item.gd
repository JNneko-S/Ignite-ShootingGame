extends Node2D
class_name PowerUpItem
## パワーアップアイテム。敵を倒すと出て(Enemy の Drop Item Scene)、ゆっくり落ちてくる。自機が触れると拾える。
## シーン(GameScene/Item/power_up_option.tscn など)で使う。種類は Kind で決める。
##
## 見た目: 子の Sprite2D の Texture を差し替える。Texture が空のあいだは、カプセルを描いて代わりにする。

enum Kind {
	OPTION,     ## 子機(オプション)が1つ増える(最大 Player の Max Options まで)
	LOCK_SPEED, ## ロックするまでの時間が短くなる(最大 Player の Lock Time Scales の段階まで)
}

signal collected(kind : Kind)

@export var kind : Kind = Kind.OPTION

@export_group("拾う")
## 自機との距離がこれ以下になったら拾える(px)
@export var pickup_radius : float = 18.0
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

@export_group("見た目")
## Sprite2D の hframes が 2 以上なら、コマを順番に送る(コマ/秒。0 なら送らない)
@export var frame_rate : float = 0.0

var _age : float = 0.0
var _rise : float = 0.0
var _base_x : float = NAN # 揺れの中心。最初の物理フレームで、今の位置から決める
var _phase : float = 0.0
var _done : bool = false

@onready var _sprite : Sprite2D = get_node_or_null("Sprite2D") as Sprite2D

func _ready() -> void:
	z_index = 6
	_rise = pop_speed
	_phase = randf() * TAU
	scale = Vector2.ZERO
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.2)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

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
	# 上へ跳ねてから、ゆっくり落ちる。左右に揺れる
	_rise = move_toward(_rise, -fall_speed, 260.0 * delta)
	var area := CameraView.visible_rect(self)
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

func _collect(player : Player) -> void:
	_done = true
	player.apply_power_up(kind)
	collected.emit(kind)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(2.0, 2.0), 0.15)
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.chain().tween_callback(queue_free)

## Sprite2D に Texture がないときの、代わりの見た目(子機は緑、ロックは赤)
func _draw() -> void:
	if _sprite and _sprite.texture:
		return
	var color := Color(0.4, 1.0, 0.6) if kind == Kind.OPTION else Color(1.0, 0.45, 0.4)
	draw_circle(Vector2.ZERO, 10.0, Color(color, 0.25))
	draw_rect(Rect2(-6, -5, 12, 10), color)
	draw_rect(Rect2(-6, -5, 12, 10), Color.WHITE, false, 1.0)
