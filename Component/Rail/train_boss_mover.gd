extends Node
class_name TrainBossMover
## 大きな列車(ボス・中ボス・援護)を、ゆっくり前後に動かす部品。列車の敵(Enemy)の子に置く。
## 移動パターンは使わない(SpawnEvent の Move Pattern も空にする)。横の位置は RailRider が線路に合わせる。
##
## 動き方:
##   1. 画面の外(進む向きの手前)から、ゆっくり入ってきて、先頭の車両が画面に入ったところで止まる
##   2. 動いているあいだも撃つ(Fire While Moving をオフにすると、止まっているあいだだけ撃つ)
##   3. しばらく撃ったら、ゆっくり次の車両が見えるところへ動く。いちばん後ろまで行ったら、また前へ戻る(行ったり来たり)
##   4. 見えている車両の砲台を全部壊されたら、壊れていない砲台のある車両へ、ゆっくり動く
##   5. Route があれば、何回か止まるごとに、ゆっくり画面の上(進む向き)へ走り去り、次の位置の線路に移って入り直す
##   6. Exit After があれば、その秒数たったら、進む向きへゆっくり走り去って消える(援護)
##
## 車両は、VisualRoot の子の Sprite2D のうち Wagon Names の名前のもの。部位(EnemyPart)は、いちばん近い車両のものとみなす。

## 車両の絵のノード名(先頭から)
@export var wagon_names : PackedStringArray = ["Main", "W3", "W2", "W1", "W0"]
## オンなら、動いているあいだも撃つ。オフなら、止まっているあいだだけ撃つ(ビームも)
@export var fire_while_moving : bool = true
## 動いているあいだ、自機が画面の真ん中か、それより下にいるときは、自機より後ろ(下)の砲口から撃たない
## (後ろから急に撃たれて、すぐ死ぬのを防ぐ)
@export var no_fire_from_behind_while_moving : bool = true
## 自機よりこの距離(px)以上、下にある砲口を「後ろ」とする
@export var behind_margin : float = 8.0
## 動く速さ(px/秒)。動き始めと止まる前は、ゆっくりになる
@export var move_speed : float = 110.0
## 入ってくるときの速さ(px/秒)
@export var enter_speed : float = 140.0
## 止まって撃っている時間(秒)。Min〜Max のあいだでランダム
@export var hold_min : float = 7.0
@export var hold_max : float = 10.0
## 見えている車両の砲台が全部壊れてから、動き出すまでの時間(秒)
@export var regroup_delay : float = 1.2
## 止める位置: その車両の(壊れていない)砲台の真ん中が、画面の上からこの割合のところに来る(0.4 なら、少し上寄り)
@export_range(0.1, 0.9, 0.05) var view_anchor : float = 0.4
## いちばん下の砲台が、画面の上からこの割合より下に来ないようにする(自機のすぐ上に砲台が来ないように)
@export_range(0.2, 0.9, 0.05) var lowest_turret_limit : float = 0.55

@export_group("線路を移る(Route)")
## 順に移る位置(RailRider の Span の番号)。空なら移らない
@export var route : Array[int] = []
## 何回止まるごとに移るか
@export var holds_per_switch : int = 2
## 走り去る・入ってくるときの速さ(px/秒)
@export var switch_speed : float = 220.0
## この距離(px)より遠くの車両へ動くときは、Far Move Max Time 秒以内に着く(遠くの砲台へ速く戻る)
@export var far_move_distance : float = 900.0
@export var far_move_max_time : float = 3.0
## 入り直してから止まるまでの、いちばん長い時間(秒)。後ろの車両を見せに行くときも、これより長くかけない
@export var switch_enter_max_time : float = 3.5
## ボスがこの段階(0 から)に入ったら、Final Span の位置へ移って、そこから動かない(線路を移らない)。-1 ならしない
@export var final_phase : int = 2
@export var final_span : int = 2

@export_group("画面の外から撃つ砲口")
## 列車の横(自機のいる側)に付いて動く砲口。画面の上から Flank Heights の割合の高さ(列車のある範囲の中)に置く。
## 砲口の Only Offscreen Sideways をオンにすると、列車が左右の画面の外にいるときだけ撃つ
@export var flank_shooters : Array[EnemyShooter] = []
@export var flank_heights : Array[float] = [0.2, 0.45]

