extends CanvasLayer
class_name PauseMenu
## ポーズ画面。シーン(GameScene/UI/pause_menu.tscn)を GameManager が出す(Pause Scene)。
##
## Pause Action(Esc)でゲームが止まり、画面が暗く・灰色になって、電光掲示板の PAUSE と、メニューが出る。
##   RESUME     : 続ける(Pause Action でも戻れる)
##   RETRY      : シャッターが閉まって、ステージを最初からやり直す
##   SHIP SELECT: シャッターが閉まって、機体選択の画面へ戻る(選んでいた機体・難易度のまま)
## 上下で選び、ショットで決める。
## ゲームオーバーの画面が出ているあいだと、自機がいないときは開かない。

## ポーズの切り替え(Input Map のアクション名。UI_Pause は Esc とゲームパッドの START)。
@export var pause_action : StringName = &"UI_Pause"
## 機体選択の画面のシーン
@export_file("*.tscn") var ship_select_scene : String = "res://GameScene/Select/ship_select.tscn"
## 閉まるシャッター(shutter.tscn)
@export var shutter_scene : PackedScene = preload("res://GameScene/UI/shutter.tscn")
## 選ぶものを変えたとき・決めたとき・開いたとき(シーンに置いた AudioStreamPlayer)
@export var move_sound : AudioStreamPlayer
@export var confirm_sound : AudioStreamPlayer
@export var open_sound : AudioStreamPlayer
## 選んでいる項目の色と、選んでいない項目の色
@export var selected_color : Color = Color(0.85, 0.97, 1.0)
@export var normal_color : Color = Color(0.35, 0.55, 0.65)

@export_group("隠しコマンド(デバッグ)")
## ポーズ中に Shift + F1 + Space を同時に押してから、この秒数のうちにこの文字を打つと、デバッグ機能が使えるようになる
## (ゲーム中に F1 でデバッグパネルが開く)
@export var debug_code : String = "debug"
@export var debug_code_time : float = 2.0

enum Item { RESUME, RETRY, SHIP_SELECT }

@onready var _root : Control = $Root
@onready var _board : LedBoard = $Root/Board
@onready var _panel : TechPanel = $Root/Panel
@onready var _items : Array[Label] = [$Root/Panel/Resume, $Root/Panel/Retry, $Root/Panel/ShipSelect]
@onready var _cursor : Control = $Root/Panel/Cursor
@onready var _fx : ColorRect = $Root/ScreenFx

## 自機(いないときは開かない)。GameManager が入れる
var player : Node
var _open : bool = false
## 隠しコマンド: 文字の入力を待つ残り時間(秒)、今まで打った文字、同時押しが続いているか
var _code_left : float = 0.0
var _typed : String = ""
var _chord_held : bool = false
## メニューで決めたあと(シャッターが閉まるあいだ)は、何も受け付けない
var _busy : bool = false
var _index : int = 0
var _time : float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

func _process(delta : float) -> void:
	_time += delta
	if _busy:
		return
	if not _open:
		if _pressed([pause_action]) and _can_open():
			_open_menu()
		return
	_check_debug_chord(delta)
	if _code_left > 0.0 or Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_F1):
		return # 隠しコマンドの入力中は、メニューを動かさない(Shift + Space で決定しないように)
	if _pressed([pause_action]):
		_close_menu()
	elif _pressed(["UI_Forward", "UI_StickUp", "ui_up"]):
		_select(_index - 1)
	elif _pressed(["UI_Back", "UI_StickDown", "ui_down"]):
		_select(_index + 1)
	elif _pressed(["UI_Shoot", "ui_accept"]):
		_decide()
	# 選んでいる項目の印が、ゆっくり左右に動く
	_cursor.position.x = 18.0 + sin(_time * 6.0) * 2.0

# ---------------------------------------------------------------- 隠しコマンド(デバッグの解放)

## Shift + F1 + Space を同時に押した瞬間から、Debug Code Time 秒のあいだ、文字の入力を待つ
func _check_debug_chord(delta : float) -> void:
	var chord := Input.is_key_pressed(KEY_SHIFT) and Input.is_key_pressed(KEY_F1) and Input.is_key_pressed(KEY_SPACE)
	if chord and not _chord_held:
		_code_left = debug_code_time
		_typed = ""
	_chord_held = chord
	if _code_left > 0.0 and not chord:
		_code_left -= delta
		if _code_left <= 0.0:
			_typed = ""

