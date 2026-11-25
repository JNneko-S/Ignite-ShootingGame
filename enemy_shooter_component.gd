extends Node2D
class_name EnemyShooter
## 敵に付ける弾発射コンポーネント。ShotPattern を複数登録でき、それぞれ独立して撃つ。
## このノードの位置が発射位置(砲口)になるので、敵の子として好きな位置に置く。
## 自機への狙い撃ちには、Player が "player" グループに入っている必要がある。
##
## ボスに BeatConductor があると、Patterns は使わず、譜面(BeatChart)のとおりに撃つ。

## 撃った瞬間に出る(砲台の反動アニメーションなどに使う)
signal fired
## Sequence(順番に撃つ弾幕)の1つを撃ち終わった(休みに入る前)。ボスの仕掛け(列車など)が、弾幕の切れ目を知るのに使う
signal sequence_step_finished(pattern : ShotPattern)
## 順番に撃つ弾幕(とその前の弾幕)を撃ち始めたとき(BeamShooter の Sync Pattern が、合わせて光線を撃つのに使う)。pattern は調整する前の元の弾幕
signal pattern_started(pattern : ShotPattern)

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
## オンなら、ANOTHER のときは、Patterns / Sequence の代わりに、下の2つを撃つ(空なら撃たない)。
## Phases を使う砲口は、ShooterPhase の Another の設定を使う
@export var another_replace : bool = false
@export var another_patterns : Array[ShotPattern] = []
@export var another_sequence : Array[ShotPattern] = []
## オンなら、二周目(RunConfig.second_round())のときは、Patterns / Sequence の代わりに、下の2つを撃つ(ANOTHER より先)。
## Phases を使う砲口は、ShooterPhase の二周目の設定を使う。二周目の弾幕は、同時に撃つ数を難易度で絞らない
@export var loop2_replace : bool = false
@export var loop2_patterns : Array[ShotPattern] = []
@export var loop2_sequence : Array[ShotPattern] = []
## いま撃っている弾幕を、難易度で絞らずに全部撃つか(二周目の弾幕・カウンター大技)
var _all_layers : bool = false

## いちばん最近撃った弾の向き(ラジアン。全方位の弾幕など、向きがないときは NAN)。砲身を振る砲台が見る
var last_fire_angle : float = NAN
## いちばん最近撃った弾幕が、砲身を振る弾幕(Swing Barrel)か
var last_fire_swing : bool = false

## 全ての弾の向きを、この角度(度)だけ回す。正で左回り(画面の左へ)。ボスのステートが、弾幕の向きを振るのに使う
var turn_degrees : float = 0.0

## false にすると撃たなくなる(壊れた部位の砲口など)。譜面で撃つときも撃たない
var enabled : bool = true
## true のあいだは撃たない(列車ボスが、自機の後ろにある砲口を一時的に止めるときなど)。Enabled とは別に、毎フレーム決め直す
var blocked : bool = false
## true のあいだは撃たない(列車ボスの押し出す弾幕(PushBarrage)が、援護がいないときに止めるなど)。Enabled・Blocked とは別に、外の部品が決める
var suppressed : bool = false

## 撃たせないようにしている数(hold_fire のタイマーが残っている数)。0 より大きいあいだ、全ての敵が撃たない(自機の復活直後など)
static var _hold_fire_count : int = 0

## 全ての敵を、seconds 秒のあいだ撃たせない。重なったら、いちばん長いものが終わるまで止まる。
## ゲームの時間で数える(ポーズ中は進まず、ヒットストップ中はゆっくり進む)
## 撃たせない状態を、すぐに全部やめる(エンディングの脱出で、追ってくる敵に撃たせるとき)
static func release_fire() -> void:
	_hold_fire_count = 0
	_hold_epoch += 1 # 解く前に始まった hold_fire のタイマーは、終わっても数を減らさない(新しい hold_fire を早く解かない)

## release_fire のたびに増える
static var _hold_epoch : int = 0

static func hold_fire(seconds : float) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or seconds <= 0.0:
		return
	_hold_fire_count += 1
	var epoch := _hold_epoch
	await tree.create_timer(seconds, false).timeout
	if epoch == _hold_epoch:
		_hold_fire_count = maxi(_hold_fire_count - 1, 0)

