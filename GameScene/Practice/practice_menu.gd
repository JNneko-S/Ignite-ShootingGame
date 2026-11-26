extends Control
## プラクティスの一覧(タイトルの START で ← → を押して PRACTICE にすると来る)。見た目はタイトルと同じ「紙・墨・朱」。
##   いちばん上の行 … 難易度を ← → で選ぶ(ANOTHER は解禁しているときだけ。2nd ○○ は、その難易度で二周目をクリアしたときだけ)
##   その下         … ミッションの一覧。← → でステージを切り替える。解禁していないミッションは「？？？」
##   決定           … 始める前の設定(残機・プラクティス+・機体)を開く
##   キャンセル     … タイトルへ
## ミッションの行: 種類のアイコン・名前・状態(new! / CLEAR / PLUS CLEAR 赤 / ASSIST 緑)
## 裏ボス Union は、4面の一覧の最後に特別な枠で出す。解禁していなければ、枠の真ん中に「？？？」と解禁条件を出す

const _Catalog := preload("res://Component/Practice/practice_catalog.gd")
const _Records := preload("res://Component/Practice/practice_records.gd")
const _Run := preload("res://Component/Practice/practice_run.gd")
const _Progress := preload("res://Component/Practice/practice_progress.gd")
const TITLE_SCENE := "res://title.tscn"
const SHIP_SELECT := "res://GameScene/Select/ship_select.tscn"
const FONT_EN := preload("res://Assets/Fonts/micronian.ttf")
const FONT_JA := preload("res://Assets/Fonts/ShitataruMinchoShogo-EB.otf")
const BACKGROUND := preload("res://Assets/1106_20261120122130.png")
const SND_MOVE := preload("res://Assets/Sounds/UI/AS_868154_しっくりくるゲーム操作音02_選択.mp3")
const SND_DECIDE := preload("res://Assets/Sounds/UI/AS_1213023_ゲームスタート（SFシューティング）10.mp3")
const SND_BACK := preload("res://Assets/Sounds/Rockon/AS_119891_コックピットなどの細かい電子音_10.mp3")
const MUSIC := preload("res://Assets/Sounds/Music/AS_839188_レース／シューティングゲーム_選択画面.mp3")

## タイトルと同じ色(紙・墨・朱)
const INK := Color(0.12, 0.09, 0.09)
const DIM := Color(0.55, 0.5, 0.5)
const ACCENT := Color(0.8, 0.14, 0.06)
const CLEAR_COLOR := Color(0.55, 0.42, 0.1)
const PLUS_COLOR := Color(0.85, 0.1, 0.06)
const ASSIST_COLOR := Color(0.1, 0.55, 0.2)
const NEW_COLOR := Color(0.95, 0.5, 0.0)

## 難易度の選択肢: [選んだ難易度, 周回, 名前]
const MODES : Array = [[0, 1, "EASY"], [1, 1, "NORMAL"], [2, 1, "HARD"], [3, 1, "ANOTHER"],
	[0, 2, "2nd EASY"], [1, 2, "2nd NORMAL"], [2, 2, "2nd HARD"], [3, 2, "2nd ANOTHER"]]
const ROW_HEIGHT := 22.0

