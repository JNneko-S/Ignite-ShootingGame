extends RefCounted
## プラクティスのミッションの一覧と、解禁のしかた。
## ミッション(辞書):
##   key        … 記録の名前(解禁・クリア)
##   kind       … "zako"(道中の区間)/ "midboss" / "boss"(ボスの攻撃1つ)/ "spell"(カウンター大技)/ "union"(裏ボスの攻撃)
##   title      … 一覧に出す名前
##   stage      … ステージの番号(1〜4)、scene … ステージのシーン
##   difficulty … 0〜3(EASY〜ANOTHER)、loop … 1 か 2(二周目)
##   start_time … ステージのどの時刻から始めるか、end_time … 道中の区間が終わる時刻
##   boss_scene / boss_name / phase / pattern / spell … ボスのミッション
## 一覧は、ステージのデータ(StageData)と、ボスのシーンの砲口の段階(ShooterPhase)から、その場で組み立てる。

const STAGES : Array = [
	{"scene": "res://stage1.tscn", "name": "STAGE 1"},
	{"scene": "res://stage2.tscn", "name": "STAGE 2"},
	{"scene": "res://stage3.tscn", "name": "STAGE 3"},
	{"scene": "res://stage4.tscn", "name": "STAGE 4"},
]
const UNION_SCENE := "res://GameScene/Enemy/SECRET/union_boss.tscn"
## ボスの主な砲口の名前(上から探す)
const MAIN_SHOOTERS : Array[String] = ["EnemyShooterComponent", "Gun_m_top"]
## 道中の区間の長さの目安(秒)
const SEGMENT_LENGTH := 30.0
const _PracticeRecords := preload("res://Component/Practice/practice_records.gd")
const _PracticeRun := preload("res://Component/Practice/practice_run.gd")

static var _cache : Dictionary = {}
static var _stage_data_cache : Dictionary = {}

# ---------------------------------------------------------------- 一覧

## difficulty・loop のミッションを、ステージごとに。[{ "name", "missions": [..] }]
static func build(difficulty : int, loop : int) -> Array:
	var cache_key := "%d:%d" % [difficulty, loop]
	if _cache.has(cache_key):
		return _cache[cache_key]
	var out : Array = []
	for i in STAGES.size():
		var info : Dictionary = STAGES[i]
		var stage := stage_data(info["scene"], difficulty, loop)
		var missions : Array = []
		if stage:
			missions = _stage_missions(i + 1, info["scene"], stage, difficulty, loop)
		if i == STAGES.size() - 1 and loop == 1 and difficulty >= 2:
			missions.append_array(_union_missions(i + 1, info["scene"], difficulty))
		out.append({"name": info["name"], "missions": missions})
	_cache[cache_key] = out
	return out

## 全部のミッションのキー(デバッグの全解禁)
static func all_keys() -> Array:
	var keys : Array = []
	for d in 4:
		for l in [1, 2]:
			for group in build(d, l):
				for m in group["missions"]:
					keys.append(m["key"])
	return keys

## ステージのシーンが読むタイムライン(難易度・周回で選ぶ。GameManager と同じ決まり)
static func stage_data(scene_path : String, difficulty : int, loop : int) -> StageData:
	var key := scene_path
	if not _stage_data_cache.has(key):
		_stage_data_cache[key] = _find_stage_data(scene_path)
	var stage : StageData = _stage_data_cache[key]
	if stage == null:
		return null
	if difficulty == 3 and stage.another_timeline:
		return stage.another_timeline
	if loop >= 2 and difficulty < 3 and stage.second_loop:
		return stage.second_loop
	return stage

static func _find_stage_data(scene_path : String) -> StageData:
	var packed := load(scene_path) as PackedScene
	var state := packed.get_state() if packed else null
	while state:
		for n in state.get_node_count():
			for p in state.get_node_property_count(n):
				if state.get_node_property_name(n, p) == &"stage":
					var value = state.get_node_property_value(n, p)
					if value is StageData:
						return value
		state = state.get_base_scene_state()
	return null

# ---------------------------------------------------------------- 道中の区間