static func is_holding_fire() -> bool:
	return _hold_fire_count > 0

## 開発用: 設定すると、弾幕を撃ち始めるたびに (砲口, 元の弾幕) で呼ばれる(どの弾幕が実際に使われているかを調べる道具が使う)
static var debug_pattern_started : Callable

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
		_all_layers = phases[0].is_loop2()
	elif loop2_replace and RunConfig.second_round():
		patterns = loop2_patterns
		sequence = loop2_sequence
		_all_layers = true
	elif another_replace and HazardRank.active:
		patterns = another_patterns
		sequence = another_sequence
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
	for pattern in (DifficultyTuning.layers(patterns, true) if _all_layers else DifficultyTuning.layers(patterns)):
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
## keep_position: オンなら、順番に撃つ弾幕(Sequence)を、前に止めたところの続きから撃つ(ボスが雑魚を呼んだあと、攻撃に戻るときなど)
## all_layers: オンなら、難易度で同時に撃つ数を絞らない(カウンター大技など、全部そろって意味がある弾幕)
func set_patterns(new_patterns : Array[ShotPattern], new_sequence : Array[ShotPattern] = [], keep_position : bool = false,
		all_layers : bool = false) -> void:
	stop()
	patterns = new_patterns
	sequence = new_sequence
	_all_layers = all_layers
	if not keep_position:
		_sequence_pos = 0
	if _has_conductor():
		return
	for pattern in (DifficultyTuning.layers(patterns, true) if all_layers else DifficultyTuning.layers(patterns)):
		_run_pattern(pattern)
	_run_sequence()

## Phases を持っているか(持っていれば、ボスの段階の切り替えで set_phase が呼ばれる)
func has_phases() -> bool:
	return not phases.is_empty()

## Phases の index 番目(0 = 第一形態)の弾幕に切り替える。足りなければ最後のもの
func set_phase(index : int, keep_position : bool = false) -> void:
	if phases.is_empty():
		return
	var phase := phases[clampi(index, 0, phases.size() - 1)]
	if phase == null:
		set_patterns([], [])
		return
	set_patterns(phase.patterns_for_difficulty(), phase.sequence_for_difficulty(), keep_position, phase.is_loop2())

## 次に撃つ、順番に撃つ弾幕(Sequence)の番号
var _sequence_pos : int = 0
## いま撃っている順番の弾幕が、もう1発でも撃ったか(止められたとき、次の弾幕へ進むかを決める)
var _run_fired : bool = false

## sequence の弾幕を、1つずつ順番に撃つ(最後まで行ったら最初に戻る)
func _run_sequence() -> void:
	if sequence.is_empty():
		return
	var generation := _generation
	while generation == _generation and not sequence.is_empty():
		if not is_inside_tree():
			return # シーンから外れた砲口は、撃つのをやめる(外れたまま回り続けて、ゲームが固まらないように)
		var index := _sequence_pos % sequence.size()
		_run_fired = false
		await _run_once(sequence[index], generation)
		if generation != _generation:
			# 途中で止められた弾幕: まだ撃ち始めていなければ、次に戻ったとき最初から。撃ち始めていたら、次の弾幕へ進む
			# (援護を呼ぶたびに止まるボスで、同じ弾幕ばかりくり返さないように)
			if _run_fired:
				_sequence_pos = index + 1
			break
		_sequence_pos = index + 1
		if is_inside_tree():
			await get_tree().process_frame # 時間のかからない弾幕だけでも、止まらないように

