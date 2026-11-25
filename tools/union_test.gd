extends Node
## 開発用: 4面のラスボスの手前から始め、ラスボスを倒して、Bエンド(裏ボス Union)を最後まで流す。
##   godot --headless --path . --fixed-fps 60 res://tools/union_test.tscn -- [難易度 0〜2] [Union を削る割合/秒]
## 自機は無敵。Union が戦い始めたら、少しずつ削る。出来事を「EVENT …」の行で出す。
var keeper := false
var _t := 0.0
var _rate := 0.012
var _union : Enemy
var _fight_seen := false
var _phase_seen := -1
var _final_dead := false
var _next_log := 0.0
## true なら、Union 戦が始まったら自機を撃墜させる(負けたら A エンドで終わるか)
var _lose := false
var _lost_done := false

func _ready() -> void:
	if keeper:
		return
	DebugTools.used = true # テストのプレイは、実績もスコアも保存しない(遊んでいる人のセーブを汚さない)
	var args := OS.get_cmdline_user_args()
	RunConfig.has_selection = true
	RunConfig.difficulty = int(args[0]) if args.size() > 0 else 2
	var watcher := Node.new()
	watcher.set_script(get_script())
	watcher.set("keeper", true)
	watcher.set("_rate", float(args[1]) if args.size() > 1 else 0.012)
	watcher.set("_lose", args.size() > 2 and args[2] == "lose")
	get_tree().root.add_child.call_deferred(watcher)
	DebugTools.force_b_end = true
	DebugTools.union_direct = args.size() > 3 and args[3] == "direct" # デバッグパネルの U と同じ(脱出を飛ばす)
	# ラスボスの少し前から
	var data = (load("res://stage4.tscn") as PackedScene).instantiate()
	var runner := data.get_node_or_null("StageRunner") as StageRunner
	var time := 210.0
	if runner and runner.stage:
		for event in runner.stage.events:
			if event is SpawnEvent and event.boss_time_bonus:
				time = event.time
	data.free()
	DebugTools.pending_start_time = maxf(time - 3.0, 0.1)
	DebugTools.skip_intro_once = true
	(func() -> void: get_tree().change_scene_to_file("res://stage4.tscn")).call_deferred()

var _patterns_seen := {}

func _enter_tree() -> void:
	if keeper:
		get_tree().node_added.connect(_on_added)
		EnemyShooter.debug_pattern_started = func(_s : EnemyShooter, pattern : ShotPattern) -> void:
			var key := pattern.resource_path.get_file()
			if pattern.resource_path.contains("SECRET/Union") and not _patterns_seen.has(key):
				_patterns_seen[key] = true
				print("PATTERN %s" % key)

func _on_added(node : Node) -> void:
	if node is Enemy and node.scene_file_path.contains("union_boss"):
		_log("UNION ADDED")
		node.tree_exiting.connect(func() -> void:
			_log("UNION EXITING dead=%s hp=%s" % [node._is_dead, str(node.get_node("HPComponent").hp)])
			print_stack())
		node.died.connect(func(_e : Enemy) -> void:
			_log("UNION DIED")
			print_stack())

func _log(text : String) -> void:
	print("EVENT t=%.1f %s" % [_t, text])

func _physics_process(delta : float) -> void:
	if not keeper:
		return
	_t += delta
	var p := get_tree().get_first_node_in_group("player")
	if p and p.has_method("start_invincibility") and not (_lose and _fight_seen):
		p.start_invincibility(1.0)
	if _lose and _fight_seen and not _lost_done and p and _t > _next_log - 9.0:
		_lost_done = true
		p.lives = 0
		p.die()
		_log("PLAYER KILLED (lives 0)")
	var scene := get_tree().current_scene
	if scene and scene.scene_file_path.contains("staff_roll"):
		EnemyShooter.debug_pattern_started = Callable() # 終わる前に外す(残したまま終えると、後片付けで落ちる)
		_log("STAFF ROLL banner=%s loop=%d hidden=%s b_end=%s game_over_screen=%s" % [StaffRoll.banner, RunConfig.loop, RunConfig.hidden_boss_defeated, Achievements.is_unlocked("b_end") if Achievements.has_method("is_unlocked") else "?", get_tree().root.find_children("*", "GameOverScreen", true, false).size() > 0])
		get_tree().quit()
		return
	# ラスボスを倒す(エンディングへ)
	if not _final_dead:
		for node in get_tree().get_nodes_in_group("enemy"):
			if node is Enemy and node.boss_reach_time >= 0.0 and node.alive_time > 2.0:
				var hp := node.get_node_or_null("HPComponent") as HPComponent
				if hp and hp.hp > 0:
					hp.hp_floor = 0
					hp.damage_lock = false
					hp.apply_damage(hp.hp + 10)
					_final_dead = true
					_log("FINAL BOSS KILLED")
	if _union == null:
		for node in get_tree().get_nodes_in_group("enemy"):
			if node is Enemy and node.scene_file_path.contains("union_boss"):
				_union = node
				_log("UNION SPAWNED at %s" % str(node.global_position))
	if is_instance_valid(_union):
		var ub := _union.get_node_or_null("UnionBoss")
		if ub and ub.has_method("is_rushing") and ub.is_rushing() and not has_meta("rush_%d" % int(_t / 3.0)):
			set_meta("rush_%d" % int(_t / 3.0), true)
			_log("RUSH at %s" % str(_union.global_position))
		if ub and ub.is_fighting():
			if not _fight_seen:
				_fight_seen = true
				_log("FIGHT START at %s player=%s" % [str(_union.global_position), str((p as Node2D).global_position if p else Vector2.ZERO)])
			var hp := _union.get_node_or_null("HPComponent") as HPComponent
			if hp and int(Engine.get_physics_frames()) % 6 == 0:
				hp.apply_damage(maxi(int(hp.max_hp * _rate * 0.1), 1))
		for child in _union.get_children():
			if child is BossPhaseController and child.current_phase() != _phase_seen:
				_phase_seen = child.current_phase()
				_log("PHASE %d" % _phase_seen)
			if child is CounterSpell and child.is_active() and not child.has_meta("logged"):
				child.set_meta("logged", true)
				_log("COUNTER SPELL %s" % child.spell_name)
	elif _union != null and not has_meta("union_gone"):
		set_meta("union_gone", true)
		_log("UNION GONE")
	if _t >= _next_log:
		_next_log += 10.0
		_log("bullets=%d enemies=%d" % [get_tree().get_nodes_in_group("enemy_bullet").size(), get_tree().get_nodes_in_group("enemy").size()])
	if _t > 420.0:
		EnemyShooter.debug_pattern_started = Callable()
		_log("TIMEOUT")
		get_tree().quit()
