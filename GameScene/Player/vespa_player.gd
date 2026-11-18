extends Player
class_name VespaPlayer
## カウンター型の自機「VESPA」。シーン(GameScene/Player/vespa.tscn)で使う。Player の仕組みはそのまま使い、次のところだけ変える。
##
##   ショット  : 左右から撃つ、威力の低いバルカン(少しぶれる)
##   Shift     : 低速移動 + スナイパー。細く速い弾が敵を貫通する。敵の中心に近いほど威力が高い(中心に当たると火花と音が変わる)
##   グレイズ  : 最後のグレイズから Graze Boost Time 秒以内に撃った弾は、威力が上がって色が変わる
##   子機      : 自機の横に並んでバルカン。向きはゲージの Lv で変わる(低いほど内向きで交わり、高いほど外向きでワイド)。
##               Shift 中は真上へ弱いスナイパー。カウンターが決まると、全部で弾が飛んできた方向へ撃ち返す
##   カウンター: 敵の弾が当たる瞬間にイグナイトを押すと、被弾を無効にして、ゲージを使わずに Lv1 のイグナイトが出る(「CRITICAL!」と出る)。
##               当たる少し前に押していてもよく、当たってから(時間がほぼ止まったあいだに)押してもよい。
##               受付の長さはゲージがあるとき(Lv1以上)は長く、Lv0 は短い。外すと、普通のイグナイト(1Lv 使う)になる
##   イグナイト: ボタンを押した瞬間に決める(押して、受付が過ぎても当たらなければ普通のイグナイト。長押しで全Lv)

## カウンターが決まった(GameManager が、ゲージを使わずに Lv1 のイグナイトを出す)
signal counter_requested

@export_group("VESPA: バルカン")
## 撃つ間隔(秒。左右1発ずつ)・1発の威力・弾の速さ
@export var vulcan_interval : float = 0.04
@export var vulcan_damage : float = 7.0
@export var vulcan_speed : float = 950.0
## 左右の撃つ位置(自機の中心から。x は左右対称に使う)と、ぶれの大きさ(度、±)
@export var vulcan_muzzle : Vector2 = Vector2(11, -6)
@export var vulcan_jitter : float = 4.0
## 弾の大きさと濃さ(数が多いので、敵の弾が見えなくならないように小さく薄く)
@export var vulcan_scale : float = 0.6
@export var vulcan_alpha : float = 0.75

@export_group("VESPA: スナイパー(Shift)")
@export var sniper_interval : float = 0.3
@export var sniper_damage : float = 120.0
@export var sniper_speed : float = 1400.0
## 弾の見た目の大きさ(x は太さ。判定も一緒に細くなる)
@export var sniper_scale : Vector2 = Vector2(0.5, 1.7)
@export var sniper_color : Color = Color(0.85, 0.55, 1.6)
## 中心に当たったときの音(シーンに置いた AudioStreamPlayer)
@export var center_hit_sound : AudioStreamPlayer

@export_group("VESPA: グレイズ中の強化")
## 最後のグレイズから、この秒数以内に撃った弾が強くなる
@export var graze_boost_time : float = 0.3
@export var graze_boost_scale : float = 1.5
@export var graze_boost_color : Color = Color(0.55, 1.3, 1.6)

@export_group("VESPA: 子機")
## 子機の位置(自機の横。内側の2機、外側の2機の順)
@export var option_positions : Array[Vector2] = [Vector2(-16, 6), Vector2(16, 6), Vector2(-34, 12), Vector2(34, 12)]
## ゲージの Lv(Lv0〜Lv5 の順)ごとの、子機の向き(度。+ は外向き、- は内向き)。内側の2機と外側の2機
@export var inner_angles : Array[float] = [-6.0, -2.0, 3.0, 8.0, 14.0, 20.0]
@export var outer_angles : Array[float] = [-13.0, -5.0, 6.0, 16.0, 25.0, 35.0]
## Lv が変わったとき、向きが変わりきるまでの時間(秒)
@export var option_turn_time : float = 0.2
@export var option_vulcan_interval : float = 0.12
@export var option_vulcan_damage : float = 9.0
@export var option_sniper_damage : float = 20.0
## カウンターの撃ち返し: 1機あたりの弾数・1発の威力・間隔(秒)
@export var counter_shots : int = 3
@export var counter_shot_damage : float = 12.0
@export var counter_shot_gap : float = 0.05

