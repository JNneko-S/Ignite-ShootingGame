extends Control
class_name TitleScreen
## 共有の状態をまとめて戻す場所(エディタがクラス名を覚える前でも動くように、ファイルを直接読み込む)
const _RunState := preload("res://Component/Settings/run_state.gd")
## (新しく足したクラスは、エディタがクラス名を覚える前でも動くように、ファイルを直接読み込んで使う)
const _AnotherRound := preload("res://GameScene/Title/another_round.gd")
## タイトル画面(title.tscn)。
##
## 流れ:
##   1. 「Press Any Key」が点滅する。何かキー(ボタン・クリック)を押すと、メニューが出る
##   2. メニュー: 上下で選び、ショット(Enter)で決める
##        START       : 出撃する機体の選択画面へ
##        OPTION      : オプション(OptionPanel)を開く
##        SCORE BOARD : 過去 20 回のスコア(ScoreBoardPanel)を開く
##        REPLAY      : (まだ作っていない。準備中と出る)
##        EXIT        : ゲームを終わる
##   戻るボタン(イグナイト / Esc)で、「Press Any Key」に戻る。

## 機体選択の画面のシーン
@export_file("*.tscn") var ship_select_scene : String = "res://GameScene/Select/ship_select.tscn"
## 選ぶものを変えたとき・決めたとき・戻ったとき(シーンに置いた AudioStreamPlayer)
@export var move_sound : AudioStreamPlayer
@export var confirm_sound : AudioStreamPlayer
@export var back_sound : AudioStreamPlayer
## タイトルの曲(ループする)と、画面を出るときに消えていく時間(秒)
@export var music : AudioStreamPlayer
@export var music_fade_time : float = 0.6
## メニューの文字の色: 選んでいるとき(赤い帯の上)・選んでいないとき・使えないとき
@export var selected_color : Color = Color(1.0, 1.0, 1.0)
@export var normal_color : Color = Color(0.12, 0.09, 0.09)
@export var disabled_color : Color = Color(0.6, 0.56, 0.56)
## 選んでいる項目の後ろの帯の色
@export var bar_color : Color = Color(0.8, 0.14, 0.06)
## 後ろの輪(2つ)が回る速さ(1秒に回る角度、度)
@export var ring_spin_speeds : Array[float] = [6.0, -4.0]
## REPLAY を選んだときに出す文字
@export var replay_message : String = "REPLAY は準備中です"

## ノーコンティニューで最終面をクリアしたあと、EndingSequence が true にする。
## タイトル画面が出たら、操作を受け付けずに「Another Round」の合図を見せて、二周目の一面へ進む
static var another_round_pending : bool = false
## 二周目の最初のステージ
@export_file("*.tscn") var second_loop_scene : String = "res://stage1.tscn"

enum Phase { PRESS, MENU, PANEL, LEAVING }
enum Item { START, OPTION, SCORE_BOARD, ACHIEVEMENTS, REPLAY, EXIT }

@onready var _press_label : Label = $PressLabel
@onready var _menu : Control = $Menu
@onready var _bar : ColorRect = $Menu/Bar
@onready var _items : Array[Label] = [$Menu/Start, $Menu/Option, $Menu/ScoreBoard, $Menu/Achievements, $Menu/Replay, $Menu/Exit]
@onready var _toast : Label = $Toast
@onready var _option : OptionPanel = $OptionPanel
@onready var _score_board : ScoreBoardPanel = $ScoreBoardPanel
@onready var _achievements : AchievementsPanel = $AchievementsPanel
@onready var _fade : ColorRect = $Fade
@onready var _rings : Array[Control] = [$Ring, $Ring2]

var _state : Phase = Phase.PRESS
var _index : int = 0
var _time : float = 0.0
var _bar_tween : Tween
var _toast_tween : Tween

func _ready() -> void:
	_menu.visible = false
	_menu.modulate.a = 0.0
	_toast.modulate.a = 0.0
	_bar.color = bar_color
	for ring in _rings:
		ring.pivot_offset = ring.size * 0.5
	_option.closed.connect(_on_panel_closed)
	_score_board.closed.connect(_on_panel_closed)
	_achievements.closed.connect(_on_panel_closed)
	# 黒から明ける
	_fade.visible = true
	_fade.color.a = 1.0
	create_tween().tween_property(_fade, "color:a", 0.0, 0.6)
	_start_music()
	_RunState.to_title() # 前のプレイの引き継ぎなどを捨てる(二周目へ入る途中なら、そのまま)
	if another_round_pending:
		another_round_pending = false
		_another_round()

