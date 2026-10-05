extends CharacterBody2D
class_name CharaProjectile

@export var speed : float = 200
@export var direction : Vector2 = Vector2.UP
@export var fire_angle : float = 30 :
	set(value):
		velocity = speed * direction.rotated(deg_to_rad(value))
@export var is_gravity : bool = false
@export var timer : Timer

@export_category("バウンス")
@export var enable_bounce : bool = false
@export var bounce_speed_multi : float = 0.8 ##バウンスするたび速度にかける数。初期は0.8で、バウンスするたび0.8倍。
@export var max_bounce : int = -1 ##最大バウンス数。-1だと無制限になる
@export var min_bounce_speed : float = 30

@onready var sprite: AnimatedSprite2D = $VisualRoot/AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var hitbox: Hitbox = $Hitbox

@export_category("一定速度")
@export var constant_speed : bool = false
@export var max_speed : float = 400.0

var _bounce_count : int = 0

func _ready() -> void:
	if timer:
		timer.timeout.connect(_on_timer_timeout)
	if enable_bounce:
		motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	velocity = speed * direction.rotated(deg_to_rad(fire_angle))
	if constant_speed:
		velocity = velocity.normalized() * max_speed

func _physics_process(delta: float) -> void:
	if is_gravity:
		var gravity_value = ProjectSettings.get_setting("physics/2d/default_gravity")
		velocity.y += gravity_value * delta
 
	if constant_speed:
		_clamp_to_max_speed()
 
	sprite.rotation = direction.angle()
	move_and_slide()
 
	if enable_bounce:
		_handle_bounce()

func _clamp_to_max_speed() -> void:
	if not velocity.is_zero_approx():
		velocity = velocity.normalized() * max_speed

func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	self.queue_free()

func _handle_bounce() -> void:
	if get_slide_collision_count() == 0:
		return
	var collision := get_slide_collision(0)
	_bounce(collision.get_normal())
 
func _bounce(normal: Vector2) -> void:
	if max_bounce >= 0 and _bounce_count >= max_bounce:
		enable_bounce = false
		return
 
	velocity = velocity.bounce(normal)
	if constant_speed:
		velocity = velocity.normalized() * max_speed
	else:
		velocity *= bounce_speed_multi
 
	_bounce_count += 1
 
	if not constant_speed and velocity.length() < min_bounce_speed:
		enable_bounce = false

#func parry_reflect(weapon : Weapon) -> void:
	#hitbox.set_collision_layer_value(3, false) #layer Enemy off
	#hitbox.set_collision_layer_value(2, true) #layer Player on
	#hitbox.set_collision_layer_value(5, true) #layer Reflect on
	#hitbox.set_collision_mask_value(2, false)
	#hitbox.set_collision_mask_value(3, true)
	#direction = Vector2( -direction.x, -direction.y )
	###direction = direction * weapon.angle * 1.2
	#if weapon.angle > 0.5:
		#direction = direction * weapon.angle
	#else:
		#direction = direction 

func destory() -> void:
	speed = 0
	queue_free()

func _on_timer_timeout() -> void:
	destory()