@export_group("VESPA: カウンター")
## 当たる前に押していてもよい時間(秒)。ゲージ Lv1 以上 / Lv0
@export var pre_window : float = 0.08
@export var pre_window_lv0 : float = 0.03
## 当たってから押してもよい時間(秒、実際の時間)。このあいだ、時間がほぼ止まる。ゲージ Lv1 以上 / Lv0
@export var post_window : float = 0.15
@export var post_window_lv0 : float = 0.05
## カウンターが決まったあとの無敵(秒)
@export var counter_invincible_time : float = 0.6
@export var counter_text_color : Color = Color(0.8, 0.6, 1.0)
## カウンターが決まったときの音(シーンに置いた AudioStreamPlayer)
@export var counter_sound : AudioStreamPlayer

enum PressState { IDLE, PRE, HOLD, DONE }

const COUNTER_RUMBLE : Array[float] = [0.9, 0.3, 0.15]

var counter_count : int = 0
var _press_state : PressState = PressState.IDLE
var _press_until : float = 0.0
var _hold_start : float = 0.0
## 当たって、カウンターの受付中(時間がほぼ止まっている)
var _pending_hit : bool = false
var _pending_until : float = 0.0
var _pending_damage : int = 0
var _pending_dir : Vector2 = Vector2.DOWN
## ゲームの時間(秒)。最後にグレイズした時刻
var _game_time : float = 0.0
var _last_graze_time : float = -100.0
var _sniper_wait : float = 0.0
var _option_wait : float = 0.0
## 子機の向きの今の Lv(なめらかに変える)
var _angle_level : float = 1.0

func _ready() -> void:
	super._ready()
	lock_shot_enabled = false # ロックショットはない(Shift はスナイパー)
	_angle_level = float(shot_look_level)
	set_process(true)

func _physics_process(delta : float) -> void:
	_game_time += delta
	super._physics_process(delta)
	_sniper_wait = maxf(_sniper_wait - delta, 0.0)
	_option_wait = maxf(_option_wait - delta, 0.0)
	_angle_level = move_toward(_angle_level, float(clampi(shot_look_level, 0, 5)), delta * maxf(1.0, absf(_angle_level - shot_look_level)) / maxf(option_turn_time, 0.01))

# ---------------------------------------------------------------- ショット

func _shoot(_delta : float) -> void:
	if not Input.is_action_pressed("UI_Shoot") or not _is_alive or bullet_scene == null:
		return
	var boosted := _graze_boosted()
	if is_focusing:
		if _sniper_wait <= 0.0:
			_sniper_wait = sniper_interval / boost_rate_scale()
			SoundManager.play_on_channel(&"player_shot", shot_sound, 0.75)
			_fire_sniper(global_position + muzzle_offset, Vector2.UP, sniper_damage, boosted, 1.0)
	elif shoot_timer.time_left <= 0.0:
		shoot_timer.start(vulcan_interval / boost_rate_scale())
		SoundManager.play_on_channel(&"player_shot", shot_sound, 1.2, -4.0)
		for side in [-1.0, 1.0]:
			var at := global_position + Vector2(vulcan_muzzle.x * side, vulcan_muzzle.y)
			var dir := Vector2.UP.rotated(deg_to_rad(randf_range(-vulcan_jitter, vulcan_jitter)))
			_fire_vulcan(at, dir, vulcan_damage, boosted)
	if _option_wait <= 0.0 and not options.is_empty():
		_option_wait = (sniper_interval if is_focusing else option_vulcan_interval) / boost_rate_scale()
		_fire_options_vespa(boosted)

func _graze_boosted() -> bool:
	return _game_time - _last_graze_time <= graze_boost_time

func _fire_vulcan(at : Vector2, dir : Vector2, damage : float, boosted : bool) -> Bullet:
	var bullet : Bullet = bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = at
	bullet.setup(dir, vulcan_speed, damage * (graze_boost_scale if boosted else 1.0) * boost_power_scale(), 0)
	bullet.scale = Vector2.ONE * vulcan_scale
	_tint(bullet, boosted, vulcan_alpha)
	return bullet

