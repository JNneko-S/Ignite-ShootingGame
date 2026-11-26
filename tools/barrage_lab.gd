extends Node
## 開発用: 弾幕を頭なし(--headless)で撃たせて、弾の数・隙間・よけやすさを測る。
##   godot --headless --path . --fixed-fps 60 res://tools/barrage_lab.tscn -- <設定の .json>
## "loop": 2 で、二周目の弾幕を撃たせる。"only_shooters": ["名前", …] で、ボスのシーン(boss_scene)の砲口を絞る
## 設定(JSON): {"tests": [{"name": "…", "patterns": ["res://…tres"], "sequence": [], "difficulty": 2,
##   "chosen": 2, "duration": 30, "origin": [240, 110], "zako": false, "moving": 0}]}
##   difficulty … 弾幕の調整に使う難易度(DifficultyTuning.level)。chosen … 選んだ難易度(限定弾幕の判定)
##   moving … 0 より大きければ、砲口がこの幅(px)で左右にゆっくり動く(雑魚の想定)
## 1つの設定ごとに「RESULT {…}」の行を出す:
##   avg / p95 / max … 画面の中の弾の数
##   free_min / free_p10 … 画面の下の 6 割で、自機が立てる場所(まわり 8px に弾がない点)の割合の、最小と下から 1 割
##   gap_min … 画面の下の 6 割で、いちばん広い隙間(弾のない円の半径、48 で打ち切り)の最小
##   bot_hits … 簡単なよけ役(少し先の弾の位置を見て、いちばん空いている方へ動く)が当たった回数(1分あたり)

const VIEW := Rect2(16, 5.333, 448, 597.333)
const PLAYER_RADIUS := 3.0
const BOT_SPEED := 300.0
const BOT_FOCUS_SPEED := 120.0
const CELL := 16.0

var _tests : Array = []
var _index := -1
var _time := 0.0
var _test : Dictionary
var _root : Node2D
var _shooter : EnemyShooter
var _bot : Node2D
var _counts : Array[int] = []
var _free : Array[float] = []
var _gaps : Array[float] = []
var _hits := 0
var _grace := 0.0
var _sample_in := 0.0
var _results : Array = []

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("barrage_lab: 設定の .json を渡してください")
		get_tree().quit(1)
		return
	var text := FileAccess.get_file_as_string(args[0])
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		push_error("barrage_lab: 設定を読めません: " + args[0])
		get_tree().quit(1)
		return
	_tests = data.get("tests", [])
	_next_test()

func _next_test() -> void:
	if _root:
		_root.queue_free()
		_root = null
	for node in get_tree().get_nodes_in_group("enemy_bullet"):
		node.queue_free()
	_index += 1
	if _index >= _tests.size():
		print("DONE")
		get_tree().quit()
		return
	_test = _tests[_index]
	_time = 0.0
	_counts.clear()
	_free.clear()
	_gaps.clear()
	_hits = 0
	_grace = 0.0
	_sample_in = 0.5
	DifficultyTuning.level = int(_test.get("difficulty", 2))
	DifficultyTuning.chosen_level = int(_test.get("chosen", _test.get("difficulty", 2)))
	HazardRank.active = bool(_test.get("another", false)) # true なら ANOTHER(ランク 0)の限定弾幕を撃つ
	RunConfig.has_selection = false
	RunConfig.loop = int(_test.get("loop", 1)) # 2 なら二周目の弾幕(ShooterPhase / EnemyShooter の二周目の設定)
	DifficultyTuning.hard_plus = bool(_test.get("hard_plus", false))
	DifficultyTuning._cache.clear()
	_root = Node2D.new()
	_root.name = "Lab"
	add_child(_root)
	var camera := Camera2D.new()
	camera.zoom = Vector2(0.75, 0.75)
	camera.position = VIEW.get_center()
	_root.add_child(camera)
	camera.make_current()
	_bot = Node2D.new()
	_bot.name = "Bot"
	_bot.add_to_group("player")
	_bot.position = Vector2(VIEW.get_center().x, VIEW.end.y - 80.0)
	_root.add_child(_bot)
	# ほかの位置からも撃たせる(ボスの呼ぶ翼など): [{"patterns": [...], "origin": [x, y]}]
	for extra in _test.get("extra", []):
		var es : EnemyShooter = (load("res://Component/Shooter/enemy_shooter_component.tscn") as PackedScene).instantiate()
		es.autostart = false
		es.only_when_on_screen = false
		es.position = Vector2(extra["origin"][0], extra["origin"][1])
		_root.add_child(es)
		var eps : Array[ShotPattern] = []
		for path in extra.get("patterns", []):
			eps.append(load(path))
		es.set_patterns(eps, [])
	if _test.has("boss_scene"):
		# ボスのシーンから、全ての砲口(EnemyShooter)の位置と段階ごとの弾幕を写して、その段階を撃たせる(登場の演出や動きは使わない)
		var proto : Node2D = (load(_test["boss_scene"]) as PackedScene).instantiate()
		var bo2 : Array = _test.get("origin", [240, 110])
		var phase_index := int(_test.get("phase", 0))
		var shooter_scene : PackedScene = load("res://Component/Shooter/enemy_shooter_component.tscn")
		for node in proto.find_children("*", "", true, false):
			if not node is EnemyShooter:
				continue
			var src := node as EnemyShooter
			if _test.has("only_shooters") and not String(src.name) in _test["only_shooters"]:
				continue
			var copy : EnemyShooter = shooter_scene.instantiate()
			copy.autostart = false
			copy.only_when_on_screen = false
			copy.position = Vector2(bo2[0], bo2[1]) + (src.global_position if src.is_inside_tree() else _local_pos(src, proto))
			copy.phases = src.phases
			copy.default_bullet_scene = src.default_bullet_scene
			copy.pause_scale = src.pause_scale
			_root.add_child(copy)
			if copy.has_phases():
				copy.set_phase(phase_index)
			elif src.loop2_replace and RunConfig.second_round():
				copy.set_patterns(src.loop2_patterns, src.loop2_sequence, false, true)
			elif phase_index == 0 or _test.get("static_all_phases", true):
				copy.set_patterns(src.patterns, src.sequence)
		proto.free()
		_shooter = null
		return
	if _test.has("scene"):
		# 本物の敵(ボス)のシーンを出して、その全ての砲口で測る。"phase" があれば、その段階にする
		var boss : Node2D = (load(_test["scene"]) as PackedScene).instantiate()
		var bo : Array = _test.get("origin", [240, 110])
		boss.position = Vector2(bo[0], bo[1])
		_root.add_child(boss)
		_shooter = null
		if _test.has("phase"):
			_force_phase.call_deferred(boss, int(_test["phase"]))
		return
	var scene : PackedScene = load("res://Component/Shooter/enemy_shooter_component.tscn")
	_shooter = scene.instantiate()
	_shooter.autostart = false
	_shooter.only_when_on_screen = false
	var o : Array = _test.get("origin", [240, 110])
	_shooter.position = Vector2(o[0], o[1])
	if _test.get("zako", false):
		_shooter.set("_zako", 1)
	_root.add_child(_shooter)
	var patterns : Array[ShotPattern] = []
	for path in _test.get("patterns", []):
		patterns.append(load(path))
	var sequence : Array[ShotPattern] = []
	for path in _test.get("sequence", []):
		sequence.append(load(path))
	_shooter.set_patterns(patterns, sequence, false, bool(_test.get("all_layers", false)))

