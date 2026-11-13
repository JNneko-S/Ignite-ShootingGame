extends Hitbox
class_name EnemyBullet
## 敵の弾。Hitbox を継承しているので、自機の GrazeArea / Hurtbox がそのまま反応する。
## Area2D + CollisionShape2D のシーンにこのスクリプトを付けて使う。
##
## 状態:
##   NORMAL  : 通常の敵弾
##   IGNITED : 反射弾(敵へ弧を描いて飛ぶ。イグナイトのフレアに触れると変わる)
##   BURNING : 焼却中(イグナイトの範囲に入った弾。燃えて消える)

## VANISHING: 弾消しで消えるところ(その場で止まり、光って消える)
enum BulletState { NORMAL, IGNITED, BURNING, VANISHING }

# ---- 連鎖の許可(イグナイトON中かつ高レベルのときだけ。全ての敵弾で共有) ----
static var _chain_allowed : bool = false

static func set_chain_allowed(allowed : bool) -> void:
	_chain_allowed = allowed

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

# ---- 弾の動き(ShotPattern の Motion。空なら speed と accel だけで動く) ----
var _motion : Array[BulletStep] = []
var _speed_scale : float = 1.0
var _step_index : int = -1
var _step_time : float = 0.0
var _step_from_speed : float = 0.0 # 区間の始めの速さ(倍率をかける前)
var _mirror : bool = false # 左右反転して出た敵の弾(曲がる向き・回す向きが逆)

# ---- 分裂(ShotPattern の Split。割れたら、Split Pattern の弾になって消える) ----
var _split_pattern : ShotPattern # 割れる設定を持つパターン(この弾を撃ったパターン)
var _split_in : float = -1.0 # 割れるまでの残り秒数。マイナスなら割れない
var _split_depth : int = 0

func _ready() -> void:
	damage_source_type = DamageSourceType.Enemy
	add_to_group("enemy_bullet") # 被弾時・イグナイト終了時の弾消しの対象
	# 当たったら消える(自機に当たっても、反射弾が敵に当たっても)
	damage_dealt.connect(_on_damage_dealt)
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

## 撃ったあとの動きを設定する。setup のあとに呼ぶ。
## speed_scale: 列弾・ばらつきによる速さの倍率(Motion の速度にもかかる)
func set_motion(motion : Array[BulletStep], speed_scale : float = 1.0, mirror : bool = false) -> void:
	_mirror = mirror
	_motion.assign(motion.filter(func(step : BulletStep) -> bool: return step != null))
	_speed_scale = speed_scale
	_step_index = -1
	if not _motion.is_empty():
		_step_from_speed = speed / maxf(speed_scale, 0.0001)
		_begin_step(0)

## 割れる設定を入れる。pattern は、この弾を撃ったパターン。depth は何回割れてできた弾か
func set_split(pattern : ShotPattern, mirror : bool = false, depth : int = 0) -> void:
	_split_depth = depth
	_mirror = mirror
	if ShotMath.splits(pattern, depth):
		_split_pattern = pattern
		_split_in = pattern.split_time
	else:
		_split_pattern = null
		_split_in = -1.0

## 割れて、Split Pattern の弾を出し、自分は消える
func _split() -> void:
	_split_in = -1.0
	var parent := get_parent()
	var child := _split_pattern.split_pattern
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var aim := (player.global_position - global_position).angle() if player else Vector2.DOWN.angle()
	var fallback : PackedScene = load(scene_file_path) if scene_file_path != "" else null
	EnemyShooter.spawn_bullets(child, 0, aim, global_position, parent, fallback, _mirror,
			ShotMath.split_turn(_split_pattern, direction.angle()), _split_depth + 1)
	# 割れた場所が一瞬光る
	if parent:
		var flash := Sprite2D.new()
		var sprite := _find_sprite()
		if sprite:
			flash.texture = sprite.texture
			flash.hframes = sprite.hframes
			flash.vframes = sprite.vframes
			flash.frame = sprite.frame
			flash.rotation = global_rotation
			flash.scale = global_scale * 1.5
			flash.z_index = z_index
			flash.modulate = Color(2.0, 2.0, 2.0, 0.9)
			parent.add_child(flash)
			flash.global_position = global_position
			var tween := flash.create_tween().set_parallel(true)
			tween.tween_property(flash, "scale", flash.scale * 2.0, 0.15)
			tween.tween_property(flash, "modulate:a", 0.0, 0.15)
			tween.chain().tween_callback(flash.queue_free)
	queue_free()

func _find_sprite() -> Sprite2D:
	for node in find_children("*", "", true, false):
		if node is Sprite2D:
			return node
	return null

## 当たった: 消える。反射弾が敵に当たったときは、その場にスコアが出る(ScoreSystem.on_reflect_hit)
func _on_damage_dealt(_hurtbox : Hurtbox) -> void:
	if is_queued_for_deletion():
		return # 同じフレームに2つの敵に当たっても、スコアは1回
	if _state == BulletState.IGNITED:
		var score_system := get_tree().get_first_node_in_group("score_system") as ScoreSystem
		if score_system:
			score_system.on_reflect_hit(global_position)
	queue_free()

