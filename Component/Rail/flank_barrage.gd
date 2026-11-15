extends Node
class_name FlankBarrage
## ボス戦の援護の列車(中ボス列車)が、画面の外(となりの画面)にいるあいだ、画面の横から弾幕を撃ち込む部品。
## 援護の列車(Enemy)の子に置く。
##   ・撃つ前に、撃ってくる画面の端に矢印を出す(一直線の弾幕は、通り道にも細い線を出す)
##   ・援護の列車が画面に入っているあいだは撃たない(列車の砲台が自分で撃つ)
##   ・援護の列車を倒せば、その側からは来なくなる(この部品も一緒に消える)
## 弾幕は「下向きに撃つ」形で作る。横から撃つときに、画面の内側へ向くように回す(Aim At Player の弾幕は、自機を狙う)。

## 順に撃つ弾幕
@export var patterns : Array[ShotPattern] = []
## 1つの弾幕を撃ち終わってから、次の予告を出すまでの時間(秒)
@export var interval : float = 1.6
## 予告(矢印)を出してから撃つまでの時間(秒)
@export var warning_time : float = 0.8
## 登場してから、最初の予告を出すまでの時間(秒)
@export var first_delay : float = 2.0
## 弾を出す位置: 画面の端から、この距離(px)だけ外
@export var edge_margin : float = 6.0
## ボスのグループ(ボスがいなければ撃たない)
@export var boss_group : StringName = &"stage_boss"
## 予告の色
@export var warning_color : Color = Color(1.0, 0.3, 0.2)
## 割れる弾(花火)を撃つ高さ(画面の上から 0〜1)。自機が Split Player Above より上にいるときは、Split Low Height に撃つ
@export var split_high_height : float = 0.08
@export var split_low_height : float = 0.75
@export var split_player_above : float = 0.35

var _enemy : Enemy
var _mover : TrainBossMover

func _ready() -> void:
	_enemy = get_parent() as Enemy
	if _enemy == null:
		push_warning("FlankBarrage: 親が Enemy ではありません")
		return
	for child in _enemy.get_children():
		if child is TrainBossMover:
			_mover = child
	_loop.call_deferred()

func _loop() -> void:
	await _wait(first_delay)
	var index := 0
	while _alive():
		if patterns.is_empty():
			return
		if not _ready_to_fire():
			await _wait(0.25)
			continue
		var pattern := patterns[index % patterns.size()]
		index += 1
		await _attack(pattern)
		await _wait(interval)

## 撃てる状態か: 援護が登場し終わっていて、走り去っていなくて、画面の横の外にいて、ボスがいる
func _ready_to_fire() -> bool:
	if not _alive() or EnemyShooter.is_holding_fire():
		return false
	if _mover and (not _mover.entered or _mover._leaving or _mover._fast_moving):
		return false
	if get_tree().get_first_node_in_group(boss_group) == null:
		return false
	var view := CameraView.visible_rect(_enemy)
	var x := _enemy.global_position.x
	return x < view.position.x - 40.0 or x > view.end.x + 40.0

## 予告を出してから、1つの弾幕を撃つ
func _attack(source : ShotPattern) -> void:
	if not DifficultyTuning.allows(source):
		return
	var pattern := DifficultyTuning.tune(source, false)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var view := CameraView.visible_rect(_enemy)
	var from_left := _enemy.global_position.x < view.get_center().x
	# 高さ: 自機を狙う弾幕・一直線の弾幕は自機の高さ、それ以外は画面の上のほう
	var y_ratio := 0.5
	if player:
		y_ratio = clampf((player.global_position.y - view.position.y) / view.size.y, 0.12, 0.9)
	var split := pattern.split_pattern != null
	if split:
		# 花火: 画面のいちばん上を横切って割れる(自機が上のほうにいるときは、下のほうに撃つ)
		y_ratio = split_low_height if y_ratio < split_player_above else split_high_height
	elif not pattern.aim_at_player and pattern.bullet_count > 1:
		y_ratio = randf_range(0.15, 0.4)
	var line := not split and not pattern.aim_at_player and pattern.bullet_count <= 1
	var warning := FlankWarning.spawn(_enemy, from_left, y_ratio, warning_time, warning_color, line)
	await _wait(warning_time)
	if is_instance_valid(warning):
		warning.queue_free()
	if not _alive():
		return
	var parent := get_tree().current_scene
	var turn := -PI * 0.5 if from_left else PI * 0.5 # 下向きの弾幕を、画面の内側へ向ける
	var shots := maxi(pattern.shot_count, 1)
	var burst_aim := 0.0
	for i in shots:
		if not _alive() or EnemyShooter.is_holding_fire():
			return
		view = CameraView.visible_rect(_enemy)
		var origin := Vector2(view.position.x - edge_margin if from_left else view.end.x + edge_margin,
				view.position.y + view.size.y * y_ratio)
		var aim := 0.0
		if player and is_instance_valid(player):
			aim = (player.global_position - origin).angle()
		if i == 0:
			burst_aim = aim
		if pattern.aim_at_player:
			EnemyShooter.spawn_bullets(pattern, i, burst_aim if pattern.aim_once_per_burst else aim, origin, parent, null, false, 0.0)
		else:
			EnemyShooter.spawn_bullets(pattern, i, 0.0, origin, parent, null, false, turn)
		await _wait(pattern.interval)

func _alive() -> bool:
	return is_instance_valid(_enemy) and _enemy.is_inside_tree() and _enemy.hp_component and _enemy.hp_component.hp > 0

func _wait(seconds : float) -> void:
	if seconds > 0.0 and is_inside_tree():
		await get_tree().create_timer(seconds, false).timeout