func _input(event : InputEvent) -> void:
	if not _open or _code_left <= 0.0:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var letter := OS.get_keycode_string(key.keycode).to_lower()
	if letter.length() != 1:
		return # Shift や F1 などは数えない
	_typed = (_typed + letter).right(debug_code.length())
	get_viewport().set_input_as_handled()
	if _typed == debug_code:
		_code_left = 0.0
		_unlock_debug()

## デバッグ機能を使えるようにした: 掲示板が切り替わって知らせる
func _unlock_debug() -> void:
	DebugTools.unlocked = true
	SoundManager.play(confirm_sound, 1.5)
	var color := _board.lit_color
	_board.lit_color = Color(0.35, 1.0, 0.4)
	_board.set_text("DEBUG ON")
	await get_tree().create_timer(1.4).timeout
	if is_instance_valid(_board):
		_board.lit_color = color
		_board.set_text("PAUSE")

func _pressed(actions : Array) -> bool:
	for action in actions:
		if InputMap.has_action(action) and Input.is_action_just_pressed(action):
			return true
	return false

## 開いてよいか(ゲームオーバーなどで、ほかが止めているときは開かない)
func _can_open() -> bool:
	if IntroTutorial.active:
		return false # 出撃のチュートリアル中は、ポーズのボタンでチュートリアルを飛ばす
	return not get_tree().paused and is_instance_valid(player) and player.is_inside_tree()

func _open_menu() -> void:
	_open = true
	get_tree().paused = true
	visible = true
	SoundManager.play(open_sound)
	_select(0, false)
	# 画面が乱れてから、暗く・灰色になる
	var material := _fx.material as ShaderMaterial
	material.set_shader_parameter("tear_chance", 0.5)
	var tween := create_tween().set_parallel(true)
	tween.tween_method(func(v : float) -> void: material.set_shader_parameter("strength", v), 0.0, 1.0, 0.15)
	tween.tween_method(func(v : float) -> void: material.set_shader_parameter("tear_chance", v), 0.5, 0.02, 0.3)
	_panel.scale = Vector2(1.0, 0.0)
	tween.tween_property(_panel, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_board.run_marquee(90.0)

func _close_menu() -> void:
	_open = false
	visible = false
	SoundManager.play(move_sound, 0.7)
	get_tree().paused = false

func _select(index : int, with_sound : bool = true) -> void:
	_index = wrapi(index, 0, _items.size())
	for i in _items.size():
		_items[i].modulate = selected_color if i == _index else normal_color
	_cursor.position.y = _items[_index].position.y + _items[_index].size.y * 0.5 - _cursor.size.y * 0.5
	if with_sound:
		SoundManager.play(move_sound)

func _decide() -> void:
	match _index:
		Item.RESUME:
			_close_menu()
		Item.RETRY:
			StageIntro.skip_next = true # やり直しは、出撃の演出を飛ばす
			_leave(get_tree().current_scene.scene_file_path, true)
		Item.SHIP_SELECT:
			_leave(ship_select_scene, false)

## シャッターが閉まってから、ステージを出る。
## reopen がオンなら、読み込んだ先でシャッターが開く(やり直し)。オフなら、閉まったまま切り替える
## (機体選択の画面は、閉まったシャッターが背景なので、そのままつながる)
func _leave(path : String, reopen : bool) -> void:
	if path == "":
		return
	_busy = true
	SoundManager.play(confirm_sound)
	# 選んだ項目が点滅して、メニューが消える
	for i in 3:
		_items[_index].modulate = Color.WHITE
		await get_tree().create_timer(0.06).timeout
		_items[_index].modulate = normal_color
		await get_tree().create_timer(0.06).timeout
	_root.visible = false
	var shutter := shutter_scene.instantiate() as ShutterTransition
	add_child(shutter)
	shutter.layout_open()
	await shutter.close()
	await get_tree().create_timer(0.15).timeout
	if reopen:
		shutter.change_scene_and_open(path)
	else:
		get_tree().paused = false
		SceneSwitcher.change(path)
