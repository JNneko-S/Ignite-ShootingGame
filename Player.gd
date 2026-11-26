extends CharacterBody2D
class_name Player

@export_group("移動")
@export var move_speed: float = 300.0
## 低速移動(UI_Focus を押している間)の速度倍率
@export_range(0.05, 1.0, 0.05) var focus_speed_multiplier : float = 0.4

## 難易度などによる、グレイズ半径の倍率(GameManager が設定する)。
## グレイズの半径そのものは、子の GrazeArea(GrazeDetector)の Radius で変える
var graze_radius_scale : float = 1.0:
	set(value):
		graze_radius_scale = value
		if graze_area:
			graze_area.radius_scale = value

@export_group("攻撃")
@export var bullet_scene : PackedScene
## 発射間隔(秒)。ShootTimer の wait_time に反映される
@export var fire_interval : float = 0.1

@onready var graze_area: GrazeDetector = $GrazeArea
@onready var invincibility: Invincibility = $Invincibility
@onready var graze_shape: CollisionShape2D = $GrazeArea/GrazeShape
@onready var shoot_timer: Timer = $ShootTimer
## 通常時(強化なし)の発射角度
@export var shot_angles : Array[float] = [0.0]
@export var muzzle_offset : Vector2 = Vector2(0, -16)
## 撃ったときの効果音(シーンに置いた AudioStreamPlayer)。空なら鳴らさない
@export var shot_sound : AudioStreamPlayer
## グレイズしたときの効果音(AudioStreamPlayer)。空なら鳴らさない
@export var graze_sound : AudioStreamPlayer
## グレイズの音を鳴らす最短の間隔(秒)。一度にたくさんグレイズしても、鳴りすぎないように
@export var graze_sound_interval : float = 0.06

@export_group("ショットの威力")
## 通常ショット1発の基礎ダメージ(整数に丸められても倍率の差が残るよう、ダメージと体力は10倍の単位で扱う)
@export var shot_damage : float = 10.0
## 威力の倍率(どこから撃っても同じ)
@export var shot_power : float = 1.2
## 近づいて撃つと、ショットの威力がこの倍率になる(敵との距離が Close Damage Distance 以内のとき)
@export var close_damage_scale : float = 1.1
@export var close_damage_distance : float = 96.0
## ショットの弾速(px/秒)。自機の移動速度(Lv5で約375)より十分速くすること
@export var shot_speed : float = 900.0
## true なら、前進している速度の分だけ弾速を足す。縦に動いても、弾の間隔が一定になり、重ならない
@export var shot_inherit_forward_speed : bool = true
## (使っていない)前は弾の色に掛けていた。今は弾の絵の色のまま撃つ
@export var shot_color : Color = Color(1.0, 1.0, 1.0)
## レベルが上がったときの、平行に並ぶ弾の横の位置(px)。Lv2 は4発、Lv3 からは5発
@export var parallel_offsets_4 : Array[float] = [-10.5, -3.5, 3.5, 10.5]
@export var parallel_offsets_5 : Array[float] = [-14.0, -7.0, 0.0, 7.0, 14.0]
## 低速移動中(ロックしていないとき)に、平行な弾・ビームの幅を絞る倍率
@export var focus_parallel_scale : float = 0.45

@export_group("ロックショット(低速移動中に撃つ)")
## オンなら、UI_Focus(Shift)を押しながら撃つと、ロックした敵を追いかける弾になる
@export var lock_shot_enabled : bool = true
## ロックできる距離(px)
@export var lock_range : float = 360.0
## ロックできる範囲の、真上からの角度(度)。70 なら前方の ±70°
@export var lock_cone_deg : float = 70.0
## 1体ロックするのにかかる時間(秒)。近い敵から順にロックする
@export var lock_time : float = 0.12
## 同時にロックできる数(ショット強化の段階 0〜5 の順)
@export var lock_max_targets : Array[int] = [2, 2, 3, 3, 4, 4]
## ロックショットの、1発あたりの威力の倍率(必ず当たるので、通常より少し弱くする)
@export var lock_damage_scale : float = 0.8
## ロックショットの曲がる速さ(度/秒)
@export var lock_turn_rate : float = 720.0
## ロックしていないときの、低速移動中のショットの広がりの倍率(0.3 なら、通常の 30% の幅に絞る)
@export var focus_spread_scale : float = 0.3
## 照準の色
@export var lock_color : Color = Color(1.0, 0.35, 0.3)
## ロックするまでの時間の倍率(パワーアップの段階 0, 1, 2, … の順)。段階の数 = 最大の段階 + 1
@export var lock_time_scales : Array[float] = [1.0, 0.75, 0.55, 0.4]
## 1体ロックしたときの効果音(AudioStreamPlayer)
@export var lock_sound : AudioStreamPlayer