var _modes : Array = [] # 出す選択肢(MODES の番号)
var _mode : int = 0 # _modes の中の番号
var _stage : int = 0
var _cursor : int = 0 # 0 = 難易度の行、1〜 = 一覧の行
var _entries : Array = [] # 一覧の行(ミッションの辞書。Union の枠は kind = "union_card")
var _rows : Array[Control] = []
var _list : VBoxContainer
var _scroll : ScrollContainer
var _mode_label : Label
var _stage_label : Label
var _count_label : Label
var _options : Control
var _opt_index : int = 0
var _opt_lives : int = 0
var _opt_plus : bool = false
var _opt_ship : int = 0
var _ships : Array = []
var _opt_labels : Array[Label] = []
var _opt_bar : ColorRect
var _snd_move : AudioStreamPlayer
var _snd_decide : AudioStreamPlayer
var _snd_back : AudioStreamPlayer
var _music : AudioStreamPlayer
var _union_open : bool = false
## 画面が開いてからの時間(開いた直前のボタンの押しっぱなしや、切り替えの途中の入力を受けない)
var _age : float = 0.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_ships = _load_ships()
	if RunConfig.ship:
		for i in _ships.size():
			if _ships[i] and _ships[i].resource_path == RunConfig.ship.resource_path:
				_opt_ship = i
	_union_open = _Progress.union_unlocked(_ships)
	for i in MODES.size():
		if _Progress.mode_visible(MODES[i][0], MODES[i][1]):
			_modes.append(i)
	# 前にいた所へ戻す(はじめては NORMAL)
	for k in _modes.size():
		var m : Array = MODES[_modes[k]]
		if _Run.last_key == "" and m[0] == 1 and m[1] == 1:
			_mode = k
		elif _Run.last_key != "" and m[0] == _Run.last_difficulty and m[1] == _Run.last_loop:
			_mode = k
	_stage = clampi(_Run.last_stage, 0, _Catalog.STAGES.size() - 1)
	_make_sounds()
	_build_ui()
	_refresh(_Run.last_key)

func _process(delta : float) -> void:
	_age += delta

# ---------------------------------------------------------------- 音

func _make_sounds() -> void:
	_snd_move = _player("MoveSound", SND_MOVE, -12.0, 1.0)
	_snd_decide = _player("ConfirmSound", SND_DECIDE, -12.0, 1.0)
	_snd_back = _player("BackSound", SND_BACK, -12.0, 0.6)
	var music : AudioStream = MUSIC.duplicate()
	if "loop" in music:
		music.set("loop", true)
	_music = _player("Music", music, -19.0, 1.0)
	_music.finished.connect(_music.play)
	_music.play()

