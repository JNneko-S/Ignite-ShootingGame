extends Node
## プラクティスのミッションを、ステージの中で進める(GameManager が、プラクティス中だけ置く)。
##   道中        … 区間の終わり(End Time)まで生き残れば成功
##   ボスの攻撃  … ボスは削れず、主な砲口は選んだ攻撃だけを撃つ。撃ち始めてから SURVIVE_TIME 秒、生き残れば成功
##   カウンター大技 … すぐ大技を始め、大技が終わるまで生き残れば成功
##   Union       … ステージの最後に、裏ボス Union を呼び出して、同じように戦う
## 残機が尽きたら失敗。成功・失敗のあと、結果を見せて、プラクティスの一覧に戻る

const _Run := preload("res://Component/Practice/practice_run.gd")
const _Records := preload("res://Component/Practice/practice_records.gd")
const _Catalog := preload("res://Component/Practice/practice_catalog.gd")
const _ENTRANCE_BLAST := preload("res://Component/Boss/entrance_blast.gd")

## ボスの攻撃を、何秒生き残れば成功か
const SURVIVE_TIME := 20.0

var _mission : Dictionary
var _gm : GameManager
var _runner : StageRunner
var _done : bool = false
## 0 より大きいあいだ、成功までの残り時間を数える
var _survive_left : float = -1.0
## 数えはじめる準備ができた(攻撃を撃ちはじめた)。登場の演出が終わったら、数えはじめる
var _armed : bool = false
var _boss : Enemy
var _hud : Label

func _ready() -> void:
	_mission = _Run.mission
	_gm = get_parent() as GameManager
	_runner = _gm.get_node_or_null("StageRunner") as StageRunner if _gm else null
	if _gm == null or _runner == null:
		return
	_gm.game_over_handler = _on_failed
	_setup_player.call_deferred()
	_make_hud()
	var kind : String = _mission.get("kind", "")
	if kind != "zako":
		_runner.practice_event_filter = _allow_event # ボスのほかの敵は出さない
		_runner.boss_spawned.connect(_on_boss_spawned)
	if kind == "union":
		_spawn_union()

func _setup_player() -> void:
	var player := _gm.player
	if not is_instance_valid(player):
		return
	player.lives = _Run.lives
	player.lives_changed.emit(player.lives)
	if _Run.plus:
		player.ignite_locked = true

func _physics_process(delta : float) -> void:
	if _done:
		return
	if _Run.plus and is_instance_valid(_gm.player):
		_gm.player.ignite_locked = true # プラクティス+: イグナイトなし
	var kind : String = _mission.get("kind", "")
	if kind == "zako":
		var left : float = float(_mission["end_time"]) - _runner.stage_time
		_hud.text = "道中  あと %.1f 秒" % maxf(left, 0.0)
		if left <= 0.0:
			_succeed()
	elif _armed and _survive_left < 0.0:
		_hud.text = "登場中"
		if _entrance_over():
			_survive_left = SURVIVE_TIME # 登場の演出が終わってから数える
	elif _survive_left > 0.0:
		_survive_left -= delta
		_hud.text = "生き残れ  あと %.1f 秒" % maxf(_survive_left, 0.0)
		if _survive_left <= 0.0:
			_succeed()

# ---------------------------------------------------------------- ボス

## ボスのミッションで、タイムラインのイベントを実行するか: 練習するボスを出すイベントと、
## 背景・スクロール・カメラ・合図(WARNING や曲)だけを通す。ほかの敵・列車・倒した数を待つイベントは飛ばす
func _allow_event(event : StageEvent) -> bool:
	if str(_mission.get("kind", "")) == "union":
		return false # Union は、空の上で(タイムラインは使わない)
	if event is SpawnEvent:
		var spawn := event as SpawnEvent
		return spawn.enemy_scene != null and spawn.enemy_scene.resource_path == str(_mission.get("boss_scene", "")) 			and absf(spawn.time - float(_mission.get("boss_time", spawn.time))) < 0.05
	if event is TrainEvent or event is WaitKillsEvent:
		return false
	return true

