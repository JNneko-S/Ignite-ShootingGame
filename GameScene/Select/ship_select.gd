extends Node
class_name ShipSelect
## 出撃機体の選択画面。シーン(GameScene/Select/ship_select.tscn)で使う。
## 閉まったシャッターの上に、電光掲示板・機体のプレビュー・選択の輪・説明の欄が並ぶ。
##
## 流れ:
##   1. 機体を選ぶ: 左右で機体を変え、ショットで決める。掲示板は「SELECT YOUR FIGHTER」が流れる
##   2. 難易度を選ぶ: 掲示板に「< NORMAL >」が出て、左右で難易度を変える。説明の欄は難易度の説明になる。
##      戻るボタンで、機体の選択に戻る
##   3. 出撃: 掲示板に LAUNCH! が点滅して、画面が消え、ステージを読み込んでからシャッターが開く
## 選んだ内容は RunConfig に入り、ステージの GameManager が読む。
##
## 操作: 左右 = UI_Left / UI_Right(と矢印キー) / 決める = UI_Shoot(と Enter) / 戻る = UI_Ignite(と Esc)

## 選べる機体(並べた順に出る)
@export var ships : Array[ShipData] = []
## 出撃するステージのシーン
@export_file("*.tscn") var stage_scene : String = "res://stage1.tscn"

@export_group("掲示板の文字")
@export var title_text : String = "SELECT YOUR FIGHTER"
@export var launch_text : String = "LAUNCH!"

@export_group("難易度(EASY, NORMAL, HARD の順)")
@export var difficulty_names : Array[String] = ["EASY", "NORMAL", "HARD"]
## 説明の欄の、見出しの下に出る短い説明
@export var difficulty_subtitles : Array[String] = ["はじめての人向け", "標準の難しさ", "上級者向け"]
## 説明の欄に出す説明
@export var difficulty_texts : Array[String] = [
	"イグナイトゲージが通常より多く、グレイズできる範囲も広い。\nまた、いくらかゲージ回復が早くなっているぞ。\nシューティングのルーキーなら、ここからスタートしよう。",
	"グレイズでゲージを溜め、イグナイトで焼き払う。\nこのゲームのちょうどいい難易度に設定されている。\n訓練された君に向けての挑戦状だ。",
	"通常より少ないゲージで出撃し、グレイズできる範囲が狭い。\nまた、ゲージの貯めやすさもいくらか難しくなっている。\n帰りの切符はどこにあるのだろう？",
]
## 掲示板の文字の色
@export var difficulty_colors : Array[Color] = [Color(0.35, 1.0, 0.4), Color(1.0, 0.62, 0.12), Color(1.0, 0.22, 0.15)]
## 最初に選んである難易度(前に選んだことがあれば、そちらを使う)
@export_range(0, 2) var default_difficulty : int = 1

@export_group("デバッグ(今だけ): ブラックスワン戦")
## 難易度で HARD を選んだ状態で、右をこの回数押すと、BLACKSWAN が選べる(赤黒の画面になる)。0 なら出ない
@export var debug_secret_presses : int = 10
## BLACKSWAN を選んで出撃したときのステージ(難易度は HARD 固定)
@export_file("*.tscn") var debug_blackswan_stage : String = "res://blackswan_test.tscn"
@export var debug_subtitle : String = "デバッグ用"
@export_multiline var debug_text : String = "ブラックスワン戦をプレイできる。難易度はHARD固定。\n戦え！黒い胡鳥と赤い不死鳥！"

@export_group("音")
## 選ぶものを変えたとき・決めたとき・戻ったとき(シーンに置いた AudioStreamPlayer)
@export var move_sound : AudioStreamPlayer
@export var confirm_sound : AudioStreamPlayer
@export var back_sound : AudioStreamPlayer
## 選択画面の曲(ループする)と、出撃するときに消えていく時間(秒)
@export var music : AudioStreamPlayer
@export var music_fade_time : float = 1.0
## バチンと火花が散ったとき
@export var spark_sound : AudioStreamPlayer

enum Step { BOOT, SHIP, DIFFICULTY, LAUNCH }
## 難易度の番号のうち、デバッグ用のブラックスワン戦
const BLACKSWAN : int = 3
const RED_LINE := Color(1.0, 0.13, 0.1)
const RED_FILL := Color(0.02, 0.0, 0.0, 0.94)

