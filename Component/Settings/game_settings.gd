extends Node
## オプションの設定(自動読み込み: GameSettings)。user://settings.cfg に保存して、起動時に読み込む。
## タイトル画面の OPTION(OptionPanel)が値を変える。
##
##   BGM / SE Vol : 音量(0〜10)。BGM バスと SFX バスの音量になる(バスがなければ、起動時に作る)。
##                  1 目盛りで VOLUME_STEP_DB ずつ下がる(0 で消音)
##   Graphic      : ウインドウの大きさ。ゲーム画面(336x448)の整数倍で、モニタに収まるものだけ。ウインドウ表示のときだけ効く
##   Mode         : WINDOW / FULLSCREEN / BORDERLESS
##   VSync        : 垂直同期のオン・オフ
##   Shake        : 画面の揺れの強さ(0〜100%)。StageCamera.shake などが shake_scale() を掛ける
##   Flash        : 画面のフラッシュの明るさ(0〜100%。光過敏対策)。ScreenFlash が flash_scale() を掛ける
##   Hitbox       : 自機の当たり判定の表示(低速移動中だけ / いつも / 出さない)
##   Slow Mode    : 敵弾が増えたら、わざとゲームを遅くする(処理落ち)。オンのあいだのプレイは、スコアが保存されない
##   Key Config   : ショット・イグナイト・低速移動・ポーズ・上下左右のキー(とゲームパッドのボタン)
##
## 音の振り分け: シーンに入った AudioStreamPlayer のバスが Master なら、
## 曲(StageBGM / MusicClock / 名前に Music か BGM が入っている / "bgm" グループ)は BGM バスへ、それ以外は SFX バスへ移す。

const PATH : String = "user://settings.cfg"
const BGM_BUS : StringName = &"BGM"
const SFX_BUS : StringName = &"SFX"
const VOLUME_STEPS : int = 10

## 音量の 1 目盛りで下げる量(dB)。10 で 0dB、1 で -32.4dB。
## (振幅をそのまま割合にすると、8 でも -2dB ほどで、変わったのが分からない)
const VOLUME_STEP_DB : float = 3.6
## Graphic の選択肢: ゲーム画面の何倍の大きさのウインドウにするか(1 〜 この数。モニタに収まらないものは出さない)
const MAX_WINDOW_SCALE : int = 6
const DEFAULT_WINDOW_SCALE : int = 2
const MODE_NAMES : Array[String] = ["WINDOW", "FULLSCREEN", "BORDERLESS"]
enum Mode { WINDOW, FULLSCREEN, BORDERLESS }
## 画面の揺れ・フラッシュの強さの目盛り(%)
const EFFECT_STEPS : Array[int] = [0, 25, 50, 75, 100]
const HITBOX_NAMES : Array[String] = ["FOCUS", "ALWAYS", "OFF"]
## 当たり判定の表示: 低速移動中だけ / いつも / 出さない
enum Hitbox { FOCUS, ALWAYS, OFF }

## キーコンフィグで変えられる操作(アクション名, 表示名)
const BINDABLE : Array = [
	[&"UI_Shoot", "SHOT"],
	[&"UI_Ignite", "IGNITE"],
	[&"UI_Focus", "SLOW MOVE"],
	[&"UI_Pause", "PAUSE"],
	[&"UI_Forward", "UP"],
	[&"UI_Back", "DOWN"],
	[&"UI_Left", "LEFT"],
	[&"UI_Right", "RIGHT"],
]

# ---- Slow Mode(処理落ち)
## 画面の敵弾がこの数を超えると、遅くなり始める
const SLOW_START_BULLETS : int = 120
## この数で、いちばん遅くなる
const SLOW_FULL_BULLETS : int = 360
## いちばん遅いときの速さ(1.0 = ふつう)
const SLOW_MIN_SCALE : float = 0.6

signal changed

