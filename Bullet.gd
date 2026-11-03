extends Hitbox
class_name Bullet

@export var animation_player : AnimationPlayer
## true なら、敵に当たっても消えずに貫通する
@export var pierce : bool = false

var direction : Vector2 = Vector2.UP
var speed : float = 600.0
var accel : float = 0.0

func _ready() -> void:
	if animation_player:
		animation_player.play("Shoot")
	if not pierce:
		damage_dealt.connect(_on_damage_dealt)
	var notifier := VisibleOnScreenNotifier2D.new()
	add_child(notifier)
	notifier.screen_exited.connect(queue_free)

func setup(dir : Vector2, spd : float, dmg : int, acc : float = 0.0) -> void:
	direction = dir.normalized()
	speed = spd
	damage = dmg
	accel = acc
	rotation = direction.angle() + PI / 2.0

## 当たったら消える。同じフレームで重なっている別の敵には、もうダメージを与えない
func _on_damage_dealt(_hurtbox : Hurtbox) -> void:
	damage = 0
	collision_shape.set_deferred("disabled", true)
	queue_free()

func _physics_process(delta : float) -> void:
	speed = maxf(speed + accel * delta, 0.0)
	global_position += direction * speed * delta
