extends RefCounted
class_name HitStop
## ヒットストップ(一瞬だけゲームの時間をほぼ止める)と、画面のフラッシュ。どこからでも static で呼ぶ。
##   HitStop.apply(get_tree(), 0.1)          ボスを倒した・被弾したなど、手応えを出したい瞬間に
##   HitStop.flash(get_tree(), Color.WHITE)  画面全体が白く光る(ボスを倒したときだけ使う)
## 続けて呼んだときは、長いほうが終わるまで止まる。止める前の速さ(デバッグのスローなど)に戻す。

## よく使う長さ(秒、実際の時間)
const PLAYER_HIT : float = 0.06
const PLAYER_DEATH : float = 0.14
const MIDBOSS_KILL : float = 0.12
const BOSS_KILL : float = 0.2
const BOSS_FINISH : float = 0.12

static var _until_msec : int = 0
static var _token : int = 0
static var _base_scale : float = 1.0
static var _active : bool = false

## time 秒(実際の時間)だけ、ゲームの速さを time_scale にする
static func apply(tree : SceneTree, time : float, time_scale : float = 0.05) -> void:
	if tree == null or time <= 0.0:
		return
	var until := Time.get_ticks_msec() + int(time * 1000.0)
	if _active:
		if until <= _until_msec:
			return # もっと長いヒットストップの途中
	else:
		_base_scale = Engine.time_scale
		_active = true
	_until_msec = until
	_token += 1
	var token := _token
	Engine.time_scale = minf(time_scale, _base_scale)
	await tree.create_timer(time, true, false, true).timeout # 実際の時間で数える
	if _active and token == _token: # 後から長いヒットストップが来ていたら、そちらが戻す
		_active = false
		Engine.time_scale = _base_scale

## apply と同じ(ステージ3側のコードからの呼び方)
static func play(tree : SceneTree, seconds : float, time_scale : float = 0.05) -> void:
	apply(tree, seconds, time_scale)

## 止めているところか
static func is_active() -> bool:
	return _active

## ヒットストップの途中で、シーンを読み直すときなどに、すぐ元の速さへ戻す
static func reset() -> void:
	if _active:
		_active = false
		Engine.time_scale = _base_scale

## 画面全体を一瞬 color で光らせて、time 秒で消す
static func flash(tree : SceneTree, color : Color = Color(1, 1, 1, 0.85), time : float = 0.35) -> void:
	if tree == null or tree.current_scene == null:
		return
	var layer := CanvasLayer.new()
	layer.layer = 30 # ゲームの UI より上、ポーズやゲームオーバーより下
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var rect := ColorRect.new()
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.size = tree.root.get_visible_rect().size
	layer.add_child(rect)
	tree.current_scene.add_child(layer)
	var tween := layer.create_tween().set_ignore_time_scale(true)
	tween.tween_property(rect, "color:a", 0.0, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(layer.queue_free)
