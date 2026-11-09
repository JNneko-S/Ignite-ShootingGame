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
## BackgroundScroller は scroll_multiplier を読んで、同じ倍率で進む。

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

## エディタの「ここから試遊」が書き出す、開始時刻のファイル(読んだら消す)
const PLAYTEST_FILE : String = "user://stage_playtest.cfg"
## 書き出してから、この秒数を過ぎた指定は使わない
const PLAYTEST_EXPIRE : float = 60.0

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
## 全滅ボーナスを数えている隊列(SpawnEvent → {total, gone, killed, last})
var _formations : Dictionary = {}

func _ready() -> void:
	add_to_group("stage_runner")
	_collect_parallax()
	_load_playtest()
	if autostart:
		start()

func start() -> void:
	if stage == null:
		push_warning("StageRunner: Stage(StageData)が設定されていません")
		return
	_build_entries()
	_formations.clear()
	_next = 0
	_finished = false
	_waiting = false
	stage_time = -start_delay
	if debug_start_time > 0.0:
		stage_time = debug_start_time
		var last_scroll : ScrollSpeedEvent = null
		while _next < _entries.size() and _entries[_next]["time"] < stage_time:
			if _entries[_next]["event"] is ScrollSpeedEvent:
				last_scroll = _entries[_next]["event"]
			_next += 1
		# 飛ばしたスクロール変更のうち、最後のものだけを即座に反映する
		if last_scroll:
			set_scroll_speed(last_scroll.speed_multiplier, 0.0)
	_running = true
	stage_started.emit()
	if debug_log:
		print("[Stage] 開始 %s イベント%d件" % [stage.stage_name, _entries.size()])

## エディタから「ここから試遊」で起動されたときだけ、debug_start_time を上書きする
func _load_playtest() -> void:
	if not OS.has_feature("editor") or not FileAccess.file_exists(PLAYTEST_FILE):
		return
	var config := ConfigFile.new()
	var error := config.load(PLAYTEST_FILE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PLAYTEST_FILE)) # 次の通常起動に影響させない
	if error != OK:
		return
	var written_at : float = config.get_value("playtest", "written_at", 0.0)
	if Time.get_unix_time_from_system() - written_at > PLAYTEST_EXPIRE:
		return # 古い指定(試遊ボタンを押したあと、別の方法で起動した)
	var stage_path : String = config.get_value("playtest", "stage_path", "")
	if stage and stage_path != "" and stage_path != stage.resource_path:
		return # 別のステージ用の指定
	debug_start_time = config.get_value("playtest", "start_time", 0.0)
	print("[Stage] 試遊: %.1f 秒から開始" % debug_start_time)

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
	if event.is_boss:
		var death := DeathExplosion.of(enemy)
		if death:
			death.big = true # 連鎖爆発 → 大爆発してから消える
	if event.boss_time_bonus:
		enemy.boss_reach_time = stage_time # スタートからボス到達までの時間(待機イベントの時間は含まない)
	# 段階の切り替え: ボスのシーンに BossPhaseController があれば、そちらを使う(SpawnEvent の Phases は使わない)
	var has_controller := enemy.get_children().any(func(n : Node) -> bool: return n is BossPhaseController)
	if not event.phases.is_empty() and not has_controller:
		var controller := BossPhaseController.new()
		controller.name = "BossPhaseController"
		controller.setup(enemy.get_node("HPComponent"), event.phases)
		controller.apply_first(enemy)
		enemy.add_child(controller)

	var parent : Node = enemy_parent if enemy_parent else get_tree().current_scene
	if GroundUnit.is_ground(enemy):
		# 地上の敵は、地面と屋根のあいだの層に出す(建物の下をくぐる)
		var layer := get_tree().get_first_node_in_group("ground_layer")
		if layer:
			parent = layer
	parent.add_child(enemy)
	_track_formation(event, enemy)
	if event.is_boss:
		boss_spawned.emit(enemy, event.boss_name, event.boss_phase_thresholds)
	if debug_log:
		print("[Stage] t=%.1f 出現 %s #%d" % [stage_time, enemy.name, unit_index])

## 全滅ボーナス: 隊列の全員がいなくなったときに、全員倒されていればボーナス
func _track_formation(event : SpawnEvent, enemy : Enemy) -> void:
	if event.formation_bonus <= 0 or event.unit_count() < 2:
		return
	if not _formations.has(event):
		_formations[event] = {"total": event.unit_count(), "gone": 0, "killed": 0, "last": Vector2.ZERO}
	var record : Dictionary = _formations[event]
	enemy.died.connect(func(dead : Enemy) -> void:
		record["killed"] += 1
		record["last"] = dead.global_position)
	enemy.tree_exited.connect(func() -> void:
		record["gone"] += 1
		if record["gone"] >= record["total"]:
			_formations.erase(event)
			if record["killed"] >= record["total"]:
				_award_formation_bonus(event.formation_bonus, record["last"]))

func _award_formation_bonus(points : int, at : Vector2) -> void:
	var score_system := get_tree().get_first_node_in_group("score_system") as ScoreSystem
	if score_system:
		score_system.add_points(points, at)
	FloatingText.spawn(get_tree(), at, "全滅 +%d" % points)
	if debug_log:
		print("[Stage] t=%.1f 全滅ボーナス %d" % [stage_time, points])

## 背景のオブジェクトを、画面の上の端のすぐ外に出す(PropEvent)
func spawn_prop(event : PropEvent) -> void:
	if event.scene == null:
		return
	var root := get_tree().current_scene
	var parent : Node2D = root.get_node_or_null(event.parent_path) as Node2D if root else null
	if parent == null:
		push_warning("StageRunner: PropEvent の親 %s が見つかりません (t=%.1f)" % [event.parent_path, event.time])
		parent = root as Node2D
		if parent == null:
			return
	var top := CameraView.visible_rect(parent).position.y
	var top_local := parent.to_local(Vector2(0.0, top)).y
	for i in maxi(event.count, 1):
		var prop := event.scene.instantiate() as Node2D
		parent.add_child(prop)
		# 1両の高さの半分くらい、画面の外から出す
		prop.position = Vector2(event.local_x, top_local - event.spacing * 0.6 - event.spacing * i)
	if debug_log:
		print("[Stage] t=%.1f 背景オブジェクト x%d" % [stage_time, event.count])

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
	_parallax.clear()
	for layer in parallax_layers:
		if layer: # 消したノードの空欄は飛ばす
			_parallax.append(layer)
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
	# BackgroundScroller は scroll_multiplier を毎フレーム読むので、Parallax2D がなくても倍率は変える
	if _parallax.is_empty() and get_tree().get_nodes_in_group("background_scroller").is_empty():
		push_warning("StageRunner: スクロールする Parallax2D / BackgroundScroller が見つかりません")
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
