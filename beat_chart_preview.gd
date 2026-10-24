@tool
extends Node2D
class_name BeatChartPreview
## ボスの譜面(BeatChart)のエディター。ボスのシーンに置くと、エディタの2D画面に、
## 譜面のとおりに撃った弾幕を描く。Playing をオンにすると、ボスの曲をエディタで鳴らしながら再生する。
## ゲーム実行中は何もせず、自分で消える。
##
## 使い方:
##   1. ボスのシーン(BeatConductor があるシーン)に Node2D を追加して、このスクリプトをアタッチする
##   2. Chart が空なら、同じシーンの BeatConductor の Chart を使う
##   3. Preview Time(秒)か Preview Bar(小節)を動かす。Playing をオンにすると、曲と一緒に進む
##
## 砲口は、シーン内の EnemyShooter の位置を使う(ボスは Boss Screen Position に止まっている前提)。
## 画面の枠は、Stage Scene の Camera2D に映る範囲(ゲーム中と同じ)。座標は全てステージのワールド座標。

@export var chart : BeatChart :
	set(value):
		chart = value
		queue_redraw()
## 曲の頭からの秒数
@export_range(0.0, 600.0, 0.01) var preview_time : float = 0.0 :
	set(value):
		preview_time = value
		if not _syncing:
			if _player and _player.playing:
				_player.seek(value) # 再生中に動かしたら、曲もその位置へ
			var target := _chart()
			if target:
				_syncing = true
				preview_bar = target.time_to_bar_beat(value)["bar"]
				_syncing = false
		queue_redraw()
## 小節で時刻を指定する(1 から)。動かすと Preview Time が、その小節の頭になる
@export var preview_bar : int = 1 :
	set(value):
		preview_bar = maxi(value, 1)
		var target := _chart()
		if target and not _syncing:
			preview_time = maxf(target.bar_beat_to_time(preview_bar, 1.0), 0.0)
@export var playing : bool = false :
	set(value):
		playing = value
		_update_player()
## オンなら、再生中にボスの曲を鳴らす
@export var play_music : bool = true :
	set(value):
		play_music = value
		_update_player()
@export_range(0.1, 2.0, 0.05) var play_speed : float = 1.0

@export_group("表示")
## 画面の範囲を取るステージのシーン(その Camera2D に映る範囲を、画面の枠にする)。空なら Camera2D なしの画面
@export var stage_scene : PackedScene :
	set(value):
		stage_scene = value
		queue_redraw()
## ステージの中で、ボスのシーンの原点がどこにいるか(ワールド座標)
@export var boss_screen_position : Vector2 = Vector2(240.0, 200.0)
## 自機の位置(ワールド座標)
@export var player_position : Vector2 = Vector2(240.0, 520.0)
@export var bullet_radius : float = 3.0
@export var max_bullets : int = 3000
@export var show_cue_list : bool = true

const BULLET_LIFETIME : float = 12.0
const REFRESH_INTERVAL : float = 0.3

var _player : AudioStreamPlayer
var _syncing : bool = false
var _refresh_timer : float = 0.0
var _schedule : Array[Dictionary] = []
var _schedule_chart : BeatChart
var _motion_cache : Dictionary = {}

func _ready() -> void:
	if not Engine.is_editor_hint():
		set_process(false)
		hide()

func _exit_tree() -> void:
	if _player:
		_player.stop()

func _process(delta : float) -> void:
	if not Engine.is_editor_hint():
		return
	if playing:
		_syncing = true
		if _player and _player.playing:
			preview_time = _player.get_playback_position() + AudioServer.get_time_since_last_mix()
		else:
			preview_time += delta * play_speed
		var target := _chart()
		if target:
			preview_bar = target.time_to_bar_beat(preview_time)["bar"]
		_syncing = false
	_refresh_timer += delta
	if _refresh_timer >= REFRESH_INTERVAL:
		_refresh_timer = 0.0
		_schedule_chart = null # 譜面の編集に追従する
		_motion_cache.clear()
		queue_redraw()

## 再生の状態に合わせて、曲を鳴らす・止める(エディタの中だけ)
func _update_player() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	var target := _chart()
	var want := playing and play_music and target != null and target.music != null
	if not want:
		if _player:
			_player.stop()
		return
	if _player == null:
		_player = AudioStreamPlayer.new()
		add_child(_player) # owner を付けないので、シーンには保存されない
	_player.stream = target.music
	_player.pitch_scale = play_speed
	_player.play(preview_time)

## Chart が空なら、同じシーンの BeatConductor の Chart
func _chart() -> BeatChart:
	if chart:
		return chart
	var root := _scene_root()
	if root:
		for node in root.find_children("*", "Node", true, false):
			if node.get_script() == BeatConductor:
				return node.get("chart") as BeatChart
	return null

func _scene_root() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().edited_scene_root if Engine.is_editor_hint() else owner

# ---------------------------------------------------------------- 描画

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var screen := CameraView.packed_scene_rect(stage_scene)
	var root := _scene_root()
	# ステージのワールド座標 → このノードの座標
	var origin := (to_local(root.global_position) if root is Node2D else Vector2.ZERO) - boss_screen_position
	draw_rect(Rect2(origin + screen.position, screen.size), Color(1.0, 1.0, 1.0, 0.7), false, 2.0)
	draw_circle(origin + player_position, 5.0, Color(0.4, 0.8, 1.0, 0.8))

	var target := _chart()
	if target == null:
		_text(origin + screen.position + Vector2(12.0, 24.0), "Chart に BeatChart を割り当てるか、シーンに BeatConductor を置いてください", Color(1.0, 0.8, 0.4))
		return
	if _schedule_chart != target:
		_schedule = target.build_schedule()
		_schedule_chart = target

	var shooters := _shooters(root)
	for shooter_name in shooters:
		draw_circle(origin + shooters[shooter_name], 5.0, Color(1.0, 0.8, 0.3))
		_text(origin + shooters[shooter_name] + Vector2(6.0, -6.0), shooter_name, Color(1.0, 0.8, 0.3, 0.8))

	var drawn := _draw_bullets(target, shooters, origin, screen)
	_draw_beat_info(target, origin, screen, drawn)
	if show_cue_list:
		_draw_cue_list(target, origin + screen.position)