## pattern を1回分(Start Delay → Shot Count 発 → Pause)だけ撃つ。Loop は見ない
func _run_once(pattern : ShotPattern, generation : int) -> void:
	if not DifficultyTuning.allows(pattern):
		if is_inside_tree():
			await get_tree().process_frame
		return
	if debug_pattern_started.is_valid():
		debug_pattern_started.call(self, pattern)
	pattern_started.emit(pattern)
	pattern = DifficultyTuning.tune(pattern, is_zako())
	var clock := MusicClock.find_in(get_tree())
	var unit := ShotMath.time_unit(pattern, clock.seconds_per_beat() if clock else 0.5)
	# この弾幕のあいだ、同じボスのゆずる弾幕をやさしくする(やさしくしない弾幕は、ほかの弾幕の設定を変えない。複合で一緒に撃つ弾幕など)
	var softens := pattern.soften_others > 1.0
	if softens:
		_set_soften(pattern.soften_others)
	# 複合: 一緒に撃つ弾幕(With Patterns)を、この弾幕が終わるまで重ねて撃つ
	var together := {"on": true}
	for companion in pattern.with_patterns:
		if companion:
			_run_companion(companion, generation, together)
	await _wait_with_warning(pattern, pattern.start_delay * unit, generation)
	var burst_aim := _aim_angle()
	for i in maxi(pattern.shot_count, 1):
		if generation != _generation:
			together["on"] = false
			if softens:
				_set_soften(1.0)
			return
		if _can_fire():
			_fire(pattern, i, burst_aim if pattern.aim_once_per_burst else _aim_angle())
			_run_fired = true
		await _wait(pattern.interval * unit)
	if generation != _generation:
		together["on"] = false
		if softens:
			_set_soften(1.0)
		return
	sequence_step_finished.emit(pattern)
	await _wait(pattern.pause * unit * pause_scale)
	together["on"] = false
	if softens:
		_set_soften(1.0)

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
	if debug_pattern_started.is_valid():
		debug_pattern_started.call(self, pattern)
	var original := pattern
	pattern = DifficultyTuning.tune(pattern, is_zako()) # この難易度用に、数や速さを変えた写し(HARD ならそのまま)
	var generation := _generation
	# 複合: 一緒に撃つ弾幕(With Patterns)も、同じあいだ撃ち続ける
	for companion in pattern.with_patterns:
		if companion:
			_run_pattern(companion)
	# Timing Unit が BEATS なら、鳴っている曲(MusicClock)のテンポで数える
	var clock := MusicClock.find_in(get_tree())
	var unit := ShotMath.time_unit(pattern, clock.seconds_per_beat() if clock else 0.5)
	await _wait_with_warning(pattern, (pattern.start_delay + _unit_delay(pattern)) * unit, generation)
	var shot_index := 0
	while generation == _generation:
		if not is_inside_tree():
			return # シーンから外れた砲口は、撃つのをやめる
		var cycle_start := Engine.get_process_frames()
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
			await _wait(pattern.interval * unit * (_soften_factor() if pattern.yields else 1.0))
			if generation != _generation:
				return
		if not pattern.loop:
			return
		await _wait_with_warning(pattern, pattern.pause * unit * pause_scale * (_soften_factor() if pattern.yields else 1.0), generation)
		if Engine.get_process_frames() == cycle_start and is_inside_tree():
			await get_tree().process_frame # 間も休みも 0 の弾幕でも、1回ごとに必ず1フレーム待つ(固まらないように)
		# ANOTHER: ランクが変わっていたら、撃ち終わったところで、次の段階の弾幕(ANOTHER 用の弾幕)に切り替える
		if HazardRank.active:
			pattern = DifficultyTuning.tune(original, is_zako())

func _can_fire() -> bool:
	if not enabled or blocked or suppressed or is_holding_fire():
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
	var mirror := _is_mirrored()
	var heading := _motion_heading() if pattern.split_across_motion else NAN
	var target := Vector2.INF
	if pattern.aim_at_point:
		target = global_position + Vector2(-pattern.aim_point.x if mirror else pattern.aim_point.x, pattern.aim_point.y)
	if pattern.muzzle_offsets.is_empty() and not pattern.aim_at_point:
		spawn_bullets(pattern, shot_index, aim_angle, global_position, parent, default_bullet_scene, mirror, deg_to_rad(turn_degrees),
				0, heading)
	else:
		# 合体攻撃: 砲口からずらした位置の全部から撃つ(自機狙いなら、それぞれの位置から。1点へ集めるなら、その点へ向けて)
		var offsets : Array[Vector2] = [Vector2.ZERO]
		if not pattern.muzzle_offsets.is_empty():
			offsets = pattern.muzzle_offsets
		var player := get_tree().get_first_node_in_group("player") as Node2D
		var aim_target := global_position + Vector2.from_angle(aim_angle) * 400.0 # バーストで固定した狙いの先
		for offset in offsets:
			var origin := global_position + Vector2(-offset.x if mirror else offset.x, offset.y)
			var angle := aim_angle
			if pattern.aim_at_point:
				angle = (target - origin).angle() if target.distance_to(origin) > 0.5 else aim_angle
			elif pattern.aim_at_player:
				var at := aim_target if pattern.aim_once_per_burst or player == null else player.global_position
				angle = (at - origin).angle()
			spawn_bullets(pattern, shot_index, angle, origin, parent, default_bullet_scene, mirror, deg_to_rad(turn_degrees),
					0, heading, target)
	last_fire_swing = pattern.swing_barrel
	if pattern.swing_barrel:
		# 弾の向きの平均(砲身を、そちらへ振る)
		var sum := Vector2.ZERO
		for shot in ShotMath.bullets(pattern, shot_index, aim_angle, _is_mirrored()):
			sum += Vector2.from_angle(shot["angle"])
		last_fire_angle = sum.angle() + deg_to_rad(turn_degrees) if sum.length() > 0.01 else NAN
	fired.emit()

