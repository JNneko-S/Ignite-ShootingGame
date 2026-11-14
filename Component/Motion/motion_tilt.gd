extends Node
class_name MotionTilt
## 動きに合わせて機体の絵を傾ける部品。敵(や、動く Node2D)の子に置く。
##   向き: 進む方向へ機首(絵の下側)を向ける。Face Mode で「少し傾ける」か「進む向きへ完全に向く」を選ぶ
##   ロール: 曲がるときや横へ流れるときに、bank_tilt シェーダーで機体を斜めに倒して見せる
##           (曲がる内側の翼が奥へ沈み、暗くなる)
## 絵は機首が下向きの前提(ロールだけなら、機首が上の自機でも使える: Face Mode を NONE、Bank Per Turn を 0 に)。
## Target の Material が空なら、シェーダーを自動で付ける。
## 親が CharacterBody2D(自機など)なら、物理フレームで動きを測る(画面のフレームと物理フレームの差でガタつかないように)。

enum FaceMode { NONE, LEAN, FULL }

## 傾ける絵。空なら、親の "Sprite2D"
@export var target : Node2D
## 向きの変え方
##   NONE: 向きは変えない(ロールだけ)
##   LEAN: 進む向きへ少しだけ傾ける(最大 Lean Max Deg まで)。止まるとまっすぐに戻る。編隊のザコ向け
##   FULL: 進む向きへ機首を完全に向ける。突撃してくる敵や、ぐるっと回り込む敵向け
@export var face_mode : FaceMode = FaceMode.LEAN
## LEAN のときの、最大の傾き(度)
@export var lean_max_deg : float = 35.0
## 向きが追いつく速さ(大きいほどキビキビ)
@export var turn_sharpness : float = 9.0
## この速さ(px/秒)より遅いときは、止まっているとみなす
@export var min_speed : float = 25.0

@export_group("ロール")
## 最大のロール(度)。0 ならロールしない。80 を超えると絵が細くなりすぎる
@export var bank_max_deg : float = 55.0
## 曲がる速さ 1 ラジアン/秒あたりのロール(度)。旋回で倒れる量
@export var bank_per_turn : float = 22.0
## 横へ流れるときのロール(度)。Bank Side Speed で横へ動いたときに、この角度まで倒れる
@export var bank_per_side : float = 35.0
@export var bank_side_speed : float = 250.0
## ロールが追いつく速さ
@export var bank_sharpness : float = 7.0
## 遠近感の強さ(px)。小さいほど立体的(シェーダーの focal)
@export var perspective : float = 140.0

const SHADER := preload("res://Component/Motion/bank_tilt.gdshader")

var _owner2d : Node2D
var _material : ShaderMaterial
var _base_rotation : float = 0.0
var _started : bool = false
var _last_pos : Vector2
var _velocity : Vector2 = Vector2.ZERO
var _heading : float = 0.0 # 進む向きの角度(ラジアン)。旋回の速さを測る
var _turn_rate : float = 0.0
var _face : float = 0.0 # 絵に足している回転
var _roll : float = 0.0
## 親が物理フレームで動く(CharacterBody2D)か
var _physics_owner : bool = false

func _ready() -> void:
	_owner2d = get_parent() as Node2D
	if target == null and _owner2d:
		target = _owner2d.get_node_or_null("Sprite2D") as Node2D
	if target == null:
		set_process(false)
		set_physics_process(false)
		return
	_physics_owner = _owner2d is CharacterBody2D
	set_process(not _physics_owner)
	set_physics_process(_physics_owner)
	_setup_material()

## 敵ごとに別のロールにするので、マテリアルは1体ずつ持つ
func _setup_material() -> void:
	if bank_max_deg <= 0.0:
		return
	var current := target.material as ShaderMaterial
	if current and current.shader == SHADER:
		_material = current.duplicate()
	elif target.material == null:
		_material = ShaderMaterial.new()
		_material.shader = SHADER
	else:
		push_warning("MotionTilt: %s には別の Material があるので、ロールは使いません" % target.get_path())
		return
	_material.set_shader_parameter("focal", perspective)
	target.material = _material

func _process(delta : float) -> void:
	_step(delta)

func _physics_process(delta : float) -> void:
	_step(delta)

func _step(delta : float) -> void:
	if delta <= 0.0 or not is_instance_valid(_owner2d):
		return
	var pos := _owner2d.global_position
	if not _started:
		# 最初のフレームで、元の回転を覚える(左右反転などが済んだあと)
		_started = true
		_last_pos = pos
		_base_rotation = target.rotation
		return
	var velocity_now := (pos - _last_pos) / delta
	_last_pos = pos
	_velocity = _velocity.lerp(velocity_now, 1.0 - exp(-14.0 * delta))
	var speed := _velocity.length()
	var moving := speed > min_speed

	# 旋回の速さ(ラジアン/秒)
	var turn_now := 0.0
	if moving:
		var heading_now := _velocity.angle()
		turn_now = angle_difference(_heading, heading_now) / delta
		_heading = heading_now
	_turn_rate = lerpf(_turn_rate, turn_now, 1.0 - exp(-10.0 * delta))

	# 向き
	var face_target := _face
	match face_mode:
		FaceMode.NONE:
			face_target = 0.0
		FaceMode.LEAN:
			face_target = 0.0
			if moving:
				# 機首は下のまま、横へ傾く(上へ戻るときも機首は下)
				var dir := Vector2(_velocity.x, absf(_velocity.y))
				var limit := deg_to_rad(lean_max_deg)
				face_target = clampf(dir.angle() - PI * 0.5, -limit, limit)
		FaceMode.FULL:
			if moving:
				face_target = _velocity.angle() - PI * 0.5 # 絵の機首は下(+y)
	_face = lerp_angle(_face, face_target, 1.0 - exp(-turn_sharpness * delta))
	target.rotation = _base_rotation + _face

	# ロール: 曲がる内側へ倒れる + 横へ流れる向きへ倒れる
	if _material:
		var side_axis := Vector2.RIGHT.rotated(target.global_rotation) # 絵の +x の向き(画面上)
		var side := 0.0
		if moving:
			side = clampf(_velocity.dot(side_axis) / maxf(bank_side_speed, 1.0), -1.0, 1.0)
		var wanted := -_turn_rate * deg_to_rad(bank_per_turn) + side * deg_to_rad(bank_per_side)
		var limit_roll := deg_to_rad(bank_max_deg)
		wanted = clampf(wanted, -limit_roll, limit_roll)
		_roll = lerpf(_roll, wanted, 1.0 - exp(-bank_sharpness * delta))
		_material.set_shader_parameter("roll", _roll)
