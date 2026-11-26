extends Node
const _PracticeRun := preload("res://Component/Practice/practice_run.gd")
## 実績(自動読み込み: Achievements)。user://achievements.cfg に保存する。
## 解除すると、画面の右上に小さく知らせる。デバッグ機能を使ったプレイ(DebugTools.used)では解除しない。
##
## 実績を足すときは、LIST に [id, 名前, 説明, 隠す(解除するまで説明を伏せる)] を足して、
## 条件を満たしたところで Achievements.unlock("id") を呼ぶ。

const PATH : String = "user://achievements.cfg"

## [id, 名前, 説明, 隠す]
const LIST : Array = [
	["first_ignite", "点火", "イグナイトを初めて発動する", false],
	["full_ignite", "全開放", "Lv5 のイグナイトを長押しで全て解き放つ", false],
	["stage1", "初陣", "ステージ1 をクリアする", false],
	["stage2", "線路の果て", "ステージ2 をクリアする", false],
	["stage3", "黒鳥を越えて", "ステージ3 をクリアする", false],
	["stage4", "中枢突破", "ラストステージをクリアする", false],
	["no_miss", "無傷の帰還", "一度もミスせずにステージをクリアする", false],
	["graze_1000", "紙一重", "1つのステージで 1000 回グレイズする", false],
	["score_10m", "一千万", "スコア 10,000,000 点に到達する", false],
	["score_30m", "三千万", "スコア 30,000,000 点に到達する", false],
	["hard_clear", "地獄帰り", "HARD でラストステージをクリアする", false],
	["rookie", "ルーキーはもう居ない！", "EASY をノーコンティニューでクリアする", false],
	["secret_mission", "極秘任務完了", "NORMAL をノーコンティニューでクリアする", false],
	["excite", "エキサイト", "HARD をノーコンティニューでクリアする", false],
	["another_clear", "アナザースペシャル", "ANOTHER をクリアする", true],
	["another_dimension", "アナザーディメンション", "ANOTHER をノーコンティニューでクリアする", true],
	["limit_break", "リミットブレイク", "ANOTHER で条件を満たして、BLACK ANOTHER に突入する", true],
	["ignite_only_vespa", "イグナイトオンリーヴェスパ", "VESPA で、ショットを敵に当てずにクリアする(イグナイトだけで戦う)", false],
	["ignite_only_bastion", "イグナイトオンリーバスティオン", "BASTION で、ショットを敵に当てずにクリアする(イグナイトだけで戦う)", false],
	["ignite_only_phoenix", "イグナイトオンリーフェニックス", "PHOENIX で、ショットを敵に当てずにクリアする(イグナイトだけで戦う)", false],
	["boss_only", "今日はボスだけでいいよ", "雑魚を1体も倒さずに、ステージのボスを倒してクリアする", false],
	["hidden_gunner", "伏兵、見つかる", "タンクの副砲を破壊する", false],
	["one_more", "ワンモアチャレンジ", "ボス戦で撃墜される", false],
	["hidden_boss_met", "目覚める災厄", "隠しボスに出会う", true],
	["hidden_boss_down", "子の親殺し", "隠しボスを倒す", true],
	["normal_round", "NORMAL ROUND CLEAR", "一周目をクリアする", false],
	["another_round", "ANOTHER ROUND CLEAR", "二周目をクリアする", true],
	["congratulation", "congratulation!", "隠しボスを倒して、二周目をクリアする", true],
	["b_end", "もうひとつの結末", "Bエンドを見る", true],
	["perfect_ignite", "パーフェクトイグナイト", "一回のイグナイトで、敵を 10 体以上倒す", false],
	["max_phoenix", "MAX・ザ・フェニックス", "Lv MAX になってから、一度も被弾せずに 5 分以上生き残る", false],
	["phoenix_revival", "不死鳥、起死回生。", "一度のゲームで、Lv0 から Lv MAX まで戻した回数が 10 回以上になる", false],
	["daioujou", "大往生", "二周目をノーダメージで進み、隠しボスを撃破する", true],
	["title_wait_10", "ここで何を待っているの？", "タイトル画面で 10 分間、何も操作しない", true],
	["title_wait_30", "だから何を待っているの？", "タイトル画面で 30 分間、何も操作しない", true],
]

signal unlocked(id : String)

