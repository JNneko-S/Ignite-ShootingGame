extends Node2D
class_name ScoreItem
## スコアアイテム。シーン(GameScene/Item/score_item.tscn)で使う。
## 敵を倒したとき・弾を焼いたとき・背景のオブジェクトを壊したときに出る。
##
## 動き: その場で少し弾けたあと、下へ落ちていく。自機が触れるか、近くを通ると吸い寄せられて拾える。
##       イグナイトの発動中は、焼いた弾の数だけ吸い寄せの範囲が広がる。
##       イグナイトを発動した瞬間に出ているアイテムは、距離に関係なく全部吸い寄せられる(1回だけ)。
##       画面の下へ落としてしまうと missed が出る(ScoreSystem はアイテムの連続取得を途切れさせる)。
##       焼いた弾・反射弾が敵に当たって出たアイテムは、数秒その場にとどまってから、自動で自機へ吸い寄せられる(hold)。
## 点数: value(出たときに決まる)× 拾ったときの連続取得の倍率。ScoreSystem が計算する。
##
## 種類(Kind): 小(雑魚) / 中(アイテムを落とす敵) / 大(中ボス、ボス) / 勲章(ボス)。種類ごとにシーンがある:
##   score_item.tscn / score_item_medium.tscn / score_item_large.tscn / score_medal.tscn
## 見た目: シーンの Sprite2D(横に hframes コマ並んだシート)のコマを順に流す。
## 大きさは Sprite2D の Scale で変える(子機より少し大きいくらい)。

signal collected(item : ScoreItem)
signal missed(item : ScoreItem)

enum Kind { SMALL, MEDIUM, LARGE, MEDAL }

## このアイテムの種類(ScoreSystem が、種類ごとのシーンを使い分ける)
@export var kind : Kind = Kind.SMALL
## 拾ったときの効果音(シーンに置いた AudioStreamPlayer)。連続で拾うと、だんだん高くなる
@export var pickup_sound : AudioStreamPlayer

@export var hframes : int = 4
## 1コマの時間(秒)
@export var frame_time : float = 0.08

@export_group("落ちる")
## 出た瞬間に弾ける速さ(px/秒)。上向きに弾けてから落ちる
@export var pop_speed : float = 110.0
## 重力(px/秒²)と、落ちる速さの上限(px/秒)
@export var gravity : float = 260.0
@export var fall_speed : float = 110.0
## 横の勢いが弱まる速さ(px/秒²)
@export var side_drag : float = 120.0

@export_group("拾う")
## 自機との距離がこれ以下になったら拾う(px)
@export var pickup_radius : float = 16.0
## 自機がこの距離まで近づくと、吸い寄せられ始める(px)。ScoreSystem から出たときは、ScoreSystem の値を使う
@export var magnet_radius : float = 44.0
## 出てから吸い寄せられるようになるまでの時間(秒)
@export var attract_delay : float = 0.2
## 吸い寄せの加速(px/秒²)と最高速度(px/秒)
@export var attract_accel : float = 1600.0
@export var attract_max_speed : float = 900.0

@export_group("とどまる")
## その場にとどまるとき(hold)、弾けた勢いが止まる速さ(px/秒²)
@export var hold_drag : float = 600.0
## とどまる時間の終わり、この秒数のあいだ点滅する
@export var hold_blink_time : float = 0.5

## 出たときに決まる点数(連続取得の倍率は、拾ったときに ScoreSystem が掛ける)
var value : int = 10
## 弾を焼いて出たアイテムか(イグナイトの発動中は、自動で吸い寄せられる)
var from_burn : bool = false
## 出したときに ScoreSystem が入れる(吸い寄せの範囲を聞く)
var score_system : ScoreSystem
var _player : Player
var _velocity : Vector2
var _age : float = 0.0
var _speed : float = 0.0
var _attracting : bool = false
var _done : bool = false
## true なら、距離に関係なく自機へ吸い寄せられる(イグナイト発動時の全回収)
var _forced : bool = false
## その場にとどまる残り時間(秒)。0 なら、とどまっていない
var _hold_left : float = 0.0

