extends Node
class_name CrashFall
## (新しく足したクラスは、エディタがクラス名を覚える前でも動くように、ファイルを直接読み込んで使う)
const _SmokePuff := preload("res://GameScene/Effect/smoke_puff.gd")
const _BossWreck := preload("res://Component/Death/boss_wreck.gd")
## 空中のボス(ブラックスワンなど)が倒されたあと、火を噴きながら地上へ墜ちていく部品。ボス(Enemy)の子に置く。
## 倒されると: 動き(移動・ステート)を止め、傾いて回りながら、小さく(遠く)暗くなっていき、煙の尾を引いて墜ちる。
## 墜ちたところ(地面)で爆発が起こり、機体は消える。大爆発(DeathExplosion)の連鎖は、墜ちながら起こる。

## 墜ちる時間(秒)
@export var fall_time : float = 2.8
## 墜ちるあいだに、画面の上で動く量(px)。横はランダムに左右どちらか
@export var fall_offset : Vector2 = Vector2(60.0, 170.0)
## 墜ちたときの大きさの倍率(小さいほど、遠くの地面まで墜ちて見える)
@export var end_scale : float = 0.3
## 回る量(度。墜ちきるまでに)
@export var spin_degrees : float = 140.0
## 焦げた色
@export var burnt_color : Color = Color(0.32, 0.27, 0.27)
## 煙の尾を出す間隔(秒)と大きさ
@export var smoke_interval : float = 0.05
@export var smoke_size : float = 11.0
## 地面に激突したときの爆発の大きさ
@export var impact_scale : float = 3.0

var _enemy : Enemy
var _from : Vector2
var _offset : Vector2
var _from_scale : Vector2
var _from_rotation : float
var _spin_sign : float = 1.0
var _t : float = 0.0
var _falling : bool = false
var _smoke_in : float = 0.0

func _ready() -> void:
	_enemy = get_parent() as Enemy
	if _enemy == null:
		return
	_enemy.keep_after_death = true
	var death := DeathExplosion.of(_enemy)
	if death:
		death.fade_out_body = false # 墜ちきるまで、姿を消さない
		death.drift = Vector2.ZERO # 流される動きは使わない(墜ちる動きは、この部品が付ける)
	_enemy.died.connect(_on_died)
	set_process(false)

func _on_died(_e : Enemy) -> void:
	_BossWreck._stop_everything(_enemy, self)
	for node in _BossWreck._visuals(_enemy):
		var tween : Tween = node.create_tween()
		tween.tween_property(node, "modulate", burnt_color, fall_time * 0.8)
	_from = _enemy.global_position
	_from_scale = _enemy.scale
	_from_rotation = _enemy.rotation
	_spin_sign = -1.0 if randf() < 0.5 else 1.0
	_offset = Vector2(fall_offset.x * _spin_sign, fall_offset.y)
	_enemy.z_as_relative = false
	_enemy.z_index = 0 # 墜ちていく機体は、自機や弾より奥
	_falling = true
	process_priority = 1000 # ほかの部品が動かしたあとで、位置を決める
	set_process(true)
	# ほかの部品の動き(Tween など)より後で位置を決める: 描く直前に上書きする
	RenderingServer.frame_pre_draw.connect(_place)

func _process(delta : float) -> void:
	if not _falling or not is_instance_valid(_enemy):
		return
	_t += delta
	_smoke_in -= delta
	if _smoke_in <= 0.0:
		_smoke_in = smoke_interval
		var k := clampf(_t / fall_time, 0.0, 1.0)
		var size := smoke_size * lerpf(1.0, end_scale + 0.2, k)
		_SmokePuff.spawn(get_tree(), _enemy.global_position + Vector2(randf_range(-10, 10), randf_range(-10, 10)) * (1.0 - k * 0.6),
				size, Vector2(randf_range(-10, 10), -randf_range(30, 60)), 1.1, Color(0.12, 0.1, 0.1, 0.6), 1)
		if randf() < 0.18:
			Explosion.spawn(get_tree(), Explosion.ZAKO, _enemy.global_position + Vector2(randf_range(-20, 20), randf_range(-20, 20)) * (1.0 - k * 0.6),
					lerpf(1.2, 0.5, k))
	_place()
	if _t >= fall_time:
		_impact()

## 墜ちる途中の位置・大きさ・傾き(だんだん速く墜ちる)
func _place() -> void:
	if not _falling or not is_instance_valid(_enemy):
		return
	var k := clampf(_t / fall_time, 0.0, 1.0)
	var e := k * k
	_enemy.global_position = _from + Vector2(_offset.x * k, _offset.y * e)
	_enemy.scale = _from_scale * lerpf(1.0, end_scale, e)
	_enemy.rotation = _from_rotation + deg_to_rad(spin_degrees) * _spin_sign * e

## 地面に激突: 大きな爆発と衝撃波、画面が揺れて、機体は消える
func _impact() -> void:
	_falling = false
	if RenderingServer.frame_pre_draw.is_connected(_place):
		RenderingServer.frame_pre_draw.disconnect(_place)
	var tree := get_tree()
	var at := _enemy.global_position
	Explosion.spawn(tree, Explosion.EXPLOSIVE, at, impact_scale)
	Explosion.spawn(tree, Explosion.WAVE, at, impact_scale * 0.7)
	Explosion.burst(tree, at, 8, 34.0, 0.9, 0.03)
	for i in 6:
		_SmokePuff.spawn(tree, at + Vector2(randf_range(-24, 24), randf_range(-12, 12)), 18.0, Vector2(randf_range(-20, 20), -randf_range(20, 40)), 2.2)
	var camera := StageCamera.of(_enemy)
	if camera:
		camera.shake(7.0, 0.35)
	_enemy.visible = false
	await tree.create_timer(0.8, false).timeout
	if is_instance_valid(_enemy):
		_enemy.queue_free()

func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_place):
		RenderingServer.frame_pre_draw.disconnect(_place)
