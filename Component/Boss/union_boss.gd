extends Node
class_name UnionBoss
## 裏ボス Union の動き。Union(Enemy)の子に置く。
##   ・登場の演出のあいだ(intro)は、撃たず、ダメージも 1 に固定する(EndingSequence が begin_fight() を呼ぶまで)
##   ・戦いが始まったら、決めた場所(home)のまわりを、ゆっくり8の字に漂う
##   ・Rush From Phase の段階から、ときどき突進する: 赤い予告線 → 画面の端へ下がる → 横切って突進しながら、
##     突進専用の弾幕(Rush Patterns。通った跡に黒いオーブの幕が落ちる)を撃つ → 元の場所へ戻る
##   ・第三形態(Rage Phase)で暴走: RageStart から Raging のアニメーションへ。オーラが強くなる
##   ・倒されたら、口を閉じて、黒い波動を出しながら爆発する

signal fight_started

const _BlackWave := preload("res://GameScene/Effect/black_wave.gd")
const _SHOOTER_SCENE := preload("res://Component/Shooter/enemy_shooter_component.tscn")

## 漂う幅(px)と、1周の時間(秒)
@export var drift : Vector2 = Vector2(70.0, 16.0)
@export var drift_period : float = 7.0
## 暴走する段階(0 から)
@export var rage_phase : int = 2

@export_group("突進")
## この段階(0 から)から突進する。-1 なら突進しない
@export var rush_from_phase : int = 1
## 突進の間隔(秒。暴走中は Rush Rage Scale 倍)
@export var rush_interval : float = 11.0
@export var rush_rage_scale : float = 0.7
## 突進する高さ(画面の上から、画面の高さの割合)
@export_range(0.15, 0.6, 0.01) var rush_height : float = 0.4
## 予告の時間・横切る時間・戻る時間(秒)
@export var rush_warning_time : float = 0.9
@export var rush_time : float = 1.3
@export var rush_return_time : float = 0.8
## 突進しながら撃つ弾幕(突進専用の砲口から、同時に撃つ)
@export var rush_patterns : Array[ShotPattern] = []

@export_group("瞬間移動")
## 瞬間移動の間隔(秒。暴走中は Rush Rage Scale 倍)。0 なら、しない
@export var teleport_interval : float = 6.5
## 現れる場所の範囲(画面の上から、画面の高さの割合)と、左右の余白(px)
@export var teleport_top : float = 0.16
@export var teleport_bottom : float = 0.3
@export var teleport_margin : float = 100.0

@export_group("リズムの瞬間移動")
## 主砲がこの弾幕(目印。弾は撃たない)を撃ち始めたら、リズムに合わせて5回瞬間移動し、そのたびに Blink Volley を撃つ
@export var blink_trigger : ShotPattern
## 瞬間移動のたびに撃つ弾幕(追い越す波動。1回撃ちきり)
@export var blink_volley : ShotPattern
## 長い拍(タン)の長さ(秒)。短い拍(タ)はその半分
@export var blink_beat : float = 0.42
## リズム(1 = タン、0.5 = タ)。毎回ランダムに1つ選ぶ
const BLINK_RHYTHMS : Array = [
	[1.0, 1.0, 0.5, 0.5, 1.0], # タン タン タ タ タン
	[0.5, 1.0, 0.5, 1.0, 1.0], # タ タン タ タン タン
	[0.5, 1.0, 1.0, 0.5, 1.0], # タ タン タン タ タン
]

var _enemy : Enemy
var _view # UnionView
var _aura : Node2D
var _aura_front : Node2D
var _hp : HPComponent
var _home : Vector2 = Vector2.ZERO
var _fighting : bool = false
var _rushing : bool = false
var _t : float = 0.0
var _rush_wait : float = 0.0
var _teleport_wait : float = 0.0
var _phase : int = 0

func _ready() -> void:
	_enemy = get_parent() as Enemy
	if _enemy == null:
		return
	_view = _enemy.get_node_or_null("UnionView")
	_aura = _enemy.get_node_or_null("UnionAura") as Node2D
	_aura_front = _enemy.get_node_or_null("UnionAuraFront") as Node2D
	_hp = _enemy.get_node_or_null("HPComponent") as HPComponent
	if _hp:
		_hp.damage_lock = true # 登場の演出のあいだは、削れない
	for child in _enemy.get_children():
		if child is BossPhaseController:
			child.phase_started.connect(_on_phase_started)
	var main := _enemy.get_node_or_null("EnemyShooterComponent") as EnemyShooter
	if main:
		main.pattern_started.connect(_on_main_pattern_started)
	_enemy.died.connect(_on_died)

