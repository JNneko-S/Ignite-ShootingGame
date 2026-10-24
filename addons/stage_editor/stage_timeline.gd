@tool
extends VBoxContainer
## 下部パネル「ステージ」の中身。StagePreview のステージを、タイムラインで表示・編集する。
##
## 操作:
##   上の目盛り(ルーラー)をクリック・ドラッグ … プレビューの時刻を動かす
##   行をクリック                         … そのイベントをインスペクタで開く
##   行のバーを左右にドラッグ               … イベントの時刻を変える(0.1秒刻み。Shift を押すと刻まない)
##   行をダブルクリック                     … プレビューの時刻を、そのイベントの時刻にする
##   ホイール / Shift+ホイール / Ctrl+ホイール … 縦スクロール / 横スクロール / 拡大縮小
##   Space / Delete / Ctrl+D              … 再生・停止 / 削除 / 複製
##
## 変更は元に戻せる(Ctrl+Z)。StageData(.tres)への保存は「保存」ボタンか、試遊のときに行う。

## プラグインから渡される
var undo_redo : EditorUndoRedoManager

const LABEL_WIDTH : float = 260.0
const RULER_HEIGHT : float = 22.0
const ROW_HEIGHT : float = 20.0
const SNAP : float = 0.1
## タイムラインの右端に足す余白(秒)
const TAIL_SECONDS : float = 10.0
const TICK_STEPS : Array[float] = [0.5, 1.0, 2.0, 5.0, 10.0, 15.0, 30.0, 60.0]

enum Drag { NONE, CURSOR, EVENT }
enum AddKind { SPAWN, SCROLL, WAIT, SIGNAL }

var _preview : StagePreview
var _selected : StageEvent
var _dirty : bool = false

var _px_per_sec : float = 40.0
var _scroll_time : float = 0.0
var _scroll_row : int = 0

var _drag : Drag = Drag.NONE
var _drag_event : StageEvent
var _drag_origin_time : float = 0.0
var _drag_start_x : float = 0.0

var _title : Label
var _play_button : Button
var _time_spin : SpinBox
var _add_menu : MenuButton
var _duplicate_button : Button
var _delete_button : Button
var _save_button : Button
var _playtest_button : Button
var _zoom_slider : HSlider
var _canvas : Control
var _hscroll : HScrollBar
var _vscroll : VScrollBar

func _init() -> void:
	name = "StageTimeline"
	custom_minimum_size = Vector2(0.0, 200.0) * _scale()
	_build_ui()