@export_group("子機(オプション)")
## 子機のシーン(ルートが PlayerOption)
@export var option_scene : PackedScene = preload("res://GameScene/Player/option.tscn")
## 子機の最大数
@export var max_options : int = 4
## 死んだときに失う子機の数。-1 なら全て(Drop Power Ups On Death がオンなら、全て落とす)
@export var options_lost_on_death : int = -1
## オンなら、死んだときに、持っていたパワーアップ(子機・ロック速度)を全てアイテムとして落とす。
## 復活してから拾い直せる
@export var drop_power_ups_on_death : bool = true
## 落とすアイテムのシーン(空なら、下の決まったシーンを使う)。
## preload にしないこと: アイテムのスクリプト(PowerUpItem)が Player を参照しているので、
## Player.gd から preload すると読み込みが循環し、アイテムのシーンがスクリプトなしで読み込まれてしまう
## (動かず拾えない絵だけが画面に残る)
@export var power_up_option_scene : PackedScene
## イグナイト中、ショット(子機も)の威力をこの倍にする。BASTION は、散弾の Ignite Shot Scale を使うので 1 にしておく
@export var ignite_damage_scale : float = 1.5
@export var power_up_lock_scene : PackedScene
const POWER_UP_OPTION_PATH := "res://GameScene/Item/power_up_option.tscn"
const POWER_UP_LOCK_PATH := "res://GameScene/Item/power_up_lock.tscn"

@export_group("ショット強化(Lv5イグナイトで+1段階。被弾で失う)")
## way弾の角度の間隔(度)
@export var power_spread_deg : float = 8.0
## バースト弾の、1発ごとの間隔(秒)
@export var power_burst_gap : float = 0.06
## 高速連射の段階(4・5段階目)の、発射間隔の倍率
@export var power_fast_interval_scale : float = 0.5

@export_group("画面・操作")
## 自機が動ける範囲の余白(px)。画面の端から、この分だけ内側までしか動けない
@export var screen_margin : float = 16.0
## 低速移動中に、当たり判定を表示する
@export var show_hitbox_on_focus : bool = true
## Hurtbox の CollisionShape2D が円でないときの、表示する半径
@export var hitbox_display_radius : float = 3.0
## 矢印キーを、移動のキーに追加する(WASD は Input Map から外せる)
@export var add_arrow_keys : bool = true
## スティックをこの割合まで倒すと全速(1 なら、いっぱいに倒したときだけ全速)
@export_range(0.3, 1.0, 0.05) var stick_full_ratio : float = 0.9

@export_group("イグナイト入力")
## 長押しで「全レベル消費」になるまでの時間(秒)。それより前に離すと、単押し(1レベル消費)
@export var ignite_hold_time : float = 1.5
## 溜めの間、自機の周りに出るリングの半径
@export var charge_ring_radius : float = 36.0

@export_group("被弾")
## 被弾して生き残ったあとの無敵時間(秒)。点滅し、この間はグレイズもできない
@export var hit_invincible_time : float = 3.0
## 被弾したとき・やられたときに、一瞬だけ時間を止める長さ(秒)。何に当たったかが分かるように
@export var hit_stop_time : float = 0.12
@export var death_stop_time : float = 0.28

@export_group("機体ごとの決まり(GameManager が読む)")
## オフなら、ゲージのLvによる威力・移動の速さの補正を使わない(どのLvでも同じ)
@export var use_level_scales : bool = true
## 空でなければ、イグナイトの効果時間(消費したレベル 1〜5 の順、秒)を、ステージの設定の代わりにこれにする
@export var ignite_durations_override : Array[float] = []
## オフなら、イグナイト中に弾を焼いても効果時間が延びない
@export var burn_extends_ignite : bool = true
## 0 以上なら、被弾時の補給アイテムで取り戻せる割合(ステージの Hit Item Recover Rate の代わり)
@export var hit_item_recover_override : float = -1.0
## 0 以上なら、補給アイテムが出る最低のレベル(ステージの Hit Item Min Level の代わり)
@export var hit_item_min_level_override : int = -1

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
## 被弾したときの炎(子の HitFlame)。なければ炎は出ない
@onready var hit_flame : PhoenixHitFlame = get_node_or_null("HitFlame")

const MAX_SHOT_STAGE : int = 5

var graze_count : int = 0
## 最後にグレイズの音を鳴らした時刻(ミリ秒)
var _last_graze_sound_msec : int = -100000
var is_focusing : bool = false

var _spawn_position : Vector2
var _is_alive : bool = true

## イグナイトがONか(ONの間、ゲージが減り続け、フレアが残る)
var _marker : HitboxMarker

var is_igniting : bool = false
## ゲージのレベルによる補正(GameManager が設定する)
var level_move_scale : float = 1.0
var level_power_scale : float = 1.0
## ショットの見た目のレベル(イグナイトのレベル。GameManager が設定する)。Lv2〜3 は平行な弾、Lv4〜5 はビーム
var shot_look_level : int = 1
var _beam : PlayerBeam