## この砲口が、いま動いている向き(ラジアン)。止まっていれば NAN
func _motion_heading() -> float:
	var now := global_position
	var frame := Engine.get_physics_frames()
	if _motion_frame < 0 or frame - _motion_frame > 2:
		# 前の位置を知らない: 次から測る
		_motion_pos = now
		_motion_frame = frame
		return NAN
	if frame != _motion_frame:
		var step := now - _motion_pos
		if step.length() > 0.05:
			_motion_dir = step
		_motion_pos = now
		_motion_frame = frame
	return _motion_dir.angle() if _motion_dir != Vector2.ZERO else NAN

func _physics_process(_delta : float) -> void:
	_motion_heading() # 毎フレーム、動いた向きを測っておく(Split Across Motion の弾幕で使う)

var _motion_pos : Vector2
var _motion_frame : int = -1
var _motion_dir : Vector2 = Vector2.ZERO

## pattern の shot_index 発目の弾を、origin から出す。EnemyShooter・分裂弾・撃ち返し弾(RevengeShooter)が使う。
## 弾の並べ方(角度・列弾・ばらつき)は、プレビューと同じ ShotMath で計算する。
## fallback_scene: pattern に弾シーンがないときの弾 / turn: 全ての弾の向きを、この角度(ラジアン)だけ回す(分裂弾用)
## split_depth: 何回割れてできた弾か(分裂弾の段階の上限に使う)
static func spawn_bullets(pattern : ShotPattern, shot_index : int, aim_angle : float, origin : Vector2,
		parent : Node, fallback_scene : PackedScene, mirror : bool = false, turn : float = 0.0, split_depth : int = 0,
		split_heading : float = NAN, arrive_at : Vector2 = Vector2.INF) -> void:
	var scene := pattern.bullet_scene if pattern.bullet_scene else fallback_scene
	if scene == null:
		push_warning("EnemyShooter: 弾シーンが未設定です")
		return
	if parent == null:
		return
	# すだれなど(From Screen Top): 砲口の真上の、画面の上の外から出す(横の並びはそのまま)
	var top_y := NAN
	if pattern.from_screen_top and parent is CanvasItem:
		top_y = CameraView.visible_rect(parent as CanvasItem).position.y - 16.0
	# 集合弾(Cluster Layers): 1発の代わりに、ひし形に並んだ塊を出す(塊の中の位置のずれ)
	var cluster : Array[Vector2] = [Vector2.ZERO]
	if pattern.cluster_layers > 0:
		cluster.clear()
		var layers := pattern.cluster_layers
		for i in range(-layers, layers + 1):
			for j in range(-layers, layers + 1):
				if absi(i) + absi(j) <= layers:
					cluster.append(Vector2(i, j) * pattern.cluster_spacing)
	# 立体弾幕(Ring3d Count): 1発の代わりに、回る輪に並んだ弾を出す(輪の中の位置は、弾が自分で動かす)
	var ring := maxi(pattern.ring3d_count, 0)
	if ring > 0:
		cluster.clear()
		for k in ring:
			cluster.append(Vector2.ZERO)
	for shot in ShotMath.bullets(pattern, shot_index, aim_angle, mirror):
		for member_index in cluster.size():
			var member : Vector2 = cluster[member_index]
			var bullet : Node2D = scene.instantiate()
			if pattern.bullet_scale != 1.0 and split_depth == 0:
				bullet.scale *= pattern.bullet_scale # 巨大弾(当たり判定も一緒に大きくなる)
			parent.add_child(bullet)
			bullet.z_index = 5
			var offset : Vector2 = shot["offset"]
			var in_group : Vector2 = member.rotated(shot["angle"] + turn + PI * 0.25) # ひし形の角を、飛ぶ向きに合わせる
			bullet.global_position = origin + offset.rotated(turn) + in_group
			if "group_offset" in bullet:
				bullet.group_offset = in_group
			if not is_nan(top_y):
				bullet.global_position.y = top_y
			if bullet.has_method("setup"):
				var speed : float = pattern.bullet_speed * shot["speed_scale"] * shot.get("launch_scale", 1.0)
				var accel : float = pattern.bullet_accel * shot["speed_scale"]
				if pattern.arrive_time > 0.0 and arrive_at.is_finite():
					# 1点へ集める弾: arrive_time 秒でちょうど着いて止まる速さと減速にする
					var d := bullet.global_position.distance_to(arrive_at)
					speed = 2.0 * d / pattern.arrive_time
					accel = -speed / pattern.arrive_time
				bullet.setup(Vector2.from_angle(shot["angle"] + turn), speed, pattern.damage, accel)
			# 片側だけ曲がりを反転する弾(Mirror Curve By Side)は、その弾だけ左右反転として扱う
			var bullet_mirror : bool = mirror != shot.get("flip", false)
			if pattern.counter_hp_ratio > 0.0 and "counter_hp_ratio" in bullet:
				bullet.counter_hp_ratio = pattern.counter_hp_ratio # カウンター弾(返すと、ボスを大きく削れる)
			if bullet.has_method("set_motion"):
				bullet.set_motion(pattern.motion, shot["speed_scale"], bullet_mirror)
			if bullet.has_method("set_split"):
				bullet.set_split(pattern, bullet_mirror, split_depth)
				if not is_nan(split_heading) and "split_heading" in bullet:
					bullet.split_heading = split_heading
			if pattern.window_width_deg > 0.0 and bullet.has_method("set_window"):
				bullet.set_window(pattern, origin)
			if ring > 0 and bullet.has_method("set_ring3d"):
				bullet.set_ring3d(pattern, member_index, shot["angle"] + turn, bullet_mirror)