func _build_ui() -> void:
	var bar := HBoxContainer.new()
	add_child(bar)

	_title = Label.new()
	_title.custom_minimum_size.x = 160.0 * _scale()
	bar.add_child(_title)

	_play_button = Button.new()
	_play_button.toggle_mode = true
	_play_button.text = "再生"
	_play_button.tooltip_text = "エディタ上でステージを再生する (Space)"
	_play_button.toggled.connect(_on_play_toggled)
	bar.add_child(_play_button)

	_time_spin = SpinBox.new()
	_time_spin.min_value = 0.0
	_time_spin.max_value = 3600.0
	_time_spin.step = 0.1
	_time_spin.suffix = "秒"
	_time_spin.tooltip_text = "プレビューの時刻"
	_time_spin.value_changed.connect(_on_time_spin_changed)
	bar.add_child(_time_spin)

	bar.add_child(VSeparator.new())

	_add_menu = MenuButton.new()
	_add_menu.text = "＋ イベント追加"
	_add_menu.flat = false
	_add_menu.tooltip_text = "プレビューの時刻に、イベントを追加する"
	var popup := _add_menu.get_popup()
	popup.add_item("出現 (SpawnEvent)", AddKind.SPAWN)
	popup.add_item("スクロール速度 (ScrollSpeedEvent)", AddKind.SCROLL)
	popup.add_item("待機 (WaitClearEvent)", AddKind.WAIT)
	popup.add_item("合図 (StageSignalEvent)", AddKind.SIGNAL)
	popup.id_pressed.connect(_on_add_pressed)
	bar.add_child(_add_menu)

	_duplicate_button = Button.new()
	_duplicate_button.text = "複製"
	_duplicate_button.tooltip_text = "選んだイベントを、プレビューの時刻に複製する (Ctrl+D)"
	_duplicate_button.pressed.connect(_duplicate_selected)
	bar.add_child(_duplicate_button)

	_delete_button = Button.new()
	_delete_button.text = "削除"
	_delete_button.tooltip_text = "選んだイベントを削除する (Delete)"
	_delete_button.pressed.connect(_delete_selected)
	bar.add_child(_delete_button)

	bar.add_child(VSeparator.new())

	_save_button = Button.new()
	_save_button.text = "保存"
	_save_button.tooltip_text = "StageData(.tres)を保存する"
	_save_button.pressed.connect(_save_stage)
	bar.add_child(_save_button)

	_playtest_button = Button.new()
	_playtest_button.text = "▶ ここから試遊"
	_playtest_button.tooltip_text = "ステージを保存して、プレビューの時刻からゲームを起動する"
	_playtest_button.pressed.connect(_playtest)
	bar.add_child(_playtest_button)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)

	var zoom_label := Label.new()
	zoom_label.text = "拡大"
	bar.add_child(zoom_label)
	_zoom_slider = HSlider.new()
	_zoom_slider.min_value = 5.0
	_zoom_slider.max_value = 200.0
	_zoom_slider.value = _px_per_sec
	_zoom_slider.custom_minimum_size.x = 120.0 * _scale()
	_zoom_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_zoom_slider.value_changed.connect(func(value : float) -> void: _px_per_sec = value)
	bar.add_child(_zoom_slider)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(body)

	_canvas = Control.new()
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.clip_contents = true
	_canvas.focus_mode = Control.FOCUS_CLICK
	_canvas.draw.connect(_draw_canvas)
	_canvas.gui_input.connect(_on_canvas_input)
	body.add_child(_canvas)

	_vscroll = VScrollBar.new()
	_vscroll.step = 1.0
	_vscroll.value_changed.connect(func(value : float) -> void: _scroll_row = int(value))
	body.add_child(_vscroll)

	_hscroll = HScrollBar.new()
	_hscroll.step = 0.0
	_hscroll.value_changed.connect(func(value : float) -> void: _scroll_time = value)
	add_child(_hscroll)

func set_preview(preview : StagePreview) -> void:
	if preview == _preview:
		return
	_preview = preview
	_selected = null
	_dirty = false
	_drag = Drag.NONE

func _process(_delta : float) -> void:
	if not is_visible_in_tree():
		return
	if not is_instance_valid(_preview) or not _preview.is_inside_tree():
		_preview = null
		_find_preview()
	_update_toolbar()
	_update_scrollbars()
	_canvas.queue_redraw()

## 編集中のシーンから StagePreview を探す
func _find_preview() -> void:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return
	if root is StagePreview:
		set_preview(root)
		return
	for node in root.find_children("*", "Node2D", true, false):
		if node is StagePreview:
			set_preview(node)
			return

func _stage() -> StageData:
	return _preview.stage if _preview else null

func _update_toolbar() -> void:
	var stage := _stage()
	var has_stage := stage != null
	if _preview == null:
		_title.text = "StagePreview なし"
	elif not has_stage:
		_title.text = "Stage が未設定"
	else:
		_title.text = stage.stage_name + (" *" if _dirty else "")
	_play_button.disabled = not has_stage
	_play_button.set_pressed_no_signal(has_stage and _preview.playing)
	_play_button.text = "停止" if _play_button.button_pressed else "再生"
	_time_spin.editable = has_stage
	if has_stage and not _time_spin.get_line_edit().has_focus():
		_time_spin.set_value_no_signal(_preview.preview_time)
	_add_menu.disabled = not has_stage
	var has_selection := has_stage and _selected != null and stage.events.has(_selected)
	_duplicate_button.disabled = not has_selection
	_delete_button.disabled = not has_selection
	_save_button.disabled = not has_stage
	_playtest_button.disabled = not has_stage