func view() -> Node2D:
	return _view

## 登場の演出が終わった: home のまわりを漂いながら、戦い始める
func begin_fight(home : Vector2) -> void:
	_home = home
	_t = 0.0
	_rush_wait = rush_interval * 0.6
	_teleport_wait = teleport_interval
	_fighting = true
	if _hp:
		_hp.damage_lock = false
	if _view:
		_view.play(&"Idle", 0.3)
	fight_started.emit()

func is_fighting() -> bool:
	return _fighting

func is_rushing() -> bool:
	return _rushing

func _physics_process(delta : float) -> void:
	if not _fighting or _enemy._is_dead:
		return
	if _rushing:
		return # 突進のあいだは、突進の動きにまかせる
	_t += delta
	var a := TAU * _t / drift_period
	var target := _home + Vector2(sin(a) * drift.x, sin(a * 2.0) * drift.y)
	_enemy.global_position = _enemy.global_position.lerp(target, clampf(delta * 3.0, 0.0, 1.0))
	# 瞬間移動(倒れる直前の大技のあいだは、しない)
	if teleport_interval > 0.0 and not _enemy.get_meta(&"counter_spell", false):
		_teleport_wait -= delta
		if _teleport_wait <= 0.0:
			_teleport_wait = teleport_interval * (rush_rage_scale if _phase >= rage_phase else 1.0)
			_teleport()
			return
	# 突進の合図(倒れる直前の大技のあいだは、突進しない)
	if rush_from_phase >= 0 and _phase >= rush_from_phase and not rush_patterns.is_empty() \
			and not _enemy.get_meta(&"counter_spell", false):
		_rush_wait -= delta
		if _rush_wait <= 0.0:
			_rush_wait = rush_interval * (rush_rage_scale if _phase >= rage_phase else 1.0)
			_rush()

