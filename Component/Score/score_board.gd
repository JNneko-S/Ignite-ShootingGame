extends RefCounted
class_name ScoreBoard
## スコアボード(過去 MAX_ENTRIES 回のプレイの記録)。user://scores.cfg に保存する。シーンを切り替えても残る(static)。
##
## 記録するとき:
##   ・ゲームオーバーになったとき(GameManager)
##   ・最後のステージをクリアしたとき(StageTransition の Next Stage が空のとき)
## 出撃(機体選択)で begin_run()、次のステージへ移るとき(StageCarry.save)に carry_stage() を呼んで、
## ステージをまたいだ被弾数・イグナイト(ボム)の回数・撃破数を足していく。
## Slow Mode(処理落ち)をオンにして遊んだプレイは、記録しない。
##
## レート(0〜100 点と、S / A / B / C / D):
##   スコア        : RATE_SCORE_WEIGHT 点(RATE_SCORE_TARGET で満点)
##   撃破数        : RATE_KILL_WEIGHT 点(RATE_KILL_TARGET で満点)
##   被弾数        : RATE_HIT_WEIGHT 点(0 回で満点。1 回ごとに RATE_HIT_PENALTY 点ずつ減る)
##   ボム使用数    : RATE_BOMB_WEIGHT 点(0 回で満点。1 回ごとに RATE_BOMB_PENALTY 点ずつ減る)

const PATH : String = "user://scores.cfg"
const MAX_ENTRIES : int = 20
const DIFFICULTY_NAMES : Array[String] = ["EASY", "NORMAL", "HARD", "ANOTHER"]

const RATE_SCORE_TARGET : float = 30000000.0
const RATE_SCORE_WEIGHT : float = 50.0
const RATE_KILL_TARGET : float = 1500.0
const RATE_KILL_WEIGHT : float = 20.0
const RATE_HIT_WEIGHT : float = 20.0
const RATE_HIT_PENALTY : float = 4.0
const RATE_BOMB_WEIGHT : float = 10.0
const RATE_BOMB_PENALTY : float = 0.5
## 難易度ごとの、レートの倍率(EASY, NORMAL, HARD, ANOTHER)
const RATE_DIFFICULTY_SCALES : Array[float] = [0.8, 1.0, 1.1, 1.2]
## この点数以上で、その評価(S, A, B, C。届かなければ D)
const GRADES : Array = [["S", 90.0], ["A", 75.0], ["B", 60.0], ["C", 40.0]]

## 前のステージまでに足した数
static var carried_hits : int = 0
static var carried_bombs : int = 0
static var carried_kills : int = 0
## このプレイ中に Slow Mode(処理落ち)が効いたか
static var slow_used : bool = false

## 新しいプレイを始める(出撃したとき)
static func begin_run() -> void:
	carried_hits = 0
	carried_bombs = 0
	carried_kills = 0
	slow_used = false

## 次のステージへ移るとき: 今のステージの数を足しておく
static func carry_stage(tree : SceneTree) -> void:
	var stats := _stage_stats(tree)
	carried_hits += stats["hits"]
	carried_bombs += stats["bombs"]
	carried_kills += stats["kills"]

## プレイが終わった: 記録して、次のプレイの準備をする。記録したら true
static func finish_run(tree : SceneTree, cleared : bool) -> bool:
	var saved := false
	if not slow_used and not GameSettings.slow_mode:
		var stats := _stage_stats(tree)
		var entry := {
			"time": Time.get_unix_time_from_system(),
			"date": Time.get_datetime_string_from_system(false, true),
			"score": stats["score"],
			"hits": carried_hits + stats["hits"],
			"bombs": carried_bombs + stats["bombs"],
			"kills": carried_kills + stats["kills"],
			"difficulty": stats["difficulty"],
			"ship": RunConfig.ship.ship_name if RunConfig.ship else "---",
			"stage": _stage_name(tree),
			"cleared": cleared,
		}
		record(entry)
		saved = true
	begin_run()
	return saved

static func _stage_stats(tree : SceneTree) -> Dictionary:
	var stats := {"score": 0, "hits": 0, "bombs": 0, "kills": 0, "difficulty": RunConfig.difficulty}
	var score_system := tree.get_first_node_in_group(&"score_system") as ScoreSystem
	if score_system:
		stats["score"] = score_system.score
		stats["kills"] = score_system.kill_count
	var game_manager := _game_manager(tree)
	if game_manager:
		stats["hits"] = game_manager.hit_count
		stats["bombs"] = game_manager.ignite_activation_count
		if not RunConfig.has_selection:
			stats["difficulty"] = int(game_manager.difficulty)
	return stats

static func _game_manager(tree : SceneTree) -> GameManager:
	if tree.current_scene is GameManager:
		return tree.current_scene
	for node in tree.current_scene.find_children("*", "GameManager", true, false) if tree.current_scene else []:
		return node
	return null

static func _stage_name(tree : SceneTree) -> String:
	if tree.current_scene == null:
		return "---"
	var file := tree.current_scene.scene_file_path.get_file().get_basename().to_upper()
	return file.replace("STAGE", "STAGE ") if file != "" else "---"

# ---------------------------------------------------------------- 保存

## 記録を足す(新しい順に MAX_ENTRIES 件まで)
static func record(entry : Dictionary) -> void:
	var entries := load_entries()
	entries.push_front(entry)
	if entries.size() > MAX_ENTRIES:
		entries.resize(MAX_ENTRIES)
	var config := ConfigFile.new()
	config.set_value("scores", "entries", entries)
	config.save(PATH)

## 記録(新しい順)
static func load_entries() -> Array:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return []
	var entries = config.get_value("scores", "entries", [])
	return entries if entries is Array else []

# ---------------------------------------------------------------- レート

## レートの点数(0〜100)
static func rate_value(entry : Dictionary) -> float:
	var score := RATE_SCORE_WEIGHT * clampf(float(entry.get("score", 0)) / RATE_SCORE_TARGET, 0.0, 1.0)
	var kills := RATE_KILL_WEIGHT * clampf(float(entry.get("kills", 0)) / RATE_KILL_TARGET, 0.0, 1.0)
	var hits := maxf(RATE_HIT_WEIGHT - RATE_HIT_PENALTY * int(entry.get("hits", 0)), 0.0)
	var bombs := maxf(RATE_BOMB_WEIGHT - RATE_BOMB_PENALTY * int(entry.get("bombs", 0)), 0.0)
	var difficulty := clampi(int(entry.get("difficulty", 1)), 0, RATE_DIFFICULTY_SCALES.size() - 1)
	return clampf((score + kills + hits + bombs) * RATE_DIFFICULTY_SCALES[difficulty], 0.0, 100.0)

## レートの評価(S / A / B / C / D)
static func grade(entry : Dictionary) -> String:
	var value := rate_value(entry)
	for pair in GRADES:
		if value >= pair[1]:
			return pair[0]
	return "D"

static func difficulty_name(entry : Dictionary) -> String:
	return DIFFICULTY_NAMES[clampi(int(entry.get("difficulty", 1)), 0, DIFFICULTY_NAMES.size() - 1)]
