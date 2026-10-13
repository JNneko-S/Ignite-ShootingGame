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
## 難易度などによる、グレイズ半径の倍率(GameManager が設定する)
var graze_radius_scale : float = 1.0

@export_group("攻撃")
@export var bullet_scene : PackedScene
## 発射間隔(秒)。ShootTimer の wait_time に反映される
@export var fire_interval : float = 0.1

@onready var graze_area: Area2D = $GrazeArea
@onready var graze_shape: CollisionShape2D = $GrazeArea/GrazeShape
@onready var shoot_timer: Timer = $ShootTimer
## 通常時(強化なし)の発射角度
@export var shot_angles : Array[float] = [0.0]
@export var muzzle_offset : Vector2 = Vector2(0, -16)

@export_group("ショットの威力(距離減衰)")
## 通常ショット1発の基礎ダメージ
@export var shot_damage : float = 1.0
## 画面中央から撃ったときの威力倍率
@export var shot_power_at_center : float = 1.2
## 画面の端から撃ったときの威力倍率
@export var shot_power_at_edge : float = 0.85
## ショットの弾速(px/秒)。自機の移動速度(Lv5で約375)より十分速くすること
@export var shot_speed : float = 900.0
## true なら、前進している速度の分だけ弾速を足す。縦に動いても、弾の間隔が一定になり、重ならない
@export var shot_inherit_forward_speed : bool = true
## 威力に応じて弾の色を変える(弾の見た目に掛け合わせる)
@export var tint_shot_by_power : bool = true
@export var shot_color_low : Color = Color(0.6, 0.75, 1.0)
@export var shot_color_high : Color = Color(1.0, 1.0, 1.0)

@export_group("ショット強化(Lv5イグナイトで+1段階。被弾で失う)")
## way弾の角度の間隔(度)
@export var power_spread_deg : float = 8.0
## バースト弾の、1発ごとの間隔(秒)
@export var power_burst_gap : float = 0.06
## 高速連射の段階(4・5段階目)の、発射間隔の倍率
@export var power_fast_interval_scale : float = 0.5

@export_group("イグナイト入力")
## 長押しで「全レベル消費」になるまでの時間(秒)。それより前に離すと、単押し(1レベル消費)
@export var ignite_hold_time : float = 1.5
## 溜めの間、自機の周りに出るリングの半径
@export var charge_ring_radius : float = 36.0

@export_group("被弾")
## 被弾して生き残ったあとの無敵時間(秒)。点滅し、この間はグレイズもできない
@export var hit_invincible_time : float = 3.0

@export_group("残機")
## 残機の数(0のとき死亡するとゲームオーバー)
@export var lives : int = 3
## 死亡してから復活するまでの時間(秒)
@export var respawn_delay : float = 0.6
## 復活後の無敵時間(秒)
@export var respawn_invincible_time : float = 3.0
## 死亡時に画面内の敵弾を消すか("enemy_bullet" グループの弾が対象)
@export var clear_bullets_on_death : bool = true

@onready var hp_component: HPComponent = $HPComponent
@onready var graze_effect: GPUParticles2D = $GrazeEffect
@onready var ignite_aura : IgniteAura = get_node_or_null("IgniteAura")

const MAX_SHOT_STAGE : int = 5

var graze_count : int = 0
var is_focusing : bool = false
var _grazed_hitboxes : Dictionary = {}

var _spawn_position : Vector2
var _is_alive : bool = true
var _invincible : bool = false
var _invincible_end_msec : int = 0
var _blink_tween : Tween

## イグナイトがONか(ONの間、ゲージが減り続け、フレアが残る)
var is_igniting : bool = false
## ゲージのレベルによる補正(GameManager が設定する)
var level_move_scale : float = 1.0
var level_power_scale : float = 1.0

## 現在のショット強化の段階(0〜5)
var shot_stage : int = 0

## イグナイトを発動できる状態か(Lv1以上で、発動中でない)。GameManager が毎フレーム設定する
var ignite_available : bool = false
enum HoldState { IDLE, HOLDING, DONE }
var _hold_state : HoldState = HoldState.IDLE
var _hold_time : float = 0.0
var _charge_ratio : float = 0.0

signal grazed(total : int)
## グレイズした瞬間に出る。演出(GrazeEffect)やゲージ側はこれを受け取る。
## bullet_position: 掠めた弾の位置 / density: その時 GrazeArea 内にある弾の数(密度の目安)
signal graze_hit(bullet_position : Vector2, density : int)
## 被弾したときに出る(無敵中・死亡中は出ない)。ゲージ(体力)の減少はこれを受けて行う
signal damaged
## 残機が変化したときに出る(UI用)
signal lives_changed(lives : int)
## 残機が尽きて死亡したときに出る
signal game_over
## 復活が完了したときに出る
signal respawned
## イグナイトが要求された。full=false は単押し(1レベル消費)、true は長押し(全レベル消費)
signal ignite_requested(full : bool)
## 長押しの溜め具合(0.0〜1.0)。リングの表示に使う
signal ignite_charge_changed(ratio : float)
## イグナイトのON/OFFが切り替わった
signal ignite_toggled(on : bool)
signal shot_stage_changed(stage : int)