@onready var _shutter : ShutterTransition = $Shutter
@onready var _ui_root : Control = $UI/Root
@onready var _board : LedBoard = $UI/Root/TitleBoard
@onready var _preview : Sprite2D = $UI/Root/PreviewFrame/PreviewPanel/PreviewShip
@onready var _selector : SelectorRing = $UI/Root/Selector
@onready var _icon : Sprite2D = $UI/Root/Selector/Icon
@onready var _ship_name : Label = $UI/Root/ShipName
@onready var _ship_index : Label = $UI/Root/ShipIndex
@onready var _desc_title : Label = $UI/Root/DescPanel/DescTitle
@onready var _desc_sub : Label = $UI/Root/DescPanel/DescSub
@onready var _desc_text : Label = $UI/Root/DescPanel/DescText
@onready var _hint : Label = $UI/Root/DescPanel/Hint

var _step : Step = Step.BOOT
var _ship_index_value : int = 0
var _difficulty : int = 1
var _board_color : Color
var _time : float = 0.0
var _preview_base : Vector2
var _icon_base : Vector2
## HARD で右を押した回数(デバッグ用)
var _secret_presses : int = 0
## 赤黒にする前の色
var _theme_saved : Dictionary = {}

func _ready() -> void:
	_board_color = _board.lit_color
	_preview_base = _preview.position
	_icon_base = _icon.position
	_difficulty = default_difficulty
	if RunConfig.has_selection:
		_difficulty = RunConfig.difficulty
		var index := ships.find(RunConfig.ship)
		_ship_index_value = maxi(index, 0)
	if ships.is_empty():
		push_warning("ShipSelect: Ships に機体がありません")
	_show_ship(false)
	_start_music()
	_boot()

## 選択画面の曲を流す。終わったら、また頭から流す(ループ)
func _start_music() -> void:
	if music == null or music.stream == null:
		return
	if not music.finished.is_connected(music.play):
		music.finished.connect(music.play)
	music.play()

## 曲を消していって止める(出撃するとき)
func _stop_music() -> void:
	if music == null or not music.playing:
		return
	if music.finished.is_connected(music.play):
		music.finished.disconnect(music.play)
	var tween := create_tween()
	tween.tween_property(music, "volume_db", -60.0, music_fade_time)
	tween.tween_callback(music.stop)

## 画面が点く: ちらついてから点き、掲示板の文字が流れ始める
func _boot() -> void:
	_ui_root.modulate.a = 0.0
	await get_tree().create_timer(0.25).timeout
	for alpha in [0.6, 0.1, 0.9, 0.3, 1.0]:
		_ui_root.modulate.a = alpha
		await get_tree().create_timer(0.05).timeout
	_board.set_text(title_text, false)
	_step = Step.SHIP

func _process(delta : float) -> void:
	_time += delta
	# 機体がふわふわ浮く
	_preview.position = _preview_base + Vector2(0.0, sin(_time * 2.0) * 3.0)
	_icon.position = _icon_base + Vector2(0.0, sin(_time * 2.4 + 1.0) * 1.5)
	match _step:
		Step.SHIP:
			if _pressed(["UI_Left", "ui_left"]):
				_change_ship(-1)
			elif _pressed(["UI_Right", "ui_right"]):
				_change_ship(1)
			elif _pressed(["UI_Shoot", "ui_accept"]):
				_to_difficulty()
		Step.DIFFICULTY:
			if _pressed(["UI_Left", "ui_left"]):
				_change_difficulty(-1)
			elif _pressed(["UI_Right", "ui_right"]):
				_change_difficulty(1)
			elif _pressed(["UI_Shoot", "ui_accept"]):
				_launch()
			elif _pressed(["UI_Ignite", "ui_cancel"]):
				_to_ship()

func _pressed(actions : Array) -> bool:
	for action in actions:
		if InputMap.has_action(action) and Input.is_action_just_pressed(action):
			return true
	return false

# ---------------------------------------------------------------- 機体

func _change_ship(direction : int) -> void:
	_selector.pulse(direction)
	SoundManager.play(move_sound)
	if ships.size() <= 1:
		_shake_icon(direction) # 1機しかないときは、少しゆれるだけ
		return
	_ship_index_value = wrapi(_ship_index_value + direction, 0, ships.size())
	_show_ship(true, direction)