## 現在のショット強化の段階(0〜5)
var shot_stage : int = 0

## ロックしている敵(近い順)。低速移動をやめると外れる
var lock_targets : Array[Node2D] = []
var _lock_timer : float = 0.0
var _reticle : LockOnReticle
## ロック速度のパワーアップの段階(0 から)
var lock_speed_level : int = 0
## 子機(パワーアップで増える)
var options : Array[PlayerOption] = []

## 子機の数、ロック速度の段階が変わったときに出る(UI用)
signal options_changed(count : int)
signal lock_speed_changed(level : int)

## イグナイトを発動できる状態か(Lv1以上で、発動中でない)。GameManager が毎フレーム設定する
var ignite_available : bool = false
## true のあいだ、イグナイトを使えない(ボス撃破〜クリアの演出中。GameManager が決める)
var ignite_locked : bool = false
enum HoldState { IDLE, HOLDING, DONE }
var _hold_state : HoldState = HoldState.IDLE
var _hold_time : float = 0.0
var _charge_ratio : float = 0.0

signal grazed(total : int)
## グレイズした瞬間に出る。演出(GrazeEffect)やゲージ側はこれを受け取る。
## bullet_position: 掠めた弾の位置 / density: その時 GrazeArea 内にある弾の数(密度の目安)
signal graze_hit(bullet_position : Vector2, density : int)
## グレイズした弾そのもの(スコアの「かなり近い」判定に使う)
signal grazed_bullet(bullet : Area2D)
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
## ANOTHER の強化(連射速度UP・威力UP)が変わった
signal boost_changed

## ANOTHER の強化アイテムの段階(0〜BOOST_MAX)。自爆しても失わない
const BOOST_MAX : int = 5
## 最大の段階での倍率(初期の何倍か)
const BOOST_MAX_SCALE : float = 1.5
var rate_boost : int = 0
var power_boost : int = 0

## 連射速度の倍率(撃つ間隔を、これで割る)
func boost_rate_scale() -> float:
	return 1.0 + (BOOST_MAX_SCALE - 1.0) * float(rate_boost) / BOOST_MAX

## 威力の倍率
func boost_power_scale() -> float:
	return 1.0 + (BOOST_MAX_SCALE - 1.0) * float(power_boost) / BOOST_MAX

## イグナイト中のショットの威力の倍率(イグナイト中でなければ 1)
func ignite_power_scale() -> float:
	return ignite_damage_scale if is_igniting else 1.0

func _ready() -> void:
	add_to_group("player") # 敵の狙い撃ち用
	if add_arrow_keys:
		_add_arrow_keys()
	_create_hitbox_marker()
	_reticle = LockOnReticle.new()
	_reticle.color = lock_color
	add_child(_reticle)
	_spawn_position = global_position # 復活位置は、最初に置かれた位置
	if ignite_aura == null:
		push_warning("Player: 子に IgniteAura(ignite_aura.gd)が見つかりません。ノード名を IgniteAura にしてください")
	if not InputMap.has_action("UI_Ignite"):
		push_warning("Player: Input Map に UI_Ignite が登録されていないため、イグナイトは発動できません")
	shoot_timer.wait_time = fire_interval
	graze_area.radius_scale = graze_radius_scale
	graze_area.grazed.connect(_on_grazed)
	_beam = PlayerBeam.new()
	_beam.player = self
	_beam.muzzle_offset = muzzle_offset
	add_child(_beam)

func _physics_process(delta: float) -> void:
	# UI_Focus が InputMap に未登録でもエラーにならないようにしている
	is_focusing = InputMap.has_action("UI_Focus") and Input.is_action_pressed("UI_Focus")
	graze_area.focusing = is_focusing
	graze_area.active = not is_invincible() # 無敵中(復活直後・イグナイト後)と、死亡中はグレイズしない

	_update_ignite_input(delta)

	var dir := move_input()
	var speed := move_speed * level_move_scale
	if is_focusing:
		speed *= focus_speed_multiplier
	velocity = dir * speed
	move_and_slide()
	# 画面の外に出ないようにする(Camera2D の位置・ズームを考えた、実際に見えている範囲)
	var area := CameraView.visible_rect(self)
	global_position = global_position.clamp(
		area.position + Vector2(screen_margin, screen_margin), area.end - Vector2(screen_margin, screen_margin))
	if _marker:
		var marker_on := _is_alive and _hitbox_shown()
		_marker.alpha = move_toward(_marker.alpha, 1.0 if marker_on else 0.0, delta * 10.0)
	_update_lock(delta)
	_shoot(delta)

# ---------------------------------------------------------------- ショット

