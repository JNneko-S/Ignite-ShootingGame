extends Node
class_name TankMover
## 戦車らしく動かす部品。ボス(Enemy)の子に置く。登場して止まったあと、決まった順の動きをくり返す:
##   前に出る → 止まる → 下がる → 左へ回り込む → 戻る → 前に出る → 止まる → 下がる → 右へ回り込む → 戻る
##
## 戦車らしさ:
##   ・横へ動くときは、その場で横滑りせず、車体を向けてから斜め前へ走り、また正面を向いて下がる
##   ・向きを変えるときは、車体ごと(ボスのノードごと)回す。砲台(Turret)は回っても自機を狙う
##   ・走っている間だけ、本体の AnimationPlayer の Move を流し、止まると Idle にする
##
## 絵は、車体の前が下(+Y)を向いている前提。位置は、出現して止まった場所(ホーム)からのずれで決める。

## 出現してから動き始めるまでの時間(秒)。登場の移動が終わってからにする
@export var start_delay : float = 3.8
## 前に出る距離(px)
@export var forward_distance : float = 45.0
## 横へ回り込む距離(px)
@export var side_distance : float = 80.0
## 走る速さ(px/秒)と、下がる速さ(px/秒)
@export var drive_speed : float = 55.0
@export var reverse_speed : float = 40.0
## 車体の向きを変える速さ(度/秒)と、斜めに走るときの最大の傾き(度)
@export var turn_speed : float = 45.0
@export var max_turn : float = 28.0
## 1つの動きのあとに止まる時間(秒)
@export var pause_time : float = 1.4
@export_group("アニメーション")
## 本体の AnimationPlayer の、走るとき・止まっているときのアニメーション
@export var move_animation : StringName = &"Move"
@export var idle_animation : StringName = &"Idle"

var _enemy : Enemy
var _anim : AnimationPlayer
var _home : Vector2
## 移動の上の位置(横揺れのずれを除いた、ボスの位置)
var _pos : Vector2

func _ready() -> void:
	_enemy = get_parent() as Enemy
	if _enemy == null:
		push_warning("TankMover: 親が Enemy ではありません")
		return
	_anim = _enemy.get_node_or_null("AnimationPlayer") as AnimationPlayer
	_run.call_deferred()

func _run() -> void:
	await _wait(start_delay)
	if not _alive():
		return
	_pos = _enemy.global_position - _enemy._applied_sway
	_home = _pos
	var side := -1.0 # 最初は左へ
	while _alive():
		# 前に出て止まり、下がる
		await _drive_to(_home + Vector2(0.0, forward_distance), false)
		await _pause()
		await _drive_to(_home, true)
		await _pause()
		# 横へ回り込む: 斜め前へ車体を向けて走り、正面を向いて下がる
		var aside := _home + Vector2(side * side_distance, 0.0)
		await _drive_to(aside + Vector2(0.0, forward_distance * 0.7), false)
		await _drive_to(aside, true)
		await _pause()
		# 戻る: 同じように、斜め前へ走ってから下がる
		await _drive_to(_home + Vector2(0.0, forward_distance * 0.7), false)
		await _drive_to(_home, true)
		await _pause()
		side = -side

## target まで走る。reverse なら、正面を向いてから後ろへ下がる。前進なら、進む向きへ車体を向けてから走る
func _drive_to(target : Vector2, reverse : bool) -> void:
	if not _alive():
		return
	var move := target - _pos
	if move.length() < 1.0:
		return
	var angle := 0.0
	if not reverse:
		# 前(+Y)が move の向きになる角度。傾きは max_turn までにする
		angle = clampf(atan2(-move.x, move.y), deg_to_rad(-max_turn), deg_to_rad(max_turn))
	await _turn_to(angle)
	if not _alive():
		return
	_play(move_animation)
	var speed := reverse_speed if reverse else drive_speed
	var tween := _enemy.create_tween()
	tween.tween_method(_set_pos, _pos, target, move.length() / maxf(speed, 1.0))\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	if not reverse and absf(angle) > 0.01:
		await _turn_to(0.0) # 走り終わったら、正面を向き直す
	_play(idle_animation)

## 車体の向きを angle(ラジアン)へ変える。その場で回るあいだも履帯は動く
func _turn_to(angle : float) -> void:
	var diff := absf(angle - _enemy.rotation)
	if diff < 0.01 or not _alive():
		return
	_play(move_animation)
	var tween := _enemy.create_tween()
	tween.tween_property(_enemy, "rotation", angle, rad_to_deg(diff) / maxf(turn_speed, 1.0))\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished

func _pause() -> void:
	_play(idle_animation)
	await _wait(pause_time)

func _set_pos(value : Vector2) -> void:
	if not _alive():
		return
	_pos = value
	_enemy.global_position = value + _enemy._applied_sway # 横揺れのずれは、そのまま保つ

func _play(animation : StringName) -> void:
	if _anim and _anim.has_animation(animation) and _anim.current_animation != animation:
		_anim.play(animation)

func _wait(seconds : float) -> void:
	if seconds <= 0.0 or not _alive():
		return
	await _enemy.get_tree().create_timer(seconds).timeout

func _alive() -> bool:
	return is_instance_valid(_enemy) and _enemy.is_inside_tree() and not _enemy._is_dead
