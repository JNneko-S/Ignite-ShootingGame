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
## 計算は EnemyShooter / EnemyBullet と同じ規則(連射、休止、回転、反転、列弾、ばらつき、Motion)。共通の計算は ShotMath にある。

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
## Timing Unit が BEATS のパターンで使うテンポ
@export var bpm : float = 150.0
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
	# Camera2D に映る範囲(ワールド座標)
	var screen := CameraView.scene_rect(get_tree().edited_scene_root if is_inside_tree() else null)
	draw_circle(Vector2.ZERO, 6.0, Color(1.0, 0.8, 0.3)) # 砲口
	var player_local := to_local(player_position)
	draw_circle(player_local, 5.0, Color(0.4, 0.8, 1.0, 0.8)) # 自機
	if pattern == null:
		_text(Vector2(12.0, -12.0), "Pattern に ShotPattern を割り当ててください", Color(1.0, 0.8, 0.4))
		return

	var drawn := 0
	var rect := Rect2(to_local(screen.position), screen.size).grow(80.0)
	var aim_angle := player_local.angle()
	var table := ShotMath.motion_table(pattern)
	for shot in ShotMath.shot_times(pattern, preview_time, 60.0 / maxf(bpm, 1.0)):
		var age : float = preview_time - shot["time"]
		if age > BULLET_LIFETIME:
			continue
		var fade := clampf(1.0 - age / BULLET_LIFETIME, 0.25, 1.0)
		for bullet in ShotMath.bullets(pattern, shot["index"], aim_angle):
			var point := ShotMath.bullet_position(pattern, table, bullet["angle"], bullet["speed_scale"], age,
					bullet["offset"], player_local)
			if not rect.has_point(point):
				continue
			draw_circle(point, bullet_radius, Color(0.55, 0.8, 1.0, fade))
			drawn += 1
			if drawn >= max_bullets:
				_text(Vector2(12.0, 16.0), "弾が多すぎるため、ここまでを表示(%d発)" % max_bullets, Color(1.0, 0.6, 0.4))
				return
	_text(Vector2(12.0, 16.0), "t = %.2f 秒 / 弾 %d発" % [preview_time, drawn], Color.WHITE)

func _text(at : Vector2, text : String, color : Color) -> void:
	var font := ThemeDB.fallback_font
	draw_string(font, at + Vector2(1.0, 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color(0.0, 0.0, 0.0, 0.8))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, color)