func _update_scrollbars() -> void:
	var visible_seconds := maxf(_timeline_width() / _px_per_sec, 0.1)
	var length := (_preview.stage_length() if _stage() else 0.0) + TAIL_SECONDS
	# 再生中は、時刻のカーソルが見える位置まで自動で送る
	if _stage() and _preview.playing:
		var t := _preview.preview_time
		if t < _scroll_time or t > _scroll_time + visible_seconds * 0.9:
			_scroll_time = maxf(t - visible_seconds * 0.1, 0.0)
	_hscroll.max_value = maxf(length, visible_seconds)
	_hscroll.page = visible_seconds
	_scroll_time = clampf(_scroll_time, 0.0, maxf(_hscroll.max_value - visible_seconds, 0.0))
	_hscroll.set_value_no_signal(_scroll_time)

	var rows := _events().size()
	var visible_rows := maxi(int((_canvas.size.y - _ruler_height()) / _row_height()), 1)
	_vscroll.max_value = maxi(rows, visible_rows)
	_vscroll.page = visible_rows
	_scroll_row = clampi(_scroll_row, 0, maxi(rows - visible_rows, 0))
	_vscroll.set_value_no_signal(_scroll_row)

# ---------------------------------------------------------------- 座標の変換

func _scale() -> float:
	return EditorInterface.get_editor_scale()

func _label_width() -> float:
	return LABEL_WIDTH * _scale()

func _ruler_height() -> float:
	return RULER_HEIGHT * _scale()

func _row_height() -> float:
	return ROW_HEIGHT * _scale()

func _timeline_width() -> float:
	return maxf(_canvas.size.x - _label_width(), 1.0)

func _time_to_x(t : float) -> float:
	return _label_width() + (t - _scroll_time) * _px_per_sec

func _x_to_time(x : float) -> float:
	return _scroll_time + (x - _label_width()) / _px_per_sec

func _row_top(row : int) -> float:
	return _ruler_height() + (row - _scroll_row) * _row_height()

## y の位置にある行。行がなければ -1
func _row_at(y : float) -> int:
	if y < _ruler_height():
		return -1
	var row := int((y - _ruler_height()) / _row_height()) + _scroll_row
	return row if row < _events().size() else -1

func _events() -> Array[StageEvent]:
	if _stage() == null:
		var empty : Array[StageEvent] = []
		return empty
	return _preview.sorted_events()

# ---------------------------------------------------------------- 描画

func _draw_canvas() -> void:
	var font := get_theme_font("font", "Label")
	var font_size := get_theme_font_size("font_size", "Label")
	var area := Rect2(Vector2.ZERO, _canvas.size)
	_canvas.draw_rect(area, Color(0.11, 0.12, 0.14))
	if _stage() == null:
		var message := "シーンに StagePreview を置いて、Stage に StageData を割り当ててください" if _preview == null \
				else "StagePreview の Stage に StageData を割り当ててください"
		_canvas.draw_string(font, Vector2(12.0, 28.0) * _scale(), message, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(1.0, 0.8, 0.4))
		return

	var events := _events()
	var row_h := _row_height()
	var label_w := _label_width()
	var bar_inset := 4.0 * _scale()

	# 行の背景とバー
	var spawn_index := 0
	for row in events.size():
		var event := events[row]
		var color := _preview.event_color(event, spawn_index)
		if event is SpawnEvent:
			spawn_index += 1
		var top := _row_top(row)
		if top + row_h < _ruler_height() or top > area.size.y:
			continue
		var row_rect := Rect2(0.0, top, area.size.x, row_h)
		if event == _selected:
			_canvas.draw_rect(row_rect, Color(0.3, 0.45, 0.7, 0.35))
		elif row % 2 == 1:
			_canvas.draw_rect(row_rect, Color(1.0, 1.0, 1.0, 0.03))
		_draw_event_bar(event, top, row_h, bar_inset, color, font, font_size)

	# ステージの終わり
	var end_x := _time_to_x(_preview.stage_length())
	_canvas.draw_line(Vector2(end_x, _ruler_height()), Vector2(end_x, area.size.y), Color(1.0, 1.0, 1.0, 0.25), 1.0)

	# 左の名前の列(バーの上に重ねる)
	_canvas.draw_rect(Rect2(0.0, _ruler_height(), label_w, area.size.y), Color(0.15, 0.16, 0.19))
	spawn_index = 0
	for row in events.size():
		var event := events[row]
		var color := _preview.event_color(event, spawn_index)
		if event is SpawnEvent:
			spawn_index += 1
		var top := _row_top(row)
		if top + row_h < _ruler_height() or top > area.size.y:
			continue
		if event == _selected:
			_canvas.draw_rect(Rect2(0.0, top, label_w, row_h), Color(0.3, 0.45, 0.7, 0.5))
		_canvas.draw_rect(Rect2(4.0, top + bar_inset, 4.0 * _scale(), row_h - bar_inset * 2.0), color)
		var text := _fit_text(font, font_size, _preview.describe_event(event), label_w - 16.0 * _scale())
		_canvas.draw_string(font, Vector2(14.0 * _scale(), top + row_h * 0.5 + font_size * 0.35), text,
				HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(1.0, 1.0, 1.0, 0.9))
	_canvas.draw_line(Vector2(label_w, 0.0), Vector2(label_w, area.size.y), Color(1.0, 1.0, 1.0, 0.2))

	_draw_ruler(font, font_size, area)

	# 時刻のカーソル
	var cursor_x := _time_to_x(_preview.preview_time)
	if cursor_x >= label_w:
		_canvas.draw_line(Vector2(cursor_x, 0.0), Vector2(cursor_x, area.size.y), Color(1.0, 0.35, 0.3), 2.0)
		var tri := 6.0 * _scale()
		_canvas.draw_colored_polygon(PackedVector2Array([
				Vector2(cursor_x - tri, 0.0), Vector2(cursor_x + tri, 0.0), Vector2(cursor_x, tri * 1.5)]),
				Color(1.0, 0.35, 0.3))

