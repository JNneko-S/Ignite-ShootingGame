extends Area2D
class_name AbsorbField
## 吸収フィールド。近づいた反射弾(イグナイトで跳ね返した敵弾)を吸い込んで消し、
## 吸った数に応じた弾を、少し後にまとめて撃ち返す。敵のシーンに子ノードとして置く。
##
## 反射弾は IgniteArea のレイヤー(9番、値 256)を持つので、それだけを拾う(自機の通常ショットは拾わない)。

signal absorbed(stored : int)
signal countered(bullet_count : int)

## フィールドの半径(px)
@export var radius : float = 56.0
## 撃ち返す弾幕。Bullet Count は、吸った数から決める
@export var counter_pattern : ShotPattern
## 撃ち返す砲口。空なら、親の EnemyShooter を探す
@export var shooter : EnemyShooter
## 1発吸うごとに、撃ち返す弾を何発増やすか
@export var bullets_per_absorb : int = 2
@export var min_bullets : int = 6
@export var max_bullets : int = 40
## 最後に吸ってから、撃ち返すまでの時間(秒)
@export var counter_delay : float = 0.6
## 拾うレイヤー(反射弾の IgniteArea)
@export_flags_2d_physics var absorb_mask : int = 256

var _stored : int = 0
var _quiet : float = 0.0
var _pulse : float = 0.0
## 撃ち返す弾幕の複製(Bullet Count だけを変えて使い回す)
var _counter_copy : ShotPattern

func _ready() -> void:
	collision_layer = 0
	collision_mask = absorb_mask
	monitorable = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	add_child(shape)
	area_entered.connect(_on_area_entered)
	if shooter == null:
		for node in get_parent().find_children("*", "", true, false):
			if node is EnemyShooter:
				shooter = node
				break

func _on_area_entered(area : Area2D) -> void:
	if not (area is EnemyBullet and area.is_ignited()):
		return
	_swallow(area)
	_stored += 1
	_quiet = 0.0
	_pulse = 1.0
	absorbed.emit(_stored)

## 弾を止めて、フィールドの中心へ吸い込んで消す(途中で敵に当たらないように、当たり判定を切る)
func _swallow(bullet : EnemyBullet) -> void:
	bullet.set_deferred("monitoring", false)
	bullet.set_deferred("monitorable", false)
	bullet.set_physics_process(false)
	var tween := bullet.create_tween().set_parallel(true)
	tween.tween_property(bullet, "global_position", global_position, 0.15)
	tween.tween_property(bullet, "scale", Vector2.ZERO, 0.15)
	tween.chain().tween_callback(bullet.queue_free)

func _process(delta : float) -> void:
	_pulse = move_toward(_pulse, 0.0, delta * 3.0)
	if _stored > 0:
		_quiet += delta
		if _quiet >= counter_delay:
			_counter()
	queue_redraw()

func _counter() -> void:
	var count := clampi(_stored * bullets_per_absorb, min_bullets, max_bullets)
	_stored = 0
	if counter_pattern == null or shooter == null:
		return
	if _counter_copy == null:
		_counter_copy = counter_pattern.duplicate() as ShotPattern
	_counter_copy.bullet_count = count
	shooter.fire_scheduled(_counter_copy, 0)
	countered.emit(count)

func _draw() -> void:
	# 吸った数が多いほど、輪が明るく太くなる
	var charge := clampf(float(_stored) / 10.0, 0.0, 1.0)
	var color := Color(0.75, 0.35, 1.0, 0.25 + 0.35 * charge + 0.4 * _pulse)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, color, 1.5 + 2.5 * charge)
	draw_circle(Vector2.ZERO, radius, Color(0.6, 0.25, 0.9, 0.05 + 0.08 * charge))