## 突進: 予告 → 端へ下がる → 横切りながら撃つ → 戻る
func _rush() -> void:
	_rushing = true
	var tree := get_tree()
	var view_rect := CameraView.visible_rect(_enemy)
	var y := view_rect.position.y + view_rect.size.y * rush_height
	var from_left := randf() < 0.5
	var start_x := view_rect.position.x + 70.0 if from_left else view_rect.end.x - 70.0
	var end_x := view_rect.end.x - 70.0 if from_left else view_rect.position.x + 70.0
	# 1. 予告: 突進する高さに、赤い線が点滅する。そのあいだに、端へ下がる
	var line := Line2D.new()
	line.width = 3.0
	line.default_color = Color(1.0, 0.1, 0.15, 0.0)
	line.z_as_relative = false
	line.z_index = 30
	line.points = PackedVector2Array([Vector2(view_rect.position.x, y), Vector2(view_rect.end.x, y)])
	tree.current_scene.add_child(line)
	var blink := line.create_tween().set_loops(3)
	blink.tween_property(line, "default_color:a", 0.8, rush_warning_time / 6.0)
	blink.tween_property(line, "default_color:a", 0.1, rush_warning_time / 6.0)
	var back := _enemy.create_tween()
	back.tween_property(_enemy, "global_position", Vector2(start_x, y), rush_warning_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await back.finished
	if is_instance_valid(line):
		line.queue_free()
	if not _still_fighting():
		_rushing = false
		return
	# 2. 突進しながら撃つ(いつもの砲口は黙らせる)
	_set_main_silent(true)
	var shooter := _SHOOTER_SCENE.instantiate() as EnemyShooter
	shooter.autostart = false
	shooter.only_when_on_screen = false
	shooter.name = "UnionRushShooter"
	_enemy.add_child(shooter)
	shooter.set_patterns(rush_patterns, [], false, true)
	var camera := StageCamera.of(_enemy)
	if camera:
		camera.shake(5.0, rush_time)
	_BlackWave.spawn(tree, _enemy.global_position, 160.0, 0.5, 20.0)
	var dash := _enemy.create_tween()
	dash.tween_property(_enemy, "global_position:x", end_x, rush_time).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)
	await dash.finished
	if is_instance_valid(shooter):
		shooter.stop()
		shooter.queue_free()
	_set_main_silent(false)
	if not _still_fighting():
		_rushing = false
		return
	# 3. 元の場所へ戻る
	var home := _enemy.create_tween()
	home.tween_property(_enemy, "global_position", _home, rush_return_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await home.finished
	_rushing = false

## 主砲が目印の弾幕を撃ち始めた: リズムの瞬間移動
func _on_main_pattern_started(pattern : ShotPattern) -> void:
	if blink_trigger and pattern == blink_trigger and _still_fighting() and not _rushing:
		_blink_volley()

## リズムに合わせて5回、瞬間移動する。現れるたびに、黒い波動と、追い越す波動の弾幕
func _blink_volley() -> void:
	_rushing = true
	var tree := get_tree()
	var rhythm : Array = BLINK_RHYTHMS[randi() % BLINK_RHYTHMS.size()]
	for beat in rhythm:
		if not _still_fighting():
			break
		var rect := CameraView.visible_rect(_enemy)
		var to := Vector2(randf_range(rect.position.x + teleport_margin, rect.end.x - teleport_margin),
			rect.position.y + rect.size.y * randf_range(teleport_top, teleport_bottom))
		_BlackWave.spawn(tree, _enemy.global_position, 120.0, 0.25, 16.0)
		await _fade_visual(0.0, 0.05)
		if not _still_fighting():
			break
		_enemy.global_position = to
		_home = to
		await _fade_visual(1.0, 0.05)
		_BlackWave.spawn(tree, to, 300.0, 0.7, 34.0)
		if blink_volley:
			var shooter := _SHOOTER_SCENE.instantiate() as EnemyShooter
			shooter.autostart = false
			shooter.only_when_on_screen = false
			shooter.name = "UnionBlinkShooter"
			_enemy.add_child(shooter)
			shooter.set_patterns([blink_volley], [], false, true)
			tree.create_timer(1.2, false).timeout.connect(func() -> void:
				if is_instance_valid(shooter):
					shooter.stop()
					shooter.queue_free())
		await tree.create_timer(maxf(float(beat) * blink_beat - 0.1, 0.05), false).timeout
	_rushing = false

## 瞬間移動: 黒い波動とともに消えて、画面の上のほうの別の場所に現れる(そこを、漂う中心にする)
func _teleport() -> void:
	_rushing = true # 動きを止める(突進と同じ扱い)
	var tree := get_tree()
	var rect := CameraView.visible_rect(_enemy)
	var to := _home
	for i in 8:
		to = Vector2(randf_range(rect.position.x + teleport_margin, rect.end.x - teleport_margin),
			rect.position.y + rect.size.y * randf_range(teleport_top, teleport_bottom))
		if to.distance_to(_enemy.global_position) > 120.0:
			break
	_BlackWave.spawn(tree, _enemy.global_position, 140.0, 0.35, 18.0)
	await _fade_visual(0.0, 0.16)
	if not _still_fighting():
		_rushing = false
		return
	_enemy.global_position = to
	_home = to
	_BlackWave.spawn(tree, to, 160.0, 0.4, 22.0)
	await _fade_visual(1.0, 0.16)
	_rushing = false

## Union の姿とオーラの濃さを変える(暴走の色の脈打ちは、Union 本体の色なので、ぶつからない)
func _fade_visual(alpha : float, time : float) -> void:
	var tween := _enemy.create_tween().set_parallel(true)
	for node in [_view, _aura, _aura_front]:
		if node:
			tween.tween_property(node, "modulate:a", alpha, time)
	await tween.finished

func _still_fighting() -> bool:
	return _fighting and is_instance_valid(_enemy) and not _enemy._is_dead

## いつもの砲口を、黙らせる・戻す(突進のあいだ)
func _set_main_silent(silent : bool) -> void:
	for node in _enemy.get_children():
		if node is EnemyShooter and not node.name in ["UnionRushShooter", "UnionBlinkShooter", "CounterSpellShooter"]:
			(node as EnemyShooter).suppressed = silent

func _on_phase_started(index : int) -> void:
	_phase = index
	if index == rage_phase and _view:
		_view.play(&"RageStart", 0.1)
		_view.queue(&"Raging")
		_BlackWave.spawn(get_tree(), _enemy.global_position, 380.0, 1.0)
		for aura in [_aura, _aura_front]:
			if aura:
				aura.set("intensity", 1.6)
		var camera := StageCamera.of(_enemy)
		if camera:
			camera.shake(8.0, 0.9)

func _on_died(_e : Enemy) -> void:
	_fighting = false
	_set_main_silent(true)
	if _view:
		_view.play(&"RageEnd", 0.1)
		_view.queue(&"Close")
	for aura in [_aura, _aura_front]:
		if aura:
			var fade : Tween = aura.create_tween()
			fade.tween_property(aura, "modulate:a", 0.0, 2.0)
	var tree := get_tree()
	for i in 4:
		if not is_instance_valid(_enemy):
			return
		_BlackWave.spawn(tree, _enemy.global_position, 300.0 + 80.0 * i, 0.9)
		await tree.create_timer(0.35, false).timeout
