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
## これまでにイグナイトで焼いた敵弾の数(全部の弾で共有)。カウンター大技が、大技のあいだに焼かれた数を数えるのに使う
static var burned_total : int = 0

static func set_chain_allowed(allowed : bool) -> void:
	_chain_allowed = allowed

var direction : Vector2 = Vector2.DOWN
var speed : float = 250.0
var accel : float = 0.0

var _state : BulletState = BulletState.NORMAL
## カウンター弾(ShotPattern の Counter Hp Ratio)。返して敵に当てると、その敵の最大HPのこの割合を削る
var counter_hp_ratio : float = 0.0
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
var _step_from_alpha : float = 1.0 # 区間の始めの不透明度
## 回る帯(ShotPattern の Window): 撃った中心からの向きが、回る帯の中にある弾だけ大きくなる
var _window_pattern : ShotPattern
var _window_origin : Vector2 = Vector2.ZERO
var _window_base_scale : Vector2 = Vector2.ONE
var _mirror : bool = false # 左右反転して出た敵の弾(曲がる向き・回す向きが逆)

# ---- 分裂(ShotPattern の Split。割れたら、Split Pattern の弾になって消える) ----
var _split_pattern : ShotPattern # 割れる設定を持つパターン(この弾を撃ったパターン)
var _split_in : float = -1.0 # 割れるまでの残り秒数。マイナスなら割れない
var _split_depth : int = 0
## 撃った敵が、撃ったときに動いていた向き(ラジアン)。Split Across Motion の弾幕で、割れる向きの基準にする。NAN なら使わない
var split_heading : float = NAN
## 集合弾(ShotPattern の Cluster Layers)の、群れの真ん中からのずれ。群れで向きを変える(AIM_GROUP)ときに使う
var group_offset : Vector2 = Vector2.ZERO
## 立体弾幕(ShotPattern の Ring3d): 回る輪の中の位置。弾はふつうに飛びながら、輪の中の位置のずれを足す
var _ring_pattern : ShotPattern
var _ring_index : int = 0
var _ring_heading : float = 0.0
var _ring_spin_sign : float = 1.0
var _ring_offset : Vector2 = Vector2.ZERO
var _ring_time : float = 0.0
var _ring_base_scale : Vector2 = Vector2.ONE
var _ring_sprite : CanvasItem
var _ring_sprite_color : Color = Color.WHITE

## 画面からこれより遠くへ行った弾は消す(px)
const FAR_AWAY_DISTANCE : float = 700.0

## 生まれた時刻と、はじめて画面に入った時刻(ミリ秒)
var _born_msec : int = 0
var _revealed_msec : int = 0

var lifetime_check : float = randf() * 0.5

# ---- 壊せる弾(ShotPattern の Break Hp)。自機のショットが当たる当たり判定を、あとから付ける ----
const BREAK_HURTBOX_PATH : String = "res://Component/Hurtbox/hurtbox.tscn"
## 壊したときの点と、出るスコアアイテムの合計
const BREAK_POINTS : int = 5000
const BREAK_ITEM_POINTS : int = 4000
var _break_hp : int = 0
var _break_hurtbox : Hurtbox

## 画面の外で生まれて、ついさっき(within_msec 以内に)画面に入ってきた弾か
func just_revealed_from_offscreen(within_msec : int) -> bool:
	if _revealed_msec == 0:
		return false # まだ画面に入ったと分かっていない(念のため守らない)
	return _revealed_msec - _born_msec > 80 and Time.get_ticks_msec() - _revealed_msec <= within_msec

