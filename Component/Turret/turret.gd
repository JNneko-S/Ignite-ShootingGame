extends Node2D
class_name Turret
## 砲台の部品。砲台のノード(回転の中心)にアタッチする。本体とは別に動き、アニメーションも独立して再生できる。
##
## ・aim_at_player がオンなら、自機の方へゆっくり向く(rest_rotation から ±max_angle の範囲で)
## ・shooter を設定すると、その砲口の位置をこの砲台の Muzzle(子の Marker2D)に合わせて動かし、
##   撃つたびに、子の AnimationPlayer で fire_animation を再生する(反動など)
## ・子の AnimationPlayer は砲台ごとに持つので、本体の AnimationPlayer(車輪など)と同時に再生できる。
##   idle_animation があれば、最初から流しておく
##
## 絵は、砲身が下(+Y)を向いている前提。

## 撃つ砲口。撃つたびに fire_animation を再生する
@export var shooter : EnemyShooter
## true なら、自機の方へ向く
@export var aim_at_player : bool = true
## 向きを変える速さ(度/秒)
@export var turn_speed : float = 90.0
## 正面(rest_rotation)から、これ以上は曲がらない(度)
@export var max_angle : float = 70.0
## 正面の向き(度)。0 なら真下
@export var rest_rotation : float = 0.0

@export_group("アニメーション")
## 撃ったときに再生する(子の AnimationPlayer の中の名前)。空なら再生しない
@export var fire_animation : StringName = &"Fire"
## 最初から流しておく。空なら流さない
@export var idle_animation : StringName = &""

var _player_node : Node2D
var _anim : AnimationPlayer
var _muzzle : Node2D
## この砲台を含む部位(EnemyPart)。壊れたら動かなくなる
var _part : EnemyPart

func _ready() -> void:
	rotation = deg_to_rad(rest_rotation)
	var node := get_parent()
	while node and _part == null:
		_part = node as EnemyPart
		node = node.get_parent()
	for child in get_children():
		if child is AnimationPlayer and _anim == null:
			_anim = child
		elif child is Marker2D and _muzzle == null:
			_muzzle = child
	if shooter:
		shooter.fired.connect(_on_fired)
	if _anim and idle_animation != &"" and _anim.has_animation(idle_animation):
		_anim.play(idle_animation)
		# 撃ったときのアニメーションが終わったら、また流す
		_anim.animation_finished.connect(func(name : StringName) -> void:
			if name != idle_animation:
				_anim.play(idle_animation))

func _physics_process(delta : float) -> void:
	if _part and _part.is_destroyed():
		return # 壊れた砲台は、もう動かない
	if aim_at_player:
		_aim(delta)
	# 砲口を、回った砲身の先に合わせる
	if shooter and _muzzle:
		shooter.global_position = _muzzle.global_position

func _aim(delta : float) -> void:
	if not is_instance_valid(_player_node):
		_player_node = get_tree().get_first_node_in_group("player") as Node2D
		if _player_node == null:
			return
	# 砲身は下(+Y)向きの絵なので、自機への角度から 90 度引く
	var wanted := (_player_node.global_position - global_position).angle() - PI / 2.0 - get_parent_rotation()
	var rest := deg_to_rad(rest_rotation)
	var limit := deg_to_rad(max_angle)
	wanted = rest + clampf(wrapf(wanted - rest, -PI, PI), -limit, limit)
	rotation = rotate_toward(rotation, wanted, deg_to_rad(turn_speed) * delta)

## 親までの回転の合計(本体が回っていても、自機の方を向けるように)
func get_parent_rotation() -> float:
	var parent := get_parent() as Node2D
	return parent.global_rotation if parent else 0.0

## 撃つたびに、反動などのアニメーションを最初から再生する
func _on_fired() -> void:
	if _anim == null or fire_animation == &"" or not _anim.has_animation(fire_animation):
		return
	_anim.stop()
	_anim.play(fire_animation)

## アニメーションを外から再生する(ボスの段階が変わったときなど)
func play(animation : StringName) -> void:
	if _anim and _anim.has_animation(animation):
		_anim.play(animation)
