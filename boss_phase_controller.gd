extends Node
class_name BossPhaseController
## ボスのHPを見て、段階(BossPhase)を切り替える。
##
## 置き方は2通り:
##   ・ボスのシーンに、このノードを置いて Phases を設定する(おすすめ)。
##     砲口ごとの弾幕は、各 EnemyShooter の Phases に入れる
##   ・ステージの SpawnEvent の Phases を設定すると、StageRunner が自動で付ける(シーンに置いていないとき)
##
## 段階が変わると: 画面の敵弾を消し(Clear Bullets)、各砲口を その段階の弾幕に切り替え、ボスが光ってから その段階の色になる。
## 砲口の弾幕: EnemyShooter に Phases があれば、その段階のもの。なければ BossPhase の Patterns(全ての砲口に同じもの)

signal phase_started(index : int)

## 段階。HPの多い順(第一形態が最初、Hp Ratio 1.0)に並べる
@export var phases : Array[BossPhase] = []
## false なら、段階が変わっても砲口の弾幕を切り替えない(ボスのステートが、今の段階を見て撃たせるとき)
@export var switch_shooters : bool = true

var _hp : HPComponent
var _index : int = 0
## 呼び寄せ(Summons)が済んだ段階
var _summoned : Dictionary = {}

func _ready() -> void:
	if _hp == null:
		var boss := get_parent()
		if boss:
			_hp = boss.get_node_or_null("HPComponent") as HPComponent
		if _hp:
			_hp.hp_changed.connect(_on_hp_changed)

## StageRunner が SpawnEvent の Phases から付けるときに使う(ツリーに入る前に呼ぶ)
func setup(hp : HPComponent, boss_phases : Array[BossPhase]) -> void:
	_hp = hp
	phases = boss_phases
	_hp.hp_changed.connect(_on_hp_changed)

## 最初の段階の弾幕を、砲口に入れる(敵がツリーに入る前に呼ぶと、そのまま撃ち始める)。
## Phases を持つ砲口は、自分で第一形態の弾幕を使うので、何もしない
func apply_first(enemy : Node) -> void:
	if phases.is_empty():
		return
	for shooter in _shooters(enemy):
		if not shooter.has_phases():
			shooter.patterns = phases[0].patterns

## 今の段階(0 = 第一形態)
func current_phase() -> int:
	return _index

func _on_hp_changed() -> void:
	if _hp.max_hp <= 0:
		return
	var ratio := float(_hp.hp) / _hp.max_hp
	# HPが一気に減ったときは、飛ばした段階も含めて、当てはまる最後の段階まで進める
	var next := _index
	while next + 1 < phases.size() and ratio <= phases[next + 1].hp_ratio:
		next += 1
	if next != _index and _hp.hp > 0:
		_start_phase(next)
	_check_summon(ratio)

func _start_phase(index : int) -> void:
	_index = index
	var phase := phases[index]
	if phase.clear_bullets:
		# ボスから近い弾ほど先に、光ってはじけて消える(点にはならない)
		EnemyBullet.vanish_all(get_tree(), (get_parent() as Node2D).global_position)
	var boss := get_parent()
	for shooter in (_shooters(boss) if switch_shooters else []):
		if shooter.has_phases():
			shooter.set_phase(index)
		else:
			shooter.set_patterns(phase.patterns)
	# 白く光ってから、この段階の色になる
	var tween := create_tween()
	tween.tween_property(boss, "modulate", Color(2.0, 2.0, 2.0), 0.08)
	tween.tween_property(boss, "modulate", phase.boss_modulate, 0.4)
	phase_started.emit(index)
	if _hp and _hp.max_hp > 0:
		_check_summon(float(_hp.hp) / _hp.max_hp)

## 今の段階の呼び寄せ: HPの割合が Summon Hp Ratio 以下になったら、1回だけ出す
func _check_summon(ratio : float) -> void:
	if phases.is_empty() or _summoned.has(_index) or _hp.hp <= 0:
		return
	var phase := phases[_index]
	if phase.summons.is_empty() or ratio > phase.summon_hp_ratio:
		return
	_summoned[_index] = true
	_summon(phase)

func _summon(phase : BossPhase) -> void:
	var runner := get_tree().get_first_node_in_group("stage_runner") as StageRunner
	if runner == null:
		return
	# まだ前の援護が残っていたら、先に急いで走り去らせて、いなくなってから次の援護を呼ぶ(重ならないように)
	var old : Array = []
	for node in get_tree().get_nodes_in_group("stage_support"):
		for child in node.get_children():
			if child is TrainBossMover:
				old.append(node)
				child.leave_now(1400.0)
	if not old.is_empty():
		EnemyShooter.hold_fire(4.0)
		var waited := 0.0
		while waited < 4.0 and old.any(func(n) -> bool: return is_instance_valid(n)):
			await get_tree().create_timer(0.1, false).timeout
			waited += 0.1
		if not is_inside_tree() or _hp.hp <= 0:
			return
	var entries : Array = []
	for event in phase.summons:
		if event == null:
			continue
		for i in event.unit_count():
			entries.append([event.unit_time(i), event, i])
	entries.sort_custom(func(a, b) -> bool: return a[0] < b[0])
	var camera := StageCamera.of(self)
	if phase.summon_look_lane >= 0 and camera:
		await _summon_with_cut_in(runner, camera, entries)
		return
	var elapsed := 0.0
	for entry in entries:
		var wait : float = entry[0] - elapsed
		if wait > 0.0:
			await get_tree().create_timer(wait, false).timeout
			elapsed = entry[0]
		if not is_inside_tree() or _hp.hp <= 0:
			return
		entry[1].execute(runner, entry[2])

