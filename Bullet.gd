extends Hitbox
class_name Bullet

@export var animation_player : AnimationPlayer
## true なら、敵に当たっても消えずに貫通する
@export var pierce : bool = false

var direction : Vector2 = Vector2.UP
var speed : float = 600.0
var accel : float = 0.0

## 追いかける相手(ロックショット)。null ならまっすぐ飛ぶ
var homing_target : Node2D
## 追いかけるときに曲がる速さ(度/秒)
var homing_turn_rate : float = 720.0

func _ready() -> void:
	if animation_player:
		animation_player.play("Shoot")
	if not pierce:
		damage_dealt.connect(_on_damage_dealt)
	var notifier := VisibleOnScreenNotifier2D.new()
	add_child(notifier)
	notifier.screen_exited.connect(queue_free)

## dmg は小数でもよい(四捨五入して、最低1にする。0.85 などが切り捨てで 0 にならないように)
func setup(dir : Vector2, spd : float, dmg : float, acc : float = 0.0) -> void:
	direction = dir.normalized()
	speed = spd
	damage = maxi(roundi(dmg), 1)
	accel = acc
	rotation = direction.angle() + PI / 2.0

## 当たったら消える。同じフレームで重なっている別の敵には、もうダメージを与えない
func _on_damage_dealt(_hurtbox : Hurtbox) -> void:
	damage = 0
	collision_shape.set_deferred("disabled", true)
	hide()
	set_physics_process(false)
	queue_free()

## ロックショットにする。相手を追いかけて曲がり、当たったら消える(通り抜けて何度も当たらないように)
func set_homing(target : Node2D, turn_rate : float) -> void:
	homing_target = target
	homing_turn_rate = turn_rate
	if not damage_dealt.is_connected(_on_homing_hit):
		damage_dealt.connect(_on_homing_hit)

func _on_homing_hit(_hurtbox : Hurtbox) -> void:
	queue_free()

func _physics_process(delta : float) -> void:
	speed = maxf(speed + accel * delta, 0.0)
	if homing_target:
		if is_instance_valid(homing_target) and homing_target.is_inside_tree():
			var max_turn := deg_to_rad(homing_turn_rate) * delta
			var wanted := direction.angle_to(global_position.direction_to(homing_target.global_position))
			direction = direction.rotated(clampf(wanted, -max_turn, max_turn))
			rotation = direction.angle() + PI / 2.0
		else:
			homing_target = null # 相手が倒れたら、そのまままっすぐ飛ぶ
	global_position += direction * speed * delta
