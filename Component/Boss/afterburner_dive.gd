extends Node
class_name AfterburnerDive
## 大型機のボスの技「アフターバーナー上昇」。ボス(Enemy)の子に置く。
##   1. 少し上へ身構えてから、画面の一番下まで、だんだん速く突っ込んでくる(体当たり。撃つのをやめる)
##   2. 一番下で、エンジンが点火する(炎がちらつき、画面が揺れる。ここではまだ炎は当たらない)
##   3. 炎を下へ噴き出しながら、元の位置へ、だんだん速く上がる。炎に触れるとやられる
##   4. 上がりきったら、少しして炎が消え、また撃ち始める
## ときどきフェイントを入れる(Feint Chance):
##   ・ためらい  … 途中で一度止まり、それから一番下まで突っ込む
##   ・空ぶかし  … 点火しかけて火が消え、少し遅れて本当に点火する
##   ・見せかけ  … 途中まで突っ込んで、そのまま戻る(攻撃しない)。少しあとで本当に突っ込む
##
## 炎は、Engines に入れた Marker2D(噴射口)の位置から出る。噴射口は絵(Sprite2D)の子に置くと、絵の大きさに合わせて動く。
## 体当たりの当たりは、Ram Hitbox(ContactHitbox)の形。突っ込んでいる間だけ当たる。
##
## ボスの移動パターンは、登場して止まったら、最後のステップの Wait After を長くして待たせておく
## (移動パターンが動いている間に、この技を始めない)。

enum Feint {
	HESITATE,      ## ためらい: 途中で止まってから突っ込む
	FAKE_IGNITION, ## 空ぶかし: 点火しかけて消え、遅れて本当に点火する
	BACK_OFF,      ## 見せかけ: 途中まで突っ込んで戻る
}

## 噴射口(Marker2D)。いくつでも
@export var engines : Array[Node2D] = []
## 体当たりの当たり(ContactHitbox)。突っ込んでいる間だけ当たる
@export var ram_hitbox : ContactHitbox
## 出現してから、最初にこの技を使うまでの時間(秒)
## false なら、自分では技を始めない(ボスのステート BossDiveState が perform() を呼ぶ)
@export var auto_run : bool = true
@export var start_delay : float = 8.0
## 次にこの技を使うまでの時間(秒、上がりきってから数える)。0 なら1回だけ
@export var repeat_interval : float = 18.0
## この段階(0 = 第一形態)から使う。BossPhaseController がなければ、いつでも使う
@export var from_phase : int = 0

@export_group("動き")
## 一番下まで下がったときの、ボスの位置(画面の下の端から、上へ何 px か)
@export var bottom_offset : float = 70.0
## 機体の下の端の目印(Marker2D)。設定すると Bottom Offset の代わりに、この目印が画面の下の端に来るところで止まる。
## 絵(Sprite2D)の子に置けば、絵の大きさを変えても止まる位置がずれない
@export var tail_marker : Node2D
## 目印を、画面の下の端からさらに下へ出す量(px)
@export var tail_overhang : float = 4.0
## 突っ込む前に、上へ身構える距離(px)と時間(秒)
@export var windup_distance : float = 16.0
@export var windup_time : float = 0.45
## 突っ込むのにかける時間(秒)と、そのイージング(Ease In なら、だんだん速くなる)
@export var descend_time : float = 1.6
@export var descend_trans : Tween.TransitionType = Tween.TRANS_CUBIC
@export var descend_ease : Tween.EaseType = Tween.EASE_IN
## 一番下で、点火してから上がり始めるまでの時間(秒)。炎がちらつく予告の時間
@export var ignite_time : float = 1.0
## 上がるのにかける時間(秒)と、そのイージング
@export var rise_time : float = 1.6
@export var rise_trans : Tween.TransitionType = Tween.TRANS_QUAD
@export var rise_ease : Tween.EaseType = Tween.EASE_IN
## true なら、上がっている間も体当たりが当たる
@export var ram_while_rising : bool = false
## 上がりきってから、炎が消え始めるまでの時間(秒)と、消えるのにかける時間(秒)
@export var flame_hold : float = 0.8
@export var flame_out_time : float = 0.5

@export_group("フェイント")
## フェイントを入れる確率(0〜1)
@export var feint_chance : float = 0.5
## 使うフェイント(この中から選ぶ)
@export var feints : Array[Feint] = [Feint.HESITATE, Feint.FAKE_IGNITION, Feint.BACK_OFF]
## ためらい・見せかけで、どこまで突っ込んでから止まるか(一番下までの割合)と、止まっている時間(秒)
@export var feint_depth : float = 0.45
@export var feint_pause : float = 0.6
## 空ぶかしで、火が消えてから本当に点火するまでの時間(秒)
@export var fake_ignition_pause : float = 0.8
## 見せかけのあと、本当に突っ込むまでの時間(秒)
@export var back_off_retry : float = 1.5

