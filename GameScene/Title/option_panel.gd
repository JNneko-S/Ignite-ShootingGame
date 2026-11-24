extends TitlePanel
class_name OptionPanel
## タイトル画面の OPTION。値は GameSettings に入れて、すぐに反映する。
##   BGM / SE VOL : 左右で音量(0〜10)
##   GRAPHIC      : 左右でウインドウの大きさ(1080p〜480p)
##   MODE         : 左右で WINDOW / FULLSCREEN / BORDERLESS
##   SLOW MODE    : 左右でオン・オフ(オンだとスコアとリプレイが保存されない)
##   KEY CONFIG   : 決定で、キーの割り当ての画面へ
##   RESET        : 決定で、全部を初期状態に戻す
##   QUIT         : 決定で、設定を保存してオプションを閉じる(戻るボタンでも同じ)
## キーの割り当ての画面: 決定してから、割り当てたいキーかボタンを押す(Capture Time 秒で取り消し)。

## キーの入力を待つ時間(秒)
@export var capture_time : float = 5.0

enum Row { BGM, SE, GRAPHIC, MODE, SLOW, KEY_CONFIG, RESET, QUIT }
const ROW_NAMES : Array[String] = ["BGM", "SE VOL", "GRAPHIC", "MODE", "SLOW MODE", "KEY CONFIG", "RESET", "QUIT"]
const ROW_HELP : Array[String] = [
	"BGM の音量を調整します。",
	"効果音の音量を調整します。",
	"ウインドウの大きさ(画質)を変更します。\nウインドウ表示のときだけ有効です。",
	"表示モードを切り替えます。\nWINDOW / FULLSCREEN / BORDERLESS",
	"敵弾が増えたときに、意図的に処理落ちさせます。\n有効にすると、スコアやリプレイが保存されません。",
	"ショット・イグナイト・低速移動・ポーズ・\n方向移動の割り当てを変更します。",
	"すべての設定を初期状態に戻します。",
	"設定を保存して、オプションを終了します。",
]
const KEY_HELP : String = "決定を押してから、割り当てたいキーか\nボタンを押してください。(%d秒で取り消し)\n同じキーを使っていた操作とは、入れ替わります。"

const ROW_TOP : float = 64.0
const ROW_STEP : float = 24.0
const NAME_X : float = 34.0
const VALUE_X : float = 150.0
const PAD_X : float = 238.0

var _row : int = 0
var _names : Array[Label] = []
var _values : Array[Label] = []
var _bar : ColorRect
var _help : Label
var _hint : Label
## キーの割り当ての画面
var _keys_page : Control
var _key_names : Array[Label] = []
var _key_values : Array[Label] = []
var _pad_values : Array[Label] = []
var _key_bar : ColorRect
var _key_row : int = 0
var _in_keys : bool = false
## キーの入力を待っている残り時間(秒)。0 なら待っていない
var _capture_left : float = 0.0
var _main_page : Control

func _build() -> void:
	var heading_bottom := make_heading("OPTION", 22.0)
	_main_page = _page()
	_bar = _page_bar(_main_page)
	for i in ROW_NAMES.size():
		var y := heading_bottom + 8.0 + i * ROW_STEP
		_names.append(_page_label(_main_page, ROW_NAMES[i], 14, Vector2(NAME_X, y)))
		_values.append(_page_label(_main_page, "", 14, Vector2(VALUE_X, y), size.x - VALUE_X - 32.0, HORIZONTAL_ALIGNMENT_CENTER))
	_keys_page = _page()
	_key_bar = _page_bar(_keys_page)
	_page_label(_keys_page, "KEY", 11, Vector2(VALUE_X, heading_bottom - 4.0), 80.0, HORIZONTAL_ALIGNMENT_CENTER).add_theme_color_override("font_color", dim_color)
	_page_label(_keys_page, "PAD", 11, Vector2(PAD_X, heading_bottom - 4.0), 70.0, HORIZONTAL_ALIGNMENT_CENTER).add_theme_color_override("font_color", dim_color)
	var key_rows := GameSettings.BINDABLE.size() + 2
	for i in key_rows:
		var y := heading_bottom + 12.0 + i * 21.0
		var title : String = "DEFAULT" if i == key_rows - 2 else ("BACK" if i == key_rows - 1 else GameSettings.BINDABLE[i][1])
		_key_names.append(_page_label(_keys_page, title, 13, Vector2(NAME_X, y)))
		_key_values.append(_page_label(_keys_page, "", 13, Vector2(VALUE_X, y), 80.0, HORIZONTAL_ALIGNMENT_CENTER))
		_pad_values.append(_page_label(_keys_page, "", 13, Vector2(PAD_X, y), 70.0, HORIZONTAL_ALIGNMENT_CENTER))
	# 説明の欄と、操作の案内
	var line := ColorRect.new()
	line.color = Color(accent_color, 0.5)
	line.position = Vector2(28.0, size.y - 112.0)
	line.size = Vector2(size.x - 56.0, 1.0)
	add_child(line)
	_help = make_label("", 11, ink_color, Vector2(28.0, size.y - 104.0), size.x - 56.0)
	_help.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_hint = make_label("↑↓ 選択   ←→ 変更   SHOT 決定   IGNITE 戻る", 10, dim_color, Vector2(margin, size.y - margin - 22.0),
		size.x - margin * 2.0, HORIZONTAL_ALIGNMENT_CENTER)