func _on_boss_spawned(enemy : Enemy, _boss_name : String, _t : Array[float]) -> void:
	if _done or _boss != null or enemy.scene_file_path != str(_mission.get("boss_scene", "")):
		return
	_boss = enemy
	if _mission.has("spell") and _mission["spell"] != "":
		_start_spell.call_deferred()
		return
	var hp := enemy.get_node_or_null("HPComponent") as HPComponent
	if hp:
		hp.damage_lock = true # 形態が進まないように(ダメージは 1 だけ入る)
	for spell in _Catalog.spells_of(enemy):
		spell.queue_free() # 攻撃の練習では、カウンター大技は出さない
	_focus_attack.call_deferred()

## 主な砲口に、選んだ攻撃だけを撃たせて、選んだ形態にする
func _focus_attack() -> void:
	if not is_instance_valid(_boss):
		return
	var main := _Catalog.main_shooter(_boss)
	var phase := int(_mission.get("phase", 0))
	var pattern := load(str(_mission.get("pattern", ""))) as ShotPattern if str(_mission.get("pattern", "")) != "" else null
	if main and pattern and not bool(_mission.get("whole", false)):
		var only : Array[ShotPattern] = [pattern]
		if not main.phases.is_empty():
			var phases : Array[ShooterPhase] = []
			phases.assign(main.phases)
			var src : ShooterPhase = phases[clampi(phase, 0, phases.size() - 1)]
			var one := src.duplicate() as ShooterPhase if src else ShooterPhase.new()
			one.sequence = only
			one.loop2_sequence = only
			one.another_sequence = only
			one.easy_sequence = only
			phases[clampi(phase, 0, phases.size() - 1)] = one
			main.phases = phases
		else:
			main.sequence = only
			main.loop2_sequence = only
			main.another_sequence = only
		main.pattern_started.connect(_on_main_pattern)
	var controller : BossPhaseController = null
	for child in _boss.get_children():
		if child is BossPhaseController:
			controller = child
	if controller and phase > 0:
		controller._start_phase(phase)
	elif main:
		if main.has_phases():
			main.set_phase(phase)
		else:
			var lists := _Catalog.shooter_lists(main, 0, int(_mission["difficulty"]), int(_mission["loop"]))
			var pats : Array[ShotPattern] = []
			pats.assign(lists["patterns"])
			var seq : Array[ShotPattern] = []
			seq.assign(main.sequence if not bool(_mission.get("whole", false)) else lists["sequence"])
			main.set_patterns(pats, seq, false, int(_mission["loop"]) >= 2)
	if main == null or bool(_mission.get("whole", false)) or pattern == null:
		_armed = true # 攻撃を選べないときは、出てきてからの時間で数える

## ボスの登場の演出が終わったか: 撃つのを止める演出(ラスボスの目覚め・入場の爆発・列車の走り込み)と、
## 画面に入って光る演出が、どれも済んでいる
func _entrance_over() -> bool:
	if not is_instance_valid(_boss):
		return true
	if EnemyShooter.is_holding_fire() or TrainBossMover.holds_fire(_boss):
		return false
	for child in _boss.get_children():
		if child is BossEntranceFx and not child._done:
			return false
		if child.get_script() == _ENTRANCE_BLAST and child.holding:
			return false
	return true

func _on_main_pattern(_p : ShotPattern) -> void:
	if not _done:
		_armed = true

## カウンター大技を、すぐ始める(倒れる直前の大技も、終わってもボスが倒れないようにする)
func _start_spell() -> void:
	# 登場の演出が終わるまで待つ(大技の時間に、登場を入れない)
	var waited := 0.0
	while waited < 12.0 and is_instance_valid(_boss) and not _done and not _entrance_over():
		await get_tree().create_timer(0.1, false).timeout
		waited += 0.1
	_hud.text = ""
	await get_tree().create_timer(0.5, false).timeout
	if _done or not is_instance_valid(_boss):
		return
	for spell in _Catalog.spells_of(_boss):
		if String(spell.name) == str(_mission["spell"]):
			spell.lethal = false
			var hp := _boss.get_node_or_null("HPComponent") as HPComponent
			if hp:
				hp.hp_floor = 0
			spell.finished.connect(_succeed, CONNECT_ONE_SHOT)
			spell._start()
			_hud.text = "大技を生き残れ"
			return
		else:
			spell.queue_free()
	_armed = true

