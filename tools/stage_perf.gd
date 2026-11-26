extends Node
## 開発用(一時): ステージの重さを、CPU(スクリプト・描画の準備)と GPU に分けて計る
##   godot --path . res://tools/stage_perf.tscn -- <stage番号> <難易度> <開始秒> <計る秒>
var keeper := false
var _t := 0.0
var _last := 0
var _acc := {}
var _n := 0
var _next := 0.0
var _end := 60.0
var _max := 0.0
var _slow := 0
var _dumps := 0

func _ready() -> void:
	if keeper:
		return
	DebugTools.used = true
	var args := OS.get_cmdline_user_args()
	var stage := int(args[0]); var diff := int(args[1])
	RunConfig.has_selection = true
	RunConfig.difficulty = diff
	DebugTools.pending_start_time = float(args[2])
	DebugTools.skip_intro_once = true
	var watcher := Node.new()
	watcher.set_script(get_script())
	watcher.set("keeper", true)
	watcher.set("_end", float(args[3]))
	get_tree().root.add_child.call_deferred(watcher)
	(func() -> void: get_tree().change_scene_to_file("res://stage%d.tscn" % stage)).call_deferred()

func _process(delta : float) -> void:
	if not keeper:
		return
	_t += delta
	var vp := get_tree().root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var p := get_tree().get_first_node_in_group("player")
	if p and p.has_method("start_invincibility"):
		p.start_invincibility(1.0)
	var now := Time.get_ticks_usec()
	if _last != 0 and _t > 2.0:
		_add("frame", (now - _last) / 1000.0)
		var ft := (now - _last) / 1000.0
		_max = maxf(_max, ft)
		if ft > 16.7: _slow += 1
		_add("gpu", RenderingServer.viewport_get_measured_render_time_gpu(vp))
		_add("render_cpu", RenderingServer.viewport_get_measured_render_time_cpu(vp))
		_add("draw", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		_add("bullets", get_tree().get_nodes_in_group("enemy_bullet").size())
		var ring := 0
		for b in get_tree().get_nodes_in_group("enemy_bullet"):
			if b._ring_pattern != null: ring += 1
		_add("ring", ring)
		var parts := 0
		for q in get_tree().current_scene.find_children("*", "GPUParticles2D", true, false):
			if q.emitting and q.is_visible_in_tree(): parts += 1
		for q in get_tree().current_scene.find_children("*", "CPUParticles2D", true, false):
			if q.emitting and q.is_visible_in_tree(): parts += 1
		_add("particles", parts)
		_n += 1
	if _dumps < 4 and Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME) > 250 and _t > 10.0:
		_dumps += 1
		var hist := {}
		for q in get_tree().root.find_children("*", "", true, false):
			if q is CanvasItem and q.is_visible_in_tree():
				var key : String = q.get_class() + ":" + (q.scene_file_path.get_file() if q.scene_file_path != "" else (q.get_script().resource_path.get_file() if q.get_script() else ""))
				hist[key] = hist.get(key, 0) + 1
		var keys := hist.keys()
		keys.sort_custom(func(a, b): return hist[a] > hist[b])
		var s := "DUMP t=%.1f draw=%d:" % [_t, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)]
		for k in keys.slice(0, 12): s += " %s=%d" % [k, hist[k]]
		print(s)
	_last = now
	if _t >= _next and _n > 0:
		_next = _t + 3.0
		var line := "PERF t=%.0f" % _t
		for k in ["frame", "draw", "bullets", "ring", "particles"]:
			line += " %s=%.1f" % [k, _acc[k] / _n]
		line += " nodes=%d" % Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
		line += " max=%.1f slow=%d" % [_max, _slow]
		_max = 0.0; _slow = 0
		print(line)
		_acc.clear(); _n = 0
	if _t > _end:
		get_tree().quit()

func _add(k : String, v : float) -> void:
	_acc[k] = _acc.get(k, 0.0) + v
