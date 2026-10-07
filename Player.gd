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

@export_group("残機")
## 残機の数(0のとき被弾するとゲームオーバー)
@export var lives : int = 2
## 被弾してから復活するまでの時間(秒)
@export var respawn_delay : float = 0.6
## 復活後の無敵時間(秒)
@export var respawn_invincible_time : float = 3.0
## 被弾時に画面内の敵弾を消すか("enemy_bullet" グループの弾が対象)
@export var clear_bullets_on_death : bool = true

@onready var hp_component: HPComponent = $HPComponent
@onready var graze_effect: GPUParticles2D = $GrazeEffect

var graze_count : int = 0
var is_focusing : bool = false
var _grazed_hitboxes : Dictionary = {}

var _spawn_position : Vector2
var _is_alive : bool = true
var _invincible : bool = false
var _blink_tween : Tween

signal grazed(total : int)
## グレイズした瞬間に出る。演出(GrazeEffect)やゲージ側はこれを受け取る。
## bullet_position: 掠めた弾の位置 / density: その時 GrazeArea 内にある弾の数(密度の目安)
signal graze_hit(bullet_position : Vector2, density : int)
## 被弾したときに出る(イグナイトゲージの減少などが受け取る)
signal damaged
## 残機が変化したときに出る(UI用)
signal lives_changed(lives : int)
## 残機が尽きて被弾したときに出る
signal game_over

func _ready() -> void:
	add_to_group("player") # 敵の狙い撃ち用
	_spawn_position = global_position # 復活位置は、最初に置かれた位置
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
	if not _is_alive:
		return
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
	# 無敵中・死亡中は被弾を無視する
	if _invincible or not _is_alive:
		return
	hp_component.apply_damage(ceili(damage))
	damaged.emit()

func _on_hp_component_is_dead() -> void:
	_is_alive = false
	if clear_bullets_on_death:
		get_tree().call_group("enemy_bullet", "queue_free")
	if lives <= 0:
		game_over.emit()
		queue_free()
		return
	lives -= 1
	lives_changed.emit(lives)
	_respawn()

func _respawn() -> void:
	# 復活までは非表示にして、操作と射撃を止める
	visible = false
	set_physics_process(false)
	var wait := create_tween() # ノードに紐づくので、途中で消えても安全
	wait.tween_interval(respawn_delay)
	await wait.finished

	global_position = _spawn_position
	velocity = Vector2.ZERO
	hp_component.restore_hp()
	visible = true
	_is_alive = true
	set_physics_process(true)
	_start_invincibility(respawn_invincible_time)

func _start_invincibility(seconds: float) -> void:
	_invincible = true
	if _blink_tween:
		_blink_tween.kill()
	_blink_tween = create_tween()
	_blink_tween.set_loops(maxi(int(seconds / 0.2), 1)) # 0.2秒で1回点滅
	_blink_tween.tween_property(self, "modulate:a", 0.3, 0.1)
	_blink_tween.tween_property(self, "modulate:a", 1.0, 0.1)
	_blink_tween.finished.connect(_end_invincibility)

func _end_invincibility() -> void:
	_invincible = false
	modulate.a = 1.0

## 残機を増やす(1UPアイテムなどから呼ぶ)
func add_life(amount: int = 1) -> void:
	lives += amount
	lives_changed.emit(lives)