var bgm_volume : int = 8
var se_volume : int = 8
## ウインドウの大きさ(ゲーム画面の何倍か)
var window_scale : int = DEFAULT_WINDOW_SCALE
var mode : int = Mode.WINDOW
var vsync : bool = true
## 画面の揺れ・フラッシュの強さ(%。EFFECT_STEPS のどれか)
var shake_percent : int = 100
var flash_percent : int = 100
var hitbox_mode : int = Hitbox.FOCUS
var slow_mode : bool = false
## アクション名 → {"key": physical_keycode(0 ならなし), "pad": ボタンの番号(-1 ならなし)}
var bindings : Dictionary = {}

## Input Map の最初の状態(RESET で戻す)
var _default_bindings : Dictionary = {}
## 処理落ちで、最後に入れたゲームの速さ(ほかの部品が速さを変えたら、手を出さない)
var _applied_scale : float = 1.0

func _enter_tree() -> void:
	# SoundManager が SFX バスを探す前にバスを作る(自動読み込みの順で、SoundManager より前に置く)
	_ensure_bus(BGM_BUS)
	_ensure_bus(SFX_BUS)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for entry in BINDABLE:
		_default_bindings[entry[0]] = _read_binding(entry[0])
	bindings = _default_bindings.duplicate(true)
	load_settings()
	apply_all()
	get_tree().node_added.connect(_on_node_added)

# ---------------------------------------------------------------- 保存・読み込み

func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return
	bgm_volume = clampi(config.get_value("audio", "bgm", bgm_volume), 0, VOLUME_STEPS)
	se_volume = clampi(config.get_value("audio", "se", se_volume), 0, VOLUME_STEPS)
	if config.has_section_key("video", "window_scale"):
		window_scale = int(config.get_value("video", "window_scale", window_scale))
	elif config.has_section_key("video", "resolution"):
		# 前の版の保存値(高さ 1080/900/720/600/480 の番号)を、いちばん近い倍率に直す
		var old_heights : Array[int] = [1080, 900, 720, 600, 480]
		var old_index := clampi(int(config.get_value("video", "resolution", 1)), 0, old_heights.size() - 1)
		window_scale = roundi(old_heights[old_index] / base_size().y)
	window_scale = clampi(window_scale, 1, max_window_scale())
	mode = clampi(config.get_value("video", "mode", mode), 0, MODE_NAMES.size() - 1)
	vsync = config.get_value("video", "vsync", vsync)
	shake_percent = _nearest_step(int(config.get_value("game", "shake", shake_percent)))
	flash_percent = _nearest_step(int(config.get_value("game", "flash", flash_percent)))
	hitbox_mode = clampi(config.get_value("game", "hitbox", hitbox_mode), 0, HITBOX_NAMES.size() - 1)
	slow_mode = config.get_value("game", "slow_mode", slow_mode)
	for entry in BINDABLE:
		var action : StringName = entry[0]
		var saved = config.get_value("keys", String(action), null)
		if saved is Dictionary:
			bindings[action] = {"key": int(saved.get("key", 0)), "pad": int(saved.get("pad", -1))}

func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "bgm", bgm_volume)
	config.set_value("audio", "se", se_volume)
	config.set_value("video", "window_scale", window_scale)
	config.set_value("video", "mode", mode)
	config.set_value("video", "vsync", vsync)
	config.set_value("game", "shake", shake_percent)
	config.set_value("game", "flash", flash_percent)
	config.set_value("game", "hitbox", hitbox_mode)
	config.set_value("game", "slow_mode", slow_mode)
	for action in bindings:
		config.set_value("keys", String(action), bindings[action])
	config.save(PATH)

## 全部を最初の値に戻す(保存はしない)
func reset_to_defaults() -> void:
	bgm_volume = 8
	se_volume = 8
	window_scale = clampi(DEFAULT_WINDOW_SCALE, 1, max_window_scale())
	mode = Mode.WINDOW
	vsync = true
	shake_percent = 100
	flash_percent = 100
	hitbox_mode = Hitbox.FOCUS
	slow_mode = false
	bindings = _default_bindings.duplicate(true)
	apply_all()

