extends Hitbox
class_name Bullet

@export var animation_player : AnimationPlayer
## true なら、敵に当たっても消えずに貫通する
@export var pierce : bool = false

var direction : Vector2 = Vector2.UP
var speed : float = 600.0
var accel : float = 0.0
## 0 より大きければ、この秒数で消える(BASTION のショットガンなど、届く距離が短い弾)。最後は薄くなって消える
var life : float = 0.0
## true なら、敵の中心に近いほど威力が高い(VESPA のスナイパー)。中心から Center Full Ratio 以内は満点、判定の端で Center Edge Scale 倍
var center_aim : bool = false
const CENTER_FULL_RATIO : float = 0.2
const CENTER_EDGE_SCALE : float = 0.5
## 敵の中心に当たったとき(Center Aim の弾だけ)。位置は当たった所
signal center_hit(at : Vector2)

## 追いかける相手(ロックショット)。null ならまっすぐ飛ぶ
var homing_target : Node2D
## 追いかけるときに曲がる速さ(度/秒)
var homing_turn_rate : float = 720.0
## 追いかけるときも、真上からこの角度(度)より横へは曲がらない(弾が横向きに飛んで、敵の弾と見まちがえないように)
const HOMING_MAX_ANGLE : float = 45.0

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

## この当たり判定に当たったときの威力(小数)。Center Aim の弾は、弾の進む向きに対する、敵の中心からの横のずれで決まる
func damage_against(hurtbox : Area2D) -> float:
	if not center_aim:
		return float(damage)
	var shape_node : CollisionShape2D = null
	for child in hurtbox.get_children():
		if child is CollisionShape2D and not child.disabled:
			shape_node = child
			break
	if shape_node == null or shape_node.shape == null:
		return float(damage)
	var half := _half_width(shape_node)
	var side := absf((global_position - shape_node.global_position).dot(direction.orthogonal()))
	var ratio := clampf(side / maxf(half, 1.0), 0.0, 1.0)
	if ratio <= CENTER_FULL_RATIO:
		center_hit.emit(global_position)
		return float(damage)
	return damage * lerpf(1.0, CENTER_EDGE_SCALE, (ratio - CENTER_FULL_RATIO) / (1.0 - CENTER_FULL_RATIO))

## 当たり判定の、横の半分の幅(画面の px)
static func _half_width(shape_node : CollisionShape2D) -> float:
	var s := shape_node.global_transform.get_scale().abs()
	var shape := shape_node.shape
	if shape is CircleShape2D:
		return (shape as CircleShape2D).radius * maxf(s.x, s.y)
	if shape is CapsuleShape2D:
		return (shape as CapsuleShape2D).radius * s.x
	if shape is RectangleShape2D:
		return (shape as RectangleShape2D).size.x * 0.5 * s.x
	return 24.0

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
	if life > 0.0:
		life -= delta
		if life <= 0.0:
			queue_free()
			return
		if life < 0.08:
			modulate.a = minf(modulate.a, life / 0.08)
	speed = maxf(speed + accel * delta, 0.0)
	if homing_target:
		if is_instance_valid(homing_target) and homing_target.is_inside_tree():
			var max_turn := deg_to_rad(homing_turn_rate) * delta
			var wanted := direction.angle_to(global_position.direction_to(homing_target.global_position))
			direction = direction.rotated(clampf(wanted, -max_turn, max_turn))
			var from_up := clampf(Vector2.UP.angle_to(direction), -deg_to_rad(HOMING_MAX_ANGLE), deg_to_rad(HOMING_MAX_ANGLE))
			direction = Vector2.UP.rotated(from_up)
			rotation = direction.angle() + PI / 2.0
		else:
			homing_target = null # 相手が倒れたら、そのまままっすぐ飛ぶ
	global_position += direction * speed * delta
