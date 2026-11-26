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

@export_group("鎖のすだれ")
## 主砲がこの名前で始まる弾幕(目印。弾は撃たない)を撃ち始めたら、鎖のすだれを始める:
##   Union が右へ動き、口から大きな黒い弾を左へ5つ、同じ間隔で順に飛ばす → 止まった黒い弾から、鎖が自機へ向けて飛び出す。
##   鎖の輪は立体弾幕(回る小さな輪)。紫の輪と黒の輪が、向きを変えて交互につながる。鎖は蛇のようにうねりながら進む。
##   鎖の速さは、あとの黒い弾ほど速い(音ゲーのソフラン) → 終わったら左へ動き、右へ5つ。これを Chain Sets 回くり返す
@export var chain_trigger_prefix : String = "u1_chain_curtain"
@export var chain_orb_scene : PackedScene
@export var chain_link_scene : PackedScene
## 鎖の、1つおきの輪(小さめの黒い弾)。空なら、全部 Chain Link Scene
@export var chain_link_alt_scene : PackedScene
@export var chain_link_alt_scale : float = 0.75
@export var chain_sets : int = 2
@export var chain_orbs : int = 5
## 黒い弾の大きさ・飛ばす間隔(秒)・止まるまでの時間(秒)
@export var chain_orb_scale : float = 2.8
@export var chain_orb_gap : float = 0.3
@export var chain_orb_fly_time : float = 0.35
## 鎖の輪の間隔(秒)と、1つの輪の弾の数・輪の半径(px)・輪の回る速さ(度/秒)
@export var chain_link_gap : float = 0.085
@export var chain_ring_bullets : int = 6
@export var chain_ring_radius : float = 10.0
@export var chain_ring_spin : float = 150.0
## うねりの、1回の振れの時間(秒)
@export var chain_snake_period : float = 0.36
## 難易度ごと(EASY, NORMAL, HARD, ANOTHER): 鎖の長さ(輪の数)・最初の鎖の速さ・1つあとの鎖ほど速くなる割合・うねりの強さ(曲がる速さ 度/秒)
@export var chain_links : Array[int] = [7, 8, 10, 12]
@export var chain_speed : Array[float] = [150.0, 170.0, 195.0, 225.0]
@export var chain_speed_step : Array[float] = [0.14, 0.17, 0.2, 0.24]
@export var chain_snake : Array[float] = [80.0, 95.0, 110.0, 125.0]

var _enemy : Enemy
var _view # UnionView
var _chain_generation : int = 0
## 主砲がこの名前で始まる弾幕を撃っているあいだは、瞬間移動も突進もしない(真ん中から回す洗濯機弾幕などが、崩れないように)
@export var calm_pattern_prefixes : Array[String] = ["u3_washer"]
var _calm : bool = false
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
	_start_with_chain_curtain()
	fight_started.emit()

## 戦いの最初の攻撃を、鎖のすだれにする(登場の演出のあいだも、主砲の順番は黙って進んでいるので、ここで合わせ直す)
func _start_with_chain_curtain() -> void:
	var main := _enemy.get_node_or_null("EnemyShooterComponent") as EnemyShooter
	if main == null or not main.has_phases() or chain_trigger_prefix == "":
		return
	var sequence : Array[ShotPattern] = main.phases[0].sequence_for_difficulty()
	for i in sequence.size():
		var pattern := sequence[i]
		if pattern and DifficultyTuning.allows(pattern) and pattern.resource_path.get_file().begins_with(chain_trigger_prefix):
			main._sequence_pos = i
			main.set_phase(0, true)
			return

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
	if teleport_interval > 0.0 and not _calm and not _enemy.get_meta(&"counter_spell", false):
		_teleport_wait -= delta
		if _teleport_wait <= 0.0:
			_teleport_wait = teleport_interval * (rush_rage_scale if _phase >= rage_phase else 1.0)
			_teleport()
			return
	# 突進の合図(倒れる直前の大技のあいだは、突進しない)
	if rush_from_phase >= 0 and _phase >= rush_from_phase and not rush_patterns.is_empty() \
			and not _calm and not _enemy.get_meta(&"counter_spell", false):
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
	var file := pattern.resource_path.get_file()
	_calm = calm_pattern_prefixes.any(func(prefix : String) -> bool: return prefix != "" and file.begins_with(prefix))
	if blink_trigger and pattern == blink_trigger and _still_fighting() and not _rushing:
		_blink_volley()
	elif chain_trigger_prefix != "" and pattern.resource_path.get_file().begins_with(chain_trigger_prefix) \
			and _still_fighting() and not _rushing:
		_chain_curtain()