@export_group("援護")
## 0 より大きければ、出てからこの秒数たったら走り去って消える
@export var exit_after : float = 0.0
## オンなら、暴走列車のように突っ込んでくる(猛スピードで入ってきて急ブレーキ。火花と画面の揺れ付き)
@export var rush_entry : bool = false
## 突っ込んでくる時間(秒)
@export var rush_time : float = 1.4
## 火花の間隔(秒)と、揺れの強さ(px)
@export var rush_spark_interval : float = 0.03
@export var rush_shake : float = 7.0
## 登場するときに鳴らす汽笛(突っ込んでくるときは、鳴らしてから Horn Lead 秒あとに突っ込む)。空なら鳴らさない
@export var horn_sound : AudioStream
@export var horn_lead : float = 1.2
## 登場するときの走る音(突っ込んでくるときは、突っ込む瞬間に鳴らす)。空なら鳴らさない
@export var rush_sound : AudioStream
## オンなら、突っ込んでくるあいだ、先頭に隕石のような白い光の筋を出す
@export var meteor_trail : bool = false

var _enemy : Enemy
var _rider : RailRider
var _wagons : Array[Dictionary] = [] # { "y": 車両の真ん中(このノードの y からのずれ), "parts": Array[EnemyPart] }
var _extent : Vector2 = Vector2.ZERO # 列車の上の端と下の端(敵の y からのずれ)
var _current : int = 0
var _direction : int = 1 # 1 = 後ろの車両へ、-1 = 前の車両へ
var _tween : Tween
var _moving : bool = false
var _route_index : int = 0
var _age : float = 0.0
var _leaving : bool = false
## 登場の効果音(汽笛・走る音)が鳴り終わる時刻(ミリ秒)。0 なら、まだ登場していない
var _entry_sound_end_msec : int = 0
## 今乗っている位置(RailRider の Span の番号)。-1 ならわからない
var span : int = -1
## 移らなければならない位置(最後の段階で中央へ)。-1 ならなし
var _force_span : int = -1
## 線路を移るのをやめた(最後の段階)
var _route_locked : bool = false
## 線路を移るために、今の位置から走り去っているところ(援護は、ボスがいなくなってから出す)
var vacating : bool = false
## 登場している途中(突っ込んで止まるまで)。このあいだは撃たない
var _entering : bool = false
## 速く動いている途中(線路を移る・走り去る・遠くの車両へ動く)。このあいだは撃たない(ゆっくり動くときだけ撃つ)
var _fast_moving : bool = false
## この列車の砲口(EnemyShooter)の一覧。初めて使うときに集める
var _all_shooters : Array[EnemyShooter] = []
## 汽笛が鳴り終わる時刻(ミリ秒)。0 なら、まだ鳴らしていない
var _horn_end_msec : int = 0
## 登場の動き(突っ込んで止まるまで)が終わったか
var entered : bool = false

func _ready() -> void:
	_enemy = get_parent() as Enemy
	if _enemy == null:
		return
	_enemy.pattern = null # 移動パターンは使わない(親の _ready より先に呼ばれる)
	_enemy.died.connect(func(_e) -> void: _stop_tween())
	# 車両の位置を測って画面の外に置くまで(1フレーム)、出てきた場所に一瞬見えてしまわないよう、隠して遠くに置いておく
	_enemy.visible = false
	_enemy.global_position.y = CameraView.visible_rect(_enemy).end.y + 5000.0
	_start.call_deferred()

func _start() -> void:
	for child in _enemy.get_children():
		if child is RailRider:
			_rider = child
			span = child.span
	_watch_phase.call_deferred()
	await get_tree().physics_frame # 車両の絵の位置(ワールド)が決まってから測る
	if not is_instance_valid(_enemy):
		return
	_measure()
	if _wagons.is_empty():
		_enemy.visible = true
		return
	_entering = true
	_set_moving(true)
	_place_outside()
	_enemy.visible = true
	_current = _first_alive(0, 1)
	if rush_entry:
		await _rush_in()
	else:
		# ゆっくり入ってくる(中ボス): 汽笛と走る音を鳴らしながら
		_entry_sound_end_msec = Time.get_ticks_msec() + int(maxf(_length_of(horn_sound), _length_of(rush_sound)) * 1000.0)
		_horn_end_msec = Time.get_ticks_msec() + int(_length_of(horn_sound) * 1000.0)
		if horn_sound:
			_play(horn_sound, -2.0)
		if rush_sound:
			_play(rush_sound, -4.0)
		await _move_to_wagon(_current, enter_speed)
	entered = true
	_entering = false
	_run()