func _ready() -> void:
	damage_source_type = DamageSourceType.Enemy
	add_to_group("enemy_bullet") # 被弾時・イグナイト終了時の弾消しの対象
	# 当たったら消える(自機に当たっても、反射弾が敵に当たっても)
	damage_dealt.connect(_on_damage_dealt)
	area_entered.connect(_on_area_entered)
	# ANOTHER: 弾がとても多いので、当たり判定を半分の大きさにする(形の資源は共有なので、ノードの大きさで縮める)
	if HazardRank.active or HazardRank.small_bullet_hitbox:
		for child in get_children():
			if child is CollisionShape2D or child is CollisionPolygon2D:
				child.scale *= HazardRank.BULLET_HITBOX_SCALE
	# 画面外に出たら消える
	var notifier := VisibleOnScreenNotifier2D.new()
	add_child(notifier)
	notifier.screen_exited.connect(queue_free)
	# 画面の外で生まれて、カメラが動いて画面に入ってきた弾か(自機の理不尽な被弾を防ぐのに使う)
	_born_msec = Time.get_ticks_msec()
	notifier.screen_entered.connect(func() -> void:
		if _revealed_msec == 0:
			_revealed_msec = Time.get_ticks_msec())
	# 画面の外で撃たれた弾(画面外から撃ってくるボス)は、画面に入らないまま遠くへ行ったら消す

func setup(dir : Vector2, spd : float, dmg : float, acc : float = 0.0) -> void:
	direction = dir.normalized()
	speed = spd
	damage = dmg
	accel = acc
	rotation = direction.angle() + PI / 2.0

## 回る帯に入れる。origin は撃った中心。setup のあとに呼ぶ
func set_window(pattern : ShotPattern, origin : Vector2) -> void:
	_window_pattern = pattern
	_window_origin = origin
	_window_base_scale = scale
	_apply_window()

## 中心から見た向きが、回る帯([速さ × 時刻, + 幅] 度)の中なら大きく、外ならふつうの大きさ。帯はすべての弾で同じ時計で回る
func _apply_window() -> void:
	var p := _window_pattern
	var t := Time.get_ticks_msec() / 1000.0
	var start := fposmod(p.window_speed_deg * t, 360.0)
	var angle := fposmod(rad_to_deg((global_position - _window_origin).angle()), 360.0)
	var inside := fposmod(angle - start, 360.0) <= p.window_width_deg
	if p.window_speed_deg < 0.0:
		inside = fposmod(start - angle, 360.0) <= p.window_width_deg
	var target := _window_base_scale * (p.window_big_scale if inside else 1.0)
	scale = scale.lerp(target, 0.35)

## 立体弾幕の輪に並べる。index は輪の中の何番目か、heading は輪が飛ぶ向き(ラジアン)。setup のあとに呼ぶ
func set_ring3d(pattern : ShotPattern, index : int, heading : float, mirror : bool = false) -> void:
	_ring_pattern = pattern
	_ring_index = index
	_ring_heading = heading
	_ring_spin_sign = -1.0 if mirror else 1.0
	_ring_base_scale = scale
	for child in get_children():
		if child is Sprite2D or child is AnimatedSprite2D:
			_ring_sprite = child
			_ring_sprite_color = child.self_modulate
			break
	_apply_ring(0.0)

## 輪の中の位置を進める: 輪の面を傾けて、手前の弾は大きく明るく、奥の弾は小さく暗くする
func _apply_ring(delta : float) -> void:
	var p := _ring_pattern
	_ring_time += delta
	var r := minf(p.ring3d_radius + p.ring3d_grow * _ring_time, maxf(p.ring3d_max_radius, p.ring3d_radius))
	var a := TAU * float(_ring_index) / float(maxi(p.ring3d_count, 1)) + deg_to_rad(p.ring3d_spin) * _ring_time * _ring_spin_sign
	var tilt := deg_to_rad(p.ring3d_tilt + p.ring3d_tumble * _ring_time)
	# 輪の面: 横 = 飛ぶ向きに直角、縦 = 飛ぶ向き。傾けるほど縦がつぶれて、奥行きになる
	var side := cos(a) * r
	var forward := sin(a) * r * cos(tilt)
	var depth := sin(a) * sin(tilt) # プラスが手前(-1〜1)
	var heading := direction.normalized() if direction != Vector2.ZERO else Vector2.from_angle(_ring_heading) # 曲がる弾でも、輪は飛ぶ向きを向く
	var offset := heading * forward + heading.orthogonal() * side
	global_position += offset - _ring_offset
	_ring_offset = offset
	scale = _ring_base_scale * (1.0 + p.ring3d_depth_scale * depth)
	z_index = 6 if depth >= 0.0 else 4
	if _ring_sprite:
		_ring_sprite.self_modulate = _ring_sprite_color.darkened(clampf(-depth, 0.0, 1.0) * 0.5)

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
		_split_in = maxf(pattern.split_time + randf_range(-pattern.split_time_random, pattern.split_time_random), 0.05)
	else:
		_split_pattern = null
		_split_in = -1.0