var _unlocked : Dictionary = {}
var _toast_layer : CanvasLayer
var _toast_queue : Array = []
var _toasting : bool = false
var _check_left : float = 0.0
## 難易度 ANOTHER を解禁したか・RATE A 以上を取った回数(achievements.cfg の [progress] に保存)
var another_unlocked : bool = false
var rate_a_count : int = 0
## 裏ボス Union のプラクティスの解禁に使う記録(achievements.cfg の [progress])
##   RATE S を取った回数 / ANOTHER を二周目までクリアしたか / NORMAL 以上でクリアした機体の名前
var rate_s_count : int = 0
var another_loop2_cleared : bool = false
var ships_cleared : Array = []
## 二周目をクリアした難易度(0〜2)。プラクティスの「2nd ○○」を出すのに使う
var loop2_cleared : Array = []
## ANOTHER の解禁に要る、RATE A の回数と、実績の数
const ANOTHER_RATE_A_NEEDED : int = 5
const ANOTHER_ACHIEVEMENTS_NEEDED : int = 8

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var config := ConfigFile.new()
	if config.load(PATH) == OK:
		for id in config.get_section_keys("unlocked") if config.has_section("unlocked") else []:
			_unlocked[id] = config.get_value("unlocked", id)
		another_unlocked = config.get_value("progress", "another_unlocked", false)
		rate_a_count = config.get_value("progress", "rate_a_count", 0)
		rate_s_count = config.get_value("progress", "rate_s_count", 0)
		another_loop2_cleared = config.get_value("progress", "another_loop2_cleared", false)
		ships_cleared = config.get_value("progress", "ships_cleared", [])
		loop2_cleared = config.get_value("progress", "loop2_cleared", [])

func is_unlocked(id : String) -> bool:
	return _unlocked.has(id)

## 解除した日時(なければ空)
func unlocked_date(id : String) -> String:
	return str(_unlocked.get(id, ""))

func unlocked_count() -> int:
	return _unlocked.size()

## 実績を解除する(もう解除していたら、何もしない)
func unlock(id : String) -> void:
	if _unlocked.has(id) or DebugTools.used or _PracticeRun.active: # プラクティス中は、実績を解除しない
		return
	var entry := _entry(id)
	if entry.is_empty():
		push_warning("Achievements: 知らない実績 %s" % id)
		return
	_unlocked[id] = Time.get_datetime_string_from_system(false, true)
	_save()
	unlocked.emit(id)
	_toast_queue.append(["実績解除", entry[1]])
	_check_another()
	if not _toasting:
		_show_toasts()

func _save() -> void:
	var config := ConfigFile.new()
	for key in _unlocked:
		config.set_value("unlocked", key, _unlocked[key])
	config.set_value("progress", "another_unlocked", another_unlocked)
	config.set_value("progress", "rate_a_count", rate_a_count)
	config.set_value("progress", "rate_s_count", rate_s_count)
	config.set_value("progress", "another_loop2_cleared", another_loop2_cleared)
	config.set_value("progress", "ships_cleared", ships_cleared)
	config.set_value("progress", "loop2_cleared", loop2_cleared)
	config.save(PATH)

# ---------------------------------------------------------------- 難易度 ANOTHER の解禁
## 次のどれかで解禁する:
##   ・NORMAL の二周目を、ノーコンティニューで RATE A 以上でクリア
##   ・HARD の一周目を、ノーコンティニューでクリア(最終面をクリアした時点で解禁)
##   ・RATE A 以上を合わせて 5 回取り、実績を 8 個解除している
## 解禁したら、機体選択の画面で HARD のときに右を何回も押すと、ANOTHER が出る。デバッグ機能が使えるときは、いつでも出る
func can_choose_another() -> bool:
	return another_unlocked or DebugTools.unlocked

## スコアボードに記録したとき(ScoreBoard が呼ぶ)
func on_run_recorded(entry : Dictionary) -> void:
	if DebugTools.used:
		return
	var grade := ScoreBoard.grade(entry)
	var rate_a := grade == "S" or grade == "A"
	if rate_a:
		rate_a_count += 1
	if grade == "S":
		rate_s_count += 1
	var all_clear := ScoreBoard.result_of(entry) == ScoreBoard.ALL_CLEAR
	var no_continue := RunConfig.continues_used == 0
	var difficulty := int(entry.get("difficulty", 1))
	if all_clear and no_continue and difficulty == 1 and rate_a:
		_unlock_another()
	_check_another()
	_save()

func _check_another() -> void:
	if rate_a_count >= ANOTHER_RATE_A_NEEDED and _unlocked.size() >= ANOTHER_ACHIEVEMENTS_NEEDED:
		_unlock_another()

