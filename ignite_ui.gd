extends Node
class_name IgniteUI
## UIノードにアタッチ。GameManager から bind() で IgniteGauge を受け取り、
## ProgressBar と Label を Tween で動かして表示する。
##
## 表示する値は「レベル + そのレベル内の進捗」の1つの連続値(例: Lv2の40% = 2.4)。
## 減るときは、この値が Tween で滑らかに下がるので、
## バーが「空 → 満タン」を繰り返しながら、ラベルが Lv3 → Lv2 → Lv1 と数え下がっていく。

@onready var bar : ProgressBar = $CanvasLayer/ProgressBar
@onready var label : Label = $CanvasLayer/Label

var _gauge : IgniteGauge
var _shown : float = 0.0        # 画面に出ている値(Tweenで動く)
var _target : float = 0.0       # ゲージの実際の値
var _shown_level : int = -1
var _bar_pos : Vector2

var _tween : Tween              # 値の移動
var _fx_tween : Tween           # 光る
var _shake_tween : Tween        # 揺れる
var _pop_tween : Tween          # ラベルが弾む
var _glow_tween : Tween         # 満タンの間の脈動

func _ready() -> void:
	bar.max_value = 1.0
	bar.step = 0.001
	_bar_pos = bar.position
	_setup_pivots.call_deferred() # レイアウト確定後に、拡大の中心を決める

func _setup_pivots() -> void:
	label.pivot_offset = label.size / 2.0

func bind(gauge : IgniteGauge) -> void:
	_gauge = gauge
	gauge.progress_changed.connect(_on_progress_changed) # level_changed のあとに必ず出る
	_target = _gauge_value()
	_set_shown(_target, false)
	_update_glow()

## レベル + 進捗(0.0〜5.0)。Lv5 は満タンなので進捗は足さない
func _gauge_value() -> float:
	var lv := _gauge.level
	if lv >= IgniteGauge.MAX_LEVEL:
		return float(lv)
	return float(lv) + _gauge.ratio()

func _on_progress_changed(_ratio : float) -> void:
	var new_target := _gauge_value()
	var delta := new_target - _target
	_target = new_target
	if is_zero_approx(delta):
		return

	if _tween:
		_tween.kill()
	_stop_glow()
	_tween = create_tween()
	if delta < 0.0:
		# 減少: 勢いよく落ちて、ゆっくり止まる。減る量が多いほど長くかける
		var amount := absf(delta)
		var duration := clampf(0.35 + 0.3 * amount, 0.35, 1.8)
		_tween.tween_method(_set_shown_animated, _shown, _target, duration)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_play_drain_fx(amount)
	else:
		_tween.tween_method(_set_shown_animated, _shown, _target, 0.18)
		if floorf(_target + 0.0001) > floorf(_shown + 0.0001):
			_play_gain_fx() # レベルが上がった
	_tween.finished.connect(_update_glow)

func _set_shown_animated(value : float) -> void:
	_set_shown(value, true)

## 値をバーとラベルに反映する。レベルが切り替わったら、ラベルを更新して弾ませる
func _set_shown(value : float, pop : bool) -> void:
	_shown = value
	var lv := mini(int(floorf(value + 0.0001)), IgniteGauge.MAX_LEVEL)
	bar.value = 1.0 if lv >= IgniteGauge.MAX_LEVEL else clampf(value - lv, 0.0, 1.0)
	if lv != _shown_level:
		var first := _shown_level < 0
		_shown_level = lv
		label.text = "Ignite %d" % lv
		if pop and not first:
			_pop_label(1.4)

# ---------------------------------------------------------------- 演出

## 減少: 赤く光って、減った量に応じて揺れる
func _play_drain_fx(amount : float) -> void:
	_flash(Color(2.0, 0.55, 0.4), 0.45 + 0.1 * amount)
	_shake(clampf(3.0 + 3.0 * amount, 3.0, 14.0))

## 増加(レベルアップ): 黄色く光って、ラベルが大きく弾む
func _play_gain_fx() -> void:
	_flash(Color(1.8, 1.6, 0.9), 0.35)
	_pop_label(1.6)

## 明るい色から、元の色へ戻る
func _flash(color : Color, time : float) -> void:
	if _fx_tween:
		_fx_tween.kill()
	bar.modulate = color
	label.modulate = color
	_fx_tween = create_tween().set_parallel(true)
	_fx_tween.tween_property(bar, "modulate", Color.WHITE, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_fx_tween.tween_property(label, "modulate", Color.WHITE, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

## だんだん小さくなる揺れ
func _shake(amplitude : float) -> void:
	if _shake_tween:
		_shake_tween.kill()
	_shake_tween = create_tween()
	var steps := 6
	for i in steps:
		var power := amplitude * (1.0 - float(i) / steps)
		var offset := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * power
		_shake_tween.tween_property(bar, "position", _bar_pos + offset, 0.04)
	_shake_tween.tween_property(bar, "position", _bar_pos, 0.04)

## ラベルが一瞬大きくなって、弾んで戻る
func _pop_label(scale_to : float) -> void:
	if _pop_tween:
		_pop_tween.kill()
	label.scale = Vector2.ONE
	_pop_tween = create_tween()
	_pop_tween.tween_property(label, "scale", Vector2.ONE * scale_to, 0.07)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_pop_tween.tween_property(label, "scale", Vector2.ONE, 0.22)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## 満タン(Lv5)の間は、バーがゆっくり脈打つ
func _update_glow() -> void:
	if _target >= float(IgniteGauge.MAX_LEVEL) - 0.0001:
		_start_glow()
	else:
		_stop_glow()

func _start_glow() -> void:
	if _glow_tween and _glow_tween.is_valid():
		return
	_glow_tween = create_tween().set_loops()
	_glow_tween.tween_property(bar, "modulate", Color(1.5, 1.25, 0.9), 0.6)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_glow_tween.tween_property(bar, "modulate", Color.WHITE, 0.6)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _stop_glow() -> void:
	if _glow_tween:
		_glow_tween.kill()
		_glow_tween = null
		bar.modulate = Color.WHITE
