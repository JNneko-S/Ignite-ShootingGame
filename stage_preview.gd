@tool
extends Node2D
class_name StagePreview
## ステージエディター。ステージのシーンに置くと、エディタの2D画面に、
## StageData の敵の動き(軌道)と、指定した時刻の敵の位置・弾幕を描画する。
## ゲーム実行中は何もせず、自分で消える。
##
## 使い方:
##   1. ステージのシーンに Node2D を追加して、このスクリプトをアタッチする(位置は原点のまま)
##   2. Stage に StageData を割り当てる
##   3. Preview Time を動かすと、その時刻の敵の位置が見える。Playing をオンにすると再生する
##   4. 下部パネルの「ステージ」(addons/stage_editor)で、タイムラインの編集と、途中からの試遊ができる
##
## 軌道は Enemy が実際に使う計算(X/Yで別々のイージング)と同じ方法で描く。
## 弾幕は、敵シーンの EnemyShooter(または SpawnEvent の Shot Patterns)を、ShotMath で計算して描く。
## 注意: WaitClearEvent(ボス待ち)で、実際の進行が止まる時間は、ここには反映されない。
## 注意: 敵が途中で倒されることは考えない(最後まで生きている前提で弾を描く)。
## BeatConductor を持つ敵(ボス)は、譜面(BeatChart)のとおりに撃つ。曲は出現と同時に始まる前提で描く。

@export var stage : StageData :
	set(value):
		stage = value
		queue_redraw()
## この時刻(ステージ開始からの秒数)の敵の位置を表示する
@export_range(0.0, 300.0, 0.1) var preview_time : float = 0.0 :
	set(value):
		preview_time = value
		queue_redraw()
## オンにすると、エディタ上でステージが再生される
@export var playing : bool = false
@export_range(0.1, 4.0, 0.1) var play_speed : float = 1.0
@export var show_paths : bool = true
@export var show_event_list : bool = true
## これより長く居座る敵(倒されるまで待機するボスなど)は、この秒数で切って、全体の長さを計算する
@export var max_enemy_lifetime : float = 60.0

@export_group("弾幕")
@export var show_bullets : bool = true
@export var bullet_radius : float = 3.0
## 描く弾の上限(多すぎると重くなる)
@export var max_bullets : int = 3000
## オンなら、編集中のシーンにある Player の位置を、自機狙いの向きに使う
@export var use_scene_player : bool = true
## 自機の位置(Use Scene Player がオフか、Player が見つからないとき)
@export var player_position : Vector2 = Vector2(168.0, 380.0)

const PATH_STEP : float = 0.04 # 軌道を描くときの、時間の刻み(秒)
const REFRESH_INTERVAL : float = 0.3 # データの編集に追従する間隔(秒)
const BULLET_MARGIN : float = 16.0 # 弾が画面外に出たとみなす余白(px)
const BULLET_LIFETIME : float = 12.0 # 譜面の弾を、何秒前の発射まで描くか

var _refresh_timer : float = 0.0
var _stage_length : float = 0.0
## 敵シーンごとの {pattern, shooters} (シーンを開かずに読むと重いので、しばらく使い回す)
var _scene_cache : Dictionary = {}
## ShotPattern ごとの ShotMath.motion_table の結果
var _motion_cache : Dictionary = {}

func _ready() -> void:
	if not Engine.is_editor_hint():
		set_process(false)
		hide()

func _process(delta : float) -> void:
	if not Engine.is_editor_hint():
		return
	if playing:
		preview_time += delta * play_speed
		if preview_time > _stage_length + 1.0:
			preview_time = 0.0
	_refresh_timer += delta
	if _refresh_timer >= REFRESH_INTERVAL:
		_refresh_timer = 0.0
		_scene_cache.clear() # 敵シーンの編集に追従する
		_motion_cache.clear()
		queue_redraw() # インスペクタでの編集に追従する

# ---------------------------------------------------------------- 外から使う(タイムラインのパネル用)

## null を除いて、時間順に並べたイベント
func sorted_events() -> Array[StageEvent]:
	var events : Array[StageEvent] = []
	if stage == null:
		return events
	for event in stage.events:
		if event != null:
			events.append(event)
	events.sort_custom(func(a : StageEvent, b : StageEvent) -> bool: return a.time < b.time)
	return events

