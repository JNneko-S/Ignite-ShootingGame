extends Node2D
class_name IgniteItem
## 被弾時に散らばる、イグナイトゲージの補給アイテム。シーン(GameScene/Item/ignite_item.tscn)で使う。
## 散らばったあと、画面(Camera2D に映っている範囲)の中の、ランダムな場所へ次々と漂っていく。自機が触れると拾えて、ゲージが増える。
## 吸い寄せはしないので、自分で拾いに行く。
##
## 見た目: 子の Sprite2D の Texture を差し替える。Texture が空のあいだは、ひし形を描いて代わりにする。

signal collected(amount : float)

@export_group("拾う")
## 自機との距離がこれ以下になったら拾える(px)
@export var pickup_radius : float = 16.0
## 出てから拾えるようになるまでの時間(秒)。被弾した瞬間に、その場で拾ってしまわないように
@export var pickup_delay : float = 0.5
## 0 より大きければ、自機がこの距離まで近づくと、少しだけ寄ってくる(px)。0 なら全く寄らない
@export var assist_radius : float = 0.0

@export_group("動き")
## 散らばったあと、止まるまでの減速(px/秒²)
@export var burst_drag : float = 320.0
## 漂う速さ(px/秒)の範囲。目的地ごとに決める
@export var drift_speed_min : float = 50.0
@export var drift_speed_max : float = 90.0
## 向きを変える強さ(px/秒²)。小さいほど大きな弧を描いてゆったり曲がる
@export var drift_steer : float = 70.0
## 目的地にこの距離まで近づくか、この秒数たったら、次の目的地を選ぶ
@export var retarget_distance : float = 40.0
@export var retarget_time : float = 4.0
## 進む向きと直角に、ゆらゆら揺れる大きさ(px/秒)と速さ(回/秒)
@export var sway_amount : float = 18.0
@export var sway_frequency : float = 0.6
## 画面の端から、この距離より内側で動く(px)
@export var screen_margin : float = 20.0
## 回転の速さ(ラジアン/秒)。0 なら回らない
@export var spin_speed : float = 2.0

@export_group("消える")
## 出てから消えるまでの時間(秒)
@export var lifetime : float = 10.0
## 消える前に点滅し始める時間(秒)
@export var blink_time : float = 2.5

var amount : float = 6.0
var _player : Node2D
var _velocity : Vector2 = Vector2.ZERO # 散らばった勢い
var _drift : Vector2 = Vector2.ZERO # 漂う動き
var _target : Vector2 = Vector2.ZERO
var _drift_speed : float = 60.0
var _target_age : float = 0.0
var _sway_phase : float = 0.0
var _age : float = 0.0
var _done : bool = false

@onready var _sprite : Sprite2D = get_node_or_null("Sprite2D") as Sprite2D

func setup(player : Node2D, value : float, burst_velocity : Vector2) -> void:
	_player = player
	amount = value
	_velocity = burst_velocity
	z_index = 5

func _ready() -> void:
	scale = Vector2.ZERO
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.2)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_sway_phase = randf() * TAU
	_pick_target()

func _physics_process(delta : float) -> void:
	if _done:
		return
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	if _age > lifetime - blink_time:
		modulate.a = 0.35 + 0.65 * absf(sin(_age * 10.0)) # 消える前の点滅

	_move(delta)
	rotation += spin_speed * delta

	if _age >= pickup_delay and _can_pick():
		var distance := global_position.distance_to(_player.global_position)
		if distance <= pickup_radius:
			_collect()
		elif assist_radius > 0.0 and distance <= assist_radius:
			global_position = global_position.move_toward(_player.global_position, 60.0 * delta)

## 散らばった勢いが弱まるにつれて、画面のあちこちへ漂う動きに切り替える
func _move(delta : float) -> void:
	_velocity = _velocity.move_toward(Vector2.ZERO, burst_drag * delta)
	_target_age += delta
	if global_position.distance_to(_target) <= retarget_distance or _target_age >= retarget_time:
		_pick_target()
	# 目的地の方へ、少しずつ向きを変える(急には曲がらないので、弧を描いて漂う)
	var wanted := global_position.direction_to(_target) * _drift_speed
	_drift = _drift.move_toward(wanted, drift_steer * delta)
	var side := _drift.orthogonal().normalized() * sway_amount * sin(_age * TAU * sway_frequency + _sway_phase)
	var blend := clampf(1.0 - _velocity.length() / 120.0, 0.0, 1.0)
	global_position += (_velocity + (_drift + side) * blend) * delta
	_stay_on_screen()

## 次の目的地を、画面の中からランダムに選ぶ(今いる場所から離れた所を選びやすくする)
func _pick_target() -> void:
	var area := CameraView.visible_rect(self).grow(-screen_margin) if is_inside_tree() else Rect2(global_position, Vector2.ONE)
	var best := global_position
	for i in 3:
		var candidate := area.position + Vector2(randf() * area.size.x, randf() * area.size.y)
		if candidate.distance_to(global_position) > best.distance_to(global_position):
			best = candidate
	_target = best
	_drift_speed = randf_range(drift_speed_min, drift_speed_max)
	_target_age = 0.0

## 画面の端から出ないようにする(散らばった勢いは跳ね返す)
func _stay_on_screen() -> void:
	var area := CameraView.visible_rect(self).grow(-screen_margin)
	if global_position.x < area.position.x or global_position.x > area.end.x:
		_velocity.x = -_velocity.x
		_drift.x = -_drift.x
	if global_position.y < area.position.y or global_position.y > area.end.y:
		_velocity.y = -_velocity.y
		_drift.y = -_drift.y
	global_position = global_position.clamp(area.position, area.end)

## 自機が生きていて、見えているときだけ拾える(復活待ちのあいだは拾えない)
func _can_pick() -> bool:
	return is_instance_valid(_player) and _player.visible and _player.is_inside_tree()

func _collect() -> void:
	_done = true
	collected.emit(amount)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.8, 1.8), 0.12)
	tween.tween_property(self, "modulate:a", 0.0, 0.12)
	tween.chain().tween_callback(queue_free)

## Sprite2D に Texture がないときの、代わりの見た目
func _draw() -> void:
	if _sprite and _sprite.texture:
		return
	var pts := PackedVector2Array([Vector2(0, -8), Vector2(6, 0), Vector2(0, 8), Vector2(-6, 0)])
	draw_circle(Vector2.ZERO, 11.0, Color(1.0, 0.5, 0.1, 0.25))
	draw_colored_polygon(pts, Color(1.0, 0.75, 0.25))
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color(1.0, 0.95, 0.7), 1.5)
