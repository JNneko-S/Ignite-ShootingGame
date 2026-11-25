extends TitlePanel
class_name AchievementsPanel
## タイトル画面の ACHIEVEMENTS。実績(Achievements)の一覧。上下で選び、戻るボタンか決定で閉じる。
## 解除したものは墨の文字と解除した日、まだのものは薄い文字。隠す実績は、解除するまで名前と説明を伏せる。

const ROWS : int = 7
const ROW_STEP : float = 46.0

var _row : int = 0
var _top : int = 0
var _bar : ColorRect
var _names : Array[Label] = []
var _descs : Array[Label] = []
var _dates : Array[Label] = []
var _count : Label

func _build() -> void:
	var y := make_heading("ACHIEVEMENTS", 20.0)
	_count = make_label("", 11, dim_color, Vector2(margin, y), size.x - margin * 2.0, HORIZONTAL_ALIGNMENT_CENTER)
	y += 20.0
	_bar = make_bar()
	for i in ROWS:
		var top := y + i * ROW_STEP
		_names.append(make_label("", 13, ink_color, Vector2(30.0, top)))
		_dates.append(make_label("", 9, dim_color, Vector2(size.x - 120.0, top + 3.0), 90.0, HORIZONTAL_ALIGNMENT_RIGHT))
		var desc := make_label("", 10, dim_color, Vector2(30.0, top + 16.0), size.x - 60.0)
		desc.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY # 長い説明は、2行目へ折り返す
		desc.max_lines_visible = 2
		_descs.append(desc)
	make_label("↑↓ 選択   IGNITE 戻る", 10, dim_color, Vector2(margin, size.y - margin - 22.0),
		size.x - margin * 2.0, HORIZONTAL_ALIGNMENT_CENTER)

func _on_open() -> void:
	_row = 0
	_top = 0
	_refresh()

func _handle_input() -> void:
	if pressed_up():
		_move(-1)
	elif pressed_down():
		_move(1)
	elif pressed_back() or pressed_ok():
		close()

func _move(direction : int) -> void:
	var total := Achievements.LIST.size()
	_row = wrapi(_row + direction, 0, total)
	if _row < _top:
		_top = _row
	elif _row >= _top + ROWS:
		_top = _row - ROWS + 1
	SoundManager.play(move_sound)
	_refresh()

func _refresh() -> void:
	var list : Array = Achievements.LIST
	_count.text = "%d / %d" % [Achievements.unlocked_count(), list.size()]
	for i in ROWS:
		var index := _top + i
		var has := index < list.size()
		_names[i].visible = has
		_descs[i].visible = has
		_dates[i].visible = has
		if not has:
			continue
		var entry : Array = list[index]
		var done : bool = Achievements.is_unlocked(entry[0])
		var hidden : bool = entry[3] and not done
		_names[i].text = "？？？" if hidden else str(entry[1])
		_descs[i].text = "？？？" if hidden else str(entry[2])
		_dates[i].text = Achievements.unlocked_date(entry[0]).replace("T", " ").left(10) if done else ""
		var selected := index == _row
		set_color(_names[i], Color.WHITE if selected else (ink_color if done else dim_color))
		set_color(_descs[i], Color(1, 1, 1, 0.85) if selected else (ink_color if done else dim_color))
		set_color(_dates[i], Color(1, 1, 1, 0.85) if selected else accent_color)
	var row := _row - _top
	_bar.position = Vector2(margin + 8.0, _names[row].position.y - 2.0)
	_bar.size = Vector2(size.x - (margin + 8.0) * 2.0, ROW_STEP - 4.0)