## ステージ全体の長さ(秒)。最後のイベントか、最後の敵が動き終わる時刻
func stage_length() -> float:
	var length := 0.0
	for event in sorted_events():
		length = maxf(length, event.unit_time(event.unit_count() - 1))
		if event is SpawnEvent:
			for unit in event.unit_count():
				length = maxf(length, event.unit_time(unit) + minf(unit_duration(event, unit), max_enemy_lifetime))
	return length

## SpawnEvent の unit 体目が、出現してから動き終わる(消える)までの秒数
func unit_duration(event : SpawnEvent, unit : int) -> float:
	var path := _build_path(event, unit, _screen_rect())
	return path["total"] if not path.is_empty() else 0.0

## イベントの色(SpawnEvent は spawn_index ごとに色を変える)
func event_color(event : StageEvent, spawn_index : int) -> Color:
	if event is SpawnEvent:
		return Color.from_hsv(fmod(spawn_index * 0.13, 1.0), 0.65, 1.0)
	if event is ScrollSpeedEvent:
		return Color(0.5, 0.85, 1.0)
	if event is WaitClearEvent:
		return Color(1.0, 0.45, 0.45)
	if event is StageSignalEvent:
		return Color(1.0, 0.85, 0.4)
	return Color(0.8, 0.8, 0.8)

## イベントを1行で説明する文字
func describe_event(event : StageEvent, with_time : bool = true) -> String:
	var line := ""
	if event is SpawnEvent:
		var enemy_name : String = event.enemy_scene.resource_path.get_file().get_basename() if event.enemy_scene else "(敵なし)"
		line = "出現 ×%d  %s  %s" % [event.unit_count(), enemy_name, event.tag]
		if event.is_boss:
			line += "  [ボス]"
	elif event is ScrollSpeedEvent:
		line = "スクロール ×%.1f" % event.speed_multiplier
	elif event is WaitClearEvent:
		line = "待機 %s" % (event.tag if event.tag != "" else "(全ての敵)")
	elif event is StageSignalEvent:
		line = "合図 %s" % event.signal_name
	else:
		line = event.get_class()
	return ("%.1fs  " % event.time + line) if with_time else line

# ---------------------------------------------------------------- 描画

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var screen := _screen_rect()
	_draw_frame(screen)
	if stage == null:
		_text(screen.position + Vector2(12.0, 24.0), "Stage に StageData を割り当ててください", Color(1.0, 0.8, 0.4))
		return

	var events := sorted_events()
	var player := _player_position()
	draw_circle(player, 5.0, Color(0.4, 0.8, 1.0, 0.8)) # 自機狙いの基準

	_stage_length = 0.0
	var spawn_index := 0
	var bullets := 0
	for event in events:
		if event is SpawnEvent:
			var color := event_color(event, spawn_index)
			spawn_index += 1
			for unit in event.unit_count():
				_draw_spawn(event, unit, color, screen)
				if show_bullets:
					bullets += _draw_bullets(event, unit, screen, player, max_bullets - bullets)
		else:
			_stage_length = maxf(_stage_length, event.time)

	if show_event_list:
		_draw_event_list(events, screen)
	var status := "t = %.1f 秒 / 全体 %.1f 秒" % [preview_time, _stage_length]
	if show_bullets:
		status += " / 弾 %d発" % bullets
		if bullets >= max_bullets:
			status += "(上限)"
	_text(Vector2(screen.position.x + 12.0, screen.end.y - 10.0), status, Color.WHITE)

## Camera2D に映る範囲の枠と、100px ごとの格子(ワールド座標)
func _draw_frame(screen : Rect2) -> void:
	draw_rect(screen, Color(1.0, 1.0, 1.0, 0.7), false, 2.0)
	var grid := Color(1.0, 1.0, 1.0, 0.08)
	for x in range(ceili(screen.position.x / 100.0) * 100, int(screen.end.x), 100):
		draw_line(Vector2(x, screen.position.y), Vector2(x, screen.end.y), grid)
	for y in range(ceili(screen.position.y / 100.0) * 100, int(screen.end.y), 100):
		draw_line(Vector2(screen.position.x, y), Vector2(screen.end.x, y), grid)

