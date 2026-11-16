extends Player
class_name BastionPlayer
## 守り型の自機「BASTION」。シーン(GameScene/Player/bastion.tscn)で使う。Player の仕組みはそのまま使い、次のところだけ変える。
##
##   ショット : ショットガン。大きく広がり、すぐ消える(近づかないと倒しにくい)。イグナイト中は威力が上がり、弾も大きく明るくなる。
##              ゲージの Lv で強くなる: Lv3 で3連発、Lv4 で間隔が短く、Lv5 で5連発
##   子機     : 自機を中心に回り、外向きに 2way で撃つ
##   Shift    : 低速移動。子機を全部、進む向き(止まったら、最後に動いた向き。最初は真上)へ向けて撃つ。ロックショットはない
##   被弾     : 無敵は短い(1.5秒)。被弾したとき、周りの弾が消える
##   ゲージ   : Lvによる威力・移動の速さの補正はない(ショットガンの連発は Lv で増える)。
##              補給アイテムは、被弾したときの進み具合を全部取り戻せ、Lv0〜1でも出る
##   イグナイト: 効果時間が長い(最大8秒)代わりに、弾を焼いても延びない。跳ね返した弾の威力は2倍
## 機体ごとの決まり(補正・効果時間)は、シーンの「機体ごとの決まり」の値で決める。

@export_group("BASTION: ショットガン")
## 1回に撃つ弾の数と、広がり(度。±この半分)
@export var pellet_count : int = 7
@export var pellet_spread : float = 60.0
## 弾の速さ(px/秒)と、消えるまでの時間(秒)。700 × 0.4 で約280px 届く
@export var pellet_speed : float = 700.0
@export var pellet_life : float = 0.4
## 1発の威力(Pellet Dps が空のときだけ使う)
@export var pellet_damage : float = 8.0
## ゲージの Lv(Lv0〜Lv5 の順)ごとの、1回に続けて撃つ回数(連発)と、撃つ間隔(秒)。
## Lv3 で3連発、Lv4 で間隔が短くなり、Lv5 で5連発
@export var pellet_bursts : Array[int] = [1, 1, 1, 3, 3, 5]
@export var pellet_intervals : Array[float] = [0.2, 0.2, 0.2, 0.2, 0.16, 0.16]
## 連発の1発ごとの間隔(秒)
@export var pellet_burst_gap : float = 0.04
## ゲージの Lv(Lv0〜Lv5 の順)ごとの、ショットガンが全部当たったときの毎秒の火力。
## 1発の威力は、これを「毎秒の弾の数」で割って決める(連発や間隔を変えても、火力はこの値のまま)。
## 空なら、どの Lv でも Pellet Damage を使う。
## 目安(1面の PHOENIX の通常ショット): Lv4 は約630、Lv5 は約660。BASTION は Lv4 で PHOENIX の Lv5 くらい、Lv5 でそれより100高く
@export var pellet_dps : Array[float] = [280.0, 280.0, 280.0, 470.0, 660.0, 760.0]
## 弾の大きさと濃さ(自機の弾が多いので、敵の弾が見えなくならないように、薄く小さくする)
@export var pellet_scale : float = 0.75
@export var pellet_alpha : float = 0.7

@export_group("BASTION: 子機")
## 子機は、ふだんは自機を中心に回り、外向きに 2way で撃つ。円の半径(px)と、回る速さ(度/秒)
@export var orbit_radius : float = 36.0
@export var orbit_speed : float = 150.0
## 2way の開き(度)
@export var option_way_spread : float = 14.0
## (今は使っていない)前の、左右に開く撃ち方のときの向き。選択画面のプレビューが読む
@export var option_angles : Array[float] = [-45.0, 45.0, -70.0, 70.0]
## 子機の撃つ間隔(秒)と、1回の威力(2way の2発に分ける)
@export var option_interval : float = 0.1
@export var option_damage : float = 8.0

@export_group("BASTION: イグナイト中")
## イグナイト中のショット・子機の威力の倍率と、弾の大きさの倍率
@export var ignite_shot_scale : float = 2.0
@export var ignite_pellet_size : float = 1.4
## イグナイトで跳ね返した弾(反射弾)の威力の倍率(PHOENIX の反射弾に対して)
@export var reflect_damage_scale : float = 2.0