func apply_all() -> void:
	apply_audio()
	apply_video()
	apply_bindings()
	changed.emit()

# ---------------------------------------------------------------- 音

func apply_audio() -> void:
	_set_bus_volume(BGM_BUS, bgm_volume)
	_set_bus_volume(SFX_BUS, se_volume)

func _set_bus_volume(bus : StringName, steps : int) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		return
	AudioServer.set_bus_mute(index, steps <= 0)
	AudioServer.set_bus_volume_db(index, -VOLUME_STEP_DB * (VOLUME_STEPS - clampi(steps, 0, VOLUME_STEPS)))

func _ensure_bus(bus : StringName) -> void:
	if AudioServer.get_bus_index(bus) >= 0:
		return
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus)
	AudioServer.set_bus_send(index, &"Master")

func _on_node_added(node : Node) -> void:
	if not (node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D):
		return
	if node.bus != &"Master":
		return
	node.bus = BGM_BUS if _is_music(node) else SFX_BUS

func _is_music(node : Node) -> bool:
	if node is StageBGM or node is MusicClock or node.is_in_group(&"bgm"):
		return true
	var lower := String(node.name).to_lower()
	return lower.contains("music") or lower.contains("bgm")

# ---------------------------------------------------------------- 画面

## ゲーム画面の大きさ(project.godot の viewport の幅・高さ)
func base_size() -> Vector2:
	return Vector2(ProjectSettings.get_setting("display/window/size/viewport_width", 336),
		ProjectSettings.get_setting("display/window/size/viewport_height", 448))

## 今のモニタに収まる、いちばん大きい倍率(ウインドウの枠の分、少し余裕をみる)
func max_window_scale() -> int:
	if DisplayServer.get_name() == "headless":
		return MAX_WINDOW_SCALE
	var usable := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	if usable.size.x <= 0 or usable.size.y <= 0:
		return MAX_WINDOW_SCALE
	var base := base_size()
	var fit := mini(floori(usable.size.x / base.x), floori((usable.size.y - 32) / base.y))
	return clampi(fit, 1, MAX_WINDOW_SCALE)

func window_size(scale : int = window_scale) -> Vector2i:
	return Vector2i(base_size() * maxi(scale, 1))

func resolution_name(scale : int = window_scale) -> String:
	var size := window_size(scale)
	return "%dx%d" % [size.x, size.y]

## 揺れの強さの倍率(0〜1)。画面を揺らす部品は、揺れの大きさにこれを掛ける
func shake_scale() -> float:
	return shake_percent / 100.0

## フラッシュの明るさの倍率(0〜1)。ScreenFlash が掛ける
func flash_scale() -> float:
	return flash_percent / 100.0

## いちばん近い EFFECT_STEPS の値
func _nearest_step(value : int) -> int:
	var best : int = EFFECT_STEPS[EFFECT_STEPS.size() - 1]
	for step in EFFECT_STEPS:
		if absi(step - value) < absi(best - value):
			best = step
	return best

## EFFECT_STEPS の中で、value から direction 目盛り動かした値(端で止まる)
func step_effect(value : int, direction : int) -> int:
	var index := clampi(EFFECT_STEPS.find(_nearest_step(value)) + direction, 0, EFFECT_STEPS.size() - 1)
	return EFFECT_STEPS[index]

func apply_video() -> void:
	# エディタの中に埋め込んで動かしているときは、ウインドウを触らない
	if Engine.has_method("is_embedded_in_editor") and Engine.call("is_embedded_in_editor"):
		return
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	# テストで起動したとき(godot ... -- --keep-window)は、保存した表示モードを使わず、ウインドウのまま
	if OS.get_cmdline_user_args().has("--keep-window"):
		return
	match mode:
		Mode.FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		Mode.BORDERLESS:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		_:
			if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			window_scale = clampi(window_scale, 1, max_window_scale()) # モニタが変わって、収まらなくなったとき
			var size := window_size()
			var screen := DisplayServer.window_get_current_screen()
			var usable := DisplayServer.screen_get_usable_rect(screen)
			DisplayServer.window_set_size(size)
			# 画面の真ん中に置く(はみ出すときは、上の端に合わせる)
			var pos := usable.position + (usable.size - size) / 2
			pos.y = maxi(pos.y, usable.position.y)
			DisplayServer.window_set_position(pos)

