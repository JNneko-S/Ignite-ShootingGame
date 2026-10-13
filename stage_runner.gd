extends Node
class_name StageRunner
## ステージのタイムラインを実行する。ステージのシーンに子ノードとして置く。
##
## 使い方:
##   1. StageData(.tres)を作り、Events に SpawnEvent などを並べる
##   2. このノードの Stage に StageData を割り当てる
##   3. 実行すると、start_delay 秒後からタイムラインが進む
##
## 背景のスクロールは、シーン内の Parallax2D を自動で探して、autoscroll を倍率で変える。

signal stage_started
## タイムラインが最後まで終わり、画面から敵がいなくなったときに出る
signal stage_cleared
## StageSignalEvent から出る(WARNING表示や、BGM切り替えなど)
signal stage_signal(signal_name : String, text : String)
## is_boss の SpawnEvent で敵を出したときに出る(BossGauge が受け取る)
signal boss_spawned(enemy : Enemy, boss_name : String, phase_thresholds : Array[float])

@export var stage : StageData
@export var autostart : bool = true
## 開始してから、タイムラインが動き出すまでの待ち時間(秒)
@export var start_delay : float = 1.0
## 敵の生成先。未設定なら現在のシーン直下
@export var enemy_parent : Node
## true なら、最後のイベントのあと、敵が全滅した時点で stage_cleared を出す
@export var auto_finish : bool = true
## スクロールさせる Parallax2D。空なら、シーン内から自動で探す
@export var parallax_layers : Array[Parallax2D] = []

@export_group("テスト用")
## 0 より大きければ、ステージのこの秒数の位置から始める(途中だけ確認したいとき)
@export var debug_start_time : float = 0.0
@export var debug_log : bool = false

## ステージの経過時間(秒)。待機中は進まない。開始前は start_delay 分だけマイナス
var stage_time : float = 0.0
var scroll_multiplier : float = 1.0

var _entries : Array[Dictionary] = []
var _next : int = 0
var _running : bool = false
var _finished : bool = false
var _waiting : bool = false
var _wait_group : String = ""
var _wait_timeout : float = 0.0
var _wait_elapsed : float = 0.0
var _parallax : Array[Parallax2D] = []
var _base_autoscroll : Array[Vector2] = []
var _scroll_tween : Tween

func _ready() -> void:
	add_to_group("stage_runner")
	_collect_parallax()
	if autostart:
		start()

func start() -> void:
	if stage == null:
		push_warning("StageRunner: Stage(StageData)が設定されていません")
		return
	_build_entries()
	_next = 0
	_finished = false
	_waiting = false
	stage_time = -start_delay
	if debug_start_time > 0.0:
		stage_time = debug_start_time
		while _next < _entries.size() and _entries[_next]["time"] < stage_time:
			_next += 1
	_running = true
	stage_started.emit()
	if debug_log:
		print("[Stage] 開始 %s イベント%d件" % [stage.stage_name, _entries.size()])

## イベントを1回ごとの実行(SpawnEvent なら1体ごと)に展開して、時間順に並べる
func _build_entries() -> void:
	_entries.clear()
	var order := 0
	for event in stage.events:
		if event == null:
			continue
		for i in event.unit_count():
			_entries.append({"time": event.unit_time(i), "order": order, "event": event, "unit": i})
			order += 1
	_entries.sort_custom(func(a : Dictionary, b : Dictionary) -> bool:
		if is_equal_approx(a["time"], b["time"]):
			return a["order"] < b["order"]
		return a["time"] < b["time"])

func _physics_process(delta : float) -> void:
	if not _running or _finished:
		return
	if _waiting:
		_update_wait(delta)
		return

	stage_time += delta
	while _next < _entries.size() and _entries[_next]["time"] <= stage_time:
		var entry := _entries[_next]
		_next += 1
		entry["event"].execute(self, entry["unit"])
		if _waiting:
			return # 待機イベントが実行された。続きは待機が終わってから

	if _next >= _entries.size() and auto_finish and _enemies_alive() == 0:
		_finished = true
		if debug_log:
			print("[Stage] クリア t=%.1f" % stage_time)
		stage_cleared.emit()