@onready var _sprite : Sprite2D = $Sprite2D

func setup(player : Player, points : int, spread : float = 1.0) -> void:
	_player = player
	value = points
	var angle := -PI / 2.0 + randf_range(-1.0, 1.0) * 1.1 * spread
	_velocity = Vector2.from_angle(angle) * pop_speed * randf_range(0.6, 1.0) * maxf(spread, 0.4)

func _ready() -> void:
	z_index = 5
	add_to_group("score_item")
	_sprite.hframes = maxi(hframes, 1)
	_sprite.frame = randi() % _sprite.hframes

func _physics_process(delta : float) -> void:
	if _done:
		return
	_age += delta
	_sprite.frame = int(_age / frame_time) % _sprite.hframes

	if _hold_left > 0.0:
		_hold(delta)
		return
	if not _attracting and (_forced or (_age >= attract_delay and _should_attract())) and _can_pick():
		_attracting = true
		_speed = maxf(_velocity.length(), 120.0)
	if _attracting and _can_pick():
		_move_to_player(delta)
		return
	_attracting = false
	_fall(delta)

func _fall(delta : float) -> void:
	_velocity.x = move_toward(_velocity.x, 0.0, side_drag * delta)
	_velocity.y = minf(_velocity.y + gravity * delta, fall_speed)
	global_position += _velocity * delta
	# 画面の下へ落としたら、取り逃し
	var area := CameraView.visible_rect(self)
	if global_position.y > area.end.y + 12.0:
		_done = true
		missed.emit(self)
		queue_free()
	else:
		global_position.x = clampf(global_position.x, area.position.x + 6.0, area.end.x - 6.0)

func _move_to_player(delta : float) -> void:
	var to_player := _player.global_position - global_position
	if to_player.length() <= pickup_radius:
		_collect()
		return
	_speed = minf(_speed + attract_accel * delta, attract_max_speed)
	_velocity = _velocity.lerp(to_player.normalized() * _speed, minf(10.0 * delta, 1.0))
	global_position += _velocity * delta

## 吸い寄せられる条件: 自機の近く。イグナイトの発動中は、焼いた弾の数だけ範囲が広がる(ScoreSystem が決める)
func _should_attract() -> bool:
	if not _can_pick():
		return false
	var radius := score_system.current_magnet_radius() if is_instance_valid(score_system) else magnet_radius
	return global_position.distance_to(_player.global_position) <= radius

## 自機が生きていて、見えているときだけ拾える(復活待ちのあいだは落ちていく)
func _can_pick() -> bool:
	return is_instance_valid(_player) and _player.visible and _player._is_alive

func _collect() -> void:
	_done = true
	collected.emit(self)
	queue_free()

## 距離に関係なく、自機へ吸い寄せる(イグナイト発動時の全回収)。自機がいないあいだは、出てくるまで待つ
func collect_now() -> void:
	_forced = true
	_end_hold()

## seconds 秒のあいだ、その場にとどまる(落ちない・吸い寄せられない。自機が触れれば拾える)。
## 時間が来たら、距離に関係なく自機へ吸い寄せられる(焼いた弾・反射弾のアイテム)
func hold(seconds : float) -> void:
	if seconds <= 0.0:
		return
	_hold_left = seconds

## とどまっている間: 弾けた勢いがすぐ止まり、ふわふわ上下する。終わり際は点滅して、吸い寄せられる合図にする
func _hold(delta : float) -> void:
	_hold_left -= delta
	_velocity = _velocity.move_toward(Vector2.ZERO, hold_drag * delta)
	global_position += _velocity * delta
	_sprite.position.y = sin(_age * 5.0) * 1.5
	if _hold_left < hold_blink_time:
		_sprite.modulate.a = 0.55 + 0.45 * absf(cos(_age * 18.0))
	if _can_pick() and global_position.distance_to(_player.global_position) <= pickup_radius:
		_collect()
		return
	if _hold_left <= 0.0:
		_forced = true
		_end_hold()

func _end_hold() -> void:
	_hold_left = 0.0
	if _sprite:
		_sprite.position = Vector2.ZERO
		_sprite.modulate.a = 1.0
