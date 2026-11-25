extends Node
## 開発用: ステージを頭なしで最後まで流す(自機は無敵、敵は少しずつ削る)。出てきた敵・弾の数・エラーを記録する。
##   godot --headless --path . --fixed-fps 60 res://tools/probe_stage.tscn -- res://stage4.tscn 420 0.004
##   引数: ステージ 秒数 削る割合 難易度 [始める秒] [continued|-] [loop2]
var _t := 0.0
var _next := 0.0
var _stage : Node
var _until := 400.0
var _rate := 0.004
var _seen := {}
var _max_bullets := 0

func _ready() -> void:
	DebugTools.used = true # テストのプレイは、実績もスコアも保存しない(遊んでいる人のセーブを汚さない)
	var args := OS.get_cmdline_user_args()
	var path := args[0] if args.size() > 0 else "res://stage4.tscn"
	if args.size() > 1:
		_until = float(args[1])
	if args.size() > 2:
		_rate = float(args[2])
	if args.size() > 3:
		# 選んだ難易度(0 = EASY / 1 = NORMAL / 2 = HARD)
		RunConfig.has_selection = true
		RunConfig.difficulty = int(args[3])
	if args.size() > 5 and args[5] == "continued":
		# 1〜3面でコンティニューしてきた状態をまねる(コンティニュー回数・ランクの戻り)
		RunConfig.continues_used = 3
		RunConfig.consecutive_game_overs = 0
		HazardRank.on_continue()
	if args.size() > 6 and args[6] == "loop2":
		RunConfig.loop = 2 # 二周目(二周目のタイムラインと弾幕)
	if args.size() > 4 and float(args[4]) > 0.0:
		# デバッグの「途中から始める」と同じ(この秒数から、出撃の演出なしで)
		DebugTools.pending_start_time = float(args[4])
		DebugTools.skip_intro_once = true
	EnemyShooter.debug_pattern_started = _on_pattern
	_stage = (load(path) as PackedScene).instantiate()
	add_child(_stage)
	get_tree().node_added.connect(_on_added)

var _patterns_seen := {}

## ボスの砲口が撃ち始めた弾幕を、1回ずつ記録する(どの弾幕が実際に使われているか)
func _on_pattern(shooter : EnemyShooter, pattern : ShotPattern) -> void:
	if shooter.is_zako() and not pattern.resource_path.contains("Exclusive"):
		return
	var key := pattern.resource_path if pattern.resource_path != "" else "(埋め込み)"
	var enemy := shooter._owner_enemy()
	var who := enemy.scene_file_path.get_file() if enemy else "?"
	var k := who + " " + key
	if _patterns_seen.has(k):
		return
	_patterns_seen[k] = true
	var runner := _stage.get_node_or_null("StageRunner")
	print("PATTERN stage=%.1f %s %s" % [runner.get("stage_time") if runner else -1.0, who, key.get_file()])

func _on_added(node : Node) -> void:
	if node is PowerUpItem:
		print("ITEM kind=%d at t=%.1f" % [(node as PowerUpItem).kind, _t])
	if node is FloatingText:
		(func() -> void:
			if is_instance_valid(node) and node.get("text") != null:
				print("TEXT %s" % node.get("text"))).call_deferred()
	if node is Enemy and node.scene_file_path != "":
		var key := node.scene_file_path.get_file()
		var runner := _stage.get_node_or_null("StageRunner")
		var st : float = runner.get("stage_time") if runner else -1.0
		if not _seen.has(key) or key.begins_with("conveyor") or key.begins_with("blood") or key.contains("formation") or key.contains("gunship") or key.contains("bomber"):
			print("SPAWN t=%.1f stage=%.1f %s" % [_t, st, key])
		_seen[key] = true

func _physics_process(delta : float) -> void:
	_t += delta
	var p := get_tree().get_first_node_in_group("player")
	if p and p.has_method("start_invincibility"):
		p.start_invincibility(1.0)
	if int(Engine.get_physics_frames()) % 6 == 0:
		for e in get_tree().get_nodes_in_group("enemy"):
			var hp := e.get_node_or_null("HPComponent")
			if hp and hp.has_method("apply_damage"):
				hp.apply_damage(int(max(hp.get("max_hp") * _rate, 8)))
	var n := get_tree().get_nodes_in_group("enemy_bullet").size()
	_max_bullets = maxi(_max_bullets, n)
	if _t >= _next:
		_next += 10.0
		var runner := _stage.get_node_or_null("StageRunner")
		print("t=%.0f stage=%.1f bullets=%d max=%d" % [_t, runner.get("stage_time") if runner else -1.0, n, _max_bullets])
		_max_bullets = 0
	if _t > _until:
		get_tree().quit()