func _show_ship(animate : bool, direction : int = 1) -> void:
	_desc_title.text = "FIGHTER"
	_hint.text = "L/R: SELECT   SHOT: OK"
	if ships.is_empty():
		return
	var ship := ships[_ship_index_value]
	for sprite in [_preview, _icon]:
		sprite.texture = ship.texture
		sprite.hframes = maxi(ship.hframes, 1)
		sprite.frame = ship.frame
	_preview.scale = Vector2.ONE * ship.preview_scale
	_icon.scale = Vector2.ONE * ship.icon_scale
	_ship_name.text = ship.ship_name
	_ship_index.text = "%d / %d" % [_ship_index_value + 1, ships.size()]
	_desc_title.text = ship.ship_name
	_desc_sub.text = ship.subtitle
	_desc_text.text = ship.description
	if animate:
		# 新しい機体が、押した向きから滑り込んでくる
		_icon.position.x = _icon_base.x + direction * 30.0
		_icon.modulate.a = 0.0
		var tween := create_tween().set_parallel(true)
		tween.tween_property(_icon, "position:x", _icon_base.x, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(_icon, "modulate:a", 1.0, 0.15)
		_flash(_preview)

func _shake_icon(direction : int) -> void:
	var tween := create_tween()
	tween.tween_property(_icon, "position:x", _icon_base.x + direction * 5.0, 0.05)
	tween.tween_property(_icon, "position:x", _icon_base.x, 0.08)

## 一瞬白く光る(切り替わった感じ)
func _flash(node : CanvasItem) -> void:
	node.modulate = Color(2.5, 2.5, 2.5)
	create_tween().tween_property(node, "modulate", Color.WHITE, 0.2)

# ---------------------------------------------------------------- 難易度

func _to_difficulty() -> void:
	if ships.is_empty():
		return
	_step = Step.DIFFICULTY
	SoundManager.play(confirm_sound)
	_selector.active = false
	_flash(_icon)
	_ship_index.text = "READY"
	_show_difficulty()

func _change_difficulty(direction : int) -> void:
	_selector.pulse(direction)
	if _difficulty == BLACKSWAN:
		if direction < 0:
			# HARD に戻ると、色も元に戻る
			_difficulty = difficulty_names.size() - 1
			_secret_presses = 0
			SoundManager.play(move_sound)
			_set_red_theme(false)
			_show_difficulty()
		else:
			SoundManager.play(back_sound)
		return
	var last := difficulty_names.size() - 1
	if direction > 0 and _difficulty == last and debug_secret_presses > 0:
		# デバッグ用: HARD で右を何回も押すと、ブラックスワン戦が出てくる
		_secret_presses += 1
		if _secret_presses >= debug_secret_presses:
			_unlock_blackswan()
			return
		SoundManager.play(back_sound, 1.0 + 0.05 * _secret_presses)
		return
	if direction < 0:
		_secret_presses = 0
	var next := clampi(_difficulty + direction, 0, last)
	if next == _difficulty:
		SoundManager.play(back_sound) # 端より先はない
		return
	_difficulty = next
	SoundManager.play(move_sound)
	_show_difficulty()

func _show_difficulty() -> void:
	_hint.text = "L/R: SELECT   SHOT: LAUNCH   E: BACK"
	if _difficulty == BLACKSWAN:
		_board.set_text("< BLACKSWAN >", false)
		_desc_title.text = "BLACKSWAN"
		_desc_sub.text = debug_subtitle
		_desc_text.text = debug_text
		return
	var d := clampi(_difficulty, 0, difficulty_names.size() - 1)
	_board.lit_color = difficulty_colors[d] if d < difficulty_colors.size() else _board_color
	_board.set_text("< %s >" % difficulty_names[d])
	_desc_title.text = difficulty_names[d]
	_desc_sub.text = difficulty_subtitles[d] if d < difficulty_subtitles.size() else ""
	_desc_text.text = difficulty_texts[d] if d < difficulty_texts.size() else ""

# ---------------------------------------------------------------- デバッグ: ブラックスワン戦

## バチンと火花が散って、画面が赤と黒になり、BLACKSWAN が選べるようになる
func _unlock_blackswan() -> void:
	_difficulty = BLACKSWAN
	_secret_presses = 0
	SoundManager.play(spark_sound)
	# 白く光る
	var flash := ColorRect.new()
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = Color(1.0, 0.95, 0.9, 0.85)
	flash.size = get_viewport().get_visible_rect().size
	_ui_root.add_child(flash)
	var fade := flash.create_tween()
	fade.tween_property(flash, "color:a", 0.0, 0.3)
	fade.tween_callback(flash.queue_free)
	# 火花: 掲示板と、選択の輪から
	var board_center := _board.position + _board.size * 0.5
	var ring_center := _selector.position + _selector.size * 0.5
	SparkBurst.spawn(_ui_root, board_center, 26, Color(1.0, 0.85, 0.5))
	SparkBurst.spawn(_ui_root, ring_center, 20, Color(1.0, 0.6, 0.3))
	for i in 4:
		SparkBurst.spawn(_ui_root, board_center + Vector2(randf_range(-140, 140), randf_range(-8, 8)), 8, Color(1.0, 0.4, 0.2))
	_glitch()
	_shake(_ui_root, 6.0)
	_set_red_theme(true)
	_show_difficulty()
	_board.flicker_off(3)
	await get_tree().create_timer(0.3).timeout
	_board.show_now()
	_board._on = true

## 画面全体の色を、赤と黒にする(off で元の色に戻す)
func _set_red_theme(on : bool) -> void:
	if _theme_saved.is_empty():
		_save_theme()
	for panel in _ui_root.find_children("*", "TechPanel", true, false):
		panel.line_color = RED_LINE if on else _theme_saved[panel]["line"]
		panel.fill_color = RED_FILL if on else _theme_saved[panel]["fill"]
		panel.queue_redraw()
	_selector.ring_color = RED_LINE if on else _theme_saved[_selector]["ring"]
	_selector.arrow_color = RED_LINE if on else _theme_saved[_selector]["arrow"]
	_selector.locked_color = RED_LINE if on else _theme_saved[_selector]["locked"]
	_selector.fill_color = RED_FILL if on else _theme_saved[_selector]["fill"]
	_board.lit_color = RED_LINE if on else _board_color
	_board.dim_color = Color(0.16, 0.02, 0.02) if on else _theme_saved[_board]["dim"]
	for label in [_ship_name, _ship_index, _desc_title, _desc_sub, _hint]:
		label.modulate = Color(1.0, 0.45, 0.42) if on else Color.WHITE
	for shutter in [$Shutter/ShutterTop, $Shutter/ShutterBottom]:
		var material := shutter.material as ShaderMaterial
		material.set_shader_parameter("metal_color", Color(0.16, 0.12, 0.12) if on else _theme_saved[shutter]["metal"])
		material.set_shader_parameter("stripe_color", Color(0.85, 0.08, 0.06) if on else _theme_saved[shutter]["stripe"])

func _save_theme() -> void:
	for panel in _ui_root.find_children("*", "TechPanel", true, false):
		_theme_saved[panel] = {"line": panel.line_color, "fill": panel.fill_color}
	_theme_saved[_selector] = {"ring": _selector.ring_color, "arrow": _selector.arrow_color,
		"locked": _selector.locked_color, "fill": _selector.fill_color}
	_theme_saved[_board] = {"dim": _board.dim_color}
	for shutter in [$Shutter/ShutterTop, $Shutter/ShutterBottom]:
		var material := shutter.material as ShaderMaterial
		_theme_saved[shutter] = {"metal": material.get_shader_parameter("metal_color"),
			"stripe": material.get_shader_parameter("stripe_color")}

## 映像が一瞬大きく乱れる
func _glitch() -> void:
	var fx := get_node_or_null("Shutter/FxLayer/ScreenFx") as ColorRect
	if fx == null:
		return
	var material := fx.material as ShaderMaterial
	var tween := create_tween().set_parallel(true)
	tween.tween_method(func(v : float) -> void: material.set_shader_parameter("tear_chance", v), 0.6, 0.04, 0.4)
	tween.tween_method(func(v : float) -> void: material.set_shader_parameter("strength", v), 1.0, 0.4, 0.4)

func _shake(node : Control, power : float) -> void:
	var tween := create_tween()
	for i in 6:
		var p := power * (1.0 - i / 6.0)
		tween.tween_property(node, "position", Vector2(randf_range(-p, p), randf_range(-p, p)), 0.03)
	tween.tween_property(node, "position", Vector2.ZERO, 0.04)

func _to_ship() -> void:
	_step = Step.SHIP
	SoundManager.play(back_sound)
	_selector.active = true
	if _difficulty == BLACKSWAN:
		_difficulty = difficulty_names.size() - 1 # 機体の選択に戻ったら、ブラックスワン戦は HARD に戻す
		_set_red_theme(false)
	_secret_presses = 0
	_board.lit_color = _board_color
	_board.set_text(title_text)
	_show_ship(false)

# ---------------------------------------------------------------- 出撃

func _launch() -> void:
	_step = Step.LAUNCH
	SoundManager.play(confirm_sound, 1.2)
	RunConfig.has_selection = true
	_stop_music()
	var blackswan := _difficulty == BLACKSWAN
	RunConfig.difficulty = 2 if blackswan else _difficulty # ブラックスワン戦は HARD 固定
	RunConfig.ship = ships[_ship_index_value] if not ships.is_empty() else null
	await _board.set_text(launch_text, false)
	await _board.blink(3, 0.1, 0.16)
	# 画面が、ちらついて消える
	for alpha in [0.2, 0.8, 0.1, 0.5, 0.0]:
		_ui_root.modulate.a = alpha
		await get_tree().create_timer(0.04).timeout
	await get_tree().create_timer(0.2).timeout
	_shutter.change_scene_and_open(debug_blackswan_stage if blackswan else stage_scene)