## 割れた弾幕を、割れた場所から順番に出す(割れた弾はすぐ消えるので、出すのは親に置いた小さなノードが続ける)
static func _emit_sequence(parent : Node, pattern : ShotPattern, aim : float, at : Vector2, fallback : PackedScene,
		mirror : bool, turn : float, depth : int) -> void:
	var emitter := Node.new()
	parent.add_child(emitter)
	for i in pattern.shot_count:
		if not is_instance_valid(emitter) or not emitter.is_inside_tree():
			return
		EnemyShooter.spawn_bullets(pattern, i, aim, at, parent, fallback, mirror, turn, depth)
		if i < pattern.shot_count - 1:
			await emitter.get_tree().create_timer(maxf(pattern.interval, 0.01), false).timeout
	if is_instance_valid(emitter):
		emitter.queue_free()

## 割れて、Split Pattern の弾を出し、自分は消える
func _split() -> void:
	_split_in = -1.0
	var parent := get_parent()
	if _split_pattern.split_vanish or _split_pattern.split_pattern == null:
		vanish(0.0) # 割れずに光って消える(巨大弾に吸い込まれる弾など)
		return
	var child := _split_pattern.split_pattern
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var aim := (player.global_position - global_position).angle() if player else Vector2.DOWN.angle()
	var fallback : PackedScene = load(scene_file_path) if scene_file_path != "" else null
	var turn := ShotMath.split_turn(_split_pattern, direction.angle())
	if _split_pattern.split_across_motion and not is_nan(split_heading) and not child.aim_at_player:
		turn = split_heading - Vector2.DOWN.angle() # 撃った敵の進む向きを基準にする(2発・180度なら、進む向きと直角に割れる)
	if child.shot_count > 1 and parent:
		# 割れた場所から、Interval ごとに1発ずつ順番に出す(Rotate Per Shot で回せば、渦を巻いて出てくる)
		_emit_sequence(parent, child, aim, global_position, fallback, _mirror, turn, _split_depth + 1)
	else:
		EnemyShooter.spawn_bullets(child, 0, aim, global_position, parent, fallback, _mirror, turn, _split_depth + 1)
	# 割れたあとの弾幕の With Patterns も、同じ場所から一緒に出す(大蛇と花火など、2種類を重ねて割れる)
	if parent:
		for companion in child.with_patterns:
			if companion == null:
				continue
			var companion_aim := aim if companion.aim_at_player else Vector2.DOWN.angle()
			if companion.shot_count > 1:
				_emit_sequence(parent, companion, companion_aim, global_position, fallback, _mirror, 0.0, _split_depth + 1)
			else:
				EnemyShooter.spawn_bullets(companion, 0, companion_aim, global_position, parent, fallback, _mirror, 0.0, _split_depth + 1)
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

## 壊せる弾にする(撃ったときに EnemyShooter が呼ぶ)。自機のショットが当たる当たり判定を付ける。
## 当たり判定は、弾の見た目より少し大きめ(大きい弾なので、狙って撃ち込めるように)
func make_breakable(hp : int) -> void:
	if hp <= 0 or _break_hurtbox:
		return
	_break_hp = hp
	var scene : PackedScene = load(BREAK_HURTBOX_PATH)
	_break_hurtbox = scene.instantiate() as Hurtbox
	_break_hurtbox.collision_layer = 64 # 敵の当たり判定と同じ層(自機のショットが当たる)
	_break_hurtbox.collision_mask = 8
	var circle := CircleShape2D.new()
	circle.radius = _base_radius() * 1.25
	(_break_hurtbox.get_node("CollisionShape2D") as CollisionShape2D).shape = circle
	add_child(_break_hurtbox)
	_break_hurtbox.recieved_damage.connect(_on_break_damage)

