extends Node2D
class_name IgniteVisual
## イグナイトのオーラの見た目。"Ignite" シーンのルート(Node2D)にアタッチする。
## 子の Sprite2D "First" / "Second" / "Third" を、レベルに応じて表示し、Tween で動かす。
##   First : 常に表示(Lv1〜)。右回り。終了の blink_time 秒前から点滅(だんだん速くなる)
##   Second: second_unlock_level 以上で追加。左回り + 伸縮
##   Third : third_unlock_level 以上で追加。右回り + 伸縮
## 各スプライトは「Lv10(最大)のオーラ半径のとき」の大きさでデザインしておく。
## レベルが低いときは、その分だけ縮小して表示される。

@export_group("出現するレベル")
@export var second_unlock_level : int = 5
@export var third_unlock_level : int = 10

@export_group("出現・消滅")
## 発動時、0 → 目標サイズまで大きくなる時間(秒)
@export var grow_time : float = 0.25
## 終了時のフェードアウト時間(秒)
@export var fade_time : float = 0.2

@export_group("回転(1周にかかる秒数。+は右回り、−は左回り、0で回転しない)")
@export var first_rotation_period : float = 6.0
@export var second_rotation_period : float = -8.0
@export var third_rotation_period : float = 5.0

@export_group("伸縮(0.05 = 基準サイズの ±5%)")
@export var first_pulse : float = 0.0
@export var second_pulse : float = 0.05
@export var third_pulse : float = 0.05
## 大きくなって小さくなるまでの1往復の秒数
@export var pulse_period : float = 1.6

@export_group("First の点滅(終了間際)")
## 終了のこの秒数前から点滅する(発動時間がこれより短いときは、最初から点滅)
@export var blink_time : float = 3.0
## 点滅で一番薄くなったときの不透明度
@export_range(0.0, 1.0, 0.05) var blink_min_alpha : float = 0.25
## 点滅の速さ(回/秒)。開始時 → 終了時に向けて速くなる
@export var blink_freq_start : float = 3.0
@export var blink_freq_end : float = 8.0

var _layers : Array[Node2D] = []
var _unlock_levels : Array[int] = []
var _base_scales : Array[Vector2] = []
var _base_rotations : Array[float] = []
var _active : Array[bool] = [false, false, false]
var _pulse : Array[float] = [0.0, 0.0, 0.0]

var _ratio : float = 1.0
var _grow : float = 0.0 # 出現アニメーション用(0→1)。Tween で動かす
var _tweens : Array[Tween] = []
var _fade_tween : Tween

func _ready() -> void:
	for layer_name in ["First", "Second", "Third"]:
		var sprite := get_node_or_null(layer_name) as Node2D
		_layers.append(sprite)
		_base_scales.append(sprite.scale if sprite else Vector2.ONE)
		_base_rotations.append(sprite.rotation if sprite else 0.0)
	_unlock_levels = [1, second_unlock_level, third_unlock_level]
	visible = false
	set_process(false)

# ---------------------------------------------------------------- 外部から呼ぶ

## 発動時に呼ぶ。
## radius_ratio: 今のオーラ半径 ÷ 最大レベルのオーラ半径(0〜1)
## duration: 発動(無敵)の長さ。終了前の点滅のタイミングに使う
func show_aura(level : int, radius_ratio : float, duration : float) -> void:
	_kill_tweens()
	if _fade_tween:
		_fade_tween.kill()
	modulate.a = 1.0
	visible = true
	_ratio = radius_ratio
	_grow = 0.0

	for i in _layers.size():
		var layer := _layers[i]
		_active[i] = layer != null and level >= _unlock_levels[i]
		_pulse[i] = 0.0
		if layer:
			layer.visible = _active[i]
			layer.rotation = _base_rotations[i]
			layer.modulate.a = 1.0
	_apply_scales()
	set_process(true)

	# 出現: 0 → 1 へ、少しオーバーシュートして落ち着く
	var grow := _track(create_tween())
	grow.tween_property(self, "_grow", 1.0, grow_time)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var periods := [first_rotation_period, second_rotation_period, third_rotation_period]
	var pulses := [first_pulse, second_pulse, third_pulse]
	for i in _layers.size():
		if _active[i]:
			_start_rotation(i, periods[i])
			_start_pulse(i, pulses[i])
	_start_blink(duration)

## 終了時に呼ぶ。フェードアウトして、全ての Tween を止める
func hide_aura() -> void:
	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 0.0, fade_time)
	_fade_tween.tween_callback(func() -> void:
		visible = false
		set_process(false)
		_kill_tweens())

# ---------------------------------------------------------------- Tween

## 回転: 0 → TAU を線形で無限ループ(つなぎ目が出ない)
func _start_rotation(i : int, period : float) -> void:
	if is_zero_approx(period):
		return
	var t := _track(create_tween().set_loops())
	t.tween_method(_set_rotation.bind(i, signf(period)), 0.0, TAU, absf(period))\
		.set_trans(Tween.TRANS_LINEAR)

func _set_rotation(angle : float, i : int, direction : float) -> void:
	_layers[i].rotation = _base_rotations[i] + angle * direction

## 伸縮: サイン波のイーズで、大きい ⇔ 小さい を滑らかに往復する
## Third は逆位相(Second が縮むとき Third は膨らむ)で動かす
func _start_pulse(i : int, amount : float) -> void:
	if amount <= 0.0 or pulse_period <= 0.0:
		return
	var from := amount if i == 2 else -amount
	var half := pulse_period / 2.0
	var t := _track(create_tween().set_loops())
	t.tween_method(_set_pulse.bind(i), from, -from, half)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_method(_set_pulse.bind(i), -from, from, half)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _set_pulse(value : float, i : int) -> void:
	_pulse[i] = value

## 点滅: 終了の blink_time 秒前から、だんだん速く点滅する
func _start_blink(duration : float) -> void:
	if blink_time <= 0.0 or _layers[0] == null or not _active[0]:
		return
	var length := minf(blink_time, duration)
	if length <= 0.0:
		return
	var t := _track(create_tween())
	t.tween_interval(maxf(duration - blink_time, 0.0))
	t.tween_method(_set_blink.bind(length), 0.0, length, length)\
		.set_trans(Tween.TRANS_LINEAR)

func _set_blink(elapsed : float, total : float) -> void:
	# 周波数が f0 → f1 に直線的に上がるチャープ波。開始時は不透明(cos = 1)
	var phase := TAU * (blink_freq_start * elapsed \
		+ (blink_freq_end - blink_freq_start) * elapsed * elapsed / (2.0 * total))
	var k := 0.5 + 0.5 * cos(phase)
	_layers[0].modulate.a = lerpf(blink_min_alpha, 1.0, k)

# ---------------------------------------------------------------- 内部

func _process(_delta : float) -> void:
	_apply_scales()

## スケール = 元のスケール × 半径比 × 出現(0→1) × 伸縮
func _apply_scales() -> void:
	for i in _layers.size():
		if _active[i]:
			_layers[i].scale = _base_scales[i] * _ratio * _grow * (1.0 + _pulse[i])

func _track(t : Tween) -> Tween:
	_tweens.append(t)
	return t

func _kill_tweens() -> void:
	for t in _tweens:
		if t and t.is_valid():
			t.kill()
	_tweens.clear()