func _player(node_name : String, stream : AudioStream, volume : float, pitch : float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.name = node_name # 名前に Music が入っていると、BGM の音量になる(GameSettings)
	p.stream = stream
	p.volume_db = volume
	p.pitch_scale = pitch
	add_child(p)
	return p

func _play(p : AudioStreamPlayer) -> void:
	SoundManager.play(p)

# ---------------------------------------------------------------- 画面

func _build_ui() -> void:
	var bg := TextureRect.new()
	bg.texture = BACKGROUND
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var paper := PaperFrame.new()
	paper.position = Vector2(6, 6)
	paper.size = Vector2(324, 436)
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(paper)
	var title := _label("PRACTICE", FONT_JA, 20, ACCENT)
	title.position = Vector2(6, 14)
	title.size = Vector2(324, 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	var line := ColorRect.new()
	line.color = ACCENT
	line.position = Vector2(168 - 70, 42)
	line.size = Vector2(140, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(line)
	_mode_label = _label("", FONT_JA, 12, INK)
	_mode_label.position = Vector2(18, 50)
	_mode_label.size = Vector2(300, 18)
	add_child(_mode_label)
	_stage_label = _label("", FONT_JA, 12, INK)
	_stage_label.position = Vector2(18, 70)
	add_child(_stage_label)
	_count_label = _label("", FONT_EN, 9, DIM)
	_count_label.position = Vector2(210, 73)
	add_child(_count_label)
	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(14, 92)
	_scroll.size = Vector2(308, 318)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(_scroll)
	_list = VBoxContainer.new()
	_list.custom_minimum_size = Vector2(304, 0)
	_list.add_theme_constant_override("separation", 1)
	_scroll.add_child(_list)
	if DebugTools.unlocked:
		var debug := _label("DEBUG  一時解禁中", FONT_JA, 9, ACCENT)
		debug.position = Vector2(244, 53)
		add_child(debug)
	var help := _label("↑↓ 選ぶ    ←→ 切り替え    決定 はじめる    キャンセル もどる", FONT_JA, 9, DIM)
	help.position = Vector2(6, 418)
	help.size = Vector2(324, 14)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(help)

func _label(text : String, font : Font, font_size : int, color : Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

## 難易度・ステージが変わった: 一覧を作り直す(focus_key のミッションにカーソルを合わせる)
func _refresh(focus_key : String = "") -> void:
	var mode : Array = MODES[_modes[_mode]]
	var groups := _Catalog.build(mode[0], mode[1])
	_stage = clampi(_stage, 0, groups.size() - 1)
	var missions : Array = groups[_stage]["missions"]
	_entries.clear()
	var union_list : Array = []
	for m in missions:
		if m["kind"] == "union":
			union_list.append(m)
		else:
			_entries.append(m)
	if not union_list.is_empty():
		# Union: 条件を満たしたら、全部まとめて解禁(新しい印が付く)
		if _union_open and not DebugTools.unlocked: # デバッグの一時的な解禁では、記録しない
			var keys : Array = []
			for m in union_list:
				if not _Records.is_unlocked(m["key"]):
					keys.append(m["key"])
			if not keys.is_empty():
				_Records.unlock_all(keys)
		_entries.append({"kind": "union_card", "key": "union_card"})
		if _union_open or _Records.saved_unlocked(union_list[0]["key"]):
			_entries.append_array(union_list)
	for row in _rows:
		row.queue_free()
	_rows.clear()
	var cleared := 0
	var total := 0
	for m in _entries:
		var row : Control = _make_union_card() if m["kind"] == "union_card" else _make_row(m)
		_list.add_child(row)
		_rows.append(row)
		if m["kind"] != "union_card":
			total += 1
			if _Records.clear_of(m["key"]) != _Records.CLEAR_NONE:
				cleared += 1
	_count_label.text = "CLEAR %d / %d" % [cleared, total]
	if focus_key != "":
		for i in _entries.size():
			if _entries[i]["key"] == focus_key:
				_cursor = i + 1
	_cursor = clampi(_cursor, 0, _entries.size())
	_update_cursor()

func _make_row(m : Dictionary) -> Control:
	var row := MissionRow.new()
	row.custom_minimum_size = Vector2(304, ROW_HEIGHT)
	row.dark = m["kind"] == "union"
	var icon := PracticeIcon.new()
	icon.kind = m["kind"]
	icon.position = Vector2(5, 4)
	icon.size = Vector2(14, 14)
	row.add_child(icon)
	var unlocked := _Records.is_unlocked(m["key"])
	var name := _label(m["title"] if unlocked else "？？？", FONT_JA, 10, INK if unlocked else DIM)
	name.position = Vector2(24, 3)
	name.size = Vector2(214, 16)
	name.clip_text = true
	row.add_child(name)
	row.name_label = name
	row.base_color = (Color(0.92, 0.85, 0.95) if row.dark else INK) if unlocked else DIM
	var state := _label("", FONT_EN, 8, INK)
	state.position = Vector2(240, 6)
	state.size = Vector2(62, 12)
	state.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(state)
	row.state_label = state
	_set_state(row, m["key"])
	return row

func _set_state(row : MissionRow, key : String) -> void:
	var state := row.state_label
	match _Records.clear_of(key):
		_Records.CLEAR_PLUS:
			state.text = "PLUS CLEAR"
			row.state_color = PLUS_COLOR
		_Records.CLEAR_NORMAL:
			state.text = "CLEAR"
			row.state_color = CLEAR_COLOR
		_Records.CLEAR_ASSIST:
			state.text = "ASSIST"
			row.state_color = ASSIST_COLOR
		_:
			state.text = "new!" if _Records.is_new(key) else ""
			row.state_color = NEW_COLOR

func _make_union_card() -> Control:
	var card := UnionCard.new()
	card.open = _union_open
	card.conditions = _Progress.union_conditions(_ships)
	card.font_en = FONT_EN
	card.font_ja = FONT_JA
	card.custom_minimum_size = Vector2(304, 66 if _union_open else 192)
	return card

func _update_cursor() -> void:
	var name : String = MODES[_modes[_mode]][2]
	_mode_label.text = "難易度    ←  %s  →" % name
	_mode_label.add_theme_color_override("font_color", ACCENT if _cursor == 0 else INK)
	_stage_label.text = "ステージ  ←  %s  →" % _Catalog.STAGES[_stage]["name"]
	_stage_label.add_theme_color_override("font_color", ACCENT if _cursor >= 1 else INK)
	for i in _rows.size():
		_rows[i].set("selected", i + 1 == _cursor)
	if _cursor >= 1 and _cursor - 1 < _entries.size():
		var key : String = _entries[_cursor - 1]["key"]
		if _Records.is_new(key):
			_Records.mark_seen(key) # 選んだら、new! は消える(次に一覧を開いたとき)
		_scroll.ensure_control_visible(_rows[_cursor - 1])

# ---------------------------------------------------------------- 操作

func _unhandled_input(event : InputEvent) -> void:
	if not event.is_pressed():
		return
	if event.is_echo() and not _is(event, ["ui_up", "ui_down", "UI_Forward", "UI_Back", "UI_StickUp", "UI_StickDown"]):
		return
	if _age < 0.3:
		return
	if _options:
		_options_input(event)
		return
	if _is(event, ["UI_Forward", "UI_StickUp", "ui_up"]):
		_cursor = wrapi(_cursor - 1, 0, _entries.size() + 1)
		_play(_snd_move)
		_update_cursor()
	elif _is(event, ["UI_Back", "UI_StickDown", "ui_down"]):
		_cursor = wrapi(_cursor + 1, 0, _entries.size() + 1)
		_play(_snd_move)
		_update_cursor()
	elif _is(event, ["UI_Left", "UI_StickLeft", "ui_left"]):
		_shift(-1)
	elif _is(event, ["UI_Right", "UI_StickRight", "ui_right"]):
		_shift(1)
	elif _is(event, ["UI_Shoot", "ui_accept"]):
		_decide()
	elif _is(event, ["UI_Ignite", "ui_cancel"]):
		_play(_snd_back)
		_leave()
	else:
		return
	get_viewport().set_input_as_handled()

func _is(event : InputEvent, actions : Array) -> bool:
	for a in actions:
		if InputMap.has_action(a) and event.is_action(a):
			return true
	return false

## ← →: 難易度の行なら難易度、一覧の行ならステージを変える
func _shift(dir : int) -> void:
	if _cursor == 0:
		if _modes.size() <= 1:
			return
		_mode = wrapi(_mode + dir, 0, _modes.size())
	else:
		_stage = wrapi(_stage + dir, 0, _Catalog.STAGES.size())
		_cursor = 1
	_play(_snd_move)
	_refresh()

func _decide() -> void:
	if _cursor < 1:
		return
	var m : Dictionary = _entries[_cursor - 1]
	if m["kind"] == "union_card" or not _Records.is_unlocked(m["key"]):
		_play(_snd_back) # 選べない(Union の枠・まだ解禁していないミッション)
		var row := _rows[_cursor - 1]
		var shake := row.create_tween()
		for x in [4.0, -4.0, 2.0, 0.0]:
			shake.tween_property(row, "position:x", x, 0.04)
		return
	_play(_snd_decide)
	_open_options()

## タイトルへ(曲を小さくしてから)
func _leave() -> void:
	set_process_unhandled_input(false)
	var fade := create_tween()
	fade.tween_property(_music, "volume_db", -60.0, 0.4)
	await fade.finished
	SceneSwitcher.change(TITLE_SCENE)

# ---------------------------------------------------------------- 始める前の設定

func _open_options() -> void:
	_options = PaperFrame.new()
	_options.position = Vector2(20, 112)
	_options.size = Vector2(296, 212)
	add_child(_options)
	var m : Dictionary = _entries[_cursor - 1]
	var head := _label(m["title"], FONT_JA, 12, ACCENT)
	head.position = Vector2(18, 16)
	head.size = Vector2(260, 18)
	head.clip_text = true
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_options.add_child(head)
	var line := ColorRect.new()
	line.color = ACCENT
	line.position = Vector2(148 - 60, 38)
	line.size = Vector2(120, 1)
	_options.add_child(line)
	_opt_bar = ColorRect.new()
	_opt_bar.color = ACCENT
	_options.add_child(_opt_bar)
	_opt_labels.clear()
	for i in 5:
		var l := _label("", FONT_JA, 12, INK)
		l.position = Vector2(24, 50 + i * 28)
		l.size = Vector2(248, 20)
		_options.add_child(l)
		_opt_labels.append(l)
	_opt_index = 3
	_opt_lives = 0
	_opt_plus = false
	_update_options()

func _update_options() -> void:
	var ship_name : String = "（今の機体）"
	if not _ships.is_empty() and _ships[_opt_ship]:
		ship_name = _ships[_opt_ship].ship_name
	var texts := [
		"残機    ←  %d  →%s" % [_opt_lives, "    アシスト" if _opt_lives > 0 else ""],
		"プラクティス＋    ←  %s  →%s" % ["ON" if _opt_plus else "OFF", "    イグナイトなし" if _opt_plus else ""],
		"機体    ←  %s  →" % ship_name,
		"はじめる",
		"もどる",
	]
	for i in _opt_labels.size():
		_opt_labels[i].text = texts[i]
		var color := INK
		if i == 0 and _opt_lives > 0:
			color = ASSIST_COLOR
		elif i == 1 and _opt_plus:
			color = PLUS_COLOR
		_opt_labels[i].add_theme_color_override("font_color", Color.WHITE if i == _opt_index else color)
	_opt_bar.position = Vector2(14, 48 + _opt_index * 28)
	_opt_bar.size = Vector2(268, 22)

func _options_input(event : InputEvent) -> void:
	if _is(event, ["UI_Forward", "UI_StickUp", "ui_up"]):
		_opt_index = wrapi(_opt_index - 1, 0, 5)
		_play(_snd_move)
	elif _is(event, ["UI_Back", "UI_StickDown", "ui_down"]):
		_opt_index = wrapi(_opt_index + 1, 0, 5)
		_play(_snd_move)
	elif _is(event, ["UI_Left", "UI_StickLeft", "ui_left", "UI_Right", "UI_StickRight", "ui_right"]):
		var dir := -1 if _is(event, ["UI_Left", "UI_StickLeft", "ui_left"]) else 1
		match _opt_index:
			0: _opt_lives = clampi(_opt_lives + dir, 0, 9)
			1: _opt_plus = not _opt_plus
			2:
				if not _ships.is_empty():
					_opt_ship = wrapi(_opt_ship + dir, 0, _ships.size())
		_play(_snd_move)
	elif _is(event, ["UI_Shoot", "ui_accept"]):
		if _opt_index == 3:
			_play(_snd_decide)
			_start()
			return
		if _opt_index == 4:
			_play(_snd_back)
			_close_options()
		elif _opt_index == 1:
			_opt_plus = not _opt_plus
			_play(_snd_move)
	elif _is(event, ["UI_Ignite", "ui_cancel"]):
		_play(_snd_back)
		_close_options()
	else:
		return
	if _options:
		_update_options()
	get_viewport().set_input_as_handled()

func _close_options() -> void:
	if _options:
		_options.queue_free()
		_options = null

func _start() -> void:
	var m : Dictionary = _entries[_cursor - 1]
	_Run.last_stage = _stage
	_Run.last_difficulty = MODES[_modes[_mode]][0]
	_Run.last_loop = MODES[_modes[_mode]][1]
	var ship : ShipData = _ships[_opt_ship] if not _ships.is_empty() else null
	set_process_unhandled_input(false)
	create_tween().tween_property(_music, "volume_db", -60.0, 0.5)
	_Run.begin(get_tree(), m, _opt_lives, _opt_plus, ship)

## 機体の選択画面にある機体の一覧(ShipData)
func _load_ships() -> Array:
	var packed := load(SHIP_SELECT) as PackedScene
	var state := packed.get_state() if packed else null
	while state:
		for n in state.get_node_count():
			for p in state.get_node_property_count(n):
				if state.get_node_property_name(n, p) == &"ships":
					return Array(state.get_node_property_value(n, p))
		state = state.get_base_scene_state()
	return []


## タイトルの板と同じ、紙の板(朱の縁と、四隅の印)
class PaperFrame extends Control:
	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		draw_rect(rect, Color(1.0, 0.99, 0.97, 0.95))
		var accent := Color(0.8, 0.14, 0.06)
		draw_rect(rect, accent, false, 1.0)
		draw_rect(rect.grow(-3.0), Color(accent, 0.35), false, 1.0)
		var corner := 10.0
		for point in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
			var sx := 1.0 if point.x < rect.get_center().x else -1.0
			var sy := 1.0 if point.y < rect.get_center().y else -1.0
			draw_line(point, point + Vector2(corner * sx, 0.0), accent, 3.0)
			draw_line(point, point + Vector2(0.0, corner * sy), accent, 3.0)


## 一覧の1行(選んでいるときは、タイトルと同じ朱の帯を敷いて、文字を白にする)
class MissionRow extends Control:
	var name_label : Label
	var state_label : Label
	var base_color : Color = Color(0.12, 0.09, 0.09)
	var state_color : Color = Color(0.12, 0.09, 0.09)
	## Union のミッションの行(黒っぽい特別な行)
	var dark : bool = false
	var selected : bool = false:
		set(value):
			selected = value
			_apply()

	func _ready() -> void:
		_apply()

	func _apply() -> void:
		if name_label:
			name_label.add_theme_color_override("font_color", Color.WHITE if selected else base_color)
		if state_label:
			state_label.add_theme_color_override("font_color", Color.WHITE if selected else state_color)
		queue_redraw()

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		if dark:
			draw_rect(rect, Color(0.06, 0.0, 0.08, 0.92))
			draw_rect(rect, Color(0.62, 0.12, 0.6, 0.8), false, 1.0)
		if selected:
			draw_rect(rect, Color(0.8, 0.14, 0.06) if not dark else Color(0.55, 0.05, 0.4))
		elif not dark:
			draw_line(Vector2(4, size.y - 0.5), Vector2(size.x - 4, size.y - 0.5), Color(0.8, 0.14, 0.06, 0.15), 1.0)


## 裏ボス Union の特別な枠: 黒い板に紫の二重の縁と朱の四隅、黒い玉の紋章。
## 解禁していなければ、真ん中に「？？？」と、解禁条件(● 達成 / ○ まだ)を出す
class UnionCard extends Control:
	var open : bool = false
	var conditions : Array = []
	var font_en : Font
	var font_ja : Font
	var selected : bool = false:
		set(value):
			selected = value
			queue_redraw()
	var _t : float = 0.0

	func _process(delta : float) -> void:
		_t += delta
		if selected:
			queue_redraw()

	func _draw() -> void:
		var rect := Rect2(Vector2(1, 1), size - Vector2(2, 2))
		var purple := Color(0.62, 0.12, 0.6)
		var glow := 0.55 + 0.45 * sin(_t * 4.0) if selected else 0.5
		draw_rect(rect, Color(0.03, 0.0, 0.05, 0.97))
		draw_rect(rect, Color(purple, 0.5 + 0.5 * glow), false, 2.0)
		draw_rect(rect.grow(-4.0), Color(purple, 0.35), false, 1.0)
		var accent := Color(0.85, 0.1, 0.08)
		for point in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
			var sx := 1.0 if point.x < rect.get_center().x else -1.0
			var sy := 1.0 if point.y < rect.get_center().y else -1.0
			draw_line(point, point + Vector2(12.0 * sx, 0.0), accent, 3.0)
			draw_line(point, point + Vector2(0.0, 12.0 * sy), accent, 3.0)
		# 黒い玉の紋章
		var c := Vector2(30, 33)
		draw_circle(c, 17.0, Color(purple, 0.25 + 0.2 * glow))
		draw_circle(c, 13.0, Color(0.0, 0.0, 0.0))
		draw_arc(c, 13.0, 0.0, TAU, 32, Color(0.85, 0.1, 0.25, 0.9), 1.5)
		draw_circle(c + Vector2(-4, -4), 2.5, Color(0.8, 0.3, 0.7))
		if font_en:
			draw_string(font_en, Vector2(56, 30), "UNION", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.95, 0.25, 0.4))
		if font_ja == null:
			return
		draw_string(font_ja, Vector2(58, 50), "裏ボス  - 融合体 -", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.85, 0.75, 0.9))
		if open:
			draw_string(font_ja, Vector2(size.x - 70, 30), "解禁", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.85, 0.4))
			return
		# まだ: 真ん中に「？？？」と、解禁条件
		draw_string(font_ja, Vector2(0, 88), "？？？", HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, Color(0.95, 0.9, 1.0, 0.6 + 0.4 * glow))
		draw_string(font_ja, Vector2(14, 106), "解禁条件", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.95, 0.25, 0.4))
		var y := 120.0
		for cond in conditions:
			var hidden : bool = cond.get("hidden", false)
			var text : String = "？？？" if hidden else cond["text"]
			var done : bool = cond["done"] and not hidden
			var col := Color(1.0, 0.85, 0.4) if done else Color(0.8, 0.75, 0.85)
			draw_string(font_ja, Vector2(14, y), ("● " if done else "○ ") + text, HORIZONTAL_ALIGNMENT_LEFT, size.x - 20, 9, col)
			y += 12.0
			for sub in cond.get("sub", []):
				var sub_col := Color(1.0, 0.85, 0.4) if sub["done"] else Color(0.7, 0.65, 0.75)
				draw_string(font_ja, Vector2(26, y), ("● " if sub["done"] else "○ ") + sub["text"], HORIZONTAL_ALIGNMENT_LEFT, size.x - 32, 9, sub_col)
				y += 12.0