## 弾のもとの当たり判定の半径(ANOTHER で小さくした分は戻す)
func _base_radius() -> float:
	for child in get_children():
		if child is CollisionShape2D and child.shape is CircleShape2D:
			var shrink : float = HazardRank.BULLET_HITBOX_SCALE if HazardRank.active or HazardRank.small_bullet_hitbox else 1.0
			return (child.shape as CircleShape2D).radius * child.scale.x / shrink
	return 24.0

## 壊せる弾の当たり判定を外す(返した・焼いた・消えた弾は、もうショットを受け止めない)
func _drop_breakable() -> void:
	if _break_hurtbox and is_instance_valid(_break_hurtbox):
		_break_hurtbox.queue_free()
	_break_hurtbox = null

func _on_break_damage(amount : int) -> void:
	if _state != BulletState.NORMAL or _break_hp <= 0:
		return
	_break_hp -= amount
	if _break_hp <= 0:
		_break()
		return
	# 当たった手応え: 一瞬白く光る
	var sprite := _find_sprite()
	if sprite:
		sprite.modulate = Color(1.8, 1.8, 1.8)
		var tween := sprite.create_tween()
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.08)

## 壊れた: 割れずに、炎を上げて消える。点とスコアアイテムが出る
func _break() -> void:
	_split_in = -1.0
	var tree := get_tree()
	var at := global_position
	(load("res://GameScene/Effect/fire_fx.gd") as GDScript).flame_burst(tree, at, 2.2)
	var camera := StageCamera.of(self)
	if camera:
		camera.shake(3.0, 0.15)
	var score_system := tree.get_first_node_in_group("score_system") as ScoreSystem
	if score_system:
		score_system.add_points(BREAK_POINTS, at)
		score_system.spawn_items(at, BREAK_ITEM_POINTS, 8, 1.4)
	vanish(0.0)

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

## 外から押される(Union が画面の下に突き当たった衝撃など): time 秒かけて、offset だけずれる(自分の動きはそのまま)
var _kick_velocity : Vector2 = Vector2.ZERO
var _kick_left : float = 0.0

func kick(offset : Vector2, time : float = 0.2) -> void:
	_kick_left = maxf(time, 0.01)
	_kick_velocity = offset / _kick_left

func is_normal() -> bool:
	return _state == BulletState.NORMAL

func is_ignited() -> bool:
	return _state == BulletState.IGNITED

## 焼却: 燃えて消える。成功したら true(スコア加算の判定に使う)
func burn() -> bool:
	if _state != BulletState.NORMAL:
		return false
	_state = BulletState.BURNING
	burned_total += 1
	_drop_breakable()
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
	_drop_breakable()
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
	_drop_breakable() # 返した弾は、もう壊せない(自分の当たり判定に当たらないように)
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
	set_deferred("monitoring", true)

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
	lifetime_check -= delta
	if _kick_left > 0.0:
		var push := minf(delta, _kick_left)
		global_position += _kick_velocity * push
		_kick_left -= push
	if lifetime_check <= 0.0:
		lifetime_check = 0.5
		_check_far_away()
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
			if _ring_pattern:
				_apply_ring(delta)
			if _window_pattern:
				_apply_window()
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
	if step.fade_to >= 0.0:
		modulate.a = lerpf(_step_from_alpha, step.fade_to, clampf(_step_time / maxf(step.duration, 0.001), 0.0, 1.0))
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
	_step_from_alpha = modulate.a
	if index >= _motion.size():
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D if is_inside_tree() else null
	var player_position := player.global_position if player else global_position + Vector2.DOWN
	var from := global_position
	if _motion[index].turn_mode == BulletStep.TurnMode.AIM_GROUP:
		from -= group_offset # 群れの真ん中から狙う(群れの弾が、みんな同じ向きになる)
	var heading := ShotMath.turned_heading(_motion[index], direction.angle(), from, player_position, _mirror)
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
	for enemy in EnemyPart.targets(get_tree()): # 敵と、ボスの部位(砲台など)
		var d := global_position.distance_squared_to(enemy.global_position)
		if d < best:
			best = d
			nearest = enemy
	return nearest

## 画面から Far Away Distance より遠くにいたら消す(画面の外から撃たれて、画面に入らなかった弾)
func _check_far_away() -> void:
	if not CameraView.visible_rect(self).grow(FAR_AWAY_DISTANCE).has_point(global_position):
		queue_free()