## 鎖のすだれ: 右へ動いて左へ5つ → 左へ動いて右へ5つ、を Chain Sets 回
func _chain_curtain() -> void:
	_rushing = true # 漂う・瞬間移動・突進を止める
	_chain_generation += 1
	var generation := _chain_generation
	var tree := get_tree()
	var level := clampi(DifficultyTuning.chosen(), 0, 3)
	for set_index in chain_sets:
		for side in [1, -1]: # 1: 右へ動いて、左へ飛ばす / -1: 左へ動いて、右へ飛ばす
			if not _chain_alive(generation):
				_rushing = false
				return
			var rect := CameraView.visible_rect(_enemy)
			var y := _home.y
			var stand_x : float = rect.end.x - 80.0 if side == 1 else rect.position.x + 80.0
			var move := _enemy.create_tween()
			move.tween_property(_enemy, "global_position", Vector2(stand_x, y), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			await move.finished
			if not _chain_alive(generation):
				_rushing = false
				return
			# 黒い弾を止める場所: Union の反対側へ、同じ間隔で5つ(2セット目は、半分ずらす)
			var near : float = stand_x - side * 70.0
			var far : float = rect.position.x + 34.0 if side == 1 else rect.end.x - 34.0
			var shift := 0.5 if set_index % 2 == 1 else 0.0
			var step := (far - near) / maxf(chain_orbs - 1 + shift, 1.0)
			var mouth := _enemy.global_position + Vector2(0, 40)
			for k in chain_orbs:
				if not _chain_alive(generation):
					break
				var anchor := Vector2(near + step * (k + shift), rect.position.y + rect.size.y * 0.27 + (k % 2) * 14.0)
				var speed : float = chain_speed[level] * (1.0 + chain_speed_step[level] * k)
				_launch_chain_orb(mouth, anchor, speed, chain_links[level], chain_snake[level], k % 2 == 1, generation)
				_BlackWave.spawn(tree, mouth, 70.0, 0.2, 10.0)
				await tree.create_timer(chain_orb_gap, false).timeout
			# 最後の鎖が出きるまで待つ
			await tree.create_timer(chain_orb_fly_time + chain_links[level] * chain_link_gap + 0.25, false).timeout
	if _chain_alive(generation):
		var back := _enemy.create_tween()
		back.tween_property(_enemy, "global_position", _home, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await back.finished
	_rushing = false

func _chain_alive(generation : int) -> bool:
	return _still_fighting() and generation == _chain_generation and not _enemy.get_meta(&"counter_spell", false)

## 口から大きな黒い弾を飛ばし、anchor で止める。止まったら、鎖(弾の列)を真下へ出して、消える
func _launch_chain_orb(mouth : Vector2, anchor : Vector2, speed : float, links : int, snake : float, flip : bool, generation : int) -> void:
	if chain_orb_scene == null or chain_link_scene == null:
		return
	var tree := get_tree()
	var parent := tree.current_scene
	var orb := chain_orb_scene.instantiate() as EnemyBullet
	parent.add_child(orb)
	orb.global_position = mouth
	orb.setup(Vector2.DOWN, 0.0, 1.0)
	orb.scale = Vector2.ONE * chain_orb_scale
	var fly := orb.create_tween()
	fly.tween_property(orb, "global_position", anchor, chain_orb_fly_time).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	await fly.finished
	if not is_instance_valid(orb) or not orb.is_normal():
		return
	# 鎖の輪: 立体弾幕の小さな輪。紫の輪(ほぼ正面を向く)と黒の輪(ほぼ真横を向く)を交互につなげる。
	# どの輪も同じうねり(曲がりの区間)で動くので、同じ場所から順に出た輪は、同じ道をたどって、蛇のようにうねる鎖になる
	var motion := _chain_snake_motion(snake)
	var ring_a := _chain_link_pattern(chain_link_scene, 0.8, speed, 20.0, motion)
	var ring_b := _chain_link_pattern(chain_link_alt_scene if chain_link_alt_scene else chain_link_scene,
		chain_link_alt_scale * 0.8, speed, 78.0, motion)
	var player := tree.get_first_node_in_group("player") as Node2D
	var aim := (player.global_position - orb.global_position).angle() if player else PI / 2.0
	for i in links:
		if not is_instance_valid(orb) or not orb.is_normal() or generation != _chain_generation or not _still_fighting():
			break
		var from := orb.global_position + Vector2.from_angle(aim) * 7.0 * chain_orb_scale
		var ring := ring_a if i % 2 == 0 else ring_b
		EnemyShooter.spawn_bullets(ring, i, aim, from, parent, ring.bullet_scene, flip)
		await tree.create_timer(chain_link_gap, false).timeout
	if is_instance_valid(orb):
		orb.vanish(0.1)

## 鎖の輪の弾幕(1つの輪を、渡した向きへ撃つ)。tilt: 輪の面の傾き(度。0 で正面、90 で真横から見た輪)
func _chain_link_pattern(scene : PackedScene, scale : float, speed : float, tilt : float, motion : Array[BulletStep]) -> ShotPattern:
	var link := ShotPattern.new()
	link.bullet_scene = scene
	link.bullet_count = 1
	link.aim_at_player = true # 向きは、渡した向き(鎖を出し始めたときの、自機の方)
	link.bullet_speed = speed
	link.bullet_scale = scale
	link.ring3d_count = chain_ring_bullets
	link.ring3d_radius = chain_ring_radius
	link.ring3d_max_radius = chain_ring_radius
	link.ring3d_spin = chain_ring_spin
	link.ring3d_tilt = tilt
	link.ring3d_tumble = 40.0
	link.motion = motion
	link.skip_auto_tuning = true
	link.set_meta("difficulty_tuned", true)
	return link

## うねり: 左右へ交互に曲がる区間を並べる(最初は半分だけ曲がるので、狙った向きを中心に振れる)
func _chain_snake_motion(turn_speed : float) -> Array[BulletStep]:
	var steps : Array[BulletStep] = []
	for k in 16:
		var step := BulletStep.new()
		step.change_speed = false
		step.duration = chain_snake_period * (0.5 if k == 0 else 1.0)
		step.angular_velocity = turn_speed * (1.0 if k % 2 == 0 else -1.0)
		steps.append(step)
	return steps

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
	_chain_generation += 1 # 形態が変わったら、鎖のすだれは打ち切る
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