## SpawnEvent の unit 体目の軌道と、現在位置を描く
func _draw_spawn(event : SpawnEvent, unit : int, color : Color, screen : Rect2) -> void:
	var spawn_time := event.unit_time(unit)
	var path := _build_path(event, unit, screen)
	if path.is_empty():
		return
	var segments : Array = path["segments"]
	var total : float = path["total"]
	_stage_length = maxf(_stage_length, spawn_time + minf(total, max_enemy_lifetime))

	if show_paths:
		var points := PackedVector2Array([path["start"]])
		for segment in segments:
			var count := maxi(int(segment["duration"] / PATH_STEP), 2)
			for i in range(1, count + 1):
				points.append(_segment_position(segment, segment["duration"] * i / count))
		if points.size() >= 2:
			draw_polyline(points, Color(color, 0.55), 1.5)
		draw_circle(path["start"], 4.0, Color(color, 0.9))
		draw_rect(Rect2(points[points.size() - 1] - Vector2(3.0, 3.0), Vector2(6.0, 6.0)), Color(color, 0.9))
		if unit == 0:
			_text(path["start"] + Vector2(6.0, -6.0), "%.1fs %s" % [event.time, event.tag], Color(color, 1.0))

	# 現在時刻の位置
	var local_time := preview_time - spawn_time
	if local_time >= 0.0 and local_time <= total:
		var current_pos : Vector2 = _path_position(path, local_time)
		draw_circle(current_pos, 9.0, Color(color, 0.95))
		draw_arc(current_pos, 11.0, 0.0, TAU, 24, Color.WHITE, 1.5)

## SpawnEvent の unit 体目が、preview_time までに撃った弾のうち、まだ画面内にあるものを描く。
## 描いた弾の数を返す
func _draw_bullets(event : SpawnEvent, unit : int, screen : Rect2, player : Vector2, budget : int) -> int:
	var local_time := preview_time - event.unit_time(unit)
	if local_time < 0.0 or budget <= 0:
		return 0
	var path := _build_path(event, unit, screen)
	if path.is_empty():
		return 0
	# 敵は動き終わると消えるので、それ以降は撃たない(撃った弾は残る)
	var fire_until := minf(local_time, path["total"])
	var screen_rect := screen
	var visible_rect := screen_rect.grow(BULLET_MARGIN)
	var info := _scene_info(event.enemy_scene)
	if info.get("chart") != null:
		return _draw_chart_bullets(info, path, local_time, fire_until, screen_rect, visible_rect, player, budget)
	var seconds_per_beat := _scene_seconds_per_beat()
	var drawn := 0
	for shooter in _shooters_for(event):
		var muzzle_offset : Vector2 = shooter["offset"]
		var color : Color = shooter["color"]
		for pattern in shooter["patterns"]:
			if pattern == null:
				continue
			var table := _motion_table(pattern)
			var burst := maxi(pattern.shot_count, 1)
			var burst_aim := 0.0
			for shot in ShotMath.shot_times(pattern, fire_until, seconds_per_beat):
				var shot_time : float = shot["time"]
				var shot_index : int = shot["index"]
				var muzzle := _path_position(path, shot_time) + muzzle_offset
				var aim_angle := (player - muzzle).angle()
				if shot_index % burst == 0:
					burst_aim = aim_angle # バーストの最初の1発の向き(aim_once_per_burst 用)
				if shooter["only_on_screen"] and not screen_rect.has_point(muzzle):
					continue # EnemyShooter._can_fire と同じ(撃たないが、発射回数は進む)
				if pattern.aim_once_per_burst:
					aim_angle = burst_aim
				for bullet in ShotMath.bullets(pattern, shot_index, aim_angle):
					var point := ShotMath.bullet_position(pattern, table, bullet["angle"], bullet["speed_scale"],
							local_time - shot_time, muzzle + bullet["offset"], player)
					if not visible_rect.has_point(point):
						continue # 画面外に出た弾は消える
					draw_circle(point, bullet_radius, color)
					drawn += 1
					if drawn >= budget:
						return drawn
	return drawn