func _unlock_another() -> void:
	if another_unlocked or DebugTools.used:
		return # デバッグ機能を使ったプレイでは、解禁しない(セーブを汚さない)
	another_unlocked = true
	_save()
	_toast_queue.append(["解禁", "難易度 ANOTHER"])
	if not _toasting:
		_show_toasts()

func _entry(id : String) -> Array:
	for entry in LIST:
		if entry[0] == id:
			return entry
	return []

# ---------------------------------------------------------------- 条件(ほかの部品から呼ぶ)

## ステージをクリアした(ScoreSystem が呼ぶ)
func on_stage_cleared(tree : SceneTree) -> void:
	var file := tree.current_scene.scene_file_path.get_file() if tree.current_scene else ""
	for n in 4:
		if file == "stage%d.tscn" % (n + 1):
			unlock("stage%d" % (n + 1))
	var gm := tree.current_scene as GameManager
	if gm and gm.death_count == 0:
		unlock("no_miss")
	if file == "stage4.tscn" and RunConfig.has_selection:
		if RunConfig.difficulty == RunConfig.ANOTHER:
			unlock("another_clear")
		elif RunConfig.difficulty == 2:
			unlock("hard_clear")
		_on_game_clear()
	# 雑魚を1体も倒さずに、ステージのボスを倒した
	var score_system := tree.get_first_node_in_group(&"score_system") as ScoreSystem
	if score_system and score_system.zako_kill_count == 0:
		unlock("boss_only")

## ラストステージをクリアした: ノーコンティニューの難易度別・ANOTHER・イグナイトだけ
func _on_game_clear() -> void:
	var no_continue := RunConfig.continues_used == 0
	if no_continue:
		match RunConfig.difficulty:
			0: unlock("rookie")
			1: unlock("secret_mission")
			2:
				unlock("excite")
				if RunConfig.loop == 1:
					_unlock_another() # HARD の一周目をノーコンティニューでクリア: ANOTHER を解禁
			RunConfig.ANOTHER: unlock("another_dimension")
	if not RunConfig.shot_damage_used and RunConfig.ship:
		unlock("ignite_only_" + RunConfig.ship.ship_name.to_lower())
	# Union のプラクティスの解禁: NORMAL 以上でクリアした機体を覚える
	if RunConfig.ship and RunConfig.difficulty >= 1 and not DebugTools.used and not _PracticeRun.active:
		var ship_name := RunConfig.ship.ship_name
		if not ship_name in ships_cleared:
			ships_cleared.append(ship_name)
			_save()

## 自機が撃墜された(GameManager が呼ぶ): ボス・中ボスがいる(ボス戦の)ときなら
func on_player_died(tree : SceneTree) -> void:
	for node in tree.get_nodes_in_group(&"enemy"):
		if node is Enemy and (node.is_midboss or node.boss_reach_time >= 0.0) and node.hp_component and node.hp_component.hp > 0:
			unlock("one_more")
			return

## 隠しボス(HiddenBoss)が出てきた・倒された
func on_hidden_boss_appeared() -> void:
	unlock("hidden_boss_met")

func on_hidden_boss_defeated() -> void:
	RunConfig.hidden_boss_defeated = true
	unlock("hidden_boss_down")
	if RunConfig.loop >= 2 and RunConfig.loop_hits == 0:
		unlock("daioujou") # 二周目を一度も被弾せずに進み、隠しボスを倒した

# ---------------------------------------------------------------- イグナイトとレベルの実績

## 今のイグナイト(いちばん最近の発動)で倒した敵の数
var _ignite_kills : int = 0
## Lv MAX になってから、被弾せずに生き残っている時間(秒)。マイナスなら数えていない(Lv MAX になったら数え始め、被弾で止まる)
var _max_survive : float = -1.0
## Lv0 まで落ちたことがあるか(このあと Lv MAX まで戻したら、起死回生を1回と数える)と、その回数
var _was_zero : bool = false
var _revivals : int = 0

## 出撃し直したとき(RunState.begin_run が呼ぶ): 一回のゲームの記録を戻す
func reset_run() -> void:
	_ignite_kills = 0
	_max_survive = -1.0
	_was_zero = false
	_revivals = 0

## イグナイトを発動した(GameManager が呼ぶ)
func on_ignite_started() -> void:
	_ignite_kills = 0

## 敵を倒した(ScoreSystem が呼ぶ)。イグナイトで倒したなら数える(発動中、またはとどめが返した弾)
func on_enemy_killed(enemy : Enemy, gm : GameManager) -> void:
	if gm == null or not gm._killed_by_ignite(enemy):
		return
	_ignite_kills += 1
	if _ignite_kills >= 10:
		unlock("perfect_ignite")