## 道中(ボス・中ボスのあいだ)を、SEGMENT_LENGTH 秒くらいずつに分けた区間。[{ "start", "end" }]
static func segments(stage : StageData) -> Array:
	var bosses : Array = []
	var waits : Array = []
	for e in stage.events:
		if e is SpawnEvent and e.is_boss:
			bosses.append(e)
		elif e is WaitClearEvent:
			waits.append(e)
	bosses.sort_custom(func(a, b) -> bool: return a.time < b.time)
	var ranges : Array = []
	var from := 0.0
	for b in bosses:
		if b.time - from >= 6.0:
			ranges.append([from, b.time])
		# ボスのあとは、そのボスを待つイベントのあとから
		var after : float = b.time + 1.0
		for w in waits:
			if w.tag == b.tag and w.time >= b.time:
				after = w.time + 0.1
				break
		from = after
	var out : Array = []
	for r in ranges:
		var length : float = r[1] - r[0]
		var n := maxi(1, roundi(length / SEGMENT_LENGTH))
		for k in n:
			out.append({"start": r[0] + length * k / n, "end": r[0] + length * (k + 1) / n})
	return out

static func zako_key(stage_no : int, loop : int, difficulty : int, index : int) -> String:
	return "%d|%d|%d|zako|%d" % [stage_no, loop, difficulty, index]

# ---------------------------------------------------------------- ボス

static func attack_key(stage_no : int, loop : int, difficulty : int, boss_file : String, phase : int, pattern_file : String) -> String:
	return "%d|%d|%d|atk|%s|%d|%s" % [stage_no, loop, difficulty, boss_file, phase, pattern_file]

static func spell_key(stage_no : int, loop : int, difficulty : int, boss_file : String, spell_name : String) -> String:
	return "%d|%d|%d|spell|%s|%s" % [stage_no, loop, difficulty, boss_file, spell_name]

static func _stage_missions(stage_no : int, scene_path : String, stage : StageData, difficulty : int, loop : int) -> Array:
	var out : Array = []
	var segs := segments(stage)
	# 道中とボスを、時刻の順に並べる
	var entries : Array = []
	for i in segs.size():
		entries.append({"time": segs[i]["start"], "zako": i})
	var seen_boss := {}
	for e in stage.events:
		if e is SpawnEvent and e.is_boss and e.enemy_scene:
			var path : String = e.enemy_scene.resource_path
			if seen_boss.has(path + str(e.time)):
				continue
			seen_boss[path + str(e.time)] = true
			entries.append({"time": e.time, "boss": e})
	entries.sort_custom(func(a, b) -> bool: return a["time"] < b["time"])
	for entry in entries:
		if entry.has("zako"):
			var i : int = entry["zako"]
			var seg : Dictionary = segs[i]
			out.append({"key": zako_key(stage_no, loop, difficulty, i), "kind": "zako",
				"title": "道中 %d  (%d〜%d秒)" % [i + 1, int(seg["start"]), int(seg["end"])],
				"stage": stage_no, "scene": scene_path, "difficulty": difficulty, "loop": loop,
				"start_time": seg["start"], "end_time": seg["end"]})
		else:
			out.append_array(_boss_missions(stage_no, scene_path, entry["boss"], difficulty, loop, stage))
	return out

static func _boss_missions(stage_no : int, scene_path : String, event : SpawnEvent, difficulty : int, loop : int, stage : StageData) -> Array:
	var out : Array = []
	var boss := event.enemy_scene.instantiate()
	var file := event.enemy_scene.resource_path.get_file().get_basename()
	var kind := "midboss" if event.tag.begins_with("midboss") else "boss"
	var name := event.boss_name if event.boss_name != "" else file
	var level := _level(difficulty, loop, stage)
	var main := main_shooter(boss)
	if main:
		var phase_count := maxi(main.phases.size(), 1)
		for ph in phase_count:
			var lists := shooter_lists(main, ph, difficulty, loop)
			var seq : Array = lists["sequence"].filter(func(p) -> bool: return p and allows(p, difficulty, level))
			var pats : Array = lists["patterns"].filter(func(p) -> bool: return p and allows(p, difficulty, level))
			var used := {}
			var attacks : Array = seq if not seq.is_empty() else pats.slice(0, 1)
			for p in attacks:
				var pfile := pattern_file(p)
				if used.has(pfile):
					continue
				used[pfile] = true
				var label := ("第%d形態  " % (ph + 1)) if phase_count > 1 else ""
				label += pretty(pfile) if not seq.is_empty() else "全体"
				out.append({"key": attack_key(stage_no, loop, difficulty, file, ph, pfile), "kind": kind,
					"title": "%s  %s" % [name, label], "stage": stage_no, "scene": scene_path,
					"difficulty": difficulty, "loop": loop, "start_time": maxf(event.time - 1.5, 0.1),
					"boss_scene": event.enemy_scene.resource_path, "boss_time": event.time, "boss_name": name,
					"phase": ph, "pattern": p.resource_path, "whole": seq.is_empty()})
	for spell in spells_of(boss):
		if spell.patterns.is_empty() or (spell.trigger_hp_ratio <= 0.0 and spell.trigger_phase < 0 and not spell.lethal):
			continue
		out.append({"key": spell_key(stage_no, loop, difficulty, file, spell.spell_name), "kind": "spell",
			"title": "%s  %s" % [name, spell.spell_name], "stage": stage_no, "scene": scene_path,
			"difficulty": difficulty, "loop": loop, "start_time": maxf(event.time - 1.5, 0.1),
			"boss_scene": event.enemy_scene.resource_path, "boss_time": event.time, "boss_name": name,
			"spell": String(spell.name)})
	boss.free()
	return out