func _shoot(_delta: float) -> void:
	if not Input.is_action_pressed("UI_Shoot") or shoot_timer.time_left > 0.0:
		return
	if bullet_scene == null:
		return
	var pattern := _shot_pattern()
	shoot_timer.start(fire_interval * pattern["interval_scale"] / boost_rate_scale())
	if _is_alive:
		SoundManager.play_on_channel(&"player_shot", shot_sound)
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
	_fire_options()
	if _is_lock_shooting():
		if not lock_targets.is_empty():
			_fire_lock_volley()
			return
		# ロックしていなければ、前方に絞ったショット
		angles = angles.map(func(a : float) -> float: return a * focus_spread_scale)
	var damage := shot_damage * shot_power * level_power_scale * ignite_power_scale()
	var look := _shot_look()
	if look >= 2 and angles.size() == shot_angles.size():
		_fire_parallel(look, roundi(damage) * angles.size())
		return
	for angle_deg in angles:
		var bullet : Bullet = bullet_scene.instantiate()
		get_tree().current_scene.add_child(bullet)
		bullet.global_position = global_position + muzzle_offset
		var direction := Vector2.UP.rotated(deg_to_rad(angle_deg))
		if bullet.has_method("setup"):
			var speed := shot_speed
			if shot_inherit_forward_speed:
				speed += maxf(velocity.dot(direction), 0.0) # 弾の向きに進んでいる速度だけ足す
			bullet.setup(direction, speed, roundi(damage), 0) # 切り捨てだと 0 ダメージになるので四捨五入

## ショットの見た目のレベル(1〜5)。イグナイトのレベルで決まる(Lv0 は Lv1 と同じ)。威力は変わらない
func _shot_look() -> int:
	return clampi(shot_look_level, 1, 5)

## Lv2 以上の見た目: まっすぐ平行に並んだ弾(Lv2 は4発、Lv3 からは5発)。
## 1回分のダメージの合計(total)は、Lv1 の3発と同じで、それを発数で分ける。
## Lv4 からはビーム: 当たり判定は Lv3 の5発と同じで、弾は見えなくして、代わりにビームを描く
func _fire_parallel(look : int, total : int) -> void:
	var offsets : Array = parallel_offsets_4 if look == 2 else parallel_offsets_5
	var width_scale := focus_parallel_scale if _is_lock_shooting() else 1.0 # 低速移動中(ロックなし)は、幅を絞る
	var beam := look >= 4
	for i in offsets.size():
		var x : float = offsets[i]
		var bullet : Bullet = bullet_scene.instantiate()
		get_tree().current_scene.add_child(bullet)
		bullet.global_position = global_position + muzzle_offset + Vector2(float(x) * width_scale, 0.0)
		var speed := shot_speed
		if shot_inherit_forward_speed:
			speed += maxf(velocity.dot(Vector2.UP), 0.0)
		# 合計が Lv1 の3発とぴったり同じになるように、割り切れない分は、はじめの弾に1ずつ足す
		var each : int = total / offsets.size() + (1 if i < total % offsets.size() else 0)
		bullet.setup(Vector2.UP, speed, each, 0)
		if beam:
			bullet.get_node("Sprite2D").visible = false # 当たり判定だけ(見た目はビーム)
	if beam and _beam:
		_beam.fire(look >= 5, absf(float(offsets[0])) * width_scale)

# ---------------------------------------------------------------- ロックショット

func _is_lock_shooting() -> bool:
	return lock_shot_enabled and is_focusing

## ロックオン中か(低速移動中に、敵を1体以上ロックしている)。子機のフォーメーションの切り替えに使う
func is_locking_on() -> bool:
	return _is_lock_shooting() and not lock_targets.is_empty()

## 低速移動中、前方の扇の中の敵を、近い順に1体ずつロックしていく
func _update_lock(delta : float) -> void:
	# 消えた敵は、型を付けた引数に渡すとエラーになるので、先に取り除く
	lock_targets.assign(lock_targets.filter(func(t) -> bool: return is_instance_valid(t) and _can_keep_lock(t)))
	if not _is_lock_shooting() or not _is_alive:
		lock_targets.clear()
		_lock_timer = current_lock_time() # Shift を押した瞬間に、1体目はすぐロックする
	else:
		var max_count : int = lock_max_targets[clampi(shot_stage, 0, lock_max_targets.size() - 1)] if not lock_max_targets.is_empty() else 1
		_lock_timer += delta
		var time_per_lock := current_lock_time()
		while _lock_timer >= time_per_lock and lock_targets.size() < max_count:
			var next := _nearest_lockable()
			if next == null:
				break
			lock_targets.append(next)
			SoundManager.play(lock_sound, 1.0 + 0.08 * (lock_targets.size() - 1)) # ロックするたびに少し高く
			_lock_timer -= time_per_lock
		if lock_targets.size() >= max_count or _nearest_lockable() == null:
			_lock_timer = minf(_lock_timer, time_per_lock) # 溜めすぎない(空きができたら、すぐ1体ロックできる)
	if _reticle:
		_reticle.targets = lock_targets