func _fire_sniper(at : Vector2, dir : Vector2, damage : float, boosted : bool, size : float) -> Bullet:
	var bullet : Bullet = bullet_scene.instantiate()
	bullet.pierce = true # 貫通する(当たっても消えない)
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = at
	bullet.setup(dir, sniper_speed, damage * (graze_boost_scale if boosted else 1.0) * boost_power_scale(), 0)
	bullet.center_aim = true
	bullet.center_hit.connect(_on_center_hit)
	bullet.scale = sniper_scale * size
	bullet.modulate = graze_boost_color if boosted else sniper_color
	return bullet

func _tint(bullet : Bullet, boosted : bool, alpha : float) -> void:
	if bullet == null:
		return
	if boosted:
		bullet.modulate = Color(graze_boost_color.r, graze_boost_color.g, graze_boost_color.b, 1.0)
	else:
		bullet.modulate = Color(1.0, 1.0, 1.0, alpha)

## 敵の中心に当たった: 色の違う火花と音
func _on_center_hit(at : Vector2) -> void:
	DeflectSpark.spawn(get_tree(), at, Vector2.UP)
	if center_hit_sound:
		SoundManager.play_on_channel(&"vespa_center", center_hit_sound, randf_range(1.15, 1.3))

# ---------------------------------------------------------------- 子機

func add_option() -> bool:
	if not super.add_option():
		return false
	var option := options.back() as PlayerOption
	var index := options.size() - 1
	var at : Vector2 = option_positions[index % option_positions.size()]
	# 横に並べる(ふだんも Shift 中も同じ位置)。向きはこちらで決めて渡す
	for list in [option.slots, option.focus_slots, option.lock_slots]:
		if index < list.size():
			list[index] = at
	option.damage_scale = 1.0
	return true

## 子機 index の、今のゲージの Lv での向き(度。0 が真上、+ が右)
func option_angle(index : int) -> float:
	var outer := index >= 2
	var table := outer_angles if outer else inner_angles
	var low := floori(_angle_level)
	var t := _angle_level - low
	var out := lerpf(_at(table, low), _at(table, low + 1), t)
	var left := option_positions[index % option_positions.size()].x < 0.0
	return -out if left else out

func _fire_options_vespa(boosted : bool) -> void:
	for i in options.size():
		var option := options[i]
		if is_focusing:
			var b := _fire_sniper(option.global_position, Vector2.UP, option_sniper_damage, boosted, 0.6)
			if b:
				b.global_position = option.global_position
			continue
		var dir := Vector2.UP.rotated(deg_to_rad(option_angle(i) + randf_range(-1.5, 1.5)))
		_fire_vulcan(option.global_position, dir, option_vulcan_damage, boosted)

## カウンターの撃ち返し: 全部の子機(なければ自機)から、弾が飛んできた方向へ一斉に撃つ
func _counter_fire(toward : Vector2) -> void:
	var sources : Array[Node2D] = []
	for option in options:
		sources.append(option)
	if sources.is_empty():
		sources.append(self)
	for n in counter_shots:
		var wait := create_tween()
		wait.tween_interval(counter_shot_gap * n)
		wait.tween_callback(func() -> void:
			if not _is_alive:
				return
			for source in sources:
				if is_instance_valid(source):
					var dir := toward.rotated(deg_to_rad(randf_range(-3.0, 3.0)))
					_fire_sniper(source.global_position, dir, counter_shot_damage, true, 0.7))

func _at(values : Array, index : int, fallback : float = 0.0) -> float:
	if values.is_empty():
		return fallback
	return float(values[clampi(index, 0, values.size() - 1)])

func _is_lock_shooting() -> bool:
	return false

# ---------------------------------------------------------------- グレイズ

func _on_grazed(bullet : Area2D, density : int) -> void:
	super._on_grazed(bullet, density)
	_last_graze_time = _game_time

# ---------------------------------------------------------------- カウンター

