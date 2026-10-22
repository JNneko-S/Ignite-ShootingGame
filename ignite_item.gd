extends Node2D
class_name IgniteItem
## 被弾時に散らばる、イグナイトゲージの補給アイテム。
## 少し散らばってから、自機に吸い寄せられ、触れるとゲージが増える。

signal collected(amount : float)

const MAGNET_DELAY : float = 0.45
const PICKUP_RADIUS : float = 14.0
const LIFETIME : float = 9.0

var amount : float = 6.0
var _velocity : Vector2 = Vector2.ZERO
var _age : float = 0.0
var _player : Node2D
var _done : bool = false

func setup(player : Node2D, value : float, burst_velocity : Vector2) -> void:
	_player = player
	amount = value
	_velocity = burst_velocity
	z_index = 5

func _ready() -> void:
	scale = Vector2.ZERO
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.2)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _physics_process(delta : float) -> void:
	if _done:
		return
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	if _age > LIFETIME - 2.0:
		modulate.a = 0.4 + 0.6 * absf(sin(_age * 12.0)) # 消える前の点滅

	var can_chase := is_instance_valid(_player) and _player.visible
	if can_chase and _age > MAGNET_DELAY:
		var to_player := _player.global_position - global_position
		var speed := minf(220.0 + (_age - MAGNET_DELAY) * 900.0, 900.0)
		_velocity = _velocity.lerp(to_player.normalized() * speed, 1.0 - exp(-10.0 * delta))
		if to_player.length() <= PICKUP_RADIUS:
			_collect()
			return
	else:
		_velocity = _velocity.move_toward(Vector2.ZERO, 260.0 * delta) # 散らばりながら減速
	global_position += _velocity * delta
	rotation += delta * 4.0

func _collect() -> void:
	_done = true
	collected.emit(amount)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.8, 1.8), 0.12)
	tween.tween_property(self, "modulate:a", 0.0, 0.12)
	tween.chain().tween_callback(queue_free)

func _draw() -> void:
	var pts := PackedVector2Array([Vector2(0, -8), Vector2(6, 0), Vector2(0, 8), Vector2(-6, 0)])
	draw_circle(Vector2.ZERO, 11.0, Color(1.0, 0.5, 0.1, 0.25))
	draw_colored_polygon(pts, Color(1.0, 0.75, 0.25))
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color(1.0, 0.95, 0.7), 1.5)