func _ready() -> void:
	add_to_group("player") # 敵の狙い撃ち用
	_spawn_position = global_position # 復活位置は、最初に置かれた位置
	if ignite_aura == null:
		push_warning("Player: 子に IgniteAura(ignite_aura.gd)が見つかりません。ノード名を IgniteAura にしてください")
	if not InputMap.has_action("UI_Ignite"):
		push_warning("Player: Input Map に UI_Ignite が登録されていないため、イグナイトは発動できません")
	shoot_timer.wait_time = fire_interval
	# シェイプがシーン内で共有されないよう複製してから半径を変更する
	graze_shape.shape = graze_shape.shape.duplicate()
	_update_graze_radius()

func _physics_process(delta: float) -> void:
	# UI_Focus が InputMap に未登録でもエラーにならないようにしている
	is_focusing = InputMap.has_action("UI_Focus") and Input.is_action_pressed("UI_Focus")
	_update_graze_radius()

	_update_ignite_input(delta)

	var dir := Input.get_vector("UI_Left", "UI_Right", "UI_Forward", "UI_Back")
	var speed := move_speed * level_move_scale
	if is_focusing:
		speed *= focus_speed_multiplier
	velocity = dir * speed
	move_and_slide()
	_shoot(delta)

# ---------------------------------------------------------------- ショット

func _shoot(_delta: float) -> void:
	if not Input.is_action_pressed("UI_Shoot") or shoot_timer.time_left > 0.0:
		return
	if bullet_scene == null:
		return
	var pattern := _shot_pattern()
	shoot_timer.start(fire_interval * pattern["interval_scale"])
	_fire_volley(pattern["angles"])
	# バースト: 同じ弾を、少しずつ遅らせて撃つ
	for i in range(1, pattern["burst"]):
		var wait := create_tween()
		wait.tween_interval(power_burst_gap * i)
		wait.tween_callback(_fire_volley.bind(pattern["angles"]))

## ショット強化の段階に応じた、発射の内容
##   0: 通常 / 1: 3点バースト / 2: 3way / 3: 3way 3点バースト / 4: 5way 高速連射 / 5: 7way 高速連射
func _shot_pattern() -> Dictionary:
	match shot_stage:
		1:
			return {"angles": shot_angles, "burst": 3, "interval_scale": 1.0}
		2:
			return {"angles": _way_angles(3), "burst": 1, "interval_scale": 1.0}
		3:
			return {"angles": _way_angles(3), "burst": 3, "interval_scale": 1.0}
		4:
			return {"angles": _way_angles(5), "burst": 1, "interval_scale": power_fast_interval_scale}
		5:
			return {"angles": _way_angles(7), "burst": 1, "interval_scale": power_fast_interval_scale}
	return {"angles": shot_angles, "burst": 1, "interval_scale": 1.0}

func _way_angles(count : int) -> Array[float]:
	var angles : Array[float] = []
	for i in count:
		angles.append((i - (count - 1) / 2.0) * power_spread_deg)
	return angles

func _fire_volley(angles : Array) -> void:
	if not _is_alive:
		return
	for angle_deg in angles:
		var bullet : Bullet = bullet_scene.instantiate()
		get_tree().current_scene.add_child(bullet)
		bullet.global_position = global_position + muzzle_offset
		var direction := Vector2.UP.rotated(deg_to_rad(angle_deg))
		if bullet.has_method("setup"):
			var t := _center_distance_ratio(bullet.global_position)
			var power := lerpf(shot_power_at_center, shot_power_at_edge, t)
			var speed := shot_speed
			if shot_inherit_forward_speed:
				speed += maxf(velocity.dot(direction), 0.0) # 弾の向きに進んでいる速度だけ足す
			bullet.setup(direction, speed, shot_damage * power * level_power_scale, 0)
			if tint_shot_by_power:
				bullet.modulate = shot_color_high.lerp(shot_color_low, t)

## ショットを1段階強化する(最大5段階)
func power_up_shot() -> void:
	if shot_stage >= MAX_SHOT_STAGE:
		return
	shot_stage += 1
	shot_stage_changed.emit(shot_stage)

