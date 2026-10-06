extends CharacterBody2D
class_name Player

@export_group("移動")
@export var move_speed: float = 300.0
## 低速移動(UI_Focus を押している間)の速度倍率
@export_range(0.05, 1.0, 0.05) var focus_speed_multiplier : float = 0.4

@export_group("グレイズ")
## 通常時のグレイズ判定の半径(px)。大きいほどグレイズしやすい
@export var graze_radius : float = 24.0
## 低速移動中のグレイズ半径の倍率(1.0で変化なし)
@export var focus_graze_multiplier : float = 1.0

@export_group("攻撃")
@export var bullet_scene : PackedScene
## 発射間隔(秒)。ShootTimer の wait_time に反映される
@export var fire_interval : float = 0.1

@onready var graze_area: Area2D = $GrazeArea
@onready var graze_shape: CollisionShape2D = $GrazeArea/GrazeShape
@onready var shoot_timer: Timer = $ShootTimer
@export var shot_angles : Array[float] = [0.0]
@export var muzzle_offset : Vector2 = Vector2(0, -16)

@onready var hp_component: HPComponent = $HPComponent
@onready var graze_effect: GPUParticles2D = $GrazeEffect

var graze_count : int = 0
var is_focusing : bool = false
var _grazed_hitboxes : Dictionary = {}

signal grazed(total : int)
## グレイズした瞬間に出る。演出(GrazeEffect)やゲージ側はこれを受け取る。
## bullet_position: 掠めた弾の位置 / density: その時 GrazeArea 内にある弾の数(密度の目安)
signal graze_hit(bullet_position : Vector2, density : int)
## 被弾したときに出る(イグナイトゲージの減少などが受け取る)
signal damaged

func _ready() -> void:
	add_to_group("player") # 敵の狙い撃ち用
	shoot_timer.wait_time = fire_interval
	# シェイプがシーン内で共有されないよう複製してから半径を変更する
	graze_shape.shape = graze_shape.shape.duplicate()
	_update_graze_radius()

func _physics_process(delta: float) -> void:
	# UI_Focus が InputMap に未登録でもエラーにならないようにしている
	is_focusing = InputMap.has_action("UI_Focus") and Input.is_action_pressed("UI_Focus")
	_update_graze_radius()

	var dir := Input.get_vector("UI_Left", "UI_Right", "UI_Forward", "UI_Back")
	var speed := move_speed
	if is_focusing:
		speed *= focus_speed_multiplier
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
			bullet.setup(direction, 300, 1, 0)

func _update_graze_radius() -> void:
	var radius := graze_radius
	if is_focusing:
		radius *= focus_graze_multiplier
	var circle := graze_shape.shape as CircleShape2D
	if circle and not is_equal_approx(circle.radius, radius):
		circle.radius = radius

func _on_graze_area_area_entered(area: Area2D) -> void:
	if area is Hitbox and area.damage_source_type == Hitbox.DamageSourceType.Enemy:
		if _grazed_hitboxes.has(area):
			return
		_grazed_hitboxes[area] = true
		graze_count += 1
		grazed.emit(graze_count)
		graze_hit.emit(area.global_position, graze_area.get_overlapping_areas().size())
		graze_effect.emitting = true

func _on_graze_area_area_exited(area: Area2D) -> void:
	_grazed_hitboxes.erase(area)

func _on_hurtbox_recieved_damage(damage: int) -> void:
	hp_component.apply_damage(ceili(damage))
	damaged.emit()

func _on_hp_component_is_dead() -> void:
	queue_free()
