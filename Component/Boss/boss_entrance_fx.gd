extends Node
class_name BossEntranceFx
## ボス・中ボスの登場の演出(文字は使わない)。StageRunner が、ボス(Is Boss)を出したときに子として付ける。
##   1. 画面の縁が、ボスの色で1回脈打つ
##   2. ボスが画面に入りきったところで、白く光り、光の輪が2重に広がって、火花が全方位へ弾ける。画面が揺れる
## ラスボス(FinalBattleIntro を持つ)には付けない(専用の演出があるので)。

## 画面に入ってから、光るまでの時間(秒)。入ってこないときは、この時間で光る
@export var max_wait : float = 3.5
@export var color : Color = Color(0.95, 0.3, 0.12)

var _enemy : Node2D
var _time : float = 0.0
var _done : bool = false

func _ready() -> void:
	_enemy = get_parent() as Node2D
	_pulse_edges()

func _process(delta : float) -> void:
	if _done or not is_instance_valid(_enemy):
		return
	_time += delta
	var view := CameraView.visible_rect(_enemy)
	var inside := view.grow(-40.0).has_point(_enemy.global_position)
	if (inside and _time > 0.6) or _time >= max_wait:
		_done = true
		_burst()

## 画面の縁が、1回脈打つ
func _pulse_edges() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 8
	add_child(layer)
	var edges := EdgeGlow.new()
	edges.color = color
	edges.set_anchors_preset(Control.PRESET_FULL_RECT)
	edges.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(edges)
	var tween := create_tween()
	tween.tween_property(edges, "strength", 1.0, 0.35).set_trans(Tween.TRANS_SINE)
	tween.tween_property(edges, "strength", 0.0, 0.9).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(layer.queue_free)

func _burst() -> void:
	var tree := get_tree()
	var at := _enemy.global_position
	ScreenFlash.play(tree, 0.45)
	var camera := StageCamera.of(_enemy)
	if camera:
		camera.shake(6.0, 0.4)
	for i in 2:
		var ring := FinalBattleIntro.ShockRing.new()
		ring.color = color.lightened(0.25)
		ring.z_index = 40
		tree.current_scene.add_child(ring)
		ring.global_position = at
		var grow := ring.create_tween().set_parallel(true)
		grow.tween_property(ring, "radius", 260.0 + 140.0 * i, 0.6 + 0.2 * i).set_delay(0.12 * i).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		grow.tween_property(ring, "thickness", 1.0, 0.6 + 0.2 * i).from(14.0 - 4.0 * i).set_delay(0.12 * i)
		grow.tween_property(ring, "modulate:a", 0.0, 0.6 + 0.2 * i).set_delay(0.12 * i)
		grow.chain().tween_callback(ring.queue_free)
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.amount = 70
	p.lifetime = 0.9
	p.explosiveness = 1.0
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 180.0
	p.initial_velocity_max = 420.0
	p.damping_min = 200.0
	p.damping_max = 380.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.0
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = curve
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 1.0, 0.95, 1.0))
	ramp.set_color(1, Color(color, 0.0))
	ramp.add_point(0.4, Color(1.0, 0.65, 0.3, 1.0))
	p.color_ramp = ramp
	p.z_index = 40
	tree.current_scene.add_child(p)
	p.global_position = at
	p.emitting = true
	tree.create_timer(1.5, false).timeout.connect(p.queue_free)

## 画面の縁の光(内側へ向かって薄くなる)
class EdgeGlow extends Control:
	var color : Color = Color.RED
	var strength : float = 0.0:
		set(value):
			strength = value
			queue_redraw()

	func _draw() -> void:
		if strength <= 0.01:
			return
		for i in 12:
			var a := strength * 0.5 * (1.0 - i / 12.0)
			draw_rect(Rect2(Vector2(i * 3.0, i * 3.0), size - Vector2(i * 6.0, i * 6.0)), Color(color, a), false, 3.0)