## 1行分のバー。SpawnEvent は、1体ごとの出現(縦線)と、動いている間(帯)を描く
func _draw_event_bar(event : StageEvent, top : float, row_h : float, inset : float, color : Color, font : Font, font_size : int) -> void:
	var y0 := top + inset
	var h := row_h - inset * 2.0
	if event is SpawnEvent:
		for unit in event.unit_count():
			var t0 : float = event.unit_time(unit)
			var duration := minf(_preview.unit_duration(event, unit), _preview.max_enemy_lifetime)
			var x0 := _time_to_x(t0)
			var x1 := _time_to_x(t0 + duration)
			_canvas.draw_rect(Rect2(x0, y0 + h * 0.25, maxf(x1 - x0, 1.0), h * 0.5), Color(color, 0.3))
			_canvas.draw_rect(Rect2(x0 - 1.0, y0, 3.0 * _scale(), h), color)
		return
	var x := _time_to_x(event.time)
	var r := h * 0.5
	var center := Vector2(x, y0 + r)
	_canvas.draw_colored_polygon(PackedVector2Array([
			center + Vector2(0.0, -r), center + Vector2(r, 0.0), center + Vector2(0.0, r), center + Vector2(-r, 0.0)]), color)
	_canvas.draw_string(font, Vector2(x + r + 4.0, top + row_h * 0.5 + font_size * 0.35),
			_preview.describe_event(event, false), HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(color, 0.85))

func _draw_ruler(font : Font, font_size : int, area : Rect2) -> void:
	var ruler_h := _ruler_height()
	_canvas.draw_rect(Rect2(0.0, 0.0, area.size.x, ruler_h), Color(0.18, 0.19, 0.23))
	var step := TICK_STEPS[TICK_STEPS.size() - 1]
	for candidate in TICK_STEPS:
		if candidate * _px_per_sec >= 60.0 * _scale():
			step = candidate
			break
	var minor := step / 5.0
	var tick := floori(_scroll_time / minor)
	var end_time := _x_to_time(area.size.x)
	while tick * minor <= end_time:
		var t := tick * minor
		var x := _time_to_x(t)
		if x >= _label_width():
			if tick % 5 == 0:
				_canvas.draw_line(Vector2(x, ruler_h * 0.4), Vector2(x, area.size.y), Color(1.0, 1.0, 1.0, 0.08))
				_canvas.draw_line(Vector2(x, ruler_h * 0.4), Vector2(x, ruler_h), Color(1.0, 1.0, 1.0, 0.6))
				var label := ("%ds" % roundi(t)) if step >= 1.0 else ("%.1fs" % t)
				_canvas.draw_string(font, Vector2(x + 3.0, ruler_h * 0.6), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
						int(font_size * 0.85), Color(1.0, 1.0, 1.0, 0.75))
			else:
				_canvas.draw_line(Vector2(x, ruler_h * 0.75), Vector2(x, ruler_h), Color(1.0, 1.0, 1.0, 0.3))
		tick += 1
	_canvas.draw_rect(Rect2(0.0, 0.0, _label_width(), ruler_h), Color(0.18, 0.19, 0.23))
	_canvas.draw_string(font, Vector2(8.0 * _scale(), ruler_h * 0.72), "%d 件のイベント" % _events().size(),
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, int(font_size * 0.85), Color(1.0, 1.0, 1.0, 0.6))

