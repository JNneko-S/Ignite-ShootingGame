extends Hitbox
class_name EnemyBullet
## 敵の弾。Hitbox を継承しているので、自機の GrazeArea / Hurtbox がそのまま反応する。
## Area2D + CollisionShape2D のシーンにこのスクリプトを付けて使う。
## イグナイトのオーラに触れると ignite() が呼ばれ、変色して敵へ跳ね返る反射弾になる。

enum BulletState { NORMAL, IGNITED }

var direction : Vector2 = Vector2.DOWN
var speed : float = 250.0
var accel : float = 0.0

var _state : BulletState = BulletState.NORMAL
var _params : IgniteParams
var _chain_until_msec : int = 0
var _age : float = 0.0
var _phase : float = 0.0
var _target : Node2D
var _retarget_in : float = 0.0

func _ready() -> void:
	damage_source_type = DamageSourceType.Enemy
	add_to_group("enemy_bullet") # 被弾時の弾消しの対象
	# 当たったら消える(自機に当たっても、反射弾が敵に当たっても)
	damage_dealt.connect(func(_hurtbox : Hurtbox) -> void: queue_free())
	area_entered.connect(_on_area_entered)
	# 画面外に出たら消える
	var notifier := VisibleOnScreenNotifier2D.new()
	add_child(notifier)
	notifier.screen_exited.connect(queue_free)

func setup(dir : Vector2, spd : float, dmg : float, acc : float = 0.0) -> void:
	direction = dir.normalized()
	speed = spd
	damage = dmg
	accel = acc
	rotation = direction.angle() + PI / 2.0

func is_ignited() -> bool:
	return _state == BulletState.IGNITED

## 着火して反射弾になる。
## chain_until_msec: この時刻まで連鎖できる / is_chain: 連鎖で着火したか
## 反射弾は距離減衰を受けず、威力は常に base_damage
func ignite(params : IgniteParams, chain_until_msec : int, is_chain : bool = false) -> void:
	if _state == BulletState.IGNITED:
		return
	_state = BulletState.IGNITED
	_params = params
	_chain_until_msec = chain_until_msec
	_age = 0.0
	_phase = randf() * TAU
	_retarget_in = 0.0

	damage_source_type = DamageSourceType.Player
	damage = params.base_damage
	modulate = params.chain_color if is_chain else params.direct_color

	direction = -direction # いったん押し返されてから、弧を描いて敵へ向かう
	remove_from_group("enemy_bullet")
	set_deferred("collision_layer", params.ignited_collision_layer)
	set_deferred("collision_mask", params.ignited_collision_mask)

func _on_area_entered(area : Area2D) -> void:
	# 連鎖: 反射弾が、他の敵弾に触れたら着火させる(イグナイト中のみ)
	if _state != BulletState.IGNITED or not _params.chain_enabled:
		return
	if Time.get_ticks_msec() > _chain_until_msec:
		return
	if area is EnemyBullet and not area.is_ignited():
		area.ignite(_params, _chain_until_msec, true)

func _physics_process(delta : float) -> void:
	if _state == BulletState.NORMAL:
		speed = maxf(speed + accel * delta, 0.0)
		global_position += direction * speed * delta
	else:
		_move_ignited(delta)

func _move_ignited(delta : float) -> void:
	_age += delta
	_retarget_in -= delta
	if _retarget_in <= 0.0 or not is_instance_valid(_target):
		_target = _find_nearest_enemy()
		_retarget_in = 0.3 + randf() * 0.2

	var desired := Vector2.UP
	if is_instance_valid(_target):
		desired = (_target.global_position - global_position).normalized()

	# 旋回は最初は緩やかで、時間とともに鋭くなる(弧を描きつつ、最終的に必ず当たる)
	var max_turn := deg_to_rad(_params.turn_rate_deg + _params.turn_rate_growth_deg * _age) * delta
	direction = direction.rotated(clampf(direction.angle_to(desired), -max_turn, max_turn))

	var sway := deg_to_rad(_params.sway_amplitude_deg) * sin(_age * TAU * _params.sway_frequency + _phase)
	var move_dir := direction.rotated(sway)
	global_position += move_dir * _params.reflect_speed * delta
	rotation = move_dir.angle() + PI / 2.0

func _find_nearest_enemy() -> Node2D:
	var nearest : Node2D = null
	var best := INF
	for node in get_tree().get_nodes_in_group("enemy"):
		var enemy := node as Node2D
		if enemy == null:
			continue
		var d := global_position.distance_squared_to(enemy.global_position)
		if d < best:
			best = d
			nearest = enemy
	return nearest
