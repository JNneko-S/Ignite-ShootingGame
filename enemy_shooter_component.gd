extends Node2D
class_name EnemyShooter
## 敵に付ける弾発射コンポーネント。ShotPattern を複数登録でき、それぞれ独立して撃つ。
## このノードの位置が発射位置(砲口)になるので、敵の子として好きな位置に置く。
## 自機への狙い撃ちには、Player が "player" グループに入っている必要がある。
##
## ボスに BeatConductor があると、Patterns は使わず、譜面(BeatChart)のとおりに撃つ。

## 撃った瞬間に出る(砲台の反動アニメーションなどに使う)
signal fired

@export var patterns : Array[ShotPattern] = []
## 順番に撃つ弾幕。1つ撃ち終わったら(Pause だけ待って)次へ進み、最後まで行ったら最初に戻る。
## Patterns(同時に撃つ)と一緒に使える。ボスの攻撃の組み立てに使う
@export var sequence : Array[ShotPattern] = []
## ボスの段階ごとの弾幕(第一形態から順に並べる)。設定すると Patterns / Sequence の代わりにこちらを使い、
## ボスの段階が変わる(BossPhaseController)と、その段階の弾幕に切り替わる。段階の数より少なければ、最後のものを使い続ける
@export var phases : Array[ShooterPhase] = []
## ShotPattern 側で弾シーンが未指定のときに使う弾(弾幕側に指定があれば、そちらが優先)
@export var default_bullet_scene : PackedScene
## 弾の生成先。未設定なら現在のシーン直下
@export var bullet_parent : Node
## true なら、画面内にいる間だけ撃つ(画面外からの不意打ち・無駄撃ち防止)
@export var only_when_on_screen : bool = true
## オンなら、画面の左右の外にいるときも撃つ(画面の上下の外では撃たない)。Only When On Screen より優先。
## 横に広いステージのボスが、となりの画面から撃ってくるのに使う
@export var fire_offscreen_sideways : bool = false
## オンなら、画面の左右の外にいるときだけ撃つ(画面の中や、上下の外では撃たない)。
## ボスが、となりの画面にいる自機を、画面の外から狙ってくる砲口に使う
@export var only_offscreen_sideways : bool = false
## 弾幕の休み(Pause)の長さの倍率。0.5 なら休みが半分になり、撃つ頻度が上がる(同じ弾幕を、もっと頻繁に撃たせるとき)
@export var pause_scale : float = 1.0
## true なら、発射のたびに使われている値をデバッグ出力に表示する(設定が効いているかの確認用)
@export var debug_log : bool = false
## false なら、出現しても自分では撃ち始めない(ボスのステートなど、外から set_patterns / set_phase で撃たせる)
@export var autostart : bool = true
## EASY のときは、Patterns の代わりに、こちらを撃つ(空なら差し替えない。Phases を使う砲口は、ShooterPhase の Easy Patterns を使う)
@export var easy_patterns : Array[ShotPattern] = []

## 全ての弾の向きを、この角度(度)だけ回す。正で左回り(画面の左へ)。ボスのステートが、弾幕の向きを振るのに使う
var turn_degrees : float = 0.0

## false にすると撃たなくなる(壊れた部位の砲口など)。譜面で撃つときも撃たない
var enabled : bool = true
## true のあいだは撃たない(列車ボスが、自機の後ろにある砲口を一時的に止めるときなど)。Enabled とは別に、毎フレーム決め直す
var blocked : bool = false

## この時刻(Time.get_ticks_msec)まで、全ての敵が撃たない(自機の復活直後など)
static var _hold_fire_until_msec : int = 0

## 全ての敵を、seconds 秒のあいだ撃たせない。すでにもっと長く止めていれば、そのまま
static func hold_fire(seconds : float) -> void:
	_hold_fire_until_msec = maxi(_hold_fire_until_msec, Time.get_ticks_msec() + int(seconds * 1000.0))

static func is_holding_fire() -> bool:
	return Time.get_ticks_msec() < _hold_fire_until_msec

## 雑魚の砲口か(-1 = まだ調べていない)。EASY で、雑魚の弾をさらに遅くするのに使う
var _zako : int = -1

## 雑魚の砲口か(ボス・中ボス・援護の列車でなければ雑魚)
func is_zako() -> bool:
	if _zako < 0:
		_zako = 1
		var node := get_parent()
		while node and not node is Enemy:
			node = node.get_parent()
		var enemy := node as Enemy
		if enemy == null or enemy.is_midboss:
			_zako = 0
		else:
			for child in enemy.get_children():
				if child is BossPhaseController or child is TrainBossMover or (child is DeathExplosion and child.big):
					_zako = 0
					break
	return _zako == 1

## stop() で増える。動いている _run_pattern は、これが変わったら止まる
var _generation : int = 0
## aim_once_per_burst 用の、パターンごとのバーストの向き(譜面で撃つとき)
var _burst_aims : Dictionary = {}