## 暴走列車の登場: 猛スピードで突っ込んできて、急ブレーキで止まる。車輪から火花が散り、画面が揺れる
func _rush_in() -> void:
	var lead := horn_lead if horn_sound else 0.0
	_entry_sound_end_msec = Time.get_ticks_msec() + int(maxf(_length_of(horn_sound), lead + _length_of(rush_sound)) * 1000.0)
	_horn_end_msec = Time.get_ticks_msec() + int(_length_of(horn_sound) * 1000.0)
	if horn_sound:
		_play(horn_sound, -2.0)
		await _wait(horn_lead) # 汽笛が鳴ってから、突っ込んでくる
	if rush_sound:
		_play(rush_sound, -4.0)
	var trail : MeteorTrail = null
	if meteor_trail:
		trail = MeteorTrail.new()
		trail.front_y = _extent.x if _front_is_top() else _extent.y
		trail.back_dir = 1.0 if _front_is_top() else -1.0
		trail.half_width = _half_width() * 1.15
		_enemy.add_child(trail)
	var target := _wagon_target_y(_current)
	var camera := StageCamera.of(self)
	if camera:
		camera.shake(rush_shake * 0.6, rush_time)
	_stop_tween()
	_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_tween.tween_property(_enemy, "global_position:y", target, rush_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_spark_loop() # 待たずに、突っ込んでいるあいだ火花を出し続ける
	await _tween.finished
	# 止まった反動で、少し前へつんのめってから戻る
	if camera:
		camera.shake(rush_shake, 0.45)
	var jolt := 18.0 * (-1.0 if _front_is_top() else 1.0)
	_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_tween.tween_property(_enemy, "global_position:y", target + jolt, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_enemy, "global_position:y", target, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if trail:
		# 止まったら、光の筋がすっと消える
		var fade := trail.create_tween()
		fade.tween_property(trail, "intensity", 0.0, 0.5)
		fade.tween_callback(trail.queue_free)
	await _tween.finished

## 登場の効果音が鳴り終わるまでの残り(秒)。まだ鳴り始めていなければ、鳴り終わるまでの全部の長さの目安
func entry_sound_remaining() -> float:
	if _entry_sound_end_msec == 0:
		return 99.0
	return maxf(float(_entry_sound_end_msec - Time.get_ticks_msec()) / 1000.0, 0.0)

## 汽笛(ファーン)が鳴り終わるまでの残り(秒)。まだ鳴らしていなければ 99
func horn_remaining() -> float:
	if _horn_end_msec == 0:
		return 99.0
	return maxf(float(_horn_end_msec - Time.get_ticks_msec()) / 1000.0, 0.0)

func _length_of(stream : AudioStream) -> float:
	return stream.get_length() if stream else 0.0

func _play(stream : AudioStream, volume_db : float) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	get_tree().current_scene.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

## 突っ込んでくるあいだ、車体の両側(線路の上)から火花を散らす
func _spark_loop() -> void:
	var t := 0.0
	var tree := get_tree()
	while t < rush_time and _alive():
		var view := CameraView.visible_rect(_enemy)
		var top := maxf(_enemy.global_position.y + _extent.x, view.position.y)
		var bottom := minf(_enemy.global_position.y + _extent.y, view.end.y)
		if bottom > top:
			# 車輪とレールがこすれて、後ろ・外側へ火花が飛ぶ
			var back := 1.0 if _front_is_top() else -1.0
			for side in [-1.0, 1.0]:
				for i in 3:
					var at := Vector2(_enemy.global_position.x + side * _half_width() + randf_range(-4, 4), randf_range(top, bottom))
					RailSparks.emit(tree, at, Vector2(side * 260.0, back * 520.0), 3, 70.0)
		await tree.create_timer(rush_spark_interval, false).timeout
		t += rush_spark_interval

## 車体の幅の半分(火花を出す位置。車輪のあたり)
func _half_width() -> float:
	var visual := _enemy.get_node_or_null("VisualRoot") as Node2D
	return 66.0 * (absf(visual.global_scale.x) if visual else 1.0)

## 車両の位置と、そこに付いている部位を測る
func _measure() -> void:
	var visual := _enemy.get_node_or_null("VisualRoot")
	if visual == null:
		return
	var top := INF
	var bottom := -INF
	for wagon_name in wagon_names:
		var sprite := visual.get_node_or_null(NodePath(wagon_name)) as Sprite2D
		if sprite == null:
			continue
		var rect := sprite.get_global_transform() * sprite.get_rect()
		var y := rect.get_center().y - _enemy.global_position.y
		_wagons.append({"y": y, "parts": []})
		top = minf(top, rect.position.y - _enemy.global_position.y)
		bottom = maxf(bottom, rect.end.y - _enemy.global_position.y)
	_extent = Vector2(top, bottom)
	for node in _enemy.find_children("*", "", true, false):
		if node is EnemyPart:
			var dy : float = node.global_position.y - _enemy.global_position.y
			var best := 0
			for i in _wagons.size():
				if absf(_wagons[i]["y"] - dy) < absf(_wagons[best]["y"] - dy):
					best = i
			_wagons[best]["parts"].append(node)

## 進む向きの手前、画面の外に置く(先頭が上なら画面の下の外、先頭が下なら画面の上の外)
func _place_outside() -> void:
	var view := CameraView.visible_rect(_enemy)
	if _front_is_top():
		_enemy.global_position.y = view.end.y + 40.0 - _extent.x
	else:
		_enemy.global_position.y = view.position.y - 40.0 - _extent.y

## 先頭の車両が上にあるか(上へ進む列車か)
func _front_is_top() -> bool:
	return _wagons.size() < 2 or _wagons[0]["y"] < _wagons[1]["y"]

func _run() -> void:
	var holds := 0
	while _alive() and not _leaving:
		await _hold()
		if not _alive() or _leaving:
			return
		if exit_after > 0.0 and _age >= exit_after:
			await _leave()
			return
		holds += 1
		if _force_span >= 0:
			# 最後の段階: 決まった位置(中央)へ移って、そこからは線路を移らない
			var target := _force_span
			_force_span = -1
			_route_locked = true
			if target != span:
				await _switch_rail_to(target)
				continue
		if not route.is_empty() and not _route_locked and holds >= holds_per_switch:
			holds = 0
			await _switch_rail()
			continue
		var next := _next_wagon()
		if next != _current:
			_current = next
			await _move_to_wagon(_current, move_speed)

## 止まって撃つ。見えている車両の砲台が全部壊れたら、早めに切り上げる
func _hold() -> void:
	_set_moving(false)
	var time := randf_range(hold_min, maxf(hold_min, hold_max))
	var t := 0.0
	while t < time and _alive() and not _leaving:
		if _force_span >= 0:
			return # 最後の段階に入った: すぐ中央へ移る
		if not _wagon_alive(_current) and _any_alive():
			await _wait(regroup_delay)
			return
		if exit_after > 0.0 and _age >= exit_after:
			return
		await _wait(0.2)
		t += 0.2

## 次に見せる車両: 進んでいる向きに、壊れていない砲台のある車両があればそこ。なければ向きを変える
func _next_wagon() -> int:
	for attempt in 2:
		var i := _current + _direction
		while i >= 0 and i < _wagons.size():
			if _wagon_alive(i):
				return i
			i += _direction
		_direction = -_direction
	return _current

func _first_alive(from : int, step : int) -> int:
	var i := from
	while i >= 0 and i < _wagons.size():
		if _wagon_alive(i):
			return i
		i += step
	return clampi(from, 0, _wagons.size() - 1)

func _wagon_alive(i : int) -> bool:
	for part in _wagons[i]["parts"]:
		if is_instance_valid(part) and not part.is_destroyed():
			return true
	return false

func _any_alive() -> bool:
	for i in _wagons.size():
		if _wagon_alive(i):
			return true
	return false

## 車両 i の砲台が画面の決まった高さに来るところまで、ゆっくり動く
func _move_to_wagon(i : int, speed : float) -> void:
	var target := _wagon_target_y(i)
	# 遠くの車両へ動くとき(一番後ろから、前に残った砲台へ戻るときなど)は、時間をかけすぎない
	var far := absf(target - _enemy.global_position.y) > far_move_distance
	_fast_moving = far # 遠くへ速く動くあいだは撃たない
	await _move_y(target, speed, far_move_max_time if far else -1.0)
	_fast_moving = false

## 車両 i を見せるときの、敵の y。壊れていない砲台の真ん中を View Anchor の高さに置き、
## いちばん下の砲台が Lowest Turret Limit より下に来ないようにする(砲台がなければ、車両の真ん中を使う)
func _wagon_target_y(i : int) -> float:
	var view := CameraView.visible_rect(_enemy)
	var top := INF
	var bottom := -INF
	for part in _wagons[i]["parts"]:
		if is_instance_valid(part) and not part.is_destroyed():
			var dy : float = part.global_position.y - _enemy.global_position.y
			top = minf(top, dy)
			bottom = maxf(bottom, dy)
	if top == INF:
		top = float(_wagons[i]["y"])
		bottom = top
	var target := view.position.y + view.size.y * view_anchor - (top + bottom) * 0.5
	var lowest := view.position.y + view.size.y * lowest_turret_limit - bottom
	return minf(target, lowest)

## y まで、動き始めと止まる前がゆっくりになるように動く。動いているあいだは撃たない
func _move_y(target : float, speed : float, max_time : float = -1.0) -> void:
	if not _alive():
		return
	_set_moving(true)
	_stop_tween()
	var distance := absf(target - _enemy.global_position.y)
	if distance > 1.0:
		_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		# 平均の速さが speed の 2/3 くらいになるように(ゆっくり動き出して、ゆっくり止まる)
		var time := maxf(distance / speed * 1.5, 2.0)
		if max_time > 0.0:
			time = minf(time, max_time) # 遠くの車両を見せに行くときも、時間をかけすぎない
		_tween.tween_property(_enemy, "global_position:y", target, time)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await _tween.finished

## Route の次の位置へ移る(援護の列車が乗っている位置は飛ばす)
func _switch_rail() -> void:
	var busy := occupied_spans(get_tree(), _enemy)
	var next : int = route[_route_index % route.size()]
	for i in route.size():
		next = route[_route_index % route.size()]
		_route_index += 1
		if not busy.has(next) and next != span:
			break
	await _switch_rail_to(next)

## 進む向きへ走り去って、画面の外に出きったら、next の位置の線路から入り直す。
## 入り直したら、次の車両を見せる(いつも先頭からにすると、後ろの車両の砲台が画面に出てこないので)
func _switch_rail_to(next : int) -> void:
	span = next # 援護が、もうこの位置を避けられるように、先に決めておく
	_fast_moving = true # 線路を移るあいだ(走り去る・入り直す)は撃たない
	vacating = true
	await _run_off(switch_speed)
	vacating = false
	if not _alive():
		return
	var ground := RailGround.of(self)
	if ground and next >= 0 and next < ground.span_count():
		_enemy.global_position.x = ground.span_x(next)
	await _wait(1.0)
	if not _alive():
		return
	_place_outside()
	_current = _next_wagon()
	await _move_y(_wagon_target_y(_current), switch_speed, switch_enter_max_time)
	_fast_moving = false

## ボスの段階を見て、最後の段階に入ったら中央へ移る
func _watch_phase() -> void:
	if not is_instance_valid(_enemy):
		return
	for child in _enemy.get_children():
		if child is BossPhaseController:
			child.phase_started.connect(func(index : int) -> void:
				if final_phase >= 0 and index >= final_phase and not _route_locked:
					_force_span = final_span)

## 進む向き(先頭の向き)へ、だんだん速くなりながら走り去る
func _run_off(speed : float) -> void:
	var view := CameraView.visible_rect(_enemy)
	var target : float
	if _front_is_top():
		target = view.position.y - 60.0 - _extent.y # 最後尾が画面の上の外へ
	else:
		target = view.end.y + 60.0 - _extent.x # 最後尾が画面の下の外へ
	_set_moving(true)
	_stop_tween()
	var distance := absf(target - _enemy.global_position.y)
	_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	# 長い列車でも、走り去るのに時間をかけすぎない(Switch Enter Max Time まで)
	var time := minf(maxf(distance / speed * 1.6, 2.0), maxf(switch_enter_max_time, 2.0))
	_tween.tween_property(_enemy, "global_position:y", target, time)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await _tween.finished

## すぐに、進む向きへ急いで走り去って消える(ボスが次の援護を呼ぶ前に、前の援護をどかす)。
## 消えたら freed になる(倒したことにはならない)
func leave_now(speed : float = 700.0) -> void:
	if _leaving or not _alive():
		return
	_leaving = true
	_fast_moving = true # 急いで走り去るあいだは撃たない
	_stop_tween()
	await _run_off(speed)
	if is_instance_valid(_enemy) and _alive():
		_enemy.queue_free()

## 援護: 走り去って消える(倒したことにはならない)
func _leave() -> void:
	_leaving = true
	await _run_off(enter_speed)
	if is_instance_valid(_enemy) and _alive():
		_enemy.queue_free()

func _physics_process(delta : float) -> void:
	_age += delta
	_place_flank_shooters()
	_block_shooters_behind_player()

## 動いているあいだ、自機が画面の真ん中より下にいたら、自機より後ろ(下)の砲口を止める
func _block_shooters_behind_player() -> void:
	if not is_instance_valid(_enemy):
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var active := no_fire_from_behind_while_moving and _moving and player != null and player.visible
	var line := INF
	if active:
		var view := CameraView.visible_rect(_enemy)
		if player.global_position.y >= view.get_center().y:
			line = player.global_position.y + behind_margin
	_enemy.set_meta("train_behind_line", line)
	if _all_shooters.is_empty():
		for node in _enemy.find_children("*", "", true, false):
			if node is EnemyShooter:
				_all_shooters.append(node)
	for shooter in _all_shooters:
		if is_instance_valid(shooter):
			shooter.blocked = shooter.global_position.y > line

## 列車(enemy)が動いていて、pos が自機より後ろ(下)なので、撃たないほうがいいか(ビームが使う)
static func is_behind_player(enemy : Node, pos : Vector2) -> bool:
	return enemy != null and enemy.has_meta("train_behind_line") and pos.y > float(enemy.get_meta("train_behind_line"))

## 画面の外から撃つ砲口を、列車の、自機のいる側の横に置く(高さは画面の中、列車のある範囲の中)
func _place_flank_shooters() -> void:
	if flank_shooters.is_empty() or not is_instance_valid(_enemy) or _wagons.is_empty():
		return
	var view := CameraView.visible_rect(_enemy)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var side := 1.0
	if player:
		side = signf(player.global_position.x - _enemy.global_position.x)
	var top := _enemy.global_position.y + _extent.x
	var bottom := _enemy.global_position.y + _extent.y
	for i in flank_shooters.size():
		var gun := flank_shooters[i]
		if not is_instance_valid(gun):
			continue
		var h : float = flank_heights[i % flank_heights.size()] if not flank_heights.is_empty() else 0.3
		var y := clampf(view.position.y + view.size.y * h, top, bottom)
		gun.global_position = Vector2(_enemy.global_position.x + side * _half_width(), y)

## 動いているあいだは撃たない(砲口を止め、止まったら、壊れていない部位の砲口だけ戻す)
func _set_moving(moving : bool) -> void:
	_moving = moving
	if not is_instance_valid(_enemy):
		return
	_enemy.set_meta("train_moving", moving)
	var hold := (moving and (not fire_while_moving or _fast_moving)) or _entering
	_enemy.set_meta("train_hold_fire", hold)
	for node in _enemy.find_children("*", "", true, false):
		if node is EnemyShooter:
			node.enabled = not hold and not _shooter_broken(node)

## 壊れた部位の砲口か(部位の Shooters に入っているか、部位の子か)
func _shooter_broken(shooter : EnemyShooter) -> bool:
	for i in _wagons.size():
		for part in _wagons[i]["parts"]:
			if is_instance_valid(part) and part.is_destroyed() and (part.shooters.has(shooter) or part.is_ancestor_of(shooter)):
				return true
	return false

## これから乗る位置(最後の段階で中央へ移る途中なら、移る先)
func target_span() -> int:
	return _force_span if _force_span >= 0 else span

## 位置を移る途中か(移る先が決まっている・今の位置から走り去っている)
func is_relocating() -> bool:
	return _force_span >= 0 or vacating

## 列車(TrainBossMover)が乗っている位置(Span)の一覧。exclude の列車は除く
static func occupied_spans(tree : SceneTree, exclude : Node = null) -> Array[int]:
	var result : Array[int] = []
	for node in tree.get_nodes_in_group("enemy"):
		if node == exclude:
			continue
		for child in node.get_children():
			if child is TrainBossMover and child.span >= 0 and not child._leaving:
				result.append(child.span)
	return result

## 動いているところか
static func is_moving(enemy : Node) -> bool:
	return enemy != null and enemy.has_meta("train_moving") and enemy.get_meta("train_moving")

## 撃つのを止めているところか(BeamShooter が見る)
static func holds_fire(enemy : Node) -> bool:
	return enemy != null and enemy.has_meta("train_hold_fire") and enemy.get_meta("train_hold_fire")

func _stop_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()

func _alive() -> bool:
	return is_instance_valid(_enemy) and is_inside_tree() and _enemy.hp_component and _enemy.hp_component.hp > 0

func _wait(seconds : float) -> void:
	if seconds > 0.0:
		await get_tree().create_timer(seconds, false).timeout