## 割り込みの演出: 画面の弾を消して敵は撃たず、自機はその場に止めて、カメラだけを援護の来る画面へ向ける。
## 援護が何両もいれば、1両ずつ: その画面へ向く → 汽笛を鳴らして突っ込んでくる → 止まって汽笛が鳴り終わったら、すぐ次の画面へ。
## 最後の援護の汽笛が鳴り終わったら、すぐ元の位置へ戻って、戦闘に戻る
func _summon_with_cut_in(runner : StageRunner, camera : StageCamera, entries : Array) -> void:
	var boss := get_parent() as Node2D
	var player := camera._get_player() as Player
	var ground := RailGround.of(self)
	EnemyBullet.vanish_all(get_tree(), boss.global_position if boss else camera.global_position)
	# 演出のあいだは自機が動けず、カメラも離れるので、出ているアイテムを先に全部回収する
	var score_system := get_tree().get_first_node_in_group("score_system") as ScoreSystem
	if score_system:
		score_system.collect_everything()
	camera.begin_focus()
	# ボスが位置を移る途中(最後の段階で中央へ)なら、走り去り終わるまで待つ(援護と重ならないように)
	var boss_mover : TrainBossMover = null
	for child in get_parent().get_children():
		if child is TrainBossMover:
			boss_mover = child
	var waited := 0.0
	while boss_mover and boss_mover.is_relocating() and waited < 8.0:
		_keep_safe(player, 2.0)
		await get_tree().create_timer(0.1, false).timeout
		waited += 0.1
	var taken : Array[int] = []
	for entry in entries:
		if not is_inside_tree() or _hp.hp <= 0:
			break
		var event : StageEvent = entry[1]
		_keep_safe(player, 12.0)
		var lane : int = event.camera_lane if "camera_lane" in event and event.camera_lane >= 0 else 1
		# ボスのすぐ隣の線路に呼ぶ(左の画面の援護は左隣、右は右隣を先に探す。空いていなければ反対側)
		var spot := _support_span(ground, lane, taken)
		var look_x := camera.lane_x(lane)
		if spot >= 0 and ground:
			taken.append(spot)
			runner.span_override = spot
			look_x = ground.span_x(spot)
		await camera.focus_to(look_x)
		var before := get_tree().get_nodes_in_group("stage_support")
		event.execute(runner, entry[2])
		runner.span_override = -1
		# 出てきた援護が突っ込んで止まり、汽笛(ファーン)が鳴り終わるまで見せる
		await get_tree().process_frame
		await get_tree().physics_frame
		var mover : TrainBossMover = null
		for node in get_tree().get_nodes_in_group("stage_support"):
			if not before.has(node):
				for child in node.get_children():
					if child is TrainBossMover:
						mover = child
		var shown := 0.0
		while mover and is_instance_valid(mover) and shown < 12.0:
			if mover.entered and mover.horn_remaining() <= 0.0:
				break
			_keep_safe(player, 2.0)
			await get_tree().create_timer(0.1, false).timeout
			shown += 0.1
	_keep_safe(player, 2.0)
	await camera.end_focus()

## 援護を出す位置(Span): ボスのすぐ隣で、空いているところ。lane が左(0)なら左隣、右(2)なら右隣を先に探す
func _support_span(ground : RailGround, lane : int, taken : Array[int]) -> int:
	if ground == null:
		return -1
	var boss_span := -1
	for child in get_parent().get_children():
		if child is TrainBossMover:
			boss_span = child.target_span()
	if boss_span < 0:
		return -1
	var busy := TrainBossMover.occupied_spans(get_tree())
	var side := -1 if lane <= 1 else 1
	for offset in [side, -side, side * 2, -side * 2]:
		var s : int = boss_span + offset
		if s >= 0 and s < ground.span_count() and not busy.has(s) and not taken.has(s):
			return s
	return -1

## 演出のあいだ、敵は撃たず、自機は当たらない
func _keep_safe(player : Player, seconds : float) -> void:
	EnemyShooter.hold_fire(seconds)
	if is_instance_valid(player):
		player.start_invincibility(seconds)

func _shooters(enemy : Node) -> Array[EnemyShooter]:
	var result : Array[EnemyShooter] = []
	for node in enemy.find_children("*", "", true, false):
		if node is EnemyShooter:
			result.append(node)
	return result
