extends CharacterBody2D
class_name Player

@export_group("移動")
@export var move_speed: float = 300.0

@export_group("攻撃")
@export var bullet_scene : PackedScene

@onready var graze_area: Area2D = $GrazeArea
@onready var graze_shape: CollisionShape2D = $GrazeArea/GrazeShape
@onready var shoot_timer: Timer = $ShootTimer
@export var shot_angles : Array[float] = [0.0]
@export var muzzle_offset : Vector2 = Vector2(0, -16)

var graze_count : int = 0
var _grazed_hitboxes : Dictionary = {}

signal grazed(total : int)

func _ready() -> void:
	pass

func _physics_process(delta: float) -> void:
	var dir := Input.get_vector("UI_Left", "UI_Right", "UI_Forward", "UI_Back")
	var speed := move_speed
	velocity = dir * speed
	move_and_slide()
	_shoot(delta)

func _shoot(delta: float) -> void:
	if not Input.is_action_pressed("UI_Shoot") or shoot_timer.time_left > 0.0:
		return
	if bullet_scene == null:
		return
	shoot_timer.start()
	for angle_deg in shot_angles:
		var bullet : Bullet = bullet_scene.instantiate()
		get_tree().current_scene.add_child(bullet)
		bullet.global_position = global_position + muzzle_offset
		var direction := Vector2.UP.rotated(deg_to_rad(angle_deg))
		if bullet.has_method("setup"):
			bullet.setup(direction, 1)

func _on_graze_area_area_entered(area: Area2D) -> void:
	if area is Hitbox and area.damage_source_type == Hitbox.DamageSourceType.Enemy:
		if _grazed_hitboxes.has(area):
			return
		_grazed_hitboxes[area] = true
		graze_count += 1
		grazed.emit(graze_count)

func _on_graze_area_area_exited(area: Area2D) -> void:
	_grazed_hitboxes.erase(area)