## node の、root から見た位置(ツリーの外にあるシーンの中で、親をたどって足す)
func _local_pos(node : Node, root_node : Node) -> Vector2:
	var t := Transform2D.IDENTITY
	var n := node
	while n and n != root_node:
		if n is Node2D:
			t = (n as Node2D).transform * t
		n = n.get_parent()
	return t.origin

func _force_phase(boss : Node, index : int) -> void:
	await get_tree().create_timer(0.3, false).timeout
	if not is_instance_valid(boss):
		return
	for child in boss.get_children():
		if child is BossPhaseController and index > 0:
			child._start_phase(index)

func _physics_process(delta : float) -> void:
	if _index >= _tests.size() or _root == null:
		return
	_time += delta
	var moving := float(_test.get("moving", 0.0))
	if moving > 0.0 and _shooter:
		var o : Array = _test.get("origin", [240, 110])
		_shooter.position.x = o[0] + sin(_time * 0.7) * moving * 0.5
	var bullets := _live_bullets()
	_move_bot(bullets, delta)
	_sample_in -= delta
	if _sample_in <= 0.0:
		_sample_in = 0.25
		_sample(bullets)
	if _time >= float(_test.get("duration", 30.0)):
		_report()
		_next_test()

## 画面の中の敵弾(画面から離れた弾は消す)。[位置, 速度, 半径] の並び
func _live_bullets() -> Array:
	var result := []
	var keep := VIEW.grow(40.0)
	for node in get_tree().get_nodes_in_group("enemy_bullet"):
		var b := node as EnemyBullet
		if b == null or b.is_queued_for_deletion():
			continue
		if not keep.has_point(b.global_position):
			b.queue_free()
			continue
		if not VIEW.has_point(b.global_position):
			continue
		if not b.has_meta(&"lab_r"):
			b.set_meta(&"lab_r", _radius_of(b))
		result.append([b.global_position, b.direction * b.speed, float(b.get_meta(&"lab_r"))])
	return result

func _radius_of(b : Node2D) -> float:
	for child in b.get_children():
		if child is CollisionShape2D and child.shape:
			var s := absf((child as CollisionShape2D).global_scale.x)
			var shape : Shape2D = child.shape
			if shape is CircleShape2D:
				return (shape as CircleShape2D).radius * s
			if shape is RectangleShape2D:
				var size := (shape as RectangleShape2D).size
				return minf(size.x, size.y) * 0.5 * s
			if shape is CapsuleShape2D:
				return (shape as CapsuleShape2D).radius * s
	return 4.0