func _enemies_alive() -> int:
	return get_tree().get_nodes_in_group("enemy").size()

# ---------------------------------------------------------------- 敵の出現

func spawn(event : SpawnEvent, unit_index : int) -> void:
	if event.enemy_scene == null:
		push_warning("StageRunner: SpawnEvent に enemy_scene がありません (t=%.1f)" % event.time)
		return
	var enemy := event.enemy_scene.instantiate() as Enemy
	if enemy == null:
		push_error("StageRunner: enemy_scene のルートが Enemy(enemy.gd)ではありません")
		return

	if event.move_pattern:
		enemy.pattern = event.move_pattern
	enemy.mirror_x = event.mirror_x != (event.alternate_mirror and unit_index % 2 == 1)
	enemy.path_offset = event.offset + event.offset_step * unit_index

	if not event.shot_patterns.is_empty():
		for node in enemy.find_children("*", "", true, false):
			if node is EnemyShooter:
				node.patterns = event.shot_patterns
	if event.hp_override > 0:
		var hp := enemy.get_node_or_null("HPComponent")
		if hp:
			hp.max_hp = event.hp_override
			hp.hp = event.hp_override
	if event.tag != "":
		enemy.add_to_group(_tag_group(event.tag)) # 待機イベントが見つけるための印

	var parent : Node = enemy_parent if enemy_parent else get_tree().current_scene
	parent.add_child(enemy)
	if event.is_boss:
		boss_spawned.emit(enemy, event.boss_name, event.boss_phase_thresholds)
	if debug_log:
		print("[Stage] t=%.1f 出現 %s #%d" % [stage_time, enemy.name, unit_index])

func _tag_group(tag : String) -> String:
	return "stage_" + tag

# ---------------------------------------------------------------- 待機(中ボス・ボス)

func begin_wait(tag : String, timeout : float) -> void:
	_wait_group = _tag_group(tag) if tag != "" else "enemy"
	_wait_timeout = timeout
	_wait_elapsed = 0.0
	_waiting = true
	if debug_log:
		print("[Stage] 待機 group=%s timeout=%.1f" % [_wait_group, timeout])

func _update_wait(delta : float) -> void:
	_wait_elapsed += delta
	var cleared := get_tree().get_nodes_in_group(_wait_group).is_empty()
	var timed_out := _wait_timeout > 0.0 and _wait_elapsed >= _wait_timeout
	if cleared or timed_out:
		_waiting = false
		if debug_log:
			print("[Stage] 待機終了 (%s)" % ("全滅" if cleared else "タイムアウト"))

# ---------------------------------------------------------------- スクロール・演出

func _collect_parallax() -> void:
	_parallax = parallax_layers.duplicate()
	if _parallax.is_empty():
		var root := get_tree().current_scene if get_tree().current_scene else owner
		if root:
			for node in root.find_children("*", "Parallax2D", true, false):
				_parallax.append(node as Parallax2D)
	_base_autoscroll.clear()
	for layer in _parallax:
		_base_autoscroll.append(layer.autoscroll)

## スクロール速度を、元の速度の multiplier 倍にする(duration 秒かけて変える)
func set_scroll_speed(multiplier : float, duration : float) -> void:
	if _parallax.is_empty():
		push_warning("StageRunner: スクロールする Parallax2D が見つかりません")
		return
	if _scroll_tween:
		_scroll_tween.kill()
	if duration <= 0.0:
		_apply_scroll(multiplier)
		return
	_scroll_tween = create_tween()
	_scroll_tween.tween_method(_apply_scroll, scroll_multiplier, multiplier, duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _apply_scroll(multiplier : float) -> void:
	scroll_multiplier = multiplier
	for i in _parallax.size():
		_parallax[i].autoscroll = _base_autoscroll[i] * multiplier

func emit_stage_signal(signal_name : String, text : String) -> void:
	if debug_log:
		print("[Stage] シグナル %s %s" % [signal_name, text])
	stage_signal.emit(signal_name, text)
