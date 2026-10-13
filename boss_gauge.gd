extends CanvasLayer
class_name BossGauge
## ボスのHPゲージ。ステージのシーンに置いて、このスクリプトをアタッチするだけで使える
## (表示は全てコードで作る。シーンに子ノードは不要)。
##
## 使い方:
##   ・SpawnEvent の is_boss をオンにすると、StageRunner の合図で、自動でボスに繋がる
##   ・手動なら bind(enemy.hp_component, "ボス名", [0.66, 0.33], enemy) を呼ぶ
##
## 動き(全てTween):
##   出現    : 上から滑り込み、ゲージが 0 → 満タン まで伸びる
##   被ダメージ: 赤いバーが素早く下がり、黄色いバーが遅れて追いかける。白く光り、軽く揺れる
##   フェーズ  : 目印(縦線)を割ると、大きく光って揺れ、phase_changed が出る
##   HPが少ない: バーが赤く脈打つ
##   撃破    : 黄色いバーが落ち切ってから、光って消える

## 目印(縦線)を割ったときに出る。0 から数える。弾幕の切り替えなどに使える
signal phase_changed(index : int)

const BAR_WIDTH : float = 260.0
const BAR_HEIGHT : float = 14.0
const TOP_MARGIN : float = 80.0
## HPの割合がこれ以下になると、バーが脈打つ
const LOW_HP_RATIO : float = 0.3

const COLOR_MAIN : Color = Color(0.92, 0.18, 0.12)
const COLOR_DAMAGE : Color = Color(1.0, 0.82, 0.35)
const COLOR_BACK : Color = Color(0.07, 0.05, 0.05, 0.85)
const COLOR_FRAME : Color = Color(1.0, 1.0, 1.0, 0.85)

## 未設定なら、"stage_runner" グループから探す
@export var stage_runner : StageRunner

var _root : Control
var _root_base : Vector2
var _damage_bar : ColorRect
var _main_bar : ColorRect
var _flash : ColorRect
var _pulse : ColorRect
var _name_label : Label
var _ticks : Array[ColorRect] = []

var _hp : HPComponent
var _boss : Node
var _thresholds : Array[float] = []
var _target_ratio : float = 1.0 # HPの本当の割合
var _main_ratio : float = 0.0   # 赤いバーに出ている割合
var _damage_ratio : float = 0.0 # 黄色いバーに出ている割合
var _intro_ratio : float = 1.0
var _active : bool = false
var _intro_playing : bool = false
var _outro_started : bool = false
var _last_shake_msec : int = 0

var _intro_tween : Tween
var _main_tween : Tween
var _damage_tween : Tween
var _flash_tween : Tween
var _shake_tween : Tween
var _pulse_tween : Tween
var _outro_tween : Tween

func _ready() -> void:
	layer = 20
	_build()
	_root.visible = false
	_connect_runner.call_deferred() # 全ノードの準備が終わってから探す

func _connect_runner() -> void:
	if stage_runner:
		stage_runner.boss_spawned.connect(_on_boss_spawned)
		return
	for node in get_tree().get_nodes_in_group("stage_runner"):
		(node as StageRunner).boss_spawned.connect(_on_boss_spawned)

func _on_boss_spawned(enemy : Enemy, boss_name : String, thresholds : Array[float]) -> void:
	bind(enemy.hp_component, boss_name, thresholds, enemy)

# ---------------------------------------------------------------- 組み立て

func _build() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root_base = Vector2((viewport_size.x - BAR_WIDTH) / 2.0, TOP_MARGIN)
	_root.position = _root_base
	_root.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	add_child(_root)

	_rect(COLOR_FRAME, Vector2(-3.0, -3.0), Vector2(BAR_WIDTH + 6.0, BAR_HEIGHT + 6.0))
	_rect(COLOR_BACK, Vector2.ZERO, Vector2(BAR_WIDTH, BAR_HEIGHT))
	_damage_bar = _rect(COLOR_DAMAGE, Vector2.ZERO, Vector2(0.0, BAR_HEIGHT))
	_main_bar = _rect(COLOR_MAIN, Vector2.ZERO, Vector2(0.0, BAR_HEIGHT))
	_pulse = _rect(Color(1.0, 0.4, 0.4, 0.0), Vector2.ZERO, Vector2(0.0, BAR_HEIGHT))
	_flash = _rect(Color(1.0, 1.0, 1.0, 0.0), Vector2.ZERO, Vector2(0.0, BAR_HEIGHT))

	_name_label = Label.new()
	_name_label.position = Vector2(0.0, -32.0)
	_name_label.add_theme_font_size_override("font_size", 18)
	_name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_name_label.add_theme_constant_override("outline_size", 4)
	_name_label.pivot_offset = Vector2(0.0, 14.0)
	_root.add_child(_name_label)