## ショット強化を全て失う(被弾・死亡時)
func reset_shot_power() -> void:
	if shot_stage == 0:
		return
	shot_stage = 0
	shot_stage_changed.emit(shot_stage)

## 画面中央からの距離を 0.0(中央)〜1.0(角)で返す
func _center_distance_ratio(pos : Vector2) -> float:
	var size := get_viewport_rect().size
	return clampf(pos.distance_to(size / 2.0) / (size.length() / 2.0), 0.0, 1.0)

# ---------------------------------------------------------------- グレイズ

func _update_graze_radius() -> void:
	var radius := graze_radius * graze_radius_scale
	if is_focusing:
		radius *= focus_graze_multiplier
	var circle := graze_shape.shape as CircleShape2D
	if circle and not is_equal_approx(circle.radius, radius):
		circle.radius = radius

func _on_graze_area_area_entered(area: Area2D) -> void:
	# 無敵中(復活直後・イグナイト後)と、死亡中はグレイズしない
	if is_invincible():
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

# ---------------------------------------------------------------- 被弾・死亡・復活

## 被弾。レベル(体力)を減らすかどうかは、damaged を受けた側(GameManager)が決める
func _on_hurtbox_recieved_damage(_damage: int) -> void:
	# 無敵中・死亡中は被弾を無視する
	if _invincible or not _is_alive:
		return
	damaged.emit()
	# 死亡しなかったときは、点滅しながら無敵になる(無敵の間はグレイズもできない)
	if _is_alive:
		start_invincibility(hit_invincible_time)

## HPComponent 側から呼ばれる場合に備えて残している(体力はゲージで管理するので通常は使わない)
func _on_hp_component_is_dead() -> void:
	die()

## 死亡する。残機があれば復活、なければゲームオーバー
func die() -> void:
	if not _is_alive:
		return
	_is_alive = false
	set_igniting(false)
	_cancel_ignite_hold()
	reset_shot_power()
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
	start_invincibility(respawn_invincible_time)
	respawned.emit()

## 無敵にする(点滅する)。すでに無敵で、残りがこれより長ければ何もしない
func start_invincibility(seconds: float) -> void:
	if seconds <= 0.0:
		return
	var end_msec := Time.get_ticks_msec() + int(seconds * 1000.0)
	if _invincible and end_msec <= _invincible_end_msec:
		return
	_invincible = true
	_invincible_end_msec = end_msec
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

## 無敵状態か(死亡中・無敵時間中のどれか)
func is_invincible() -> bool:
	return not _is_alive or _invincible

## 残機を増やす(1UPアイテムなどから呼ぶ)
func add_life(amount: int = 1) -> void:
	lives += amount
	lives_changed.emit(lives)

# ---------------------------------------------------------------- イグナイト

## 発動の効果中かどうかを切り替える(効果の開始・終了は GameManager が行う)。効果中は無敵ではない
func set_igniting(on : bool) -> void:
	if is_igniting == on:
		return
	if on and not _is_alive:
		return
	is_igniting = on
	ignite_toggled.emit(on)

## ボタン入力。単押し(1.5秒未満で離す)は1レベル、長押しは1.5秒たった時点で全レベルを要求する
func _update_ignite_input(delta : float) -> void:
	if not InputMap.has_action("UI_Ignite"):
		return
	var pressed := Input.is_action_pressed("UI_Ignite")
	match _hold_state:
		HoldState.IDLE:
			if Input.is_action_just_pressed("UI_Ignite") and ignite_available and _is_alive:
				_hold_state = HoldState.HOLDING
				_hold_time = 0.0
		HoldState.HOLDING:
			if not pressed:
				_hold_state = HoldState.IDLE
				_set_charge(0.0)
				ignite_requested.emit(false) # 単押し
			else:
				_hold_time += delta
				_set_charge(_hold_time / ignite_hold_time)
				if _hold_time >= ignite_hold_time:
					_hold_state = HoldState.DONE # 離すまで、次の入力は受けない
					_set_charge(0.0)
					ignite_requested.emit(true) # 長押し: 自動で最大
		HoldState.DONE:
			if not pressed:
				_hold_state = HoldState.IDLE

func _cancel_ignite_hold() -> void:
	_hold_state = HoldState.IDLE
	_set_charge(0.0)

func _set_charge(ratio : float) -> void:
	_charge_ratio = clampf(ratio, 0.0, 1.0)
	ignite_charge_changed.emit(_charge_ratio)
	queue_redraw()

## 溜めの間、自機の周りにリングを出す
func _draw() -> void:
	if _charge_ratio > 0.0:
		draw_arc(Vector2.ZERO, charge_ring_radius, -PI / 2.0, -PI / 2.0 + TAU * _charge_ratio,
			48, Color(1.0, 0.6, 0.2, 0.9), 3.0)