func _ready() -> void:
	if not phases.is_empty() and phases[0]:
		patterns = phases[0].patterns_for_difficulty()
		sequence = phases[0].sequence_for_difficulty()
	elif DifficultyTuning.is_easy() and not easy_patterns.is_empty():
		patterns = easy_patterns
	if debug_log:
		print("[EnemyShooter] 開始 node=%s patterns=%d" % [get_path(), patterns.size()])
		for pattern in patterns:
			print("    start_delay=%.2f shot_count=%d interval=%.2f loop=%s pause=%.2f bullet_count=%d" % [
				pattern.start_delay, pattern.shot_count, pattern.interval,
				pattern.loop, pattern.pause, pattern.bullet_count])
	if not autostart:
		return # 外から撃たせる
	if _has_conductor():
		return # 譜面で撃つので、Patterns では撃たない
	for pattern in DifficultyTuning.layers(patterns):
		_run_pattern(pattern)
	_run_sequence()

## この敵(シーンのルート)に BeatConductor があるか
func _has_conductor() -> bool:
	var root := owner if owner else get_parent()
	if root == null:
		return false
	for node in root.get_children():
		if node is BeatConductor:
			return true
	return false

## Patterns で撃つのを止める(BeatConductor が、譜面で撃つときに呼ぶ)
func stop() -> void:
	_generation += 1

## 撃っている弾幕を止めて、new_patterns(同時に撃つ)と new_sequence(順番に撃つ)に切り替える(ボスの段階の切り替えなど)
func set_patterns(new_patterns : Array[ShotPattern], new_sequence : Array[ShotPattern] = []) -> void:
	stop()
	patterns = new_patterns
	sequence = new_sequence
	if _has_conductor():
		return
	for pattern in DifficultyTuning.layers(patterns):
		_run_pattern(pattern)
	_run_sequence()

## Phases を持っているか(持っていれば、ボスの段階の切り替えで set_phase が呼ばれる)
func has_phases() -> bool:
	return not phases.is_empty()

## Phases の index 番目(0 = 第一形態)の弾幕に切り替える。足りなければ最後のもの
func set_phase(index : int) -> void:
	if phases.is_empty():
		return
	var phase := phases[clampi(index, 0, phases.size() - 1)]
	if phase == null:
		set_patterns([], [])
		return
	set_patterns(phase.patterns_for_difficulty(), phase.sequence_for_difficulty())

## sequence の弾幕を、1つずつ順番に撃つ(最後まで行ったら最初に戻る)
func _run_sequence() -> void:
	if sequence.is_empty():
		return
	var generation := _generation
	var index := 0
	while generation == _generation and not sequence.is_empty():
		await _run_once(sequence[index % sequence.size()], generation)
		index += 1
		if is_inside_tree():
			await get_tree().process_frame # 時間のかからない弾幕だけでも、止まらないように

## pattern を1回分(Start Delay → Shot Count 発 → Pause)だけ撃つ。Loop は見ない
func _run_once(pattern : ShotPattern, generation : int) -> void:
	if not DifficultyTuning.allows(pattern):
		await get_tree().process_frame
		return
	pattern = DifficultyTuning.tune(pattern, is_zako())
	var clock := MusicClock.find_in(get_tree())
	var unit := ShotMath.time_unit(pattern, clock.seconds_per_beat() if clock else 0.5)
	await _wait_with_warning(pattern, pattern.start_delay * unit, generation)
	var burst_aim := _aim_angle()
	for i in maxi(pattern.shot_count, 1):
		if generation != _generation:
			return
		if _can_fire():
			_fire(pattern, i, burst_aim if pattern.aim_once_per_burst else _aim_angle())
		await _wait(pattern.interval * unit)
	if generation != _generation:
		return
	await _wait(pattern.pause * unit * pause_scale)

## 譜面(BeatConductor)から、pattern の shot_index 発目を撃つ
func fire_scheduled(pattern : ShotPattern, shot_index : int) -> void:
	if not DifficultyTuning.allows(pattern):
		return
	var burst := maxi(pattern.shot_count, 1)
	if shot_index % burst == 0 or not _burst_aims.has(pattern):
		_burst_aims[pattern] = _aim_angle()
	if not _can_fire():
		return
	_fire(DifficultyTuning.tune(pattern, is_zako()), shot_index, _burst_aims[pattern] if pattern.aim_once_per_burst else _aim_angle())