## 一覧の行の、種類のアイコン(道中 = 編隊の点 / 中ボス = ひし形 / ボス = 王冠 / 大技 = 星 / Union = 黒い玉)
class PracticeIcon extends Control:
	var kind : String = "zako"

	func _draw() -> void:
		var c := size * 0.5
		match kind:
			"zako":
				for p in [Vector2(-4, 3), Vector2(0, -3), Vector2(4, 3)]:
					draw_circle(c + p, 2.0, Color(0.15, 0.35, 0.6))
			"midboss":
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -6), c + Vector2(6, 0), c + Vector2(0, 6), c + Vector2(-6, 0)]), Color(0.85, 0.45, 0.05))
			"boss":
				draw_colored_polygon(PackedVector2Array([c + Vector2(-6, 4), c + Vector2(-6, -4), c + Vector2(-3, 0), c + Vector2(0, -6),
					c + Vector2(3, 0), c + Vector2(6, -4), c + Vector2(6, 4)]), Color(0.8, 0.14, 0.06))
			"spell":
				var pts := PackedVector2Array()
				for i in 10:
					var r := 6.5 if i % 2 == 0 else 2.8
					pts.append(c + Vector2.from_angle(-PI / 2 + TAU * i / 10.0) * r)
				draw_colored_polygon(pts, Color(0.85, 0.6, 0.0))
			"union":
				draw_circle(c, 6.5, Color(0.62, 0.12, 0.6))
				draw_circle(c, 5.0, Color(0.02, 0.0, 0.04))
				draw_circle(c + Vector2(-1.5, -1.5), 1.2, Color(0.8, 0.3, 0.7))