## 裏ボス Union を、ステージの上の真ん中に呼び出す
func _spawn_union() -> void:
	# 本番と同じ場所: 脱出したあとの、暗く禍々しい雲の空(曲も Union 戦のもの)
	for node in get_tree().current_scene.find_children("*", "", true, false):
		if node.has_method("practice_union_backdrop"):
			node.practice_union_backdrop()
			break
	await get_tree().create_timer(1.0, false).timeout
	var packed := load(str(_mission["boss_scene"])) as PackedScene
	if packed == null:
		return
	var event := SpawnEvent.new()
	event.enemy_scene = packed
	event.is_boss = true
	event.boss_name = "UNION"
	event.boss_phase_thresholds = [0.66, 0.33]
	event.tag = "union"
	_runner.spawn(event, 0)
	if not is_instance_valid(_boss):
		return
	for child in _boss.get_children():
		if child is BossEntranceFx:
			child.queue_free()
	var view := CameraView.visible_rect(_boss)
	var home := Vector2(view.get_center().x, view.position.y + view.size.y * 0.24)
	_boss.global_position = home
	var ub := _boss.get_node_or_null("UnionBoss")
	await get_tree().create_timer(0.5, false).timeout
	if ub and is_instance_valid(_boss):
		ub.begin_fight(home)
		if not (_mission.has("spell") and _mission["spell"] != ""):
			var hp := _boss.get_node_or_null("HPComponent") as HPComponent
			if hp:
				hp.damage_lock = true

# ---------------------------------------------------------------- 結果

func _succeed() -> void:
	if _done:
		return
	_done = true
	var kind := _Records.CLEAR_NORMAL
	if _Run.lives > 0:
		kind = _Records.CLEAR_ASSIST
	elif _Run.plus:
		kind = _Records.CLEAR_PLUS
	_Records.set_clear(str(_mission["key"]), kind)
	var text : String = {"clear": "MISSION CLEAR", "plus": "PRACTICE+ CLEAR", "assist": "ASSIST CLEAR"}[kind]
	var color : Color = {"clear": Color(1.0, 0.95, 0.7), "plus": Color(1.0, 0.25, 0.2), "assist": Color(0.4, 1.0, 0.5)}[kind]
	_finish(text, color)

func _on_failed() -> void:
	if _done:
		return
	_done = true
	_finish("FAILED", Color(0.7, 0.7, 0.8))

func _finish(text : String, color : Color) -> void:
	var tree := get_tree()
	EnemyShooter.hold_fire(30.0)
	tree.call_group("enemy_bullet", "vanish", 0.2)
	if is_instance_valid(_gm.player):
		_gm.player.start_invincibility(10.0)
	var layer := CanvasLayer.new()
	layer.layer = 95
	add_child(layer)
	var label := Label.new()
	label.text = text
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.02))
	label.add_theme_constant_override("outline_size", 8)
	layer.add_child(label)
	label.modulate.a = 0.0
	create_tween().tween_property(label, "modulate:a", 1.0, 0.25)
	await tree.create_timer(2.6, true, false, true).timeout
	_Run.finish(tree)

## 画面の上に、ミッションの名前と残り時間を出す
func _make_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var title := Label.new()
	title.text = "PRACTICE%s  %s" % ["+" if _Run.plus else "", _mission.get("title", "")]
	title.position = Vector2(8, 96)
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3) if _Run.plus else Color(1.0, 0.9, 0.6))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	title.add_theme_constant_override("outline_size", 4)
	layer.add_child(title)
	_hud = Label.new()
	_hud.position = Vector2(8, 112)
	_hud.add_theme_font_size_override("font_size", 11)
	_hud.add_theme_color_override("font_color", Color(1, 1, 1))
	_hud.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_hud.add_theme_constant_override("outline_size", 4)
	layer.add_child(_hud)