## 裏ボス Union(Bエンド。HARD と ANOTHER)。ステージの最後に、そのまま呼び出して戦う
static func _union_missions(stage_no : int, scene_path : String, difficulty : int) -> Array:
	var out : Array = []
	var packed := load(UNION_SCENE) as PackedScene
	if packed == null:
		return out
	var boss := packed.instantiate()
	var main := main_shooter(boss)
	var file := UNION_SCENE.get_file().get_basename()
	if main:
		for ph in main.phases.size():
			var lists := shooter_lists(main, ph, difficulty, 1)
			var used := {}
			for p in lists["sequence"]:
				if p == null or not allows(p, difficulty, 2):
					continue
				var pfile := pattern_file(p)
				if used.has(pfile):
					continue
				used[pfile] = true
				out.append({"key": attack_key(stage_no, 1, difficulty, file, ph, pfile), "kind": "union",
					"title": "UNION  第%d形態  %s" % [ph + 1, pretty(pfile)], "stage": stage_no, "scene": scene_path,
					"difficulty": difficulty, "loop": 1, "start_time": 9999.0, "boss_scene": UNION_SCENE,
					"boss_time": -1.0, "boss_name": "UNION", "phase": ph, "pattern": p.resource_path, "whole": false})
	for spell in spells_of(boss):
		out.append({"key": spell_key(stage_no, 1, difficulty, file, spell.spell_name), "kind": "union",
			"title": "UNION  %s" % spell.spell_name, "stage": stage_no, "scene": scene_path, "difficulty": difficulty,
			"loop": 1, "start_time": 9999.0, "boss_scene": UNION_SCENE, "boss_time": -1.0, "boss_name": "UNION",
			"spell": String(spell.name)})
	boss.free()
	return out

## ボスのカウンター大技
static func spells_of(boss : Node) -> Array:
	return boss.find_children("*", "", true, false).filter(func(n) -> bool: return n is CounterSpell)

## ボスの主な砲口
static func main_shooter(boss : Node) -> EnemyShooter:
	for n in MAIN_SHOOTERS:
		var s := boss.get_node_or_null(n) as EnemyShooter
		if s and (not s.phases.is_empty() or not s.patterns.is_empty() or not s.sequence.is_empty()
				or not s.loop2_patterns.is_empty() or not s.loop2_sequence.is_empty()):
			return s
	return null

## 砲口の、段階 ph の「同時に撃つ弾幕」と「順番に撃つ弾幕」(難易度・周回で選ぶ。ShooterPhase と同じ決まり)
static func shooter_lists(shooter : EnemyShooter, ph : int, difficulty : int, loop : int) -> Dictionary:
	if not shooter.phases.is_empty():
		var phase : ShooterPhase = shooter.phases[clampi(ph, 0, shooter.phases.size() - 1)]
		if phase == null:
			return {"patterns": [], "sequence": []}
		if loop >= 2 and difficulty < 3 and phase.loop2_replace:
			return {"patterns": Array(phase.loop2_patterns), "sequence": Array(phase.loop2_sequence)}
		if difficulty == 3 and phase.another_replace:
			return {"patterns": Array(phase.another_patterns), "sequence": Array(phase.another_sequence)}
		if difficulty == 0:
			return {"patterns": Array(phase.easy_patterns if not phase.easy_patterns.is_empty() else phase.patterns),
				"sequence": Array(phase.easy_sequence if not phase.easy_sequence.is_empty() else phase.sequence)}
		return {"patterns": Array(phase.patterns), "sequence": Array(phase.sequence)}
	if loop >= 2 and difficulty < 3 and shooter.loop2_replace:
		return {"patterns": Array(shooter.loop2_patterns), "sequence": Array(shooter.loop2_sequence)}
	if difficulty == 3 and shooter.another_replace:
		return {"patterns": Array(shooter.another_patterns), "sequence": Array(shooter.another_sequence)}
	if difficulty == 0 and not shooter.easy_patterns.is_empty():
		return {"patterns": Array(shooter.easy_patterns), "sequence": Array(shooter.sequence)}
	return {"patterns": Array(shooter.patterns), "sequence": Array(shooter.sequence)}