@export_group("BASTION: イグナイトのあと")
## イグナイトが終わったあとの無敵が切れてから、その無敵と同じ秒数のあいだ、グレイズで入るゲージがこの倍になる。
## 無敵中はグレイズしないので、危ないところでグレイズしたときだけ得をする。そのあいだ、機体が水色に脈打つ
@export var after_ignite_graze_scale : float = 2.0
@export var after_ignite_tint : Color = Color(0.6, 0.95, 1.4)

@export_group("BASTION: 被弾")
## 被弾したときに、自機のこの半径(px)の中の敵弾を消す
@export var hit_clear_radius : float = 40.0

## 最後に動いた向き(Shift 中の子機の向き)。最初は真上
var _aim_dir : Vector2 = Vector2.UP
## イグナイトが終わった物理フレーム(その直後の無敵だけを数える)と、その無敵の秒数
var _ignite_end_frame : int = -1
var _after_ignite_time : float = 0.0
## グレイズで入るゲージが多い残り時間(秒)
var _boost_left : float = 0.0
var _pellet_wait : float = 0.0

func _ready() -> void:
	super._ready()
	lock_shot_enabled = false # ロックショットはない(Shift は子機の向きを変える)
	ignite_toggled.connect(func(on : bool) -> void:
		if not on:
			_ignite_end_frame = Engine.get_physics_frames())
	invincibility.ended.connect(_on_invincibility_ended)
	# 跳ね返した弾の威力: 反射弾の設定(IgniteParams)を、この機体用に写して倍にする(PHOENIX の設定は変えない)
	if ignite_aura and ignite_aura.params:
		ignite_aura.params = ignite_aura.params.duplicate()
		ignite_aura.params.base_damage *= reflect_damage_scale

func _physics_process(delta : float) -> void:
	super._physics_process(delta)
	if velocity.length_squared() > 100.0:
		_aim_dir = velocity.normalized()
	if _pellet_wait > 0.0:
		_pellet_wait -= delta
	_update_boost(delta)

## ショット: 子機は Option Interval ごと、ショットガンは Pellet Interval ごとに撃つ
func _shoot(_delta : float) -> void:
	if not Input.is_action_pressed("UI_Shoot") or not _is_alive:
		return
	if shoot_timer.time_left <= 0.0:
		shoot_timer.start(option_interval)
		_fire_options()
	# ショットガンは、子機とは別の間隔で撃つ(Lv で間隔が変わる)
	if _pellet_wait <= 0.0 and bullet_scene:
		var level := clampi(shot_look_level, 0, 5)
		_pellet_wait += _at(pellet_intervals, level, 0.2)
		if _pellet_wait < 0.0:
			_pellet_wait = 0.0
		SoundManager.play_on_channel(&"player_shot", shot_sound)
		var volley := _volley_damage(level)
		_fire_shotgun(volley)
		# 連発: 同じショットガンを、少しずつ遅らせて撃つ
		for i in range(1, int(_at(pellet_bursts, level, 1))):
			var wait := create_tween()
			wait.tween_interval(pellet_burst_gap * i)
			wait.tween_callback(func() -> void:
				if _is_alive:
					_fire_shotgun(volley))

## ショットガン1回(弾 Pellet Count 発)の威力の合計。Lv の毎秒の火力 ÷ 1秒に撃つ回数
func _volley_damage(level : int) -> float:
	if pellet_dps.is_empty():
		return pellet_damage * pellet_count
	var per_second := _at(pellet_bursts, level, 1) / maxf(_at(pellet_intervals, level, 0.2), 0.01)
	return _at(pellet_dps, level, 280.0) / maxf(per_second, 0.01)

func _at(values : Array, index : int, fallback : float) -> float:
	if values.is_empty():
		return fallback
	return float(values[clampi(index, 0, values.size() - 1)])

func _power() -> float:
	return ignite_shot_scale if is_igniting else 1.0