## 譜面(BeatChart)で撃つ敵の弾。時刻は、出現からの秒数 = 譜面の時刻
func _draw_chart_bullets(info : Dictionary, path : Dictionary, local_time : float, fire_until : float,
		screen_rect : Rect2, visible_rect : Rect2, player : Vector2, budget : int) -> int:
	var chart : BeatChart = info["chart"]
	if not info.has("schedule"):
		info["schedule"] = chart.build_schedule()
	var shooters : Dictionary = {}
	for shooter in info["shooters"]:
		shooters[shooter["name"]] = shooter
	var drawn := 0
	for shot in chart.shots_between(info["schedule"], local_time - BULLET_LIFETIME, fire_until):
		var pattern : ShotPattern = shot["pattern"]
		var table := _motion_table(pattern)
		var shot_time : float = shot["time"]
		var names : Array = shooters.keys() if shot["shooter"] == "" else [shot["shooter"]]
		var excluded : PackedStringArray = shot["except"]
		for shooter_name in names:
			if not shooters.has(shooter_name) or excluded.has(shooter_name):
				continue
			var shooter : Dictionary = shooters[shooter_name]
			var muzzle : Vector2 = _path_position(path, shot_time) + shooter["offset"]
			if shooter["only_on_screen"] and not screen_rect.has_point(muzzle):
				continue
			var aim_angle := (player - muzzle).angle()
			for bullet in ShotMath.bullets(pattern, shot["index"], aim_angle):
				var point := ShotMath.bullet_position(pattern, table, bullet["angle"], bullet["speed_scale"],
						local_time - shot_time, muzzle + bullet["offset"], player)
				if not visible_rect.has_point(point):
					continue
				draw_circle(point, bullet_radius, shooter["color"])
				drawn += 1
				if drawn >= budget:
					return drawn
	return drawn

func _draw_event_list(events : Array[StageEvent], screen : Rect2) -> void:
	var y := screen.position.y + 24.0
	for event in events:
		var active := event.time <= preview_time
		_text(Vector2(screen.position.x + 12.0, y), describe_event(event), Color(1.0, 1.0, 1.0, 1.0 if active else 0.45))
		y += 16.0
		if y > screen.end.y - 30.0:
			break

# ---------------------------------------------------------------- 軌道の計算(Enemy と同じ方法)

## 軌道を、区間(セグメント)の並びにする。Enemy._run_pattern / _run_step と同じ規則
func _build_path(event : SpawnEvent, unit : int, screen : Rect2) -> Dictionary:
	var pattern : MovePattern = event.move_pattern
	if pattern == null:
		pattern = _scene_info(event.enemy_scene).get("pattern") as MovePattern
	if pattern == null:
		return {}
	var mirror := event.mirror_x != (event.alternate_mirror and unit % 2 == 1)
	var offset := event.offset + event.offset_step * unit

	var cursor := offset
	if pattern.override_start_position:
		cursor = _to_screen(pattern.start_position, mirror, offset, screen)
	var start := cursor

	var segments : Array = []
	var elapsed := 0.0
	for step in pattern.steps:
		if step == null:
			continue
		var target : Vector2
		if step.relative:
			var delta := step.target
			if mirror:
				delta.x = -delta.x
			target = cursor + delta
		else:
			target = _to_screen(step.target, mirror, offset, screen)
		segments.append({
			"start_time": elapsed, "duration": step.duration, "wait": step.wait_after,
			"from": cursor, "to": target, "step": step})
		cursor = target
		elapsed += step.duration + step.wait_after
	return {"start": start, "segments": segments, "total": elapsed}

## Enemy._convert_absolute と同じ(Camera2D に映る範囲の、左右の中心で反転する)
func _to_screen(point : Vector2, mirror : bool, offset : Vector2, screen : Rect2) -> Vector2:
	if mirror:
		point.x = screen.position.x * 2.0 + screen.size.x - point.x
	return point + offset

## 区間の、開始から local 秒後の位置(X と Y で別々のイージング)
func _segment_position(segment : Dictionary, local : float) -> Vector2:
	var step : MoveStep = segment["step"]
	var from : Vector2 = segment["from"]
	var to : Vector2 = segment["to"]
	var duration : float = segment["duration"]
	if duration <= 0.0 or local >= duration:
		return to
	var x : float = Tween.interpolate_value(from.x, to.x - from.x, local, duration, step.x_trans, step.x_ease)
	var y : float = Tween.interpolate_value(from.y, to.y - from.y, local, duration, step.y_trans, step.y_ease)
	return Vector2(x, y)

