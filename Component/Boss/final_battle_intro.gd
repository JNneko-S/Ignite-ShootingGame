extends Node
class_name FinalBattleIntro
## ラスボスの登場の演出(最終決戦)。ラスボス(Enemy)の子に置く。
##   1. 中枢が鳴動する: 画面が揺れ続け、色が抜けて赤く縁取られ、陽炎が立つ。コアから光の筋が回りながら伸びる
##   2. ラスボスがコアから浮上してくる(移動パターンで動く)
##   3. 覚醒: 白く光って一瞬止まり、ボスから衝撃波が広がる。色ずれが走り、朱と白の火花が全方位へ弾け、光の輪と二つ目の衝撃波が続く
##   4. そのあと、戦いのあいだずっと、画面の縁が赤く脈打ち、陽炎がゆれる(ボスを倒すと消える)
## 演出のあいだ、敵は撃たない。

const FX_SHADER := preload("res://Shaders/final_battle_fx.gdshader")

## 鳴動の時間(秒)。このあと覚醒する
@export var rumble_time : float = 4.2
## 覚醒してから、撃ち始めるまでの時間(秒)
@export var awaken_time : float = 1.6
@export_group("色")
@export var accent_color : Color = Color(0.92, 0.16, 0.08)
@export var ink_color : Color = Color(0.08, 0.05, 0.05)
@export var paper_color : Color = Color(1.0, 0.97, 0.92)
@export_group("戦いのあいだの画面")
## 赤い縁取りの濃さ・陽炎の強さ・色ずれ・色を抜く量
@export var battle_vignette : float = 0.38
@export var battle_heat : float = 0.18
@export var battle_aberration : float = 0.002
@export var battle_desaturate : float = 0.12

var _enemy : Enemy
var _fx_layer : CanvasLayer
var _fx : ShaderMaterial
var _rays : CoreRays
var _embers : CPUParticles2D
var _ended : bool = false

func _ready() -> void:
	_enemy = get_parent() as Enemy
	if _enemy == null:
		return
	_enemy.died.connect(_on_died)
	_play.call_deferred()

