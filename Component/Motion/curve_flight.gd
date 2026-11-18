extends Node
class_name CurveFlight
## 敵を、FlightCurve(数式の曲線)に沿って飛ばす部品。StageRunner が、SpawnEvent の Flight Curve に合わせて付ける。
## 画面の上から曲線の上の自分の位置へ入ってきて、決まった周だけ曲線をなぞり、最後はその向きのまま画面の外へ抜けて消える。
## 何機目か(unit_index)で、曲線の上の位置をずらす(編隊で図形を描く)。機首の向きは MotionTilt に任せる。

var curve : FlightCurve
var unit_index : int = 0

var _enemy : Enemy
var _time : float = 0.0
var _center : Vector2
var _mirror : float = 1.0
var _entry : Vector2
var _velocity : Vector2 = Vector2.ZERO
var _leaving : bool = false

func _ready() -> void:
	_enemy = get_parent() as Enemy
	if _enemy == null or curve == null:
		queue_free()
		return
	# 移動パターンは使わない(親の _ready より先に呼ばれるので、まだ動き出していない)
	_enemy.pattern = null
	_center = _enemy._convert_absolute(curve.center)
	_mirror = -1.0 if _enemy.mirror_x else 1.0
	var first := _curve_position(0.0)
	var view := CameraView.visible_rect(_enemy)
	_entry = Vector2(first.x, view.position.y - 70.0)
	_enemy.global_position = _entry

## 曲線の上の位置(t 秒のとき)
func _curve_position(t : float) -> Vector2:
	var flight := maxf(curve.period * curve.turns, 0.01)
	var u := t / maxf(curve.period, 0.01) + unit_index * curve.phase_step
	var p := curve.point(u)
	var scale := lerpf(1.0, curve.end_scale, clampf(t / flight, 0.0, 1.0))
	p = p.rotated(deg_to_rad(curve.spin) * t) * scale
	p.x *= _mirror
	return _center + p

func _physics_process(delta : float) -> void:
	if not is_instance_valid(_enemy) or _enemy.is_wreck():
		return
	var before := _enemy.global_position
	if _leaving:
		_enemy.global_position += _velocity * delta
		if not CameraView.visible_rect(_enemy).grow(90.0).has_point(_enemy.global_position):
			_enemy.queue_free()
		return
	_time += delta
	var enter := maxf(curve.enter_time, 0.0)
	var t := _time - enter
	var pos : Vector2
	if t < 0.0:
		# 上から、曲線の上の自分の位置へ入ってくる(着いたときに曲線の動きへ、なめらかにつながるように)
		var w := smoothstep(0.0, 1.0, _time / maxf(enter, 0.01))
		pos = _entry.lerp(_curve_position(0.0), w)
	else:
		pos = _curve_position(t)
	_enemy.global_position = pos
	if delta > 0.0:
		_velocity = (pos - before) / delta
	if t >= curve.period * curve.turns:
		# なぞり終わった: その向きのまま抜けていく(遅すぎるときは、少し速く)
		_leaving = true
		var speed := maxf(_velocity.length(), 220.0)
		_velocity = (_velocity.normalized() if _velocity.length() > 1.0 else Vector2.DOWN) * speed
