extends Node
## 開発用(一時): 1面のボスから4面まで、ステージの切り替えを通しで流す(各面はボスの手前から始め、ボスはすぐ倒す)
##   godot --path . res://tools/transition_test.tscn -- <難易度>
const BOSS_TIME := {1: 122.0, 2: 89.5, 3: 120.0, 4: 209.5}
var keeper := false
var _t := 0.0
var _scene : Node
var _stage := 0
var _boss_seen := {}
var _end_at := -1.0

func _ready() -> void:
	if keeper:
		return
	DebugTools.used = true
	var args := OS.get_cmdline_user_args()
	RunConfig.has_selection = true
	RunConfig.difficulty = int(args[0]) if args.size() > 0 else 2
	var watcher := Node.new()
	watcher.set_script(get_script())
	watcher.set("keeper", true)
	get_tree().root.add_child.call_deferred(watcher)
	_go.call_deferred()

func _go() -> void:
	var loading = load("res://GameScene/UI/loading_overlay.gd")
	await loading.run(get_tree())
	DebugTools.pending_start_time = BOSS_TIME[1] - 3.0
	DebugTools.skip_intro_once = true
	get_tree().change_scene_to_file("res://stage1.tscn")

func _physics_process(delta : float) -> void:
	if not keeper:
		return
	_t += delta
	var scene := get_tree().current_scene
	if scene != _scene and scene != null:
		_scene = scene
		var path := scene.scene_file_path
		print("SCENE t=%.1f %s" % [_t, path])
		for k in BOSS_TIME:
			if path.ends_with("stage%d.tscn" % k):
				_stage = k
		var runner := get_tree().get_first_node_in_group("stage_runner") as StageRunner
		if runner and _stage < 4:
			runner.stage_cleared.connect(func() -> void:
				print("CLEARED stage%d t=%.1f" % [_stage, _t])
				DebugTools.pending_start_time = BOSS_TIME[_stage + 1] - 3.0, CONNECT_ONE_SHOT)
		if runner and _stage == 4:
			runner.final_boss_defeated.connect(func() -> void:
				print("FINAL BOSS DOWN t=%.1f" % _t)
				_end_at = _t + 25.0, CONNECT_ONE_SHOT)
	var p := get_tree().get_first_node_in_group("player")
	if p and p.has_method("start_invincibility"):
		p.start_invincibility(1.0)
	# ボス・中ボスは、出てから少しで倒す
	for n in get_tree().get_nodes_in_group("enemy"):
		var e := n as Enemy
		if e == null or e._is_dead or not (e.is_midboss or e.boss_reach_time >= 0.0) or e.hp_component == null:
			continue
		var id := e.get_instance_id()
		if not _boss_seen.has(id):
			_boss_seen[id] = _t
		elif _t - _boss_seen[id] > 4.0:
			e.hp_component.hp_floor = 0
			e.hp_component.damage_lock = false
			e.hp_component.apply_damage(e.hp_component.hp + 10)
	if (_end_at > 0.0 and _t > _end_at) or _t > 900.0:
		print("END t=%.1f stage=%d" % [_t, _stage])
		get_tree().quit()
