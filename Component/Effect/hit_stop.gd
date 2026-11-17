class_name HitStop
## ヒットストップ: 一瞬だけゲームの時間をほぼ止める。どこからでも HitStop.play(get_tree(), 秒) で呼ぶ。
## 時間は実際の時間で数える(止めている時間そのものはゆっくりにならない)。
## 続けて呼ばれたときは、長く止める方・より止める方を優先し、最後のものが元の速さに戻す。

## 止めているあいだのゲームの速さ(0 に近いほど止まる)
const DEFAULT_SCALE : float = 0.05

static var _token : int = 0
static var _until_msec : int = 0

## seconds 秒(実際の時間)だけ、ゲームの速さを time_scale にする
static func play(tree : SceneTree, seconds : float, time_scale : float = DEFAULT_SCALE) -> void:
	if tree == null or seconds <= 0.0:
		return
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	if until <= _until_msec and Engine.time_scale <= time_scale:
		return # もっと長く・強く止めているところ
	_until_msec = maxi(_until_msec, until)
	_token += 1
	var token := _token
	Engine.time_scale = minf(Engine.time_scale, time_scale) if is_active() else time_scale
	var wait := float(_until_msec - Time.get_ticks_msec()) / 1000.0
	await tree.create_timer(maxf(wait, 0.0), true, false, true).timeout # 実際の時間で数える
	if token == _token:
		Engine.time_scale = 1.0
		_until_msec = 0

## 止めているところか
static func is_active() -> bool:
	return Time.get_ticks_msec() < _until_msec

## すぐ元の速さに戻す(シーンを切り替えるときなど)
static func reset() -> void:
	_token += 1
	_until_msec = 0
	Engine.time_scale = 1.0