@export_group("炎")
## 伸びきった炎の長さ(px)と太さ(px)
@export var flame_length : float = 460.0
@export var flame_width : float = 46.0
## 点火のときの画面の揺れ(px)
@export var shake_strength : float = 6.0
## 点火の効果音(シーンに置いた AudioStreamPlayer)
@export var sound : AudioStreamPlayer

var _enemy : Enemy
var _flames : Array[AfterburnerFlame] = []
## 移動の上の位置(横揺れのずれを除いた、ボスの位置)
var _pos : Vector2
## 技の最中か(FighterMover などの、ほかの動きを止めるのに使う)
var _diving : bool = false

func is_diving() -> bool:
	return _diving
var _shake_power : float = 0.0
var _camera_base : Vector2
var _camera : Camera2D

func _ready() -> void:
	_enemy = get_parent() as Enemy
	if _enemy == null:
		push_warning("AfterburnerDive: 親が Enemy ではありません")
		return
	for engine in engines:
		var flame := AfterburnerFlame.new()
		flame.length = flame_length
		flame.width = flame_width
		_enemy.add_child.call_deferred(flame)
		_enemy.move_child.call_deferred(flame, 0) # ボスの絵より先に並べて、絵の下に描く
		_flames.append(flame)
	if ram_hitbox:
		ram_hitbox.set_active.call_deferred(false)
	_enemy.died.connect(func(_e : Enemy) -> void: _stop_attack()) # 倒されたら、炎と体当たりはすぐ消す
	_run.call_deferred()

func _process(delta : float) -> void:
	# 炎を、噴射口の位置に合わせる
	for i in _flames.size():
		if is_instance_valid(_flames[i]) and is_instance_valid(engines[i]):
			_flames[i].global_position = engines[i].global_position
	# 画面の揺れ
	if _shake_power > 0.0 and is_instance_valid(_camera):
		_shake_power = maxf(_shake_power - shake_strength * delta * 1.5, 0.0)
		_camera.offset = _camera_base + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake_power
		if _shake_power <= 0.0:
			_camera.offset = _camera_base

func _run() -> void:
	if not auto_run:
		return # ボスのステート(BossDiveState)が perform() を呼ぶ
	await _wait(start_delay)
	while _alive():
		if not _phase_ok():
			await _wait(1.0)
			continue
		await perform()
		if repeat_interval <= 0.0:
			return
		await _wait(repeat_interval)

## 技を1回する(フェイントの見せかけのときは、少しあとで本当に突っ込むまで)。終わるまで await できる
func perform() -> void:
	if not _alive():
		return
	_diving = true
	var attacked := await _dive(_pick_feint())
	if not attacked:
		# 見せかけだった: 少しあとで、本当に突っ込む
		await _wait(back_off_retry)
		if _alive():
			await _dive(-1)
	_diving = false

## フェイントを選ぶ。入れないときは -1
func _pick_feint() -> int:
	if feints.is_empty() or randf() >= feint_chance:
		return -1
	return feints.pick_random()