func _nearest_lockable() -> Node2D:
	var best : Node2D = null
	var best_distance := INF
	for enemy in EnemyPart.targets(get_tree()): # 敵と、ボスの部位(砲台など)
		if lock_targets.has(enemy) or not _in_lock_area(enemy, lock_range):
			continue
		var d := global_position.distance_squared_to(enemy.global_position)
		if d < best_distance:
			best_distance = d
			best = enemy
	return best

## ロックできる場所にいるか(画面内で、前方の扇の中、距離が range 以内)
func _in_lock_area(enemy : Node2D, max_range : float) -> bool:
	if not CameraView.visible_rect(self).has_point(enemy.global_position):
		return false
	var to_enemy := enemy.global_position - global_position
	if to_enemy.length() > max_range:
		return false
	return absf(Vector2.UP.angle_to(to_enemy)) <= deg_to_rad(lock_cone_deg)

## 一度ロックした敵は、少し離れても(扇の外でも)、画面内にいる間は外さない
func _can_keep_lock(enemy : Node2D) -> bool:
	if not EnemyPart.is_target(enemy): # 倒された・壊れた・残骸になった
		return false
	return CameraView.visible_rect(self).has_point(enemy.global_position) 			and global_position.distance_to(enemy.global_position) <= lock_range * 1.3

## ロックした敵に、1体1発ずつ追いかける弾を撃つ(左右に少し開いて出て、弧を描いて向かう)
func _fire_lock_volley() -> void:
	var count := lock_targets.size()
	for i in count:
		var target := lock_targets[i]
		var bullet : Bullet = bullet_scene.instantiate()
		get_tree().current_scene.add_child(bullet)
		bullet.global_position = global_position + muzzle_offset
		var spread := (i - (count - 1) / 2.0) * 25.0
		var direction := Vector2.UP.rotated(deg_to_rad(spread))
		bullet.setup(direction, shot_speed, shot_damage * shot_power * level_power_scale * lock_damage_scale * ignite_power_scale(), 0)
		bullet.set_homing(target, lock_turn_rate)
		bullet.modulate = lock_color.lerp(Color.WHITE, 0.4)

## 1体ロックするのにかかる時間(ロック速度のパワーアップを反映した値)
func current_lock_time() -> float:
	if lock_time_scales.is_empty():
		return lock_time
	return lock_time * lock_time_scales[clampi(lock_speed_level, 0, lock_time_scales.size() - 1)]

# ---------------------------------------------------------------- パワーアップ(子機・ロック速度)

## パワーアップアイテムを拾った。強化できたら true(最大のときは false)
func apply_power_up(kind : PowerUpItem.Kind) -> bool:
	match kind:
		PowerUpItem.Kind.OPTION:
			if add_option():
				HazardRank.add(5, 5, "OPTION")
				return true
			return false
		PowerUpItem.Kind.RATE:
			if rate_boost >= BOOST_MAX:
				return false
			rate_boost += 1
			HazardRank.add(3, 3, "RATE UP")
			boost_changed.emit()
			FloatingText.spawn(get_tree(), global_position + Vector2(0, -36), "Bullet Speed Up!", Color(0.45, 0.8, 1.0))
			return true
		PowerUpItem.Kind.POWER:
			if power_boost >= BOOST_MAX:
				return false
			power_boost += 1
			HazardRank.add(6, 6, "POWER UP")
			boost_changed.emit()
			FloatingText.spawn(get_tree(), global_position + Vector2(0, -36), "Damage Up!", Color(1.0, 0.6, 0.25))
			return true
		PowerUpItem.Kind.LOCK_SPEED:
			return upgrade_lock_speed()
		PowerUpItem.Kind.OPTION_PAIR:
			var added := add_option()
			added = add_option() or added
			if added:
				FloatingText.spawn(get_tree(), global_position + Vector2(0, -36), "Option x2!", Color(0.45, 1.0, 0.6))
			return added
		PowerUpItem.Kind.HEAL:
			var to_level := int(get_meta(&"heal_level", 3))
			var gm := ScoreBoard._game_manager(get_tree())
			if gm and gm.refill_ignite(to_level):
				FloatingText.spawn(get_tree(), global_position + Vector2(0, -36), "Recover! IGNITE Lv%d" % to_level, Color(1.0, 0.55, 0.6))
				return true
			FloatingText.spawn(get_tree(), global_position + Vector2(0, -36), "IGNITE OK", Color(1.0, 0.8, 0.8), 12)
			return false
	return false

## 子機を1つ増やす(最大 max_options)
func add_option() -> bool:
	if options.size() >= max_options or option_scene == null:
		return false
	var option := option_scene.instantiate() as PlayerOption
	option.setup(self, options.size())
	add_child(option)
	options.append(option)
	options_changed.emit(options.size())
	return true