## その難易度で撃つか(DifficultyTuning.allows と同じ決まりを、難易度を渡して判断する)
static func allows(p : ShotPattern, difficulty : int, level : int) -> bool:
	if p.another_only:
		return difficulty == 3
	if p.max_difficulty < 3:
		if difficulty == 3 and p.also_another and p.max_difficulty == 2:
			return true
		return difficulty >= p.min_difficulty and difficulty <= p.max_difficulty
	return level >= p.min_difficulty

## 弾幕の調整に使う難易度(ステージの Difficulty Step・二周目で一段上。ANOTHER は HARD)
static func _level(difficulty : int, loop : int, stage : StageData) -> int:
	if difficulty >= 3:
		return 2
	var lv := difficulty + (stage.difficulty_step if stage else 0)
	if loop >= 2:
		lv += 1
	return mini(lv, 2)

static func pattern_file(p : ShotPattern) -> String:
	return p.resource_path.get_file().get_basename() if p.resource_path != "" else "embedded"

## 弾幕のファイル名を、一覧に出す名前に(難易度の印を外す)
static func pretty(file : String) -> String:
	var s := file
	for suffix in ["_e", "_n", "_h", "_a"]:
		if s.ends_with(suffix):
			s = s.substr(0, s.length() - 2)
			break
	return s.replace("_l2", "").replace("_", " ")

# ---------------------------------------------------------------- 解禁(ふつうのプレイから呼ぶ)

## 今のシーンのステージの番号(1〜4。プラクティスにないシーンなら 0)
static func stage_no_of(tree : SceneTree) -> int:
	var scene := tree.current_scene
	if scene == null:
		return 0
	for i in STAGES.size():
		if STAGES[i]["scene"] == scene.scene_file_path:
			return i + 1
	return 0

static func _loop_key() -> int:
	return 2 if RunConfig.second_round() else 1

## ボスの主な砲口が、弾幕を撃ち始めた(EnemyShooter が呼ぶ)
static func note_attack(shooter : EnemyShooter, pattern : ShotPattern) -> void:
	if _PracticeRun.active or DebugTools.used or pattern == null:
		return
	if not String(shooter.name) in MAIN_SHOOTERS:
		return
	var enemy := shooter._owner_enemy()
	if enemy == null or not (enemy.is_midboss or enemy.boss_reach_time >= 0.0):
		return
	var stage_no := stage_no_of(shooter.get_tree())
	if stage_no == 0:
		return
	var phase := 0
	for child in enemy.get_children():
		if child is BossPhaseController:
			phase = child.current_phase()
	var file := enemy.scene_file_path.get_file().get_basename()
	var loop := 1 if file == UNION_SCENE.get_file().get_basename() else _loop_key()
	_PracticeRecords.unlock(attack_key(stage_no, loop, DifficultyTuning.chosen(), file, phase, pattern_file(pattern)))

## カウンター大技が始まった(CounterSpell が呼ぶ)
static func note_spell(enemy : Enemy, spell_name : String) -> void:
	if _PracticeRun.active or DebugTools.used or enemy == null:
		return
	var stage_no := stage_no_of(enemy.get_tree())
	if stage_no == 0:
		return
	var file := enemy.scene_file_path.get_file().get_basename()
	var loop := 1 if file == UNION_SCENE.get_file().get_basename() else _loop_key()
	_PracticeRecords.unlock(spell_key(stage_no, loop, DifficultyTuning.chosen(), file, spell_name))

## 道中の区間を、ミスせずに抜けた(StageRunner が呼ぶ)
static func note_segment(tree : SceneTree, index : int) -> void:
	if _PracticeRun.active or DebugTools.used:
		return
	var stage_no := stage_no_of(tree)
	if stage_no == 0:
		return
	_PracticeRecords.unlock(zako_key(stage_no, _loop_key(), DifficultyTuning.chosen(), index))
