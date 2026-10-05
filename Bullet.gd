extends Hitbox
class_name Bullet

@export var animation_player : AnimationPlayer

var direction : Vector2 = Vector2.UP
var speed : float = 600.0

func _ready() -> void:
	if animation_player:
		animation_player.play("Shoot")
	var notifier := VisibleOnScreenNotifier2D.new()
	add_child(notifier)
	notifier.screen_exited.connect(queue_free)

func setup(dir: Vector2, dmg: int) -> void:
	direction = dir.normalized()
	damage = dmg
	rotation = direction.angle() + PI / 2.0

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