func _run_pattern(pattern : ShotPattern) -> void:
	if not DifficultyTuning.allows(pattern):
		return # この難易度では撃たない弾幕
	pattern = DifficultyTuning.tune(pattern, is_zako()) # この難易度用に、数や速さを変えた写し(HARD ならそのまま)
	var generation := _generation
	# Timing Unit が BEATS なら、鳴っている曲(MusicClock)のテンポで数える
	var clock := MusicClock.find_in(get_tree())
	var unit := ShotMath.time_unit(pattern, clock.seconds_per_beat() if clock else 0.5)
	await _wait_with_warning(pattern, pattern.start_delay * unit, generation)
	var shot_index := 0
	while generation == _generation:
		var burst_aim := _aim_angle()
		for i in maxi(pattern.shot_count, 1):
			if generation != _generation:
				return
			if _can_fire():
				_fire(pattern, shot_index, burst_aim if pattern.aim_once_per_burst else _aim_angle())
				if debug_log:
					print("[EnemyShooter] t=%.2f node=%s shot=%d interval=%.2f pause=%.2f pattern=%s" % [
						Time.get_ticks_msec() / 1000.0, get_path(), shot_index, pattern.interval, pattern.pause,
						pattern.resource_path if pattern.resource_path != "" else "(シーン内に埋め込み)"])
			shot_index += 1
			await _wait(pattern.interval * unit)
			if generation != _generation:
				return
		if not pattern.loop:
			return
		await _wait_with_warning(pattern, pattern.pause * unit * pause_scale, generation)

func _can_fire() -> bool:
	if not enabled or blocked or is_holding_fire():
		return false
	var view := CameraView.visible_rect(self)
	if only_offscreen_sideways:
		var in_height := global_position.y >= view.position.y - 120.0 and global_position.y <= view.end.y
		return in_height and (global_position.x < view.position.x or global_position.x > view.end.x)
	if fire_offscreen_sideways:
		return global_position.y >= view.position.y and global_position.y <= view.end.y # 高さが画面の中なら、左右の外でも撃つ
	return not only_when_on_screen or view.has_point(global_position)

func _fire(pattern : ShotPattern, shot_index : int, aim_angle : float) -> void:
	var parent : Node = bullet_parent if bullet_parent else get_tree().current_scene
	spawn_bullets(pattern, shot_index, aim_angle, global_position, parent, default_bullet_scene, _is_mirrored(), deg_to_rad(turn_degrees))
	fired.emit()

## pattern の shot_index 発目の弾を、origin から出す。EnemyShooter・分裂弾・撃ち返し弾(RevengeShooter)が使う。
## 弾の並べ方(角度・列弾・ばらつき)は、プレビューと同じ ShotMath で計算する。
## fallback_scene: pattern に弾シーンがないときの弾 / turn: 全ての弾の向きを、この角度(ラジアン)だけ回す(分裂弾用)
## split_depth: 何回割れてできた弾か(分裂弾の段階の上限に使う)
static func spawn_bullets(pattern : ShotPattern, shot_index : int, aim_angle : float, origin : Vector2,
		parent : Node, fallback_scene : PackedScene, mirror : bool = false, turn : float = 0.0, split_depth : int = 0) -> void:
	var scene := pattern.bullet_scene if pattern.bullet_scene else fallback_scene
	if scene == null:
		push_warning("EnemyShooter: 弾シーンが未設定です")
		return
	if parent == null:
		return
	for shot in ShotMath.bullets(pattern, shot_index, aim_angle, mirror):
		var bullet : Node2D = scene.instantiate()
		parent.add_child(bullet)
		bullet.z_index = 5
		var offset : Vector2 = shot["offset"]
		bullet.global_position = origin + offset.rotated(turn)
		if bullet.has_method("setup"):
			bullet.setup(Vector2.from_angle(shot["angle"] + turn), pattern.bullet_speed * shot["speed_scale"], pattern.damage, pattern.bullet_accel * shot["speed_scale"])
		# 片側だけ曲がりを反転する弾(Mirror Curve By Side)は、その弾だけ左右反転として扱う
		var bullet_mirror : bool = mirror != shot.get("flip", false)
		if bullet.has_method("set_motion"):
			bullet.set_motion(pattern.motion, shot["speed_scale"], bullet_mirror)
		if bullet.has_method("set_split"):
			bullet.set_split(pattern, bullet_mirror, split_depth)

## 左右反転して出た敵(Enemy の mirror_x)の砲口なら、弾幕も左右反転する
func _is_mirrored() -> bool:
	var node := get_parent()
	while node:
		if node is Enemy:
			return node.mirror_x
		node = node.get_parent()
	return false

## 自機への角度(自機がいなければ真下)
func _aim_angle() -> float:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		return (player.global_position - global_position).angle()
	return Vector2.DOWN.angle()

## 撃つ前の seconds 秒を待つ。pattern に Warning Time があれば、待ちの最後の Warning Time 秒に予告線を出す。
## 待ちが Warning Time より短ければ、予告のぶんだけ長く待つ
func _wait_with_warning(pattern : ShotPattern, seconds : float, generation : int) -> void:
	var warn := pattern.warning_time
	if warn <= 0.0:
		await _wait(seconds)
		return
	await _wait(maxf(seconds - warn, 0.0))
	if generation != _generation or not is_inside_tree():
		return
	var line := AimWarning.new()
	line.setup(self, pattern, generation, warn)
	add_child(line)
	await _wait(warn)
	if is_instance_valid(line):
		line.queue_free()

## このノードに紐づく Tween で待つ。ノードが消えたときに安全に処理が止まる
func _wait(seconds : float) -> void:
	if seconds <= 0.0:
		return
	var tween := create_tween()
	tween.tween_interval(seconds)
	await tween.finished