## この砲口のボス(Enemy)。いなければ null
func _owner_enemy() -> Enemy:
	var node := get_parent()
	while node:
		if node is Enemy:
			return node
		node = node.get_parent()
	return null

## ゆずる・やさしくするを共有する相手(持ち主の敵。敵の中にない砲口なら、親のノード)
func _soften_owner() -> Node:
	var enemy := _owner_enemy()
	return enemy if enemy else get_parent()

## ほかの砲台をやさしくする倍率を、ボスに覚えさせる(1 で元に戻す)
func _set_soften(factor : float) -> void:
	var enemy := _soften_owner()
	if enemy == null:
		return
	if factor > 1.0:
		enemy.set_meta(&"soften_others", factor)
	elif enemy.has_meta(&"soften_others"):
		enemy.remove_meta(&"soften_others")

## 今、同じボスのほかの砲口が求めている、やさしくする倍率(なければ 1)
func _soften_factor() -> float:
	var enemy := _soften_owner()
	return float(enemy.get_meta(&"soften_others", 1.0)) if enemy else 1.0

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

## Start Delay Per Unit のぶん、撃ち始めを遅らせる秒数(同じイベントで出た何体目か × この値)
func _unit_delay(pattern : ShotPattern) -> float:
	if pattern.start_delay_per_unit == 0.0:
		return 0.0
	var node := get_parent()
	while node:
		if node is Enemy:
			return pattern.start_delay_per_unit * float(node.unit_index)
		node = node.get_parent()
	return 0.0

## 複合の弾幕: 本体(順番に撃つ弾幕)が撃ち終わるまで、一緒に撃つ弾幕を1回分ずつ繰り返す
func _run_companion(companion : ShotPattern, generation : int, together : Dictionary) -> void:
	while together["on"] and generation == _generation and is_inside_tree():
		await _run_once(companion, generation)
		if is_inside_tree():
			await get_tree().process_frame