## 弾をマス目に分ける(近くの弾だけ見るため)
func _buckets(bullets : Array, lookahead : float) -> Dictionary:
	var grid := {}
	for b in bullets:
		var p : Vector2 = b[0] + b[1] * lookahead
		var key := Vector2i(floori(p.x / CELL), floori(p.y / CELL))
		if not grid.has(key):
			grid[key] = []
		grid[key].append([p, b[2]])
	return grid

## point のまわりの、いちばん近い弾までの隙間(弾の大きさを引いた距離)。cap で打ち切り
func _clearance(grid : Dictionary, point : Vector2, cap : float) -> float:
	var best := cap
	var reach := ceili((cap + 12.0) / CELL)
	var c := Vector2i(floori(point.x / CELL), floori(point.y / CELL))
	for dx in range(-reach, reach + 1):
		for dy in range(-reach, reach + 1):
			var key := Vector2i(c.x + dx, c.y + dy)
			if not grid.has(key):
				continue
			for item in grid[key]:
				var d : float = point.distance_to(item[0]) - item[1]
				if d < best:
					best = d
	return best

func _move_bot(bullets : Array, delta : float) -> void:
	var now := _buckets(bullets, 0.0)
	_grace -= delta
	if _grace <= 0.0 and _clearance(now, _bot.position, 8.0) < PLAYER_RADIUS:
		_hits += 1
		_grace = 1.2
		if _test.get("debug", false):
			var nearest := []
			for b in bullets:
				if (b[0] as Vector2).distance_to(_bot.position) < 30.0:
					nearest.append("%s v=%s r=%.1f" % [(b[0] as Vector2).round(), (b[1] as Vector2).round(), b[2]])
			print("HIT t=%.2f bot=%s near=%s" % [_time, _bot.position.round(), nearest])
	var soon := _buckets(bullets, 0.12)
	var later := _buckets(bullets, 0.28)
	var far := _buckets(bullets, 0.45)
	var area := Rect2(VIEW.position + Vector2(10, VIEW.size.y * 0.3), VIEW.size - Vector2(20, VIEW.size.y * 0.3 + 10))
	var best_pos := _bot.position
	var best_score := -INF
	for speed : float in [0.0, BOT_FOCUS_SPEED, BOT_SPEED]:
		for i in (1 if speed == 0.0 else 8):
			var step : Vector2 = Vector2.from_angle(TAU * i / 8.0) * speed * delta
			var cand : Vector2 = (_bot.position + step).clamp(area.position, area.end)
			var c1 := _clearance(soon, cand + step * 7.0, 24.0)
			var c2 := _clearance(later, cand + step * 16.0, 24.0)
			var c3 := _clearance(far, cand + step * 26.0, 24.0)
			var c0 := _clearance(now, cand, 24.0)
			var score := minf(c0, minf(c1, c2) + 2.0) * 3.0 + minf(c1, c2) * 0.5 + c3 * 0.35
			score -= absf(cand.x - VIEW.get_center().x) * 0.004 + absf(cand.y - (VIEW.end.y - 90.0)) * 0.006
			# 画面の下のふちに追い詰められない(横へ逃げる)
			score -= maxf(cand.y - (VIEW.end.y - 70.0), 0.0) * 1.2
			score -= maxf(absf(cand.x - VIEW.get_center().x) - VIEW.size.x * 0.4, 0.0) * 0.25
			if speed == BOT_SPEED:
				score -= 0.3
			if score > best_score:
				best_score = score
				best_pos = cand
	_bot.position = best_pos

func _sample(bullets : Array) -> void:
	_counts.append(bullets.size())
	var grid := _buckets(bullets, 0.0)
	var total := 0
	var free := 0
	var best := 0.0
	var top := VIEW.position.y + VIEW.size.y * 0.4
	var y := top
	while y < VIEW.end.y - 6.0:
		var x := VIEW.position.x + 8.0
		while x < VIEW.end.x - 8.0:
			var c := _clearance(grid, Vector2(x, y), 48.0)
			total += 1
			if c >= 8.0:
				free += 1
			best = maxf(best, c)
			x += 12.0
		y += 12.0
	_free.append(float(free) / maxf(total, 1))
	_gaps.append(best)

func _percentile(values : Array, q : float) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	return float(sorted[clampi(int(round(q * (sorted.size() - 1))), 0, sorted.size() - 1)])

func _report() -> void:
	var sum := 0.0
	for c in _counts:
		sum += c
	var minutes := maxf(float(_test.get("duration", 30.0)) / 60.0, 0.01)
	var result := {
		"name": _test.get("name", "?"),
		"avg": snappedf(sum / maxf(_counts.size(), 1), 0.1),
		"p95": _percentile(_counts, 0.95),
		"max": _percentile(_counts, 1.0),
		"free_min": snappedf(_percentile(_free, 0.0), 0.01),
		"free_p10": snappedf(_percentile(_free, 0.1), 0.01),
		"gap_min": snappedf(_percentile(_gaps, 0.0), 0.1),
		"bot_hits": snappedf(_hits / minutes, 0.1),
	}
	print("RESULT " + JSON.stringify(result))