## ロックするまでの時間を、1段階短くする
func upgrade_lock_speed() -> bool:
	if lock_speed_level >= lock_time_scales.size() - 1:
		return false
	lock_speed_level += 1
	lock_speed_changed.emit(lock_speed_level)
	return true

## 子機を count 個失う(-1 なら全て)。後から増えたものから消える
func lose_options(count : int = -1) -> void:
	var n := options.size() if count < 0 else mini(count, options.size())
	for i in n:
		var option : PlayerOption = options.pop_back()
		if is_instance_valid(option):
			option.vanish()
	if n > 0:
		options_changed.emit(options.size())

## 持っているパワーアップを全て、アイテムにして周りに散らばらせる(子機は全て消え、ロック速度は最初に戻る)
func _drop_power_ups() -> void:
	var scenes : Array[PackedScene] = []
	var option_scene : PackedScene = power_up_option_scene if power_up_option_scene else load(POWER_UP_OPTION_PATH)
	var lock_scene : PackedScene = power_up_lock_scene if power_up_lock_scene else load(POWER_UP_LOCK_PATH)
	for i in options.size():
		scenes.append(option_scene)
	for i in lock_speed_level:
		scenes.append(lock_scene)
	lose_options(-1)
	if lock_speed_level > 0:
		lock_speed_level = 0
		lock_speed_changed.emit(lock_speed_level)
	var count := scenes.size()
	for i in count:
		if scenes[i] == null:
			continue
		var item := scenes[i].instantiate()
		item.position = global_position
		# 扇状に、左右へ散らばる(真ん中ほど高く跳ねる)
		var side := 0.0 if count == 1 else (float(i) / (count - 1)) * 2.0 - 1.0
		if item is PowerUpItem:
			item.launch(side * 110.0, 230.0 - absf(side) * 60.0)
		get_tree().current_scene.add_child.call_deferred(item)

## 子機も撃つ。ロックしていれば、ロックした敵を順番に分けて追いかける
func _fire_options() -> void:
	if options.is_empty():
		return
	var locking := is_locking_on()
	var damage := shot_damage * shot_power * level_power_scale * (lock_damage_scale if locking else 1.0) * ignite_power_scale()
	for i in options.size():
		var target : Node2D = lock_targets[i % lock_targets.size()] if locking else null
		options[i].fire(bullet_scene, shot_speed, damage, target, lock_turn_rate)

## ショットの段階(power_up_shot)で撃ち方が変わる機体か。撃ち方が別の機体(BASTION など)は false にする
func uses_shot_stage() -> bool:
	return true

## ショットを1段階強化する(最大5段階)。show_popup なら「SHOT UP!」を出して、自機を金色に光らせる
func power_up_shot(show_popup : bool = false) -> void:
	if shot_stage >= MAX_SHOT_STAGE or not uses_shot_stage():
		return
	shot_stage += 1
	shot_stage_changed.emit(shot_stage)
	if show_popup and is_inside_tree():
		var text := "SHOT MAX!!" if shot_stage >= MAX_SHOT_STAGE else "SHOT UP! %d" % shot_stage
		LevelUpPopup.show_text(get_tree(), global_position, text)
		var sprite := get_node_or_null("Sprite2D") as CanvasItem
		if sprite:
			if not sprite.has_meta("base_self_modulate"):
				sprite.set_meta("base_self_modulate", sprite.self_modulate)
			var tween := sprite.create_tween()
			tween.tween_property(sprite, "self_modulate", Color(2.6, 2.1, 0.8), 0.0)
			tween.tween_property(sprite, "self_modulate", sprite.get_meta("base_self_modulate"), 0.5)

## ショット強化を全て失う(被弾・死亡時)
## 敵(の当たり判定)が at にあるときの、近距離のショットの倍率。遠ければ 1
func close_damage_scale_at(at : Vector2) -> float:
	if not _is_alive or close_damage_scale == 1.0:
		return 1.0
	return close_damage_scale if global_position.distance_to(at) <= close_damage_distance else 1.0

func reset_shot_power() -> void:
	if shot_stage == 0:
		return
	shot_stage = 0
	shot_stage_changed.emit(shot_stage)
	if is_inside_tree():
		LevelUpPopup.show_text(get_tree(), global_position + Vector2(0, 18), "SHOT DOWN")


# ---------------------------------------------------------------- グレイズ

## GrazeArea(GrazeDetector)が、敵弾をグレイズしたとき
func _on_grazed(bullet : Area2D, density : int) -> void:
	graze_count += 1
	grazed.emit(graze_count)
	graze_hit.emit(bullet.global_position, density)
	grazed_bullet.emit(bullet)
	graze_effect.emitting = true
	var now := Time.get_ticks_msec()
	if now - _last_graze_sound_msec >= int(graze_sound_interval * 1000.0):
		_last_graze_sound_msec = now
		SoundManager.play_on_channel(&"player_graze", graze_sound, randf_range(0.95, 1.05)) # 高さを少しばらして、続けて鳴っても単調にしない