## 突っ込んで、上がる。feint は Feint の値か -1。見せかけで戻ったときは false を返す
func _dive(feint : int) -> bool:
	var shooters := _stop_shooters()
	_pos = _enemy.global_position - _enemy._applied_sway
	var home := _pos
	var view := CameraView.visible_rect(_enemy)
	var bottom := Vector2(home.x, view.end.y - bottom_offset)
	if is_instance_valid(tail_marker):
		bottom.y = view.end.y + tail_overhang - (tail_marker.global_position.y - _enemy.global_position.y)
	# 身構える(少し上へ)
	await _move(home + Vector2(0.0, -windup_distance), windup_time, Tween.TRANS_SINE, Tween.EASE_OUT)
	if not _alive():
		return _abort()
	_set_ram(true)
	# 突っ込む(ためらい・見せかけは、途中で一度止まる)
	if feint == Feint.HESITATE or feint == Feint.BACK_OFF:
		var middle := _pos.lerp(bottom, feint_depth)
		await _move(middle, descend_time * feint_depth, descend_trans, descend_ease)
		if not _alive():
			return _abort()
		await _wait(feint_pause)
		if not _alive():
			return _abort()
		if feint == Feint.BACK_OFF:
			_set_ram(false)
			await _move(home, descend_time, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
			_resume_shooters(shooters)
			return false
		await _move(bottom, descend_time * (1.0 - feint_depth) + 0.2, descend_trans, descend_ease)
	else:
		await _move(bottom, descend_time, descend_trans, descend_ease)
	if not _alive():
		return _abort()
	# 点火(ちらつく予告。まだ炎は当たらない)
	await _ignite()
	if not _alive():
		return _abort()
	if feint == Feint.FAKE_IGNITION:
		# 空ぶかし: 火が消えて、少し遅れて本当に点火する
		var cut := _enemy.create_tween()
		cut.tween_method(_set_power, 0.4, 0.0, 0.15)
		await cut.finished
		await _wait(fake_ignition_pause)
		if not _alive():
			return _abort()
		await _ignite()
		if not _alive():
			return _abort()
	# 炎を一気に伸ばして、元の位置へ上がる
	if not ram_while_rising:
		_set_ram(false)
	var grow := _enemy.create_tween()
	grow.tween_method(_set_power, 0.45, 1.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await _move(home, rise_time, rise_trans, rise_ease)
	_set_ram(false)
	if not _alive():
		return _abort()
	# 少しして、炎が消える
	await _wait(flame_hold)
	if not _alive():
		return _abort()
	var fade := _enemy.create_tween()
	fade.tween_method(_set_power, 1.0, 0.0, flame_out_time)
	await fade.finished
	_resume_shooters(shooters)
	return true

## 点火: 音と揺れ、炎が小さくちらつく
func _ignite() -> void:
	if sound:
		SoundManager.play(sound)
	_start_shake()
	var tween := _enemy.create_tween()
	tween.tween_method(_set_power, 0.0, 0.3, ignite_time * 0.4)
	tween.tween_method(func(p : float) -> void: _set_power(p + randf_range(-0.08, 0.08)), 0.3, 0.45, ignite_time * 0.6)
	await tween.finished

func _abort() -> bool:
	_stop_attack()
	return true

func _stop_attack() -> void:
	_set_power(0.0)
	_set_ram(false)

func _set_ram(on : bool) -> void:
	if is_instance_valid(ram_hitbox):
		ram_hitbox.set_active(on)

func _move(target : Vector2, duration : float, trans : Tween.TransitionType, ease_type : Tween.EaseType) -> void:
	if not _alive():
		return
	var tween := _enemy.create_tween()
	tween.tween_method(_set_pos, _pos, target, maxf(duration, 0.01)).set_trans(trans).set_ease(ease_type)
	await tween.finished

func _set_pos(value : Vector2) -> void:
	if not _alive():
		return
	_pos = value
	_enemy.global_position = value + _enemy._applied_sway # 横揺れのずれは、そのまま保つ

func _set_power(value : float) -> void:
	for flame in _flames:
		if is_instance_valid(flame):
			flame.power = clampf(value, 0.0, 1.0)

## 撃つのをやめさせて、やめさせた砲口を返す
func _stop_shooters() -> Array[EnemyShooter]:
	var shooters : Array[EnemyShooter] = []
	for node in _enemy.find_children("*", "", true, false):
		if node is EnemyShooter:
			shooters.append(node)
			node.stop()
	return shooters

## 今の段階の弾幕で、また撃ち始める
func _resume_shooters(shooters : Array[EnemyShooter]) -> void:
	if not auto_run:
		return # 撃たせるのはボスのステートに任せる
	if not _alive():
		return
	var controller := _controller()
	for shooter in shooters:
		if not is_instance_valid(shooter) or not shooter.enabled:
			continue
		if shooter.has_phases():
			shooter.set_phase(controller.current_phase() if controller else 0)
		else:
			shooter.set_patterns(shooter.patterns, shooter.sequence)

func _controller() -> BossPhaseController:
	for child in _enemy.get_children():
		if child is BossPhaseController:
			return child
	return null

func _phase_ok() -> bool:
	var controller := _controller()
	return controller == null or controller.current_phase() >= from_phase

func _start_shake() -> void:
	if shake_strength <= 0.0:
		return
	if not is_instance_valid(_camera):
		_camera = _enemy.get_viewport().get_camera_2d()
		if _camera:
			_camera_base = _camera.offset
	_shake_power = shake_strength

func _wait(seconds : float) -> void:
	if seconds <= 0.0 or not _alive():
		return
	await _enemy.get_tree().create_timer(seconds).timeout

func _alive() -> bool:
	return is_instance_valid(_enemy) and _enemy.is_inside_tree() and not _enemy._is_dead
