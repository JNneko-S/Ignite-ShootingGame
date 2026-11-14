extends Camera2D
class_name StageCamera
## 横に広いステージ(ステージ2の線路など)で、描画範囲を左右に動かすカメラ。ステージの Camera2D にアタッチする。
##
## 動き方(Mode):
##   FOLLOW: 自機が画面の中央から Dead Zone より外へ寄ると、カメラが付いていく(Follow Min X〜Follow Max X の範囲)
##   LOCK:   決めた位置(レーン)へ移って止まる。自機はその画面の中だけを動ける(中ボス戦)
##   LOOK:   決めた位置へ一時的に向いて、Hold 秒たったら元の位置へ戻り、前の動き方に戻る(ボス戦で、来る列車を見せる)
## LOCK / LOOK でカメラが動くあいだ、自機も一緒に運ばれる(画面の中での位置はそのまま)。
##
## 敵の出現位置: StageRunner は、敵を出すときにカメラの「最初の位置からのずれ」を足す。
## なので SpawnEvent / MovePattern の座標は、今まで通り「画面の座標」で作ればよい。
##
## StageCameraEvent(タイムラインのイベント)から change() / look() を呼ぶ。

enum Mode { FOLLOW, LOCK, LOOK }

## レーン(LOCK / LOOK で使う、カメラの中心の x)。左から順に。ステージ2は 左・中央・右
@export var lanes : Array[float] = [-384.0, 240.0, 864.0]
## 最初の動き方と、LOCK のときのレーン
@export var start_mode : Mode = Mode.FOLLOW
@export var start_lane : int = 1

@export_group("FOLLOW")
## カメラの中心が動ける範囲(x)
@export var follow_min_x : float = -384.0
@export var follow_max_x : float = 864.0
## 自機が画面の中央からこの距離(px)より外へ寄ったら、カメラが付いていく
@export var dead_zone : float = 90.0
## 付いていく速さ(大きいほどぴったり)。0 ならずれずにぴったり
@export var follow_sharpness : float = 10.0

@export_group("移動")
## LOCK / LOOK で移るときの時間(秒)
@export var move_time : float = 1.2

## 敵の出現位置などの基準になる、最初のカメラの x
var home_x : float = 0.0
var mode : Mode = Mode.FOLLOW

var _player : Node2D
var _move_tween : Tween
var _moving : bool = false
var _return_mode : Mode = Mode.FOLLOW
var _look_serial : int = 0
## LOCK / LOOK で動くとき、自機も一緒に運ぶか
var _carry : bool = true
var _look_back_x : float = 0.0
var _shake_tween : Tween

func _ready() -> void:
	add_to_group("stage_camera")
	home_x = global_position.x
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	mode = start_mode
	if mode == Mode.LOCK:
		global_position.x = lane_x(start_lane)

## シーンの中の StageCamera(なければ null)
static func of(node : Node) -> StageCamera:
	if node == null or not node.is_inside_tree():
		return null
	return node.get_tree().get_first_node_in_group("stage_camera") as StageCamera

## カメラが最初の位置から横にずれている量(敵の出現位置に足す)。StageCamera がなければ 0
static func view_offset(node : Node) -> Vector2:
	var camera := of(node)
	return Vector2(camera.global_position.x - camera.home_x, 0.0) if camera else Vector2.ZERO

func lane_x(lane : int) -> float:
	if lanes.is_empty():
		return home_x
	return lanes[clampi(lane, 0, lanes.size() - 1)]

## 動き方を変える。lane は LOCK のときのレーン。time が負なら move_time
func change(new_mode : Mode, lane : int = 1, time : float = -1.0) -> void:
	_look_serial += 1 # 戻る予定の LOOK は取り消す
	match new_mode:
		Mode.FOLLOW:
			_kill_move()
			mode = Mode.FOLLOW
		Mode.LOCK:
			mode = Mode.LOCK
			_move_to(lane_x(lane), move_time if time < 0.0 else time)
		Mode.LOOK:
			look(lane_x(lane), 2.0, time)

## x の位置へ一時的に向いて、hold 秒たったら前の動き方に戻る。
## carry_player がオフなら、自機は動かさずにその場に止めておく(カメラだけが向く演出。自機は操作できず、画面の外にいてもよい)
func look(x : float, hold : float, time : float = -1.0, carry_player : bool = true) -> void:
	var t := move_time if time < 0.0 else time
	_carry = carry_player
	var player := _get_player() as Player
	if not carry_player and player:
		_freeze_player(player, true)
	if mode != Mode.LOOK:
		_return_mode = mode
		_look_back_x = global_position.x # 向いている途中で次の Look が来ても、最初の位置へ戻る
	mode = Mode.LOOK
	_look_serial += 1
	var serial := _look_serial
	var back_x := _look_back_x
	await _move_to(clampf(x, follow_min_x, follow_max_x), t)
	await get_tree().create_timer(maxf(hold, 0.0), false).timeout
	if serial != _look_serial:
		return # そのあいだに、別の指示が来た(自機を止めたままにして、あとの指示に任せる)
	# 元の位置へ戻る(運んでいれば、自機も一緒に戻る)。戻り終わってから、前の動き方に戻す
	await _move_to(back_x, t)
	_end_freeze(player)
	_carry = true
	if serial != _look_serial:
		return
	mode = _return_mode

