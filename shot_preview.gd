@tool
extends Node2D
class_name ShotPreview
## 弾幕エディターの第1段階。ShotPattern の弾の動きを、エディタの2D画面に描いて確認する。
## 発射位置は、このノードの位置。ゲーム実行中は自分で消える。
##
## 使い方:
##   1. シーンに Node2D を追加して、このスクリプトをアタッチする(敵の砲口の位置に置くと分かりやすい)
##   2. Pattern に ShotPattern(.tres)を割り当てる
##   3. Preview Time を動かすか、Playing をオンにする
##   4. Player Position に、自機の位置を入れる(自機狙いの弾の向きに使う)
##
## 計算は EnemyShooter と同じ規則(連射、休止、回転、反転、加速度)。

@export var pattern : ShotPattern :
	set(value):
		pattern = value
		queue_redraw()
@export_range(0.0, 30.0, 0.05) var preview_time : float = 2.0 :
	set(value):
		preview_time = value
		queue_redraw()
@export var playing : bool = false
@export_range(0.1, 4.0, 0.1) var play_speed : float = 1.0
## 再生で、この秒数まで進んだら最初に戻る
@export var loop_length : float = 10.0
## 自機狙いの向きを決めるための、自機の位置(グローバル座標)
@export var player_position : Vector2 = Vector2(576.0, 560.0)
@export var bullet_radius : float = 4.0
## 描く弾の上限(多すぎると重くなる)
@export var max_bullets : int = 4000

const BULLET_LIFETIME : float = 12.0
const REFRESH_INTERVAL : float = 0.3

var _refresh : float = 0.0

func _ready() -> void:
	if not Engine.is_editor_hint():
		set_process(false)
		hide()

func _process(delta : float) -> void:
	if not Engine.is_editor_hint():
		return
	if playing:
		preview_time += delta * play_speed
		if preview_time > loop_length:
			preview_time = 0.0
	_refresh += delta
	if _refresh >= REFRESH_INTERVAL:
		_refresh = 0.0
		queue_redraw() # インスペクタでの編集に追従する

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var screen := Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width", 1152)),
		float(ProjectSettings.get_setting("display/window/size/viewport_height", 648)))
	draw_circle(Vector2.ZERO, 6.0, Color(1.0, 0.8, 0.3)) # 砲口
	var player_local := to_local(player_position)
	draw_circle(player_local, 5.0, Color(0.4, 0.8, 1.0, 0.8)) # 自機
	if pattern == null:
		_text(Vector2(12.0, -12.0), "Pattern に ShotPattern を割り当ててください", Color(1.0, 0.8, 0.4))
		return

	var drawn := 0
	var rect := Rect2(to_local(Vector2.ZERO), screen).grow(80.0)
	for shot in _shots_until(preview_time):
		var age : float = preview_time - shot["time"]
		if age > BULLET_LIFETIME:
			continue
		var travelled := _distance(age)
		var fade := clampf(1.0 - age / BULLET_LIFETIME, 0.25, 1.0)
		for angle in shot["angles"]:
			var point : Vector2 = Vector2.from_angle(angle) * travelled
			if not rect.has_point(point):
				continue
			draw_circle(point, bullet_radius, Color(0.55, 0.8, 1.0, fade))
			drawn += 1
			if drawn >= max_bullets:
				_text(Vector2(12.0, 16.0), "弾が多すぎるため、ここまでを表示(%d発)" % max_bullets, Color(1.0, 0.6, 0.4))
				return
	_text(Vector2(12.0, 16.0), "t = %.2f 秒 / 弾 %d発" % [preview_time, drawn], Color.WHITE)

## 時刻 until までに発射された弾を、発射ごとに返す
func _shots_until(until : float) -> Array[Dictionary]:
	var shots : Array[Dictionary] = []
	var t := pattern.start_delay
	var index := 0
	var guard := 0
	while t <= until and guard < 5000:
		for i in maxi(pattern.shot_count, 1):
			var fire_time := t + pattern.interval * i
			if fire_time > until:
				return shots
			shots.append({"time": fire_time, "angles": _angles(index)})
			index += 1
			guard += 1
		if not pattern.loop:
			return shots
		t += pattern.interval * maxi(pattern.shot_count, 1) + pattern.pause
		if pattern.interval <= 0.0 and pattern.pause <= 0.0:
			return shots # 時間が進まない設定で、無限ループしないように
	return shots

## shot_index 回目の発射で出る、全ての弾の角度(ラジアン)。EnemyShooter._fire と同じ計算
func _angles(shot_index : int) -> Array[float]:
	var base := Vector2.DOWN.angle()
	if pattern.aim_at_player:
		base = to_local(player_position).angle()
	base += deg_to_rad(pattern.base_angle + pattern.rotate_per_shot * _rotation_steps(shot_index))
	var count := maxi(pattern.bullet_count, 1)
	var is_ring := pattern.spread_angle >= 360.0
	var result : Array[float] = []
	for i in count:
		var offset := 0.0
		if count > 1:
			if is_ring:
				offset = 360.0 * i / count
			else:
				offset = -pattern.spread_angle / 2.0 + pattern.spread_angle * i / (count - 1)
		result.append(base + deg_to_rad(offset))
	return result

func _rotation_steps(shot_index : int) -> int:
	var n := pattern.reverse_every_shots
	if n <= 0:
		return shot_index
	var k := shot_index % (n * 2)
	return k if k < n else n * 2 - k

## 発射から age 秒後の、砲口からの距離(加速度で止まったら、そこで止まる)
func _distance(age : float) -> float:
	var v := pattern.bullet_speed
	var a := pattern.bullet_accel
	if a < 0.0:
		var stop := v / -a
		if age > stop:
			return v * stop + 0.5 * a * stop * stop
	return v * age + 0.5 * a * age * age

func _text(at : Vector2, text : String, color : Color) -> void:
	var font := ThemeDB.fallback_font
	draw_string(font, at + Vector2(1.0, 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color(0.0, 0.0, 0.0, 0.8))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, color)