func _rect(color : Color, pos : Vector2, rect_size : Vector2) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = color
	rect.position = pos
	rect.size = rect_size
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(rect)
	return rect

func _make_ticks() -> void:
	for tick in _ticks:
		tick.queue_free()
	_ticks.clear()
	for t in _thresholds:
		_ticks.append(_rect(Color(1.0, 1.0, 1.0, 0.95),
			Vector2(BAR_WIDTH * t - 1.0, -3.0), Vector2(2.0, BAR_HEIGHT + 6.0)))
		_root.move_child(_name_label, -1)

# ---------------------------------------------------------------- 接続

## hp: ボスのHPComponent / thresholds: フェーズの目印にするHPの割合(例 [0.66, 0.33])
func bind(hp : HPComponent, boss_name : String = "", thresholds : Array[float] = [], boss : Node = null) -> void:
	_unbind()
	_hp = hp
	_boss = boss
	_thresholds = thresholds.duplicate()
	_name_label.text = boss_name
	_target_ratio = _ratio_of(hp)
	hp.hp_changed.connect(_on_hp_changed)
	hp.is_dead.connect(_on_dead)
	if boss:
		boss.tree_exiting.connect(_on_boss_gone)
	_make_ticks()
	_play_intro()

func _unbind(kill_outro : bool = true) -> void:
	if _hp and is_instance_valid(_hp):
		if _hp.hp_changed.is_connected(_on_hp_changed):
			_hp.hp_changed.disconnect(_on_hp_changed)
		if _hp.is_dead.is_connected(_on_dead):
			_hp.is_dead.disconnect(_on_dead)
	if _boss and is_instance_valid(_boss) and _boss.tree_exiting.is_connected(_on_boss_gone):
		_boss.tree_exiting.disconnect(_on_boss_gone)
	_hp = null
	_boss = null
	for t in [_intro_tween, _main_tween, _damage_tween, _flash_tween, _shake_tween, _pulse_tween]:
		_kill(t)
	if kill_outro:
		_kill(_outro_tween) # 退場の最後(自分のコールバック内)から呼ぶときは、止めない
	_pulse.color.a = 0.0
	_flash.color.a = 0.0
	_active = false
	_intro_playing = false
	_outro_started = false

func _ratio_of(hp : HPComponent) -> float:
	return clampf(float(hp.hp) / float(maxi(hp.max_hp, 1)), 0.0, 1.0)

func _kill(tween : Tween) -> void:
	if tween and tween.is_valid():
		tween.kill()

# ---------------------------------------------------------------- 値の反映

func _set_main(ratio : float) -> void:
	_main_ratio = ratio
	var width := BAR_WIDTH * ratio
	_main_bar.size.x = width
	_pulse.size.x = width
	_flash.size.x = width

func _set_damage(ratio : float) -> void:
	_damage_ratio = ratio
	_damage_bar.size.x = BAR_WIDTH * ratio

# ---------------------------------------------------------------- 出現

func _play_intro() -> void:
	_active = true
	_outro_started = false
	_intro_playing = true
	_intro_ratio = _target_ratio
	_root.visible = true
	_root.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_root.position = _root_base + Vector2(0.0, -36.0)
	_set_main(0.0)
	_set_damage(0.0)

	_intro_tween = create_tween()
	_intro_tween.tween_property(_root, "modulate:a", 1.0, 0.25)
	_intro_tween.parallel().tween_property(_root, "position", _root_base, 0.45)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# ゲージが 0 から伸びる
	_intro_tween.tween_method(_fill_intro, 0.0, 1.0, 1.1)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_intro_tween.tween_callback(_end_intro)

func _fill_intro(progress : float) -> void:
	var ratio := progress * _intro_ratio
	_set_main(ratio)
	_set_damage(ratio)

func _end_intro() -> void:
	_intro_playing = false
	# 出現中にダメージを受けていたら、ここで追いつく
	if not is_equal_approx(_main_ratio, _target_ratio):
		_animate_to(_target_ratio)
	_update_low_hp()

# ---------------------------------------------------------------- HPの変化

func _on_hp_changed() -> void:
	if not _active or _hp == null or _outro_started:
		return
	var old_ratio := _target_ratio
	var new_ratio := _ratio_of(_hp)
	_target_ratio = new_ratio
	if _intro_playing:
		return
	if new_ratio < old_ratio:
		_on_damaged(old_ratio, new_ratio)
	elif new_ratio > old_ratio:
		_animate_to(new_ratio) # 回復