## 二周目へ: タイトルを少し見せたあと、グリッチが走って「Welcome to Another Round」。終わったら一面へ
func _another_round() -> void:
	_state = Phase.LEAVING # 操作は受け付けない
	_press_label.visible = false
	# 画面は、黒の上にタイトルロゴだけ(背景の絵・輪・メニューは隠す)
	for path in ["TextureRect", "Ring", "Ring2", "Menu", "Toast"]:
		var node := get_node_or_null(path) as CanvasItem
		if node:
			node.visible = false
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(black)
	move_child(black, 0)
	await get_tree().create_timer(1.4).timeout
	# 曲が歪んで止まる
	if music and music.playing:
		var warp := create_tween().set_parallel(true)
		warp.tween_property(music, "pitch_scale", 0.45, 0.8).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		warp.tween_property(music, "volume_db", music.volume_db - 30.0, 0.8)
		warp.chain().tween_callback(music.stop)
	var overlay = _AnotherRound.new()
	add_child(overlay)
	await overlay.play()
	# 白く光ったところから、ぱっと暗転する
	_fade.color = Color(0, 0, 0, 1)
	_fade.visible = true
	overlay.queue_free()
	await get_tree().create_timer(0.6).timeout
	StageIntro.skip_next = false
	# まだゲームのリソースを読み込んでいなければ、暗転の上にロード画面を出して、先に全部読み込む
	var loading = load("res://GameScene/UI/loading_overlay.gd")
	await loading.run(get_tree())
	# 真っ暗なので、写真を貼る切り替え(SceneSwitcher)はいらない。そのまま読み込んで切り替える
	get_tree().change_scene_to_file(second_loop_scene)

func _start_music() -> void:
	if music == null or music.stream == null:
		return
	if not music.finished.is_connected(music.play):
		music.finished.connect(music.play)
	music.play()

func _process(delta : float) -> void:
	_time += delta
	_tick_idle(delta)
	for i in _rings.size():
		_rings[i].rotation_degrees += ring_spin_speeds[i % ring_spin_speeds.size()] * delta
	match _state:
		Phase.PRESS:
			_press_label.modulate.a = 0.55 + 0.45 * cos(_time * 3.5)
		Phase.MENU:
			_handle_menu()

## 「Press Any Key」: キー・ボタン・クリックのどれでも
func _input(event : InputEvent) -> void:
	if _is_activity(event):
		_idle_time = 0.0 # 何か操作したら、放置の時間は数え直し
	if _state != Phase.PRESS:
		return
	var any : bool = (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventJoypadButton and event.pressed) \
		or (event is InputEventMouseButton and event.pressed)
	if not any:
		return
	get_viewport().set_input_as_handled()
	_show_menu()

# ---------------------------------------------------------------- メニュー

func _show_menu() -> void:
	_state = Phase.MENU
	SoundManager.play(confirm_sound)
	_menu.visible = true
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_press_label, "modulate:a", 0.0, 0.15)
	tween.tween_property(_menu, "modulate:a", 1.0, 0.25)
	_select(_index, false)
	# 押したキーを、そのままメニューの決定にしない: 全部のボタンを離すまで、メニューは受け付けない
	_menu.set_meta(&"ready", false)

func _hide_menu() -> void:
	_state = Phase.PRESS
	_menu.set_meta(&"ready", false)
	SoundManager.play(back_sound)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_menu, "modulate:a", 0.0, 0.15)
	tween.tween_property(_press_label, "modulate:a", 1.0, 0.15)
	await tween.finished
	if _state == Phase.PRESS:
		_menu.visible = false

func _handle_menu() -> void:
	if not _menu.get_meta(&"ready", false):
		if not _any_held():
			_menu.set_meta(&"ready", true)
		return
	if _pressed(["UI_Forward", "UI_StickUp", "ui_up"]):
		_select(_index - 1)
	elif _pressed(["UI_Back", "UI_StickDown", "ui_down"]):
		_select(_index + 1)
	elif _pressed(["UI_Shoot", "ui_accept"]):
		_decide()
	elif _pressed(["UI_Ignite", "ui_cancel"]):
		_hide_menu()

