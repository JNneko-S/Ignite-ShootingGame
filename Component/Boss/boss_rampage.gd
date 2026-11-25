extends Node
class_name BossRampage
## ボスの「暴走状態」。ボス(Enemy)の子に置く。決まった段階(BossPhaseController の段階)に入ると暴走する:
##   ・名前を大きく出して、画面が赤く光って揺れる
##   ・機体が赤く脈打ち、体から血のような火花が散り続ける
##   ・全ての砲口の休み(Pause)が短くなり(Pause Scale を掛ける)、動き(FighterMover)が速く、落ち着きがなくなる
## 暴走のあいだも、カウンター大技などは今までどおり(砲口の Pause Scale を変えるだけ)。

const _HitSpark := preload("res://GameScene/Effect/hit_spark.gd")

## 暴走する段階(0 から)
@export var trigger_phase : int = 2
## 出す名前
@export var title : String = "RAMPAGE"
@export var subtitle : String = "暴走"
## 砲口の Pause Scale に掛ける倍率(小さいほど休みが短い)
@export_range(0.3, 1.0, 0.05) var pause_scale : float = 0.75
## 動きの速さに掛ける倍率と、止まる時間に掛ける倍率(FighterMover)
@export var move_speed_scale : float = 1.4
@export_range(0.1, 1.0, 0.05) var move_pause_scale : float = 0.5
## 脈打つ色と、1回の脈の時間(秒)
@export var pulse_color : Color = Color(1.0, 0.18, 0.18)
@export var pulse_time : float = 0.45
## 火花を散らす間隔(秒)と、散らす範囲(ボスの中心からの半径 px)
@export var spark_interval : float = 0.12
@export var spark_radius : float = 70.0

var _enemy : Enemy
var _active : bool = false
var _pulse : Tween
var _spark_left : float = 0.0

func _ready() -> void:
	_enemy = get_parent() as Enemy
	if _enemy == null:
		return
	for child in _enemy.get_children():
		if child is BossPhaseController:
			child.phase_started.connect(func(index : int) -> void:
				if index == trigger_phase:
					_start())
	_enemy.died.connect(func(_e : Enemy) -> void: _stop())

func is_active() -> bool:
	return _active

func _start() -> void:
	if _active or not is_inside_tree() or _enemy._is_dead:
		return
	_active = true
	var tree := get_tree()
	ScreenFlash.play(tree, 0.45)
	HitStop.apply(tree, 0.08)
	var camera := StageCamera.of(_enemy)
	if camera:
		camera.shake(9.0, 0.7)
	var at := _enemy.global_position + Vector2(0, 76)
	FloatingText.spawn(tree, at, title + "!!", pulse_color.lightened(0.3), 18)
	FloatingText.spawn(tree, at + Vector2(0, 22), subtitle, Color(1.0, 0.9, 0.9), 14)
	for node in _enemy.find_children("*", "", true, false):
		if node is EnemyShooter:
			(node as EnemyShooter).pause_scale *= pause_scale
		elif node is FighterMover:
			var mover := node as FighterMover
			mover.speed *= move_speed_scale
			mover.dash_speed *= move_speed_scale
			mover.pause_min *= move_pause_scale
			mover.pause_max *= move_pause_scale
	# 赤く脈打つ(段階の色 Boss Modulate と、暴走の色のあいだを行き来する)。段階が変わるときの光が終わってから
	var base := _enemy.modulate
	for child in _enemy.get_children():
		if child is BossPhaseController and trigger_phase < child.phases.size():
			base = child.phases[trigger_phase].boss_modulate
	await tree.create_timer(0.5, false).timeout
	if not _active or not is_instance_valid(_enemy) or _enemy._is_dead:
		return
	_pulse = _enemy.create_tween().set_loops()
	_pulse.tween_property(_enemy, "modulate", base.lerp(Color(1.8, pulse_color.g * 2.0, pulse_color.b * 2.0), 0.7), pulse_time * 0.5)\
		.set_trans(Tween.TRANS_SINE)
	_pulse.tween_property(_enemy, "modulate", base, pulse_time * 0.5).set_trans(Tween.TRANS_SINE)

func _stop() -> void:
	_active = false
	if _pulse and _pulse.is_valid():
		_pulse.kill()

func _process(delta : float) -> void:
	if not _active or not is_instance_valid(_enemy) or _enemy._is_dead:
		return
	_spark_left -= delta
	if _spark_left > 0.0:
		return
	_spark_left = spark_interval
	var dir := Vector2.from_angle(randf() * TAU)
	_HitSpark.spawn(get_tree(), _enemy.global_position + dir * randf_range(10.0, spark_radius), dir, randf_range(0.8, 1.3))