# ---------------------------------------------------------------- キー

## アクションの、今のキー(とボタン)を読む
func _read_binding(action : StringName) -> Dictionary:
	var result := {"key": 0, "pad": -1}
	if not InputMap.has_action(action):
		return result
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and result["key"] == 0:
			var key := event as InputEventKey
			result["key"] = key.physical_keycode if key.physical_keycode != 0 else key.keycode
		elif event is InputEventJoypadButton and result["pad"] == -1:
			result["pad"] = (event as InputEventJoypadButton).button_index
	return result

## bindings の内容を Input Map に入れる(最初のキーと、最初のボタンを置き換える。スティックなどはそのまま)
func apply_bindings() -> void:
	for action in bindings:
		if not InputMap.has_action(action):
			continue
		var binding : Dictionary = bindings[action]
		var key_done := false
		var pad_done := false
		for event in InputMap.action_get_events(action):
			if event is InputEventKey and not key_done:
				InputMap.action_erase_event(action, event)
				key_done = true
			elif event is InputEventJoypadButton and not pad_done:
				InputMap.action_erase_event(action, event)
				pad_done = true
		if binding["key"] != 0:
			var key := InputEventKey.new()
			key.physical_keycode = binding["key"]
			InputMap.action_add_event(action, key)
		if binding["pad"] >= 0:
			var button := InputEventJoypadButton.new()
			button.button_index = binding["pad"]
			InputMap.action_add_event(action, button)

## action のキーを keycode にする。ほかの操作が同じキーなら、入れ替える
func bind_key(action : StringName, keycode : int) -> void:
	_bind(action, "key", keycode)

## action のゲームパッドのボタンを button にする。ほかの操作が同じボタンなら、入れ替える
func bind_pad(action : StringName, button : int) -> void:
	_bind(action, "pad", button)

func _bind(action : StringName, kind : String, value) -> void:
	var old = bindings[action][kind]
	for other in bindings:
		if other != action and bindings[other][kind] == value:
			bindings[other][kind] = old
	bindings[action][kind] = value
	apply_bindings()
	changed.emit()

func key_name(action : StringName) -> String:
	var code : int = bindings.get(action, {}).get("key", 0)
	if code == 0:
		return "---"
	return OS.get_keycode_string(code).to_upper()

func pad_name(action : StringName) -> String:
	var button : int = bindings.get(action, {}).get("pad", -1)
	if button < 0:
		return "---"
	return "BTN %d" % button

# ---------------------------------------------------------------- 処理落ち

func _physics_process(_delta : float) -> void:
	if not slow_mode:
		if _applied_scale != 1.0 and is_equal_approx(Engine.time_scale, _applied_scale):
			Engine.time_scale = 1.0
		_applied_scale = 1.0
		return
	if HitStop.is_active() or get_tree().paused:
		return
	# ほかの部品(デバッグのスローなど)が速さを変えていたら、手を出さない
	if not is_equal_approx(Engine.time_scale, _applied_scale):
		return
	var bullets := get_tree().get_node_count_in_group(&"enemy_bullet")
	var t := clampf(float(bullets - SLOW_START_BULLETS) / float(SLOW_FULL_BULLETS - SLOW_START_BULLETS), 0.0, 1.0)
	var target := lerpf(1.0, SLOW_MIN_SCALE, t)
	_applied_scale = snappedf(lerpf(_applied_scale, target, 0.1), 0.01)
	Engine.time_scale = _applied_scale
	if get_tree().get_first_node_in_group(&"score_system") != null:
		ScoreBoard.slow_used = true # 処理落ちありで遊んだプレイは、スコアを保存しない