func _fire_shotgun(volley_damage : float) -> void:
	var size := pellet_scale * (ignite_pellet_size if is_igniting else 1.0)
	# 合計を弾に分ける(割り切れない分は、はじめの弾に1ずつ足す)。イグナイト中は倍になる
	var total := maxi(roundi(volley_damage * _power()), pellet_count)
	for i in pellet_count:
		var each : int = total / pellet_count + (1 if i < total % pellet_count else 0)
		var t := 0.5 if pellet_count <= 1 else float(i) / (pellet_count - 1)
		var angle := lerpf(-pellet_spread * 0.5, pellet_spread * 0.5, t) + randf_range(-2.0, 2.0)
		var bullet : Bullet = bullet_scene.instantiate()
		get_tree().current_scene.add_child(bullet)
		bullet.global_position = global_position + muzzle_offset
		bullet.setup(Vector2.UP.rotated(deg_to_rad(angle)), pellet_speed * randf_range(0.92, 1.05), each, 0)
		bullet.life = pellet_life
		bullet.scale = Vector2.ONE * size
		bullet.modulate = Color(1.4, 1.25, 1.1, 1.0) if is_igniting else Color(1.0, 1.0, 1.0, pellet_alpha)

## 子機: ふだんは自機のまわりを回り、外向き(自機から子機の向き)に 2way で撃つ。
## Shift 中は今までどおり、自機の横に並んで、進む向きへ1発ずつ撃つ。ロックはしない
func _fire_options() -> void:
	if options.is_empty() or bullet_scene == null:
		return
	for option in options:
		if is_focusing:
			_style_option_bullet(option.fire(bullet_scene, shot_speed, option_damage * _power(), null, 0.0, _aim_dir))
			continue
		var out := Vector2.from_angle(option.orbit_angle())
		for side in [-0.5, 0.5]:
			var dir := out.rotated(deg_to_rad(option_way_spread * side))
			_style_option_bullet(option.fire(bullet_scene, shot_speed, option_damage * 0.5 * _power(), null, 0.0, dir))

func _style_option_bullet(bullet : Bullet) -> void:
	if bullet == null:
		return
	bullet.modulate = Color(1.0, 1.0, 1.0, pellet_alpha)
	if is_igniting:
		bullet.scale = Vector2.ONE * ignite_pellet_size

func add_option() -> bool:
	if not super.add_option():
		return false
	# 子機を、自機のまわりを回る形にする(威力は Option Damage をそのまま使う)
	var option := options.back() as PlayerOption
	option.orbit_radius = orbit_radius
	option.orbit_speed = orbit_speed
	option.damage_scale = 1.0
	return true

func _is_lock_shooting() -> bool:
	return false

func _on_hurtbox_recieved_damage(damage : int) -> void:
	var will_hit := not (is_invincible() or DebugTools.invincible)
	super._on_hurtbox_recieved_damage(damage)
	if will_hit and _is_alive:
		_clear_nearby_bullets()

## 被弾した瞬間に、自機の周りの敵弾を消す(続けて当たりにくくする)
func _clear_nearby_bullets() -> void:
	for node in get_tree().get_nodes_in_group("enemy_bullet"):
		var bullet := node as EnemyBullet
		if bullet and bullet.global_position.distance_to(global_position) <= hit_clear_radius:
			bullet.vanish(0.0)

# ---------------------------------------------------------------- イグナイトのあとの、溜まりやすい時間

## イグナイトが終わった直後に付く無敵だけ、秒数を覚えておく(復活などの無敵では起きない)
func start_invincibility(seconds : float) -> void:
	if _ignite_end_frame == Engine.get_physics_frames() and _is_alive:
		_after_ignite_time = seconds
	super.start_invincibility(seconds)

## 無敵が切れた: イグナイトのあとの無敵なら、同じ秒数だけ溜まりやすくなる
func _on_invincibility_ended() -> void:
	if _after_ignite_time > 0.0 and _is_alive:
		_boost_left = _after_ignite_time
	_after_ignite_time = 0.0

func _update_boost(delta : float) -> void:
	var sprite := get_node_or_null("Sprite2D") as CanvasItem
	if _boost_left > 0.0:
		_boost_left = maxf(_boost_left - delta, 0.0)
		if sprite:
			var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.02)
			var tint := Color.WHITE.lerp(after_ignite_tint, pulse)
			sprite.self_modulate = Color(tint.r, tint.g, tint.b, 1.0) if _boost_left > 0.0 else Color.WHITE
	elif sprite and sprite.self_modulate != Color.WHITE:
		sprite.self_modulate = Color.WHITE

func graze_gain_scale() -> float:
	return after_ignite_graze_scale if _boost_left > 0.0 else 1.0
