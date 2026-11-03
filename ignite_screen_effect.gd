extends Node2D
class_name IgniteScreenEffect
## イグナイトの画面演出。シーン(GameScene/Effect/ignite_screen_effect.tscn)で使い、GameManager が作る。
##   発動の瞬間: 自機から衝撃波のリングが広がる + ヒットストップ(一瞬だけ時間がほぼ止まる)
##   発動中    : 画面の四辺が光る。光の太さは残り時間に合わせて細くなり、終わり際は点滅する
##   終了      : 光がすっと消える
##
## 見た目: 衝撃波は子の Sprite2D(Wave)に Texture を入れると、それを広げる。空なら円を描く。
##         画面のふちの光は子の EdgeGlow(ColorRect)のシェーダーで描く。色や太さはシェーダーの値でも変えられる。

@export_group("衝撃波")
## リングが広がりきるまでの時間(秒)
@export var wave_time : float = 0.35
## リングの色と太さ(px)
@export var wave_color : Color = Color(1.0, 0.6, 0.2)
@export var wave_width : float = 6.0
## 半径の最小(焼却範囲が小さいときでも、これくらいは広がる)
@export var wave_min_radius : float = 90.0

@export_group("ヒットストップ")
## 時間を遅くする長さ(実際の秒)と、その間の速さ(0.05 なら 1/20)
@export var hitstop_time : float = 0.08
@export_range(0.0, 1.0, 0.01) var hitstop_scale : float = 0.05

@export_group("画面のふち")
## 光の色
@export var edge_color : Color = Color(1.0, 0.45, 0.1)
## 光の太さ(画面の幅に対する割合)。残り時間が減ると、end_thickness まで細くなる
@export var start_thickness : float = 0.14
@export var end_thickness : float = 0.04
## 光の強さ
@export var edge_intensity : float = 0.85
## 残りがこの秒数を切ったら点滅する
@export var blink_time : float = 0.5
## 終わったときに消えるまでの時間(秒)
@export var fade_out_time : float = 0.2

@onready var _edge : ColorRect = $Layer/EdgeGlow
@onready var _wave_sprite : Sprite2D = get_node_or_null("Wave") as Sprite2D

var _active : bool = false
var _duration : float = 1.0
var _time_left : float = 0.0
var _wave_age : float = -1.0
var _wave_radius : float = 0.0
var _edge_strength : float = 0.0 # 0〜1。発動中は 1、消えるときに 0 へ
var _fade_tween : Tween
var _hitstop_token : int = 0

func _ready() -> void:
	top_level = true
	z_index = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_edge(0.0, start_thickness)
	if _wave_sprite:
		_wave_sprite.visible = false

## 発動。at は衝撃波の中心(画面の座標)、radius は焼却範囲の半径、duration は効果時間(秒)
func start(at : Vector2, radius : float, duration : float) -> void:
	_active = true
	_duration = maxf(duration, 0.01)
	_time_left = _duration
	global_position = at
	_wave_radius = maxf(radius, wave_min_radius)
	_wave_age = 0.0
	if _fade_tween:
		_fade_tween.kill()
	_edge_strength = 1.0
	_hitstop()

## 終了(時間切れ・死亡)。光を消す
func stop() -> void:
	if not _active:
		return
	_active = false
	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "_edge_strength", 0.0, fade_out_time)

func _process(delta : float) -> void:
	var game_delta := delta * Engine.time_scale # ヒットストップ中は、演出もゆっくり
	if _active:
		_time_left = maxf(_time_left - game_delta, 0.0)
	var ratio := _time_left / _duration
	var thickness := lerpf(end_thickness, start_thickness, ratio)
	var blink := 1.0
	if _active and _time_left < blink_time:
		blink = 0.45 + 0.55 * absf(cos(_time_left * TAU * 4.0)) # 終わり際は点滅
	_apply_edge(_edge_strength * blink, thickness)
	_update_wave(delta) # 衝撃波はヒットストップ中も広がる(止まった時間の中で広がる)

func _apply_edge(strength : float, thickness : float) -> void:
	var mat := _edge.material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("glow_color", edge_color)
	mat.set_shader_parameter("intensity", strength * edge_intensity)
	mat.set_shader_parameter("thickness", thickness)
	_edge.visible = strength > 0.001

func _update_wave(delta : float) -> void:
	if _wave_age < 0.0:
		return
	_wave_age += delta
	var t := _wave_age / wave_time
	if t >= 1.0:
		_wave_age = -1.0
		if _wave_sprite:
			_wave_sprite.visible = false
	elif _wave_sprite and _wave_sprite.texture:
		var eased := 1.0 - pow(1.0 - t, 3.0)
		var tex_radius := maxf(_wave_sprite.texture.get_size().x * 0.5, 1.0)
		_wave_sprite.visible = true
		_wave_sprite.scale = Vector2.ONE * (_wave_radius * eased / tex_radius)
		_wave_sprite.modulate = Color(wave_color, 1.0 - t)
	queue_redraw()

func _draw() -> void:
	if _wave_age < 0.0 or (_wave_sprite and _wave_sprite.texture):
		return
	var t := clampf(_wave_age / wave_time, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - t, 3.0) # 最初が速く、だんだん遅く
	var radius := _wave_radius * eased
	var alpha := 1.0 - t
	draw_circle(Vector2.ZERO, radius, Color(wave_color, 0.12 * alpha)) # 内側をうっすら
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 96, Color(wave_color, alpha), wave_width * (1.0 - t * 0.5), true)
	draw_arc(Vector2.ZERO, radius * 0.92, 0.0, TAU, 96, Color(1.0, 1.0, 1.0, alpha * 0.6), 2.0, true)

## 一瞬だけ、ゲームの時間をほぼ止める
func _hitstop() -> void:
	if hitstop_time <= 0.0:
		return
	_hitstop_token += 1
	var token := _hitstop_token
	Engine.time_scale = hitstop_scale
	await get_tree().create_timer(hitstop_time, true, false, true).timeout # 実際の時間で数える
	if token == _hitstop_token: # 続けて発動したときは、最後のものが戻す
		Engine.time_scale = 1.0

func _exit_tree() -> void:
	Engine.time_scale = 1.0