## カメラだけを、いくつかの場所へ順に向ける演出の始まり(自機はその場に止める)。focus_to() で向け、end_focus() で戻る
func begin_focus() -> void:
	_look_serial += 1 # 動いている Look は取り消す
	if mode != Mode.LOOK:
		_return_mode = mode
		_look_back_x = global_position.x
	mode = Mode.LOOK
	_carry = false
	var player := _get_player() as Player
	if player:
		_freeze_player(player, true)

## x の位置へ、time 秒かけてカメラだけを向ける(begin_focus のあと)
func focus_to(x : float, time : float = -1.0) -> void:
	await _move_to(clampf(x, follow_min_x, follow_max_x), move_time if time < 0.0 else time)

## 元の位置へ戻って、自機を動けるようにし、前の動き方に戻す
func end_focus(time : float = -1.0) -> void:
	await _move_to(_look_back_x, move_time if time < 0.0 else time)
	_carry = true
	_end_freeze(_get_player() as Player)
	mode = _return_mode

func _end_freeze(player : Player) -> void:
	if is_instance_valid(player) and player.has_meta("camera_frozen"):
		_freeze_player(player, false)

## カメラだけが向く演出のあいだ、自機を止める(操作・画面内への押し戻し・被弾を止める)
func _freeze_player(player : Player, frozen : bool) -> void:
	if frozen:
		player.set_meta("camera_frozen", true)
		player.set_physics_process(false)
		player.velocity = Vector2.ZERO
	else:
		player.remove_meta("camera_frozen")
		player.set_physics_process(true)
		player.start_invincibility(1.0) # 戻った直後に、すぐ当たらないように

## 画面を揺らす(strength px、time 秒かけておさまる)
func shake(strength : float, time : float) -> void:
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
	_shake_tween = create_tween()
	_shake_tween.tween_method(func(k : float) -> void:
		offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * strength * k, 1.0, 0.0, time)
	_shake_tween.tween_callback(func() -> void: offset = Vector2.ZERO)

## 最後にカメラが横に動いた時刻(ミリ秒)
var last_move_msec : int = 0
var _last_x : float = NAN

## カメラが、ついさっき(within_msec 以内に)横に動いていたか
static func moved_recently(node : Node, within_msec : int) -> bool:
	var camera := of(node)
	return camera != null and Time.get_ticks_msec() - camera.last_move_msec <= within_msec

func _physics_process(delta : float) -> void:
	if not is_nan(_last_x) and absf(global_position.x - _last_x) > 0.3:
		last_move_msec = Time.get_ticks_msec()
	_last_x = global_position.x
	if mode != Mode.FOLLOW or _moving:
		return
	var player := _get_player()
	if player == null:
		return
	var target := global_position.x
	var dx := player.global_position.x - global_position.x
	if dx > dead_zone:
		target = player.global_position.x - dead_zone
	elif dx < -dead_zone:
		target = player.global_position.x + dead_zone
	target = clampf(target, follow_min_x, follow_max_x)
	if follow_sharpness <= 0.0:
		global_position.x = target
	else:
		global_position.x = lerpf(global_position.x, target, 1.0 - exp(-follow_sharpness * delta))

## x へ time 秒かけて移る。自機も一緒に運ぶ
func _move_to(x : float, time : float) -> void:
	_kill_move()
	if is_equal_approx(x, global_position.x):
		return
	_moving = true
	if time <= 0.0:
		_shift(x)
		_moving = false
		return
	_move_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_move_tween.tween_method(_shift, global_position.x, x, time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _move_tween.finished
	_moving = false

func _kill_move() -> void:
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
	_moving = false

## カメラを x に置き、動いた分だけ自機も運ぶ(Look で carry_player がオフのときは運ばない)
func _shift(x : float) -> void:
	var dx := x - global_position.x
	global_position.x = x
	var player := _get_player()
	if player and _carry:
		player.global_position.x += dx

func _get_player() -> Node2D:
	if not is_instance_valid(_player):
		_player = null
		for node in get_tree().get_nodes_in_group("player"):
			if node is Player:
				_player = node
				break
	return _player