# ---------------------------------------------------------------- 被弾・死亡・復活

## 被弾。レベル(体力)を減らすかどうかは、damaged を受けた側(GameManager)が決める
func _on_hurtbox_recieved_damage(_damage: int) -> void:
	# 無敵中・死亡中・デバッグの無敵中は被弾を無視する
	if is_invincible() or DebugTools.invincible:
		return
	var hit_position := global_position
	var hit_direction := _hit_direction()
	var was_alive := _is_alive
	damaged.emit()
	# 一瞬止めて、自機を赤と白に光らせる(何に当たったか分かるように)。やられたときは長めに止めて、画面も光らせる
	if _is_alive:
		HitStop.play(get_tree(), hit_stop_time)
	elif was_alive:
		HitStop.play(get_tree(), death_stop_time)
		ScreenFlash.play(get_tree(), 0.8)
	_flash_hit()
	# 死亡しなかったときは、点滅しながら無敵になる(無敵の間はグレイズもできない)
	if _is_alive:
		Rumble.play(Rumble.PLAYER_HIT) # ゲームパッドが震える
		start_invincibility(hit_invincible_time)
		if hit_flame:
			hit_flame.burst(hit_position, hit_direction) # イグナイトが残っている: 撃たれた向きの先へ炎が噴き出す
	elif was_alive and hit_flame:
		hit_flame.scatter(hit_position) # イグナイトがない: 爆発して炎が散る

## 被弾した瞬間に、自機を赤 → 白 → 元の色に光らせる(ヒットストップ中も、実際の時間で進む)
func _flash_hit() -> void:
	var sprite := get_node_or_null("Sprite2D") as CanvasItem
	if sprite == null:
		return
	if not sprite.has_meta("base_self_modulate"):
		sprite.set_meta("base_self_modulate", sprite.self_modulate) # 機体ごとの元の色(BASTION は少し明るい)
	var base : Color = sprite.get_meta("base_self_modulate")
	var tween := sprite.create_tween().set_ignore_time_scale(true)
	tween.tween_property(sprite, "self_modulate", Color(3.0, 0.7, 0.6), 0.0)
	tween.tween_interval(0.05)
	tween.tween_property(sprite, "self_modulate", Color(2.5, 2.5, 2.5), 0.0)
	tween.tween_interval(0.05)
	tween.tween_property(sprite, "self_modulate", base, 0.12)

## 被弾した弾が進んでいた向き(炎を飛ばす向き)。弾でなければ、当たったものから自機への向き
func _hit_direction() -> Vector2:
	var hurtbox := get_node_or_null("Hurtbox") as Hurtbox
	var hitbox : Hitbox = hurtbox.last_hitbox if hurtbox else null
	if not is_instance_valid(hitbox):
		return Vector2.DOWN
	if hitbox is EnemyBullet:
		return (hitbox as EnemyBullet).direction
	var away := global_position - hitbox.global_position
	return away.normalized() if away.length() > 1.0 else Vector2.DOWN

## HPComponent 側から呼ばれる場合に備えて残している(体力はゲージで管理するので通常は使わない)
func _on_hp_component_is_dead() -> void:
	die()

## 死亡する。残機があれば復活、なければゲームオーバー
func die() -> void:
	if not _is_alive:
		return
	_is_alive = false
	Rumble.play(Rumble.PLAYER_DEATH)
	set_igniting(false)
	_cancel_ignite_hold()
	reset_shot_power()
	if drop_power_ups_on_death:
		_drop_power_ups()
	else:
		lose_options(options_lost_on_death)
	if clear_bullets_on_death:
		get_tree().call_group("enemy_bullet", "queue_free")
	if lives <= 0:
		game_over.emit()
		queue_free()
		return
	HazardRank.on_death(lives) # ANOTHER: 自爆でランクが下がる(残機が少ないほど大きく)
	lives -= 1
	lives_changed.emit(lives)
	_respawn()

## 理不尽な被弾を防ぐ: 自機が動いてカメラが横に流れているときに、画面の外から入ってきたばかりの弾には当たらない。
## (見えないところから飛んできた弾に、よける間もなく当たらないように)
## 悪用を防ぐため: カメラが止まっていれば効かない(画面の端で待っていても守られない)。画面の中で撃たれた弾にも効かない
@export_group("理不尽な被弾を防ぐ")
@export var reveal_grace_msec : int = 350

func ignores_hit(area : Area2D) -> bool:
	if has_meta("camera_frozen"):
		return true # カメラだけがほかを向いている演出のあいだは、何にも当たらない
	if not area is EnemyBullet:
		return false
	if not StageCamera.moved_recently(self, reveal_grace_msec):
		return false
	return (area as EnemyBullet).just_revealed_from_offscreen(reveal_grace_msec)