func _play() -> void:
	var tree := get_tree()
	EnemyShooter.hold_fire(rumble_time + awaken_time + 1.0)
	_build_fx()
	# 1. 鳴動
	var calm := create_tween().set_parallel(true)
	calm.tween_method(_set_param.bind("vignette"), 0.0, 0.65, 1.5)
	calm.tween_method(_set_param.bind("desaturate"), 0.0, 0.35, 1.5)
	calm.tween_method(_set_param.bind("heat"), 0.0, 0.7, 1.5)
	calm.tween_method(_set_param.bind("pulse"), 0.0, 1.0, 1.5)
	create_tween().tween_property(_rays, "power", 1.0, rumble_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var camera := StageCamera.of(_enemy)
	var left := rumble_time
	while left > 0.0 and not _ended:
		if camera:
			camera.shake(2.0 + 4.0 * (1.0 - left / rumble_time), 0.3)
		await tree.create_timer(0.25, false).timeout
		left -= 0.25
	if _ended:
		return
	# 3. 覚醒
	ScreenFlash.play(tree, 1.0)
	HitStop.apply(tree, 0.18)
	if camera:
		camera.shake(14.0, 1.0)
	_fx.set_shader_parameter("wave_center", _screen_uv(_enemy.global_position))
	var burst := create_tween().set_parallel(true)
	burst.tween_method(_set_param.bind("wave_radius"), 0.0, 1.3, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	burst.tween_method(_set_param.bind("wave_strength"), 0.06, 0.0, 1.0)
	burst.tween_method(_set_param.bind("aberration"), 0.035, battle_aberration, 1.2)
	burst.tween_property(_rays, "power", 0.0, 1.0)
	burst.tween_property(_rays, "spread", 2.5, 1.0).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	Explosion.spawn(tree, Explosion.WAVE, _enemy.global_position, 2.5)
	await _awaken_vfx()
	if _ended:
		return
	# 4. 戦いのあいだの画面
	var settle := create_tween().set_parallel(true)
	settle.tween_method(_set_param.bind("vignette"), 0.65, battle_vignette, 1.0)
	settle.tween_method(_set_param.bind("desaturate"), 0.35, battle_desaturate, 1.0)
	settle.tween_method(_set_param.bind("heat"), 0.7, battle_heat, 1.0)

## 画面の効果の層を作る(ゲーム画面の上、文字の下)
func _build_fx() -> void:
	_fx_layer = CanvasLayer.new()
	_fx_layer.layer = 5
	add_child(_fx_layer)
	var rect := ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fx = ShaderMaterial.new()
	_fx.shader = FX_SHADER
	var size := get_viewport().get_visible_rect().size
	_fx.set_shader_parameter("aspect", size.x / size.y)
	_fx.set_shader_parameter("vignette_color", Color(accent_color.darkened(0.45), 1.0))
	rect.material = _fx
	_fx_layer.add_child(rect)
	# コアから伸びる光の筋(画面の真ん中の下から)
	_rays = CoreRays.new()
	_rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rays.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rays.color = accent_color
	_fx_layer.add_child(_rays)

func _set_param(value, key : String) -> void:
	if _fx:
		_fx.set_shader_parameter(key, value)

func _screen_uv(world : Vector2) -> Vector2:
	var screen := get_viewport().get_canvas_transform() * world
	return screen / get_viewport().get_visible_rect().size

## 覚醒の VFX(文字は使わない): 朱と白の火花が全方位へ弾け、少し遅れて二つ目の衝撃波と、光の輪が広がる。
## そのあと、戦いのあいだずっと、画面の下から火の粉が舞い上がる
func _awaken_vfx() -> void:
	var tree := get_tree()
	var at := _enemy.global_position
	# 火花: 白 → 橙 → 朱 → 消える。全方位へ一気に弾けて、減速しながら散る
	_spark_burst(at, 200, 260.0, 560.0, 1.4, 8.0)
	_spark_burst(at, 100, 80.0, 220.0, 2.0, 11.0)
	# 光の輪(広がりながら細く薄くなる)
	var ring := ShockRing.new()
	ring.color = accent_color.lightened(0.3)
	ring.z_index = 40
	tree.current_scene.add_child(ring)
	ring.global_position = at
	var grow := ring.create_tween().set_parallel(true)
	grow.tween_property(ring, "radius", 520.0, 0.9).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	grow.tween_property(ring, "thickness", 1.0, 0.9).from(26.0)
	grow.tween_property(ring, "modulate:a", 0.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	grow.chain().tween_callback(ring.queue_free)
	# 二つ目の衝撃波
	await tree.create_timer(0.35, false).timeout
	if _ended:
		return
	var camera := StageCamera.of(_enemy)
	if camera:
		camera.shake(8.0, 0.5)
	_fx.set_shader_parameter("wave_center", _screen_uv(_enemy.global_position))
	var second := create_tween().set_parallel(true)
	second.tween_method(_set_param.bind("wave_radius"), 0.0, 1.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	second.tween_method(_set_param.bind("wave_strength"), 0.035, 0.0, 0.8)
	_spark_burst(_enemy.global_position, 90, 300.0, 620.0, 1.0, 7.0)
	_start_embers()
	await tree.create_timer(awaken_time, false).timeout

## 全方位へ弾ける火花
func _spark_burst(at : Vector2, amount : int, speed_min : float, speed_max : float, life : float, size : float) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 1.0
	p.direction = Vector2.UP
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = speed_min
	p.initial_velocity_max = speed_max
	p.damping_min = speed_min * 0.6
	p.damping_max = speed_max * 0.8
	p.scale_amount_min = size * 0.5
	p.scale_amount_max = size
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = curve
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 1.0, 0.95, 1.0))
	ramp.set_color(1, Color(accent_color, 0.0))
	ramp.add_point(0.25, Color(1.0, 0.7, 0.3, 1.0))
	ramp.add_point(0.6, Color(accent_color, 0.9))
	p.color_ramp = ramp
	p.z_index = 40
	get_tree().current_scene.add_child(p)
	p.global_position = at
	p.emitting = true
	get_tree().create_timer(life + 0.5, false).timeout.connect(p.queue_free)

## 戦いのあいだ、画面の下から舞い上がる火の粉(画面に貼り付けて、ゆらゆら昇る)
func _start_embers() -> void:
	if _fx_layer == null:
		return
	var size := get_viewport().get_visible_rect().size
	var p := CPUParticles2D.new()
	p.amount = 46
	p.lifetime = 4.5
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(size.x * 0.55, 6.0)
	p.position = Vector2(size.x * 0.5, size.y + 10.0)
	p.direction = Vector2.UP
	p.spread = 18.0
	p.gravity = Vector2(0.0, -12.0)
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 75.0
	p.orbit_velocity_min = -0.02
	p.orbit_velocity_max = 0.02
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.85, 0.5, 0.0))
	ramp.set_color(1, Color(accent_color, 0.0))
	ramp.add_point(0.15, Color(1.0, 0.75, 0.35, 0.9))
	ramp.add_point(0.7, Color(accent_color, 0.6))
	p.color_ramp = ramp
	_fx_layer.add_child(p)
	_embers = p