func _draw_bullets(target : BeatChart, shooters : Dictionary, origin : Vector2, screen : Rect2) -> int:
	var visible_rect := screen.grow(16.0)
	var drawn := 0
	for shot in target.shots_between(_schedule, preview_time - BULLET_LIFETIME, preview_time):
		var pattern : ShotPattern = shot["pattern"]
		var table := _motion_table(pattern)
		var age : float = preview_time - shot["time"]
		var names : Array = shooters.keys() if shot["shooter"] == "" else [shot["shooter"]]
		var excluded : PackedStringArray = shot["except"]
		for shooter_name in names:
			if not shooters.has(shooter_name) or excluded.has(shooter_name):
				continue
			var muzzle : Vector2 = shooters[shooter_name]
			var aim_angle := (player_position - muzzle).angle()
			for bullet in ShotMath.bullets(pattern, shot["index"], aim_angle):
				var point := ShotMath.bullet_position(pattern, table, bullet["angle"], bullet["speed_scale"], age,
						muzzle + bullet["offset"], player_position)
				if not visible_rect.has_point(point):
					continue
				draw_circle(origin + point, bullet_radius, _cue_color(shot["cue"], target))
				drawn += 1
				if drawn >= max_bullets:
					return drawn
	return drawn

## 小節・拍と、メトロノーム(今の拍が光る)
func _draw_beat_info(target : BeatChart, origin : Vector2, screen : Rect2, drawn : int) -> void:
	var bar_beat := target.time_to_bar_beat(preview_time)
	var bar : int = bar_beat["bar"]
	var beat : float = bar_beat["beat"]
	var y := origin.y + screen.end.y - 12.0
	var left := origin.x + screen.position.x
	_text(Vector2(left + 12.0, y), "%d 小節 %.2f 拍 / %.2f 秒 / BPM %.1f / 弾 %d発" % [bar, beat, preview_time, target.bpm, drawn], Color.WHITE)
	if preview_time < target.first_beat_offset:
		return
	var beats := maxi(target.beats_per_bar, 1)
	for i in beats:
		var center := Vector2(left + 20.0 + i * 18.0, y - 22.0)
		var lit := i == floori(beat - 1.0)
		var flash := 1.0 - fposmod(beat - 1.0, 1.0) # 拍の頭で一番明るい
		var color := Color(1.0, 0.45, 0.3) if i == 0 else Color(0.9, 0.9, 0.9)
		draw_circle(center, 6.0, Color(color, 0.25 + 0.75 * flash) if lit else Color(color, 0.15))

## 譜面の行の一覧。今撃っている行を明るくする
func _draw_cue_list(target : BeatChart, origin : Vector2) -> void:
	var y := origin.y + 24.0
	var t := _loop_local_time(target)
	for window in target.cue_windows():
		var cue : BeatCue = window["cue"]
		var active : bool = t >= window["start"] and t < window["end"]
		var pattern_name := cue.pattern.resource_path.get_file().get_basename() if cue.pattern and cue.pattern.resource_path != "" \
				else ("(休み)" if cue.pattern == null else "(埋め込み)")
		var line := "%d小節 %.1f拍  %s  %s  %s" % [cue.bar, cue.beat, cue.shooter if cue.shooter != "" else "全砲口", pattern_name, cue.note]
		_text(Vector2(origin.x + 12.0, y), ("▶ " if active else "   ") + line,
				Color(_cue_color(cue, target), 1.0 if active else 0.45))
		y += 16.0

## ループする譜面で、今の時刻を1周目の時刻に直す(行の一覧の表示用)
func _loop_local_time(target : BeatChart) -> float:
	if not target.is_looping() or preview_time < target.loop_end_time():
		return preview_time
	var start := target.loop_start_time()
	return start + fposmod(preview_time - start, target.loop_end_time() - start)

func _cue_color(cue : BeatCue, target : BeatChart) -> Color:
	var index := target.cues.find(cue)
	return Color.from_hsv(fmod(0.55 + index * 0.13, 1.0), 0.5, 1.0, 0.9)

## シーン内の EnemyShooter の、ゲーム画面での位置(名前 → 位置)
func _shooters(root : Node) -> Dictionary:
	var result := {}
	if root == null:
		return result
	var root_position := (root as Node2D).global_position if root is Node2D else Vector2.ZERO
	for node in root.find_children("*", "Node2D", true, false):
		if node.get_script() == EnemyShooter:
			result[String(node.name)] = boss_screen_position + ((node as Node2D).global_position - root_position)
	return result

func _motion_table(pattern : ShotPattern) -> Array[Dictionary]:
	if not _motion_cache.has(pattern):
		_motion_cache[pattern] = ShotMath.motion_table(pattern)
	return _motion_cache[pattern]


func _text(at : Vector2, text : String, color : Color) -> void:
	var font := ThemeDB.fallback_font
	draw_string(font, at + Vector2(1.0, 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color(0.0, 0.0, 0.0, 0.8))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, color)
