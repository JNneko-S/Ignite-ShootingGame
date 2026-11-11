extends Node
class_name FighterMover
## 戦闘機らしく動かす部品。ボス(Enemy)の子に置く。登場して止まったあと、上下左右に動き回る。
##
## 動き方(毎回ランダムに選ぶ。動いたあとは少し止まる):
##   ・横切る … 反対側へ大きく横に動く
##   ・すばやく … 近くへ短く、すばやく動く(上下左右どこでも)
##   ・詰める … 前(下)へ出てから、元の高さへ戻る
## 横に動くときは、進む向きへ機体を少し傾ける。
## 動く範囲は、登場して止まった場所(ホーム)からの距離で決める。
## Dive(AfterburnerDive)が技をしている間と、Hold Position のステート(CrossFire など)の間は止まり、終わったらまた動く。

## 出現してから動き始めるまでの時間(秒)。登場の移動が終わってからにする
@export var start_delay : float = 3.2
## AfterburnerDive。技の間は動かない
@export var dive : AfterburnerDive

@export_group("範囲")
## ホームから左右へ動ける距離(px)
@export var range_x : float = 80.0
## ホームから上へ / 下へ動ける距離(px)
@export var range_up : float = 25.0
@export var range_down : float = 55.0

@export_group("速さ")
## ふつうに動く速さ(px/秒)
@export var speed : float = 90.0
## すばやく動くときの速さ(px/秒)
@export var dash_speed : float = 200.0
## 動いたあとに止まる時間(秒)。この間でランダム
@export var pause_min : float = 0.3
@export var pause_max : float = 1.0

@export_group("傾き")
## 横に動くときの最大の傾き(度)
@export var bank_angle : float = 7.0
## この横の速さ(px/秒)で、最大まで傾く
@export var bank_full_speed : float = 160.0
## 傾きが追いつく速さ(大きいほど、すぐ傾く)
@export var bank_follow : float = 6.0

enum Move { SWEEP, DART, PRESS }

var _enemy : Enemy
var _home : Vector2
## 移動の上の位置(横揺れのずれを除いた、ボスの位置)
var _pos : Vector2
var _tween : Tween
var _started : bool = false
var _last_x : float = 0.0

func _ready() -> void:
	_enemy = get_parent() as Enemy
	if _enemy == null:
		push_warning("FighterMover: 親が Enemy ではありません")
		return
	_run.call_deferred()

func _process(delta : float) -> void:
	if not _started or not _alive():
		return
	# 横の速さに合わせて、機体を傾ける。技の間はまっすぐに戻す
	var vx := (_enemy.global_position.x - _last_x) / maxf(delta, 0.0001)
	_last_x = _enemy.global_position.x
	var target := 0.0
	if not _diving():
		target = deg_to_rad(bank_angle) * clampf(vx / maxf(bank_full_speed, 1.0), -1.0, 1.0)
	_enemy.rotation = lerp_angle(_enemy.rotation, target, minf(bank_follow * delta, 1.0))

func _run() -> void:
	await _wait(start_delay)
	if not _alive():
		return
	_home = _enemy.global_position - _enemy._applied_sway
	_last_x = _enemy.global_position.x
	_started = true
	while _alive():
		if _diving():
			await _wait(0.2)
			continue
		_pos = _enemy.global_position - _enemy._applied_sway
		match [Move.SWEEP, Move.SWEEP, Move.DART, Move.DART, Move.PRESS].pick_random():
			Move.SWEEP:
				await _move_to(_sweep_target(), speed)
			Move.DART:
				await _move_to(_dart_target(), dash_speed)
			Move.PRESS:
				await _move_to(Vector2(_pos.x, _home.y + range_down), speed)
				await _wait(randf_range(pause_min, pause_max) * 0.5)
				if _alive() and not _diving():
					await _move_to(Vector2(_pos.x, _home.y + randf_range(-range_up, 0.0)), speed * 0.8)
		await _wait(randf_range(pause_min, pause_max))

## 反対側へ大きく横に動く(高さも少し変える)
func _sweep_target() -> Vector2:
	var side := -1.0 if _pos.x > _home.x else 1.0
	return Vector2(_home.x + side * randf_range(range_x * 0.5, range_x),
		_home.y + randf_range(-range_up, range_down * 0.6))

## 近くへ短く動く(上下左右どこでも)
func _dart_target() -> Vector2:
	var step := Vector2.from_angle(randf() * TAU) * randf_range(30.0, 55.0)
	return _clamp(_pos + step)

func _clamp(point : Vector2) -> Vector2:
	return Vector2(clampf(point.x, _home.x - range_x, _home.x + range_x),
		clampf(point.y, _home.y - range_up, _home.y + range_down))

## target へ動く(はじめと終わりがなめらか)。途中で技が始まったら、そこで止まる
func _move_to(target : Vector2, move_speed : float) -> void:
	if not _alive() or _diving():
		return
	target = _clamp(target)
	_pos = _enemy.global_position - _enemy._applied_sway
	var distance := _pos.distance_to(target)
	if distance < 1.0:
		return
	_tween = _enemy.create_tween()
	_tween.tween_method(_set_pos, _pos, target, distance / maxf(move_speed, 1.0))\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _tween.finished

func _set_pos(value : Vector2) -> void:
	if not _alive():
		return
	if _diving():
		return # 技が始まった: 位置は技に任せる(この移動は、そのまま空回りして終わる)
	_pos = value
	_enemy.global_position = value + _enemy._applied_sway

## 技の最中か、動かないステートの間(BossState の Hold Position)
func _diving() -> bool:
	if _enemy and _enemy.get_meta(&"hold_position", false):
		return true
	return is_instance_valid(dive) and dive.is_diving()

func _wait(seconds : float) -> void:
	if seconds <= 0.0 or not _alive():
		return
	await _enemy.get_tree().create_timer(seconds, false).timeout

func _alive() -> bool:
	return is_instance_valid(_enemy) and _enemy.is_inside_tree() and not _enemy._is_dead