func _respawn() -> void:
	# 復活までは非表示にして、操作と射撃を止める
	visible = false
	set_physics_process(false)
	var wait := create_tween() # ノードに紐づくので、途中で消えても安全
	wait.tween_interval(respawn_delay)
	await wait.finished

	global_position = _spawn_position + StageCamera.view_offset(self) # カメラが横に動いていたら、その画面の中で復活する
	velocity = Vector2.ZERO
	hp_component.restore_hp()
	visible = true
	_is_alive = true
	set_physics_process(true)
	start_invincibility(respawn_invincible_time)
	respawned.emit()

## 無敵にする(点滅する)。Invincibility 部品に任せる
func start_invincibility(seconds: float) -> void:
	invincibility.start(seconds)

## 演出のあいだの無敵(強制移動・突入の演出など)。begin_guard と end_guard を同じ数だけ呼ぶ(重なってもよい)
var _guard_count : int = 0

func begin_guard() -> void:
	_guard_count += 1

func end_guard() -> void:
	_guard_count = maxi(_guard_count - 1, 0)
	if _guard_count == 0:
		start_invincibility(1.0) # 終わった直後に、すぐ当たらないように

## 無敵状態か(死亡中・無敵時間中・演出のあいだのどれか)
func is_invincible() -> bool:
	return not _is_alive or invincibility.is_active() or _guard_count > 0

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
	if ignite_blocked():
		_cancel_ignite_hold()
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

## 演出中で、イグナイトを使えないか(出撃・ステージの切り替え・カメラだけ別を向く場面など、自機を止めている演出と、ボス撃破〜クリアの演出)
func ignite_blocked() -> bool:
	return ignite_locked or not is_physics_processing() or has_meta("camera_frozen")

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

# ---------------------------------------------------------------- 操作・表示の補助

## 移動の入力(長さ 0〜1)。
##   キーボード・十字キー: 押した向きへ、まっすぐ全速(斜めも全速)。スティックのずれが混ざらないよう、押しているあいだはスティックを見ない
##   スティック          : 倒した向きへ、倒した分だけの速さ(Stick Full Ratio 以上倒すと全速)
func move_input() -> Vector2:
	var digital := Input.get_vector("UI_Left", "UI_Right", "UI_Forward", "UI_Back")
	if digital != Vector2.ZERO:
		return digital.normalized()
	if not InputMap.has_action("UI_StickLeft"):
		return Vector2.ZERO
	var stick := Input.get_vector("UI_StickLeft", "UI_StickRight", "UI_StickUp", "UI_StickDown")
	if stick == Vector2.ZERO:
		return stick
	var amount := clampf(stick.length() / maxf(stick_full_ratio, 0.01), 0.0, 1.0)
	return stick.normalized() * amount

## 移動のアクションに、矢印キーを足す(すでにあれば何もしない)
func _add_arrow_keys() -> void:
	var keys := {"UI_Left": KEY_LEFT, "UI_Right": KEY_RIGHT, "UI_Forward": KEY_UP, "UI_Back": KEY_DOWN}
	for action in keys:
		if not InputMap.has_action(action):
			continue
		var exists := false
		for event in InputMap.action_get_events(action):
			if event is InputEventKey and (event.physical_keycode == keys[action] or event.keycode == keys[action]):
				exists = true
		if not exists:
			var key := InputEventKey.new()
			key.physical_keycode = keys[action]
			InputMap.action_add_event(action, key)

## 当たり判定の印を作る。大きさと位置は、Hurtbox の円形シェイプに合わせる
## 当たり判定を見せるか。オプションの HITBOX(低速移動中だけ / いつも / 出さない)で決まる。
## FOCUS のときは、show_hitbox_on_focus がオンなら低速移動中に出す
func _hitbox_shown() -> bool:
	match GameSettings.hitbox_mode:
		GameSettings.Hitbox.ALWAYS:
			return true
		GameSettings.Hitbox.OFF:
			return false
	return show_hitbox_on_focus and is_focusing

func _create_hitbox_marker() -> void:
	_marker = HitboxMarker.new()
	_marker.z_index = 10
	_marker.radius = hitbox_display_radius
	var shape_node := get_node_or_null("Hurtbox/CollisionShape2D") as CollisionShape2D
	if shape_node:
		var hurtbox := shape_node.get_parent() as Node2D
		_marker.position = hurtbox.position + shape_node.position
		if shape_node.shape is CircleShape2D:
			_marker.radius = maxf((shape_node.shape as CircleShape2D).radius, 2.0)
	add_child(_marker)

# ---------------------------------------------------------------- 機体ごとに変えるところ(派生の機体が上書きする)

## グレイズ1回で入るゲージの倍率(GameManager が掛ける)。ふだんは 1
func graze_gain_scale() -> float:
	return 1.0