func _path_position(path : Dictionary, local_time : float) -> Vector2:
	var current : Vector2 = path["start"]
	for segment in path["segments"]:
		var start_time : float = segment["start_time"]
		if local_time < start_time:
			break
		current = _segment_position(segment, local_time - start_time)
	return current

# ---------------------------------------------------------------- 敵シーンの読み取り

## SpawnEvent の敵が持つ砲口の並び。SpawnEvent の Shot Patterns があれば、全ての砲口をそれで置き換える
## (StageRunner.spawn と同じ規則)
func _shooters_for(event : SpawnEvent) -> Array:
	var shooters : Array = _scene_info(event.enemy_scene).get("shooters", [])
	if event.shot_patterns.is_empty():
		return shooters
	var replaced : Array = []
	for shooter in shooters:
		var copy : Dictionary = shooter.duplicate()
		copy["patterns"] = event.shot_patterns
		replaced.append(copy)
	return replaced

func _motion_table(pattern : ShotPattern) -> Array[Dictionary]:
	if not _motion_cache.has(pattern):
		_motion_cache[pattern] = ShotMath.motion_table(pattern)
	return _motion_cache[pattern]

## 敵シーンを一時的に作って、移動パターンと砲口(EnemyShooter)の設定を読む。
## エディタでは敵のスクリプトは動かないので、作っても弾を撃ったりはしない
func _scene_info(scene : PackedScene) -> Dictionary:
	if scene == null:
		return {}
	if _scene_cache.has(scene):
		return _scene_cache[scene]
	var info := {"pattern": null, "shooters": [], "chart": null}
	var root := scene.instantiate()
	if root:
		info["pattern"] = root.get("pattern") as MovePattern
		var index := 0
		for node in root.find_children("*", "", true, false):
			if node.get_script() == BeatConductor:
				info["chart"] = node.get("chart") as BeatChart
				continue
			if node.get_script() != EnemyShooter:
				continue
			var patterns : Array = []
			var value = node.get("patterns")
			if value is Array:
				patterns = value
			var on_screen = node.get("only_when_on_screen")
			info["shooters"].append({
				"name": String(node.name),
				"offset": _offset_in(root, node),
				"patterns": patterns,
				"only_on_screen": on_screen if on_screen is bool else true,
				"color": Color.from_hsv(fmod(0.55 + index * 0.17, 1.0), 0.45, 1.0, 0.9)})
			index += 1
		root.free()
	_scene_cache[scene] = info
	return info

## node の位置を、シーンのルートから見た座標にする
func _offset_in(root : Node, node : Node) -> Vector2:
	var xform := Transform2D.IDENTITY
	var current := node
	while current != null and current != root:
		if current is Node2D:
			xform = (current as Node2D).transform * xform
		current = current.get_parent()
	return xform.origin

## 編集中のシーンにある MusicClock のテンポ(Timing Unit が BEATS のパターン用)。なければ 120 BPM
func _scene_seconds_per_beat() -> float:
	var root := get_tree().edited_scene_root if is_inside_tree() else null
	if root:
		for node in root.find_children("*", "AudioStreamPlayer", true, false):
			if node.get_script() == MusicClock:
				return 60.0 / maxf(float(node.get("bpm")), 1.0)
	return 0.5

func _player_position() -> Vector2:
	if use_scene_player:
		var root := get_tree().edited_scene_root if is_inside_tree() else null
		if root:
			for node in root.find_children("*", "Node2D", true, false):
				if node.get_script() == Player:
					return to_local((node as Node2D).global_position)
	return to_local(player_position)

# ---------------------------------------------------------------- 補助

## 編集中のシーンの Camera2D に映る範囲(ワールド座標)。このノードは原点に置く前提
func _screen_rect() -> Rect2:
	return CameraView.scene_rect(get_tree().edited_scene_root if is_inside_tree() else null)

func _text(at : Vector2, text : String, color : Color) -> void:
	var font := ThemeDB.fallback_font
	draw_string(font, at + Vector2(1.0, 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color(0.0, 0.0, 0.0, 0.8))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, color)
