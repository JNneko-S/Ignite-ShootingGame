extends Node
## 開発用: 4面のブラッドスワンを越えてからコンティニューしたとき、越えたところから始まるか(と、子機の数)を確かめる。
##   godot --headless --path . --fixed-fps 60 res://tools/checkpoint_test.tscn -- [難易度 0〜2]
const _RunState := preload("res://Component/Settings/run_state.gd")
var _phase := 0
var _t := 0.0

var keeper := false

func _ready() -> void:
	if keeper:
		return
	# 見張り役(このスクリプトの写し)を、シーンの外(ルート)に置いてから、4面へ切り替える
	var watcher := Node.new()
	watcher.set_script(get_script())
	watcher.set("keeper", true)
	get_tree().root.add_child.call_deferred(watcher)
	set_physics_process(false)
	DebugTools.used = true # テストのプレイは、実績もスコアも保存しない(遊んでいる人のセーブを汚さない)
	var args := OS.get_cmdline_user_args()
	RunConfig.has_selection = true
	RunConfig.difficulty = int(args[0]) if args.size() > 0 else 1
	_RunState.clear_checkpoint()
	DebugTools.pending_start_time = 145.0
	DebugTools.skip_intro_once = true
	(func() -> void: get_tree().change_scene_to_file("res://stage4.tscn")).call_deferred()

func _physics_process(delta : float) -> void:
	if not keeper:
		return
	_t += delta
	var p := get_tree().get_first_node_in_group("player")
	if p and p.has_method("start_invincibility"):
		p.start_invincibility(1.0)
	var runner := get_tree().get_first_node_in_group("stage_runner")
	if _phase == 0:
		if int(Engine.get_physics_frames()) % 6 == 0:
			for e in get_tree().get_nodes_in_group("enemy"):
				var hp := e.get_node_or_null("HPComponent")
				if hp:
					hp.apply_damage(int(max(hp.get("max_hp") * 0.01, 8)))
		if _RunState.checkpoint_scene != "":
			print("CHECKPOINT scene=%s time=%.1f (t=%.1f)" % [_RunState.checkpoint_scene, _RunState.checkpoint_time, _t])
			# ゲームオーバーの画面の「コンティニュー」と同じ手順
			var scene := get_tree().current_scene
			if scene and scene.scene_file_path == _RunState.checkpoint_scene:
				DebugTools.pending_start_time = _RunState.checkpoint_time
				_RunState.checkpoint_restart = true
			RunConfig.continues_used += 1
			StageIntro.skip_next = true
			get_tree().reload_current_scene()
			_phase = 1
			_t = 0.0
		elif _t > 150.0:
			print("FAIL no checkpoint"); get_tree().quit()
	elif _phase == 1 and _t > 2.0:
		var pl := get_tree().get_first_node_in_group("player") as Player
		print("RESTARTED stage_time=%.1f options=%d difficulty=%d" % [runner.stage_time if runner else -1.0, pl.options.size() if pl else -1, RunConfig.difficulty])
		_phase = 2
	elif _phase == 2 and _t > 8.0:
		print("END stage_time=%.1f" % (runner.stage_time if runner else -1.0))
		get_tree().quit()