func _on_damaged(old_ratio : float, new_ratio : float) -> void:
	# 赤いバー: 素早く下がる
	_kill(_main_tween)
	_main_tween = create_tween()
	_main_tween.tween_method(_set_main, _main_ratio, new_ratio, 0.12)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# 黄色いバー: 攻撃が止まってから、遅れて追いつく(当たるたびに待ち直す)
	_kill(_damage_tween)
	_damage_tween = create_tween()
	_damage_tween.tween_interval(0.45)
	_damage_tween.tween_method(_set_damage, _damage_ratio, new_ratio, 0.5)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

	_flash_hit(0.55, 0.18)
	_shake(clampf((old_ratio - new_ratio) * 40.0 + 2.0, 2.0, 8.0), false)
	for i in _thresholds.size():
		if old_ratio > _thresholds[i] and new_ratio <= _thresholds[i]:
			_phase_crossed(i)
	_update_low_hp()

## 赤と黄色のバーを、同時に目標まで動かす(回復や、出現中の遅れを取り戻すとき)
func _animate_to(ratio : float) -> void:
	_kill(_main_tween)
	_kill(_damage_tween)
	_main_tween = create_tween()
	_main_tween.tween_method(_set_main, _main_ratio, ratio, 0.3)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_damage_tween = create_tween()
	_damage_tween.tween_interval(0.2)
	_damage_tween.tween_method(_set_damage, _damage_ratio, ratio, 0.4)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

## フェーズの目印を割った: 大きく光って、強く揺れて、目印とボス名が弾む
func _phase_crossed(index : int) -> void:
	_flash_hit(1.0, 0.4)
	_shake(10.0, true)
	var tick := _ticks[index]
	tick.modulate = Color(3.0, 3.0, 1.2)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(tick, "modulate", Color.WHITE, 0.5)
	_name_label.scale = Vector2(1.35, 1.35)
	tween.tween_property(_name_label, "scale", Vector2.ONE, 0.4)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	phase_changed.emit(index)

# ---------------------------------------------------------------- 演出

## バーが白く光って、すぐ消える
func _flash_hit(alpha : float, time : float) -> void:
	_kill(_flash_tween)
	_flash.color.a = alpha
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash, "color:a", 0.0, time)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

## だんだん小さくなる揺れ。連続で当たっても、揺れすぎないよう間引く
func _shake(amplitude : float, force : bool) -> void:
	var now := Time.get_ticks_msec()
	if not force and now - _last_shake_msec < 70:
		return
	_last_shake_msec = now
	_kill(_shake_tween)
	_shake_tween = create_tween()
	var steps := 6
	for i in steps:
		var power := amplitude * (1.0 - float(i) / steps)
		var offset := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * power
		_shake_tween.tween_property(_root, "position", _root_base + offset, 0.04)
	_shake_tween.tween_property(_root, "position", _root_base, 0.04)

## HPが少ないときは、バーが赤く脈打つ
func _update_low_hp() -> void:
	var low := _target_ratio > 0.0 and _target_ratio <= LOW_HP_RATIO
	if low:
		if _pulse_tween and _pulse_tween.is_valid():
			return
		_pulse_tween = create_tween().set_loops()
		_pulse_tween.tween_property(_pulse, "color:a", 0.45, 0.3)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_pulse_tween.tween_property(_pulse, "color:a", 0.0, 0.3)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		_kill(_pulse_tween)
		_pulse.color.a = 0.0

# ---------------------------------------------------------------- 撃破・退場

func _on_dead() -> void:
	_play_outro()

## ボスが倒されずに消えたとき(画面外へ逃げたなど)
func _on_boss_gone() -> void:
	_play_outro()

func _play_outro() -> void:
	if not _active or _outro_started:
		return
	_outro_started = true
	_intro_playing = false
	_kill(_pulse_tween)
	_pulse.color.a = 0.0
	_animate_to(0.0) # 赤も黄色も、空まで落とす

	_outro_tween = create_tween()
	_outro_tween.tween_interval(0.9) # 黄色いバーが落ち切るまで待つ
	_outro_tween.tween_callback(func() -> void: _flash_hit(1.0, 0.3))
	_outro_tween.tween_interval(0.2)
	_outro_tween.tween_property(_root, "modulate:a", 0.0, 0.5)
	_outro_tween.parallel().tween_property(_root, "position", _root_base + Vector2(0.0, -24.0), 0.5)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_outro_tween.tween_callback(_finish_outro)

func _finish_outro() -> void:
	_root.visible = false
	_root.position = _root_base
	_unbind(false)