func _page() -> Control:
	var page := Control.new()
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.size = size
	add_child(page)
	return page

func _page_bar(page : Control) -> ColorRect:
	var bar := ColorRect.new()
	bar.color = accent_color
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(bar)
	return bar

func _page_label(page : Control, text : String, font_size : int, at : Vector2, width : float = 0.0,
		align : HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := make_label(text, font_size, ink_color, at, width, align)
	label.reparent(page, false)
	return label

func _on_open() -> void:
	_in_keys = false
	_capture_left = 0.0
	_row = 0
	_show_page()

func _show_page() -> void:
	_main_page.visible = not _in_keys
	_keys_page.visible = _in_keys
	_refresh()

# ---------------------------------------------------------------- 入力

func _handle_input() -> void:
	if _capture_left > 0.0:
		_capture_left -= get_process_delta_time()
		if _capture_left <= 0.0:
			_capture_left = 0.0
			SoundManager.play(back_sound)
		_refresh()
		return
	if _in_keys:
		_handle_keys_input()
		return
	if pressed_up():
		_select(_row - 1)
	elif pressed_down():
		_select(_row + 1)
	elif pressed_left():
		_change(-1)
	elif pressed_right():
		_change(1)
	elif pressed_ok():
		_decide()
	elif pressed_back():
		_quit()

func _select(row : int) -> void:
	_row = wrapi(row, 0, ROW_NAMES.size())
	SoundManager.play(move_sound)
	_refresh()

## 左右で値を変える
func _change(direction : int) -> void:
	match _row:
		Row.BGM:
			GameSettings.bgm_volume = clampi(GameSettings.bgm_volume + direction, 0, GameSettings.VOLUME_STEPS)
			GameSettings.apply_audio()
		Row.SE:
			GameSettings.se_volume = clampi(GameSettings.se_volume + direction, 0, GameSettings.VOLUME_STEPS)
			GameSettings.apply_audio()
		Row.GRAPHIC:
			# 一覧は大きい順なので、右で小さく・左で大きくならないよう、向きを逆にする
			GameSettings.resolution_index = wrapi(GameSettings.resolution_index - direction, 0, GameSettings.RESOLUTIONS.size())
			GameSettings.apply_video()
		Row.MODE:
			GameSettings.mode = wrapi(GameSettings.mode + direction, 0, GameSettings.MODE_NAMES.size())
			GameSettings.apply_video()
		Row.SLOW:
			GameSettings.slow_mode = not GameSettings.slow_mode
		_:
			return
	SoundManager.play(move_sound) # SE の音量を変えたときは、新しい音量で鳴る
	_refresh()

func _decide() -> void:
	match _row:
		Row.KEY_CONFIG:
			SoundManager.play(confirm_sound)
			_in_keys = true
			_key_row = 0
			_show_page()
		Row.RESET:
			SoundManager.play(confirm_sound)
			GameSettings.reset_to_defaults()
			_refresh()
			_help.text = "すべての設定を、初期状態に戻しました。"
		Row.QUIT:
			_quit()
		Row.SLOW:
			_change(1)
		_:
			pass

## 設定を保存して閉じる
func _quit() -> void:
	GameSettings.save_settings()
	close()

# ---------------------------------------------------------------- キーの割り当て

func _handle_keys_input() -> void:
	var rows := _key_names.size()
	if pressed_up():
		_key_row = wrapi(_key_row - 1, 0, rows)
		SoundManager.play(move_sound)
		_refresh()
	elif pressed_down():
		_key_row = wrapi(_key_row + 1, 0, rows)
		SoundManager.play(move_sound)
		_refresh()
	elif pressed_ok():
		SoundManager.play(confirm_sound)
		if _key_row == rows - 1:
			_leave_keys()
		elif _key_row == rows - 2:
			GameSettings.bindings = GameSettings._default_bindings.duplicate(true)
			GameSettings.apply_bindings()
			_refresh()
		else:
			_capture_left = capture_time
			_opened_frame = Engine.get_process_frames() # 決定に使ったキーを、割り当てに使わない
			_refresh()
	elif pressed_back():
		SoundManager.play(back_sound)
		_leave_keys()

func _leave_keys() -> void:
	_in_keys = false
	_show_page()

## キーの入力を待っているときに、押したキーかボタンを割り当てる
func _input(event : InputEvent) -> void:
	if not is_open or _capture_left <= 0.0 or Engine.get_process_frames() == _opened_frame:
		return
	var action : StringName = GameSettings.BINDABLE[_key_row][0]
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		var code := key.physical_keycode if key.physical_keycode != 0 else key.keycode
		GameSettings.bind_key(action, code)
	elif event is InputEventJoypadButton and event.pressed:
		GameSettings.bind_pad(action, (event as InputEventJoypadButton).button_index)
	else:
		return
	get_viewport().set_input_as_handled()
	_capture_left = 0.0
	# 押したキーが、そのまま決定や戻るにならないよう、次のフレームまで待つ
	_opened_frame = Engine.get_process_frames() + 1
	SoundManager.play(confirm_sound)
	_refresh()

# ---------------------------------------------------------------- 表示

func _refresh() -> void:
	if _in_keys:
		_refresh_keys()
		return
	_values[Row.BGM].text = _volume_text(GameSettings.bgm_volume)
	_values[Row.SE].text = _volume_text(GameSettings.se_volume)
	_values[Row.GRAPHIC].text = "<  %s  >" % GameSettings.resolution_name()
	_values[Row.MODE].text = "<  %s  >" % GameSettings.MODE_NAMES[GameSettings.mode]
	_values[Row.SLOW].text = "<  %s  >" % ("ON" if GameSettings.slow_mode else "OFF")
	for i in _names.size():
		var selected := i == _row
		var color := Color.WHITE if selected else ink_color
		if i == Row.GRAPHIC and GameSettings.mode != GameSettings.Mode.WINDOW and not selected:
			color = dim_color # 全画面のときは効かない
		set_color(_names[i], color)
		set_color(_values[i], color)
	_place_bar(_bar, _names[_row])
	_help.text = ROW_HELP[_row]

func _refresh_keys() -> void:
	var rows := _key_names.size()
	for i in rows:
		var selected := i == _key_row
		var color := Color.WHITE if selected else ink_color
		set_color(_key_names[i], color)
		set_color(_key_values[i], color)
		set_color(_pad_values[i], color)
		if i < GameSettings.BINDABLE.size():
			var action : StringName = GameSettings.BINDABLE[i][0]
			var waiting := selected and _capture_left > 0.0
			_key_values[i].text = ("PRESS..." if fmod(_time, 0.5) < 0.3 else "") if waiting else GameSettings.key_name(action)
			_pad_values[i].text = "" if waiting else GameSettings.pad_name(action)
	_place_bar(_key_bar, _key_names[_key_row])
	if _key_row == rows - 2:
		_help.text = "キーの割り当てを、初期状態に戻します。"
	elif _key_row == rows - 1:
		_help.text = "オプションに戻ります。"
	else:
		_help.text = KEY_HELP % int(capture_time)

func _place_bar(bar : ColorRect, label : Label) -> void:
	bar.position = Vector2(margin + 10.0, label.position.y + 1.0)
	bar.size = Vector2(size.x - (margin + 10.0) * 2.0, label.get_minimum_size().y - 2.0)

func _volume_text(value : int) -> String:
	return "%s %2d" % ["■".repeat(value) + "□".repeat(GameSettings.VOLUME_STEPS - value), value]
