extends Node
## 開発用: プラクティスを確かめる。記録は user://practice_test.cfg に書く(遊んでいる人の記録は汚さない)。
##   godot --headless --path . --fixed-fps 60 res://tools/practice_test.tscn
## 1. 難易度ごとの、ステージごとのミッションの数を出す
## 2. いくつかのミッションを実際に遊ぶ(自機は無敵)。一覧の画面へ戻ってきたら、記録を出す
## 3. 最後のミッションは、自機を撃墜させて、失敗で戻るかを見る
const _Catalog := preload("res://Component/Practice/practice_catalog.gd")
const _Records := preload("res://Component/Practice/practice_records.gd")
const _Run := preload("res://Component/Practice/practice_run.gd")

var keeper := false
var _queue : Array = []
var _current : Dictionary = {}
var _lose := false
var _t := 0.0
var _killed := false
var _in_stage := false
var _menu_time := 0.0

func _ready() -> void:
	if keeper:
		return
	DebugTools.used = true
	_Records.path_override = "user://practice_test.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://practice_test.cfg"))
	var names := ["EASY", "NORMAL", "HARD", "ANOTHER"]
	for mode in [[0, 1], [1, 1], [2, 1], [3, 1], [0, 2], [1, 2], [2, 2]]:
		var groups := _Catalog.build(mode[0], mode[1])
		var counts := []
		for g in groups:
			var kinds := {}
			for m in g["missions"]:
				kinds[m["kind"]] = kinds.get(m["kind"], 0) + 1
			counts.append("%s=%d %s" % [g["name"], g["missions"].size(), str(kinds)])
		print("CATALOG %s%s: %s" % ["2nd " if mode[1] == 2 else "", names[mode[0]], " | ".join(counts)])
	# 遊ぶミッション
	var picks : Array = [[2, 1, 0, "boss", 2], [2, 2, 3, "boss", 1], [1, 1, 0, "zako", 1]]
	for pick in picks:
		var groups := _Catalog.build(pick[0], pick[1])
		var list : Array = groups[pick[2]]["missions"].filter(func(m) -> bool: return m["kind"] == pick[3])
		if list.size() > pick[4]:
			_queue.append(list[pick[4]])
	var watcher := Node.new()
	watcher.set_script(get_script())
	watcher.set("keeper", true)
	watcher.set("_queue", _queue)
	get_tree().root.add_child.call_deferred(watcher)

func _physics_process(delta : float) -> void:
	if not keeper:
		return
	_t += delta
	var scene := get_tree().current_scene
	if scene and scene.scene_file_path.contains("stage"):
		_in_stage = true
	if scene and scene.scene_file_path.contains("practice_menu"):
		_menu_time += delta
	else:
		_menu_time = 0.0
	if _current.is_empty() or (_in_stage and _menu_time > 1.0):
		if not _current.is_empty():
			print("RESULT %s -> %s (%.1fs)" % [_current["title"], _Records.clear_of(_current["key"]) if _Records.clear_of(_current["key"]) != "" else "FAILED/none", _t])
		if _queue.is_empty():
			print("DONE")
			EnemyShooter.debug_pattern_started = Callable()
			get_tree().quit()
			return
		_current = _queue.pop_front()
		_lose = _queue.is_empty() # 最後のミッションは、撃墜させる
		_killed = false
		_in_stage = false
		_t = 0.0
		print("START %s  [%s diff=%d loop=%d]" % [_current["title"], _current["kind"], _current["difficulty"], _current["loop"]])
		EnemyShooter.debug_pattern_started = func(sh : EnemyShooter, pat : ShotPattern) -> void:
			if sh._owner_enemy() and sh._owner_enemy().scene_file_path.contains("tank_kai"):
				print("  %s fired %s t=%.1f" % [sh.name, pat.resource_path.get_file(), _t])
		_Run.begin(get_tree(), _current, 0, false, null)
		return
	if int(_t * 60.0) % 300 == 0:
		var r := get_tree().get_first_node_in_group("stage_runner") as StageRunner
		print("  t=%.0f scene=%s stage_time=%s enemies=%d hold=%s paused=%s ts=%.2f" % [_t, scene.scene_file_path.get_file() if scene else "-",
			str(snappedf(r.stage_time, 0.1)) if r else "-", get_tree().get_nodes_in_group("enemy").size(),
			EnemyShooter.is_holding_fire(), get_tree().paused, Engine.time_scale])
	var p := get_tree().get_first_node_in_group("player") as Player
	if p:
		if _lose and _in_stage and _t > 6.0 and not _killed:
			_killed = true
			p.lives = 0
			p.die()
			print("  player killed")
		elif not _lose:
			p.start_invincibility(1.0)
	if _t > 70.0:
		print("TIMEOUT %s" % _current["title"])
		EnemyShooter.debug_pattern_started = Callable()
		get_tree().quit()