func is_normal() -> bool:
	return _state == BulletState.NORMAL

func is_ignited() -> bool:
	return _state == BulletState.IGNITED

## 焼却: 燃えて消える。成功したら true(スコア加算の判定に使う)
func burn() -> bool:
	if _state != BulletState.NORMAL:
		return false
	_state = BulletState.BURNING
	BurnPuff.spawn(get_tree(), global_position) # 燃え尽きる炎(そのあと、その場にスコアアイテムが残る)
	remove_from_group("enemy_bullet")
	set_deferred("monitorable", false) # 自機に当たらなくなる
	set_deferred("monitoring", false)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "modulate", Color(1.0, 0.5, 0.1, 0.0), 0.18)
	tween.tween_property(self, "scale", scale * 1.6, 0.18)
	tween.chain().tween_callback(queue_free)
	return true

## 弾消し(ボスの形態変更など)で消える。点にはならない。
## 当たり判定はすぐ消え、その場で止まって、delay 秒後に白く光ってはじけ、消滅のエフェクトを残す。
## 通常の弾だけが対象(反射弾・焼却中の弾はそのまま)。消えることになったら true
func vanish(delay : float = 0.0) -> bool:
	if _state != BulletState.NORMAL:
		return false
	_state = BulletState.VANISHING
	remove_from_group("enemy_bullet")
	set_deferred("monitorable", false) # 自機に当たらず、グレイズもできなくなる
	set_deferred("monitoring", false)
	var sprite := _find_sprite()
	var color := sprite.self_modulate * modulate if sprite else Color(0.7, 0.85, 1.0)
	var tween := create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_callback(func() -> void: VanishPuff.spawn(get_tree(), global_position, color))
	tween.set_parallel(true)
	tween.tween_property(self, "modulate", Color(2.5, 2.5, 2.5, 0.0), 0.14)
	tween.tween_property(self, "scale", scale * 1.7, 0.14)
	tween.chain().tween_callback(queue_free)
	return true

## 画面の敵弾を、まとめて弾消しする。from から近い弾ほど先に消える(波が広がるように)。
## spread_time: いちばん遠い弾が消えるまでの時間(秒)
static func vanish_all(tree : SceneTree, from : Vector2, spread_time : float = 0.35) -> void:
	if tree == null:
		return
	var bullets := tree.get_nodes_in_group("enemy_bullet")
	var far := 1.0
	for node in bullets:
		far = maxf(far, from.distance_to((node as Node2D).global_position))
	for node in bullets:
		var bullet := node as EnemyBullet
		if bullet:
			bullet.vanish(spread_time * from.distance_to(bullet.global_position) / far)
		elif is_instance_valid(node):
			node.queue_free()

## 反射弾になる。
## chain_until_msec: この時刻まで連鎖できる / is_chain: 連鎖で着火したか
func ignite(params : IgniteParams, chain_until_msec : int, is_chain : bool = false) -> void:
	if _state != BulletState.NORMAL:
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
	match _state:
		BulletState.IGNITED:
			# 連鎖: 反射弾が他の敵弾に触れたら反射させる(連鎖が許可されている間のみ)
			if not _chain_allowed or not _params.chain_enabled:
				return
			if Time.get_ticks_msec() > _chain_until_msec:
				return
			if area is EnemyBullet and area.is_normal():
				area.ignite(_params, _chain_until_msec, true)

func _physics_process(delta : float) -> void:
	match _state:
		BulletState.NORMAL:
			if _split_in >= 0.0:
				_split_in -= delta
				if _split_in <= 0.0:
					_split()
					return
			if _motion.is_empty():
				speed = maxf(speed + accel * delta, 0.0)
				global_position += direction * speed * delta
			else:
				_update_motion(delta)
		BulletState.IGNITED:
			_move_ignited(delta)

## Motion の区間を進めて、動かす(ShotMath.motion_table と同じ順番の計算)
func _update_motion(delta : float) -> void:
	if _step_index >= _motion.size():
		global_position += direction * speed * delta # 最後の区間のあとは、まっすぐ飛ぶ
		return
	var step := _motion[_step_index]
	_step_time += delta
	speed = ShotMath.step_speed(step, _step_from_speed, minf(_step_time, step.duration)) * _speed_scale
	if step.angular_velocity != 0.0:
		direction = direction.rotated(ShotMath.angular_velocity(step, _mirror) * delta)
		rotation = direction.angle() + PI / 2.0
	global_position += direction * speed * delta
	# 区間の終わり: 次の区間の向きは、動いたあとの位置で決める
	if _step_time >= step.duration - 0.0001:
		_step_from_speed = ShotMath.step_speed(step, _step_from_speed, step.duration)
		_begin_step(_step_index + 1)

func _begin_step(index : int) -> void:
	_step_index = index
	_step_time = 0.0
	if index >= _motion.size():
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D if is_inside_tree() else null
	var player_position := player.global_position if player else global_position + Vector2.DOWN
	var heading := ShotMath.turned_heading(_motion[index], direction.angle(), global_position, player_position, _mirror)
	direction = Vector2.from_angle(heading)
	rotation = heading + PI / 2.0

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