## 実際の時間(秒)。ヒットストップ中も進む
func _now() -> float:
	return Time.get_ticks_usec() / 1000000.0

func _has_gauge() -> bool:
	return shot_look_level >= 1

## イグナイトのボタンは、こちらの _process で見る(ヒットストップで物理がほぼ止まっていても、押したのが分かるように)
func _update_ignite_input(_delta : float) -> void:
	pass

func _process(_delta : float) -> void:
	if not InputMap.has_action("UI_Ignite"):
		return
	if not _is_alive:
		_pending_hit = false
		_press_state = PressState.IDLE
		_set_charge(0.0)
		return
	var now := _now()
	var pressed := Input.is_action_pressed("UI_Ignite")
	var just := Input.is_action_just_pressed("UI_Ignite")
	# 当たったあとの受付中: 押せばカウンター、間に合わなければ被弾
	if _pending_hit:
		if just:
			_counter(_pending_dir)
		elif now >= _pending_until:
			_pending_hit = false
			HitStop.reset()
			super._on_hurtbox_recieved_damage(_pending_damage)
		return
	# 演出中は、イグナイトを受け付けない
	if ignite_blocked():
		if _press_state != PressState.IDLE:
			_press_state = PressState.IDLE
			_set_charge(0.0)
		return
	match _press_state:
		PressState.IDLE:
			if just:
				_press_state = PressState.PRE
				_press_until = now + (pre_window if _has_gauge() else pre_window_lv0)
				_hold_start = now
		PressState.PRE:
			# 当たる前の受付: このあいだに当たればカウンター。過ぎたら普通のイグナイト(押し続けていれば長押し)
			if now >= _press_until:
				if pressed:
					_press_state = PressState.HOLD
				else:
					_press_state = PressState.IDLE
					if ignite_available:
						ignite_requested.emit(false)
		PressState.HOLD:
			if not pressed:
				_press_state = PressState.IDLE
				_set_charge(0.0)
				if ignite_available:
					ignite_requested.emit(false) # 単押し: 1Lv
			else:
				var ratio := (now - _hold_start) / maxf(ignite_hold_time, 0.01)
				_set_charge(ratio)
				if ratio >= 1.0:
					_press_state = PressState.DONE
					_set_charge(0.0)
					if ignite_available:
						ignite_requested.emit(true) # 長押し: 全Lv
		PressState.DONE:
			if not pressed:
				_press_state = PressState.IDLE

func _cancel_ignite_hold() -> void:
	super._cancel_ignite_hold()
	_press_state = PressState.IDLE

func _on_hurtbox_recieved_damage(damage : int) -> void:
	if is_invincible() or DebugTools.invincible or not _is_alive or _pending_hit:
		return
	var dir := _hit_direction()
	# 当たる少し前に押していた: カウンター
	if _press_state == PressState.PRE:
		_counter(dir)
		return
	# 当たった瞬間に時間をほぼ止めて、押すのを待つ
	_pending_hit = true
	_pending_damage = damage
	_pending_dir = dir
	var window := post_window if _has_gauge() else post_window_lv0
	_pending_until = _now() + window
	HitStop.apply(get_tree(), window + 0.05, 0.02)

## カウンター成功: 被弾を無効にし、ゲージを使わずに Lv1 のイグナイトを出し、子機で撃ち返す
func _counter(hit_dir : Vector2) -> void:
	_pending_hit = false
	_press_state = PressState.DONE if Input.is_action_pressed("UI_Ignite") else PressState.IDLE
	_set_charge(0.0)
	counter_count += 1
	HitStop.reset()
	HitStop.apply(get_tree(), 0.1)
	Rumble.play(COUNTER_RUMBLE)
	start_invincibility(counter_invincible_time)
	FloatingText.spawn(get_tree(), global_position + Vector2(0, -26), "CRITICAL!", counter_text_color, 14)
	if counter_sound:
		SoundManager.play(counter_sound)
	counter_requested.emit()
	# 弾が飛んできた方向(弾の進む向きの逆)へ撃ち返す
	var toward := -hit_dir if hit_dir.length_squared() > 0.0001 else Vector2.UP
	_counter_fire(toward.normalized())