## 広がる光の輪
class ShockRing extends Node2D:
	var color : Color = Color.WHITE
	var radius : float = 0.0:
		set(value):
			radius = value
			queue_redraw()
	var thickness : float = 20.0

	func _draw() -> void:
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 96, color, thickness)
		draw_arc(Vector2.ZERO, radius * 0.92, 0.0, TAU, 96, Color(1.0, 1.0, 1.0, 0.6), maxf(thickness * 0.3, 1.0))

## ラスボスを倒した: 画面の効果を消す
func _on_died(_e : Enemy) -> void:
	_ended = true
	if _fx == null:
		return
	var fade := create_tween().set_parallel(true)
	for key in ["vignette", "heat", "aberration", "desaturate", "wave_strength"]:
		var from = _fx.get_shader_parameter(key)
		fade.tween_method(_set_param.bind(key), float(from) if from != null else 0.0, 0.0, 1.5)
	if _rays:
		fade.tween_property(_rays, "power", 0.0, 0.5)
	fade.chain().tween_callback(func() -> void:
		if is_instance_valid(_fx_layer):
			_fx_layer.queue_free())

## コアから回りながら伸びる光の筋(画面の真ん中の下から放射状に)
class CoreRays extends Control:
	var color : Color = Color.RED
	var power : float = 0.0:
		set(value):
			power = value
			queue_redraw()
	var spread : float = 1.0
	var _time : float = 0.0

	func _process(delta : float) -> void:
		_time += delta
		if power > 0.01:
			queue_redraw()

	func _draw() -> void:
		if power <= 0.01:
			return
		var origin := Vector2(size.x * 0.5, size.y * 0.95)
		var reach := size.length() * spread
		for i in 14:
			var angle := -PI * 0.5 + sin(_time * 0.7 + i * 1.7) * 1.3 + (i - 7) * 0.16
			var half := 0.025 + 0.02 * sin(_time * 3.0 + i)
			var a := Vector2.from_angle(angle - half) * reach
			var b := Vector2.from_angle(angle + half) * reach
			var alpha := power * (0.18 + 0.12 * sin(_time * 6.0 + i * 2.3))
			draw_colored_polygon(PackedVector2Array([origin, origin + a, origin + b]), Color(color.lightened(0.3), alpha))
		draw_circle(origin, 40.0 * power, Color(1.0, 0.9, 0.8, 0.5 * power))