## イグナイトのレベルが変わった(GameManager が呼ぶ)
func on_ignite_level(level : int) -> void:
	if level <= 0:
		_was_zero = true
	if level >= IgniteGauge.MAX_LEVEL:
		if _max_survive < 0.0:
			_max_survive = 0.0
		if _was_zero:
			_was_zero = false
			_revivals += 1
			if _revivals >= 10:
				unlock("phoenix_revival")

## 被弾した(GameManager が呼ぶ): Lv MAX からの生き残りの時間は、数え直し(また Lv MAX になってから)
func on_player_hit() -> void:
	_max_survive = -1.0

## Lv MAX からの生き残りの時間を進める(ステージで、ポーズしていないあいだ)
func _tick_max_survive(delta : float) -> void:
	if _max_survive < 0.0 or get_tree().paused or not (get_tree().current_scene is GameManager):
		return
	_max_survive += delta
	if _max_survive >= 300.0:
		unlock("max_phoenix")

## 周をクリアした(EndingSequence が呼ぶ)
func on_round_clear() -> void:
	var another_run := RunConfig.has_selection and RunConfig.difficulty == RunConfig.ANOTHER
	if RunConfig.loop >= 2 and another_run and not DebugTools.used and not another_loop2_cleared:
		another_loop2_cleared = true # Union のプラクティスの解禁: ANOTHER を二周目までクリアした
		_save()
	if RunConfig.loop >= 2 and RunConfig.has_selection and not another_run and not DebugTools.used and not RunConfig.difficulty in loop2_cleared:
		loop2_cleared.append(RunConfig.difficulty) # プラクティスの「2nd ○○」を出す
		_save()
	if RunConfig.loop >= 2:
		unlock("another_round")
		if RunConfig.hidden_boss_defeated:
			unlock("congratulation")
	else:
		unlock("normal_round")

## スコア・グレイズ・イグナイトは、ステージのあいだ、ときどき見て調べる
func _process(delta : float) -> void:
	_tick_max_survive(delta)
	_check_left -= delta
	if _check_left > 0.0:
		return
	_check_left = 0.5
	var tree := get_tree()
	var score_system := tree.get_first_node_in_group(&"score_system") as ScoreSystem
	if score_system:
		if score_system.score >= 10000000:
			unlock("score_10m")
		if score_system.score >= 30000000:
			unlock("score_30m")
	var player := tree.get_first_node_in_group(&"player") as Player
	if player and player.graze_count >= 1000:
		unlock("graze_1000")
	var gm := tree.current_scene as GameManager
	if gm:
		if gm.ignite_activation_count > 0:
			unlock("first_ignite")
		if gm.full_use_count > 0:
			unlock("full_ignite")

# ---------------------------------------------------------------- 知らせ

## 画面の右上に、墨の帯に朱の線で「実績解除」と名前を出す。いくつかあれば順番に
func _show_toasts() -> void:
	_toasting = true
	if _toast_layer == null:
		_toast_layer = CanvasLayer.new()
		_toast_layer.layer = 120
		add_child(_toast_layer)
	while not _toast_queue.is_empty():
		var item : Array = _toast_queue.pop_front()
		var name : String = item[1]
		var view := get_viewport().get_visible_rect().size
		var panel := ColorRect.new()
		panel.color = Color(0.08, 0.05, 0.05, 0.85)
		panel.size = Vector2(170.0, 34.0)
		panel.position = Vector2(view.x + 4.0, 52.0)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_toast_layer.add_child(panel)
		var line := ColorRect.new()
		line.color = Color(0.85, 0.16, 0.07)
		line.size = Vector2(3.0, 34.0)
		panel.add_child(line)
		var head := Label.new()
		head.text = item[0]
		head.position = Vector2(10.0, 1.0)
		head.add_theme_font_size_override("font_size", 9)
		head.add_theme_color_override("font_color", Color(1.0, 0.45, 0.25))
		panel.add_child(head)
		var body := Label.new()
		body.text = name
		body.position = Vector2(10.0, 13.0)
		body.add_theme_font_size_override("font_size", 13)
		body.add_theme_color_override("font_color", Color(1.0, 0.97, 0.92))
		panel.add_child(body)
		var tween := create_tween()
		tween.tween_property(panel, "position:x", view.x - 176.0, 0.3).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tween.tween_interval(2.4)
		tween.tween_property(panel, "position:x", view.x + 4.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_callback(panel.queue_free)
		await tween.finished
	_toasting = false
