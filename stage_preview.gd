@tool
extends Node2D
class_name StagePreview
## ステージエディターの第1段階。ステージのシーンに置くと、エディタの2D画面に、
## StageData の敵の動き(軌道)と、指定した時刻の敵の位置を描画する。
## ゲーム実行中は何もせず、自分で消える。
##
## 使い方:
##   1. ステージのシーンに Node2D を追加して、このスクリプトをアタッチする(位置は原点のまま)
##   2. Stage に StageData を割り当てる
##   3. Preview Time を動かすと、その時刻の敵の位置が見える。Playing をオンにすると再生する
##
## 軌道は Enemy が実際に使う計算(X/Yで別々のイージング)と同じ方法で描く。
## 注意: WaitClearEvent(ボス待ち)で、実際の進行が止まる時間は、ここには反映されない。

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

const PATH_STEP : float = 0.04 # 軌道を描くときの、時間の刻み(秒)
const REFRESH_INTERVAL : float = 0.3 # データの編集に追従する間隔(秒)

var _refresh_timer : float = 0.0
var _stage_length : float = 0.0

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
		queue_redraw() # インスペクタでの編集に追従する

# ---------------------------------------------------------------- 描画

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var screen := _screen_size()
	_draw_frame(screen)
	if stage == null:
		_text(Vector2(12.0, 24.0), "Stage に StageData を割り当ててください", Color(1.0, 0.8, 0.4))
		return

	var events : Array[StageEvent] = []
	for event in stage.events:
		if event != null:
			events.append(event)
	events.sort_custom(func(a : StageEvent, b : StageEvent) -> bool: return a.time < b.time)

	_stage_length = 0.0
	var spawn_index := 0
	for event in events:
		if event is SpawnEvent:
			var color := Color.from_hsv(fmod(spawn_index * 0.13, 1.0), 0.65, 1.0)
			spawn_index += 1
			for unit in maxi(event.count, 1):
				_draw_spawn(event, unit, color, screen)
		else:
			_stage_length = maxf(_stage_length, event.time)

	if show_event_list:
		_draw_event_list(events)
	_text(Vector2(12.0, screen.y - 10.0), "t = %.1f 秒 / 全体 %.1f 秒" % [preview_time, _stage_length], Color.WHITE)

func _draw_frame(screen : Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, screen), Color(1.0, 1.0, 1.0, 0.7), false, 2.0)
	var grid := Color(1.0, 1.0, 1.0, 0.08)
	for x in range(100, int(screen.x), 100):
		draw_line(Vector2(x, 0.0), Vector2(x, screen.y), grid)
	for y in range(100, int(screen.y), 100):
		draw_line(Vector2(0.0, y), Vector2(screen.x, y), grid)

## SpawnEvent の unit 体目の軌道と、現在位置を描く
func _draw_spawn(event : SpawnEvent, unit : int, color : Color, screen : Vector2) -> void:
	var spawn_time := event.time + event.interval * unit
	var path := _build_path(event, unit, screen)
	if path.is_empty():
		return
	var segments : Array = path["segments"]
	var total : float = path["total"]
	_stage_length = maxf(_stage_length, spawn_time + total)

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

func _draw_event_list(events : Array[StageEvent]) -> void:
	var y := 24.0
	for event in events:
		var line := ""
		if event is SpawnEvent:
			var enemy_name : String = event.enemy_scene.resource_path.get_file().get_basename() if event.enemy_scene else "(敵なし)"
			line = "%.1fs  出現 ×%d  %s  %s" % [event.time, maxi(event.count, 1), enemy_name, event.tag]
		elif event is ScrollSpeedEvent:
			line = "%.1fs  スクロール ×%.1f" % [event.time, event.speed_multiplier]
		elif event is WaitClearEvent:
			line = "%.1fs  待機 %s" % [event.time, event.tag if event.tag != "" else "(全ての敵)"]
		elif event is StageSignalEvent:
			line = "%.1fs  合図 %s" % [event.time, event.signal_name]
		else:
			line = "%.1fs  %s" % [event.time, event.get_class()]
		var active := event.time <= preview_time
		_text(Vector2(12.0, y), line, Color(1.0, 1.0, 1.0, 1.0 if active else 0.45))
		y += 16.0
		if y > _screen_size().y - 30.0:
			break

# ---------------------------------------------------------------- 軌道の計算(Enemy と同じ方法)

## 軌道を、区間(セグメント)の並びにする。Enemy._run_pattern / _run_step と同じ規則
func _build_path(event : SpawnEvent, unit : int, screen : Vector2) -> Dictionary:
	var pattern : MovePattern = event.move_pattern if event.move_pattern else _scene_pattern(event.enemy_scene)
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

func _to_screen(point : Vector2, mirror : bool, offset : Vector2, screen : Vector2) -> Vector2:
	if mirror:
		point.x = screen.x - point.x
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

## 敵のシーンに設定されている Pattern を、シーンを開かずに読む
func _scene_pattern(scene : PackedScene) -> MovePattern:
	if scene == null:
		return null
	var state := scene.get_state()
	if state.get_node_count() == 0:
		return null
	for i in state.get_node_property_count(0):
		if state.get_node_property_name(0, i) == &"pattern":
			return state.get_node_property_value(0, i) as MovePattern
	return null

# ---------------------------------------------------------------- 補助

func _screen_size() -> Vector2:
	return Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width", 1152)),
		float(ProjectSettings.get_setting("display/window/size/viewport_height", 648)))

func _text(at : Vector2, text : String, color : Color) -> void:
	var font := ThemeDB.fallback_font
	draw_string(font, at + Vector2(1.0, 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color(0.0, 0.0, 0.0, 0.8))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, color)