## 何かのボタン(メニューで使うもの)を押したままか
func _any_held() -> bool:
	for action in ["UI_Shoot", "ui_accept", "UI_Ignite", "ui_cancel", "UI_Forward", "UI_Back", "ui_up", "ui_down"]:
		if InputMap.has_action(action) and Input.is_action_pressed(action):
			return true
	return false

func _pressed(actions : Array) -> bool:
	for action in actions:
		if InputMap.has_action(action) and Input.is_action_just_pressed(action):
			return true
	return false

func _select(index : int, with_sound : bool = true) -> void:
	_index = wrapi(index, 0, _items.size())
	for i in _items.size():
		var color := normal_color
		if i == _index:
			color = selected_color
		elif i == Item.REPLAY:
			color = disabled_color
		_items[i].add_theme_color_override("font_color", color)
	# 赤い帯が、選んだ項目へ滑って、筆で引いたように左から伸びる
	var item := _items[_index]
	var target_y := item.position.y + 2.0
	var full_width := _menu.size.x
	if _bar_tween:
		_bar_tween.kill()
	_bar_tween = create_tween().set_parallel(true)
	_bar_tween.tween_property(_bar, "position:y", target_y, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_bar.size = Vector2(full_width * 0.4, item.size.y - 4.0)
	_bar.position.x = full_width * 0.3
	_bar_tween.tween_property(_bar, "size:x", full_width, 0.14).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_bar_tween.tween_property(_bar, "position:x", 0.0, 0.14).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	if with_sound:
		SoundManager.play(move_sound)

func _decide() -> void:
	match _index:
		Item.START:
			SoundManager.play(confirm_sound)
			_leave(func() -> void: SceneSwitcher.change(ship_select_scene))
		Item.OPTION:
			_open_panel(_option)
		Item.SCORE_BOARD:
			_open_panel(_score_board)
		Item.ACHIEVEMENTS:
			_open_panel(_achievements)
		Item.REPLAY:
			SoundManager.play(back_sound)
			_show_toast(replay_message)
		Item.EXIT:
			SoundManager.play(confirm_sound)
			_leave(func() -> void: get_tree().quit())

func _open_panel(panel : TitlePanel) -> void:
	_state = Phase.PANEL
	SoundManager.play(confirm_sound)
	create_tween().tween_property(_menu, "modulate:a", 0.25, 0.12)
	panel.open()

func _on_panel_closed() -> void:
	_state = Phase.MENU
	create_tween().tween_property(_menu, "modulate:a", 1.0, 0.12)

func _show_toast(text : String) -> void:
	_toast.text = text
	if _toast_tween:
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.2)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.4)

## 選んだ項目が点滅して、画面が暗くなってから after を呼ぶ
func _leave(after : Callable) -> void:
	_state = Phase.LEAVING
	var item := _items[_index]
	for i in 3:
		item.add_theme_color_override("font_color", bar_color)
		_bar.visible = false
		await get_tree().create_timer(0.06).timeout
		item.add_theme_color_override("font_color", selected_color)
		_bar.visible = true
		await get_tree().create_timer(0.06).timeout
	if music and music.playing:
		if music.finished.is_connected(music.play):
			music.finished.disconnect(music.play)
		create_tween().tween_property(music, "volume_db", -60.0, music_fade_time)
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, music_fade_time)
	await tween.finished
	after.call()

# ---------------------------------------------------------------- 放置の実績

## タイトル画面で、何も操作していない時間(秒)
var _idle_time : float = 0.0

func _tick_idle(delta : float) -> void:
	_idle_time += delta
	if _idle_time >= 600.0:
		Achievements.unlock("title_wait_10") # 10 分「ここで何を待っているの？」
	if _idle_time >= 1800.0:
		Achievements.unlock("title_wait_30") # 30 分「だから何を待っているの？」

## 操作したか(キー・ボタン・クリック・スティックを倒す・マウスを大きく動かす)
func _is_activity(event : InputEvent) -> bool:
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton:
		return event.is_pressed()
	if event is InputEventJoypadMotion:
		return absf((event as InputEventJoypadMotion).axis_value) > 0.5
	if event is InputEventMouseMotion:
		return (event as InputEventMouseMotion).relative.length() > 2.0
	return false