## 幅に収まるように、文字を末尾から削る
func _fit_text(font : Font, font_size : int, text : String, width : float) -> String:
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x <= width:
		return text
	while text.length() > 1 and font.get_string_size(text + "…", HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x > width:
		text = text.left(text.length() - 1)
	return text + "…"

# ---------------------------------------------------------------- 入力

func _on_canvas_input(event : InputEvent) -> void:
	if _stage() == null:
		return
	if event is InputEventMouseButton:
		_on_mouse_button(event)
	elif event is InputEventMouseMotion and _drag != Drag.NONE:
		_on_mouse_drag(event)
	elif event is InputEventKey and event.pressed and not event.echo:
		_on_key(event)

func _on_mouse_button(event : InputEventMouseButton) -> void:
	if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		var direction := -1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0
		if event.ctrl_pressed:
			# マウスの位置を中心に拡大縮小
			var anchor := _x_to_time(event.position.x)
			_px_per_sec = clampf(_px_per_sec * (1.0 - direction * 0.15), _zoom_slider.min_value, _zoom_slider.max_value)
			_zoom_slider.set_value_no_signal(_px_per_sec)
			_scroll_time = maxf(anchor - (event.position.x - _label_width()) / _px_per_sec, 0.0)
		elif event.shift_pressed:
			_scroll_time = maxf(_scroll_time + direction * 80.0 / _px_per_sec, 0.0)
		else:
			_scroll_row = maxi(_scroll_row + int(direction) * 2, 0)
		_canvas.accept_event()
		return

	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if not event.pressed:
		_finish_drag()
		return

	var x := event.position.x
	var y := event.position.y
	if y < _ruler_height():
		if x >= _label_width():
			_drag = Drag.CURSOR
			_set_cursor_time(_x_to_time(x))
		_canvas.accept_event()
		return

	var row := _row_at(y)
	if row < 0:
		_select(null)
		if x >= _label_width():
			_drag = Drag.CURSOR
			_set_cursor_time(_x_to_time(x))
		_canvas.accept_event()
		return

	var target := _events()[row]
	_select(target)
	if event.double_click:
		_set_cursor_time(target.time)
	elif x >= _label_width():
		_drag = Drag.EVENT
		_drag_event = target
		_drag_origin_time = target.time
		_drag_start_x = x
	_canvas.accept_event()

func _on_mouse_drag(event : InputEventMouseMotion) -> void:
	match _drag:
		Drag.CURSOR:
			_set_cursor_time(_x_to_time(event.position.x))
		Drag.EVENT:
			var t := maxf(_drag_origin_time + (event.position.x - _drag_start_x) / _px_per_sec, 0.0)
			if not event.shift_pressed:
				t = snappedf(t, SNAP)
			_drag_event.time = t # 離したときに、元に戻せる操作として登録する
			_preview.queue_redraw()
	_canvas.accept_event()

func _finish_drag() -> void:
	if _drag == Drag.EVENT and _drag_event and not is_equal_approx(_drag_event.time, _drag_origin_time):
		var new_time := _drag_event.time
		undo_redo.create_action("イベントの時刻を変更")
		undo_redo.add_do_property(_drag_event, "time", new_time)
		undo_redo.add_undo_property(_drag_event, "time", _drag_origin_time)
		undo_redo.commit_action(false) # ドラッグ中に、もう反映している
		_dirty = true
	_drag = Drag.NONE
	_drag_event = null

func _on_key(event : InputEventKey) -> void:
	match event.keycode:
		KEY_SPACE:
			_on_play_toggled(not _preview.playing)
		KEY_DELETE:
			_delete_selected()
		KEY_D:
			if event.ctrl_pressed:
				_duplicate_selected()
			else:
				return
		_:
			return
	_canvas.accept_event()

# ---------------------------------------------------------------- 操作

func _set_cursor_time(t : float) -> void:
	_preview.playing = false
	_preview.preview_time = maxf(t, 0.0)

func _select(event : StageEvent) -> void:
	_selected = event
	if event:
		EditorInterface.edit_resource(event)

func _on_play_toggled(pressed : bool) -> void:
	if _preview:
		_preview.playing = pressed

func _on_time_spin_changed(value : float) -> void:
	if _stage():
		_set_cursor_time(value)

func _cursor_time() -> float:
	return snappedf(_preview.preview_time, SNAP)

func _on_add_pressed(id : int) -> void:
	var event : StageEvent
	match id:
		AddKind.SPAWN:
			var spawn := SpawnEvent.new()
			if _selected is SpawnEvent:
				spawn.enemy_scene = _selected.enemy_scene # よく使う敵を引き継ぐ
			event = spawn
		AddKind.SCROLL:
			event = ScrollSpeedEvent.new()
		AddKind.WAIT:
			event = WaitClearEvent.new()
		AddKind.SIGNAL:
			event = StageSignalEvent.new()
	if event == null:
		return
	event.time = _cursor_time()
	var events := _stage().events.duplicate()
	events.append(event)
	_commit_events(events, "イベントを追加")
	_select(event)

func _duplicate_selected() -> void:
	var stage := _stage()
	if stage == null or _selected == null or not stage.events.has(_selected):
		return
	# 埋め込みの移動パターンなどは、別物としてコピーする(.tres のファイルは共有のまま)
	var copy := _selected.duplicate_deep(Resource.DEEP_DUPLICATE_INTERNAL) as StageEvent
	copy.time = _cursor_time()
	var events := stage.events.duplicate()
	events.append(copy)
	_commit_events(events, "イベントを複製")
	_select(copy)

func _delete_selected() -> void:
	var stage := _stage()
	if stage == null or _selected == null or not stage.events.has(_selected):
		return
	var events := stage.events.duplicate()
	events.erase(_selected)
	_commit_events(events, "イベントを削除")
	_selected = null
	EditorInterface.inspect_object(_preview)

## StageData の events を、元に戻せる操作として置き換える。
## StageData とシーンのノードは元に戻す履歴が別なので、_preview は操作に入れない(描画は自分で更新される)
func _commit_events(events : Array, action_name : String) -> void:
	var stage := _stage()
	undo_redo.create_action(action_name)
	undo_redo.add_do_property(stage, "events", events)
	undo_redo.add_undo_property(stage, "events", stage.events.duplicate())
	undo_redo.commit_action()
	_dirty = true

## StageData が .tres のファイルなら保存する。シーンに埋め込まれていれば、シーンの保存で一緒に保存される
func _save_stage() -> bool:
	var stage := _stage()
	if stage == null:
		return false
	var path := stage.resource_path
	if path == "" or path.contains("::"):
		EditorInterface.save_scene()
		_dirty = false
		return true
	var error := ResourceSaver.save(stage, path)
	if error != OK:
		push_error("Stage Editor: %s を保存できませんでした (%s)" % [path, error_string(error)])
		return false
	_dirty = false
	return true

## 保存してから、プレビューの時刻を StageRunner に渡して、編集中のシーンを起動する
func _playtest() -> void:
	var stage := _stage()
	if stage == null or not _save_stage():
		return
	_preview.playing = false
	var config := ConfigFile.new()
	config.set_value("playtest", "start_time", _cursor_time())
	config.set_value("playtest", "stage_path", stage.resource_path if not stage.resource_path.contains("::") else "")
	config.set_value("playtest", "written_at", Time.get_unix_time_from_system())
	var error := config.save(StageRunner.PLAYTEST_FILE)
	if error != OK:
		push_error("Stage Editor: 試遊の設定を書き出せませんでした (%s)" % error_string(error))
		return
	EditorInterface.play_current_scene()
