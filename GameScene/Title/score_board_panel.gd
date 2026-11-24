extends TitlePanel
class_name ScoreBoardPanel
## タイトル画面の SCORE BOARD。過去 20 回のプレイの記録(ScoreBoard)を一覧にする。
## 上下で記録を選ぶと、下の欄に詳しい内容(日時・機体・到達ステージ・被弾数・ボム使用数・撃破数・レート)が出る。
## 左右で並び順(新しい順 / スコア順)を変える。戻るボタンか決定で閉じる。

const SORT_NAMES : Array[String] = ["RECENT", "HIGH SCORE"]
const LIST_ROWS : int = ScoreBoard.MAX_ENTRIES
const ROW_STEP : float = 11.0

var _entries : Array = []
var _sorted : Array = []
var _sort : int = 0
var _row : int = 0
var _bar : ColorRect
var _sort_labels : Array[Label] = []
var _rows : Array = [] # 1行ごとの [番号, 日付, スコア, 難易度, 評価] の Label
var _empty : Label
var _detail : Array[Label] = []

func _build() -> void:
	var y := make_heading("SCORE BOARD", 20.0)
	_sort_labels.append(make_label(SORT_NAMES[0], 12, ink_color, Vector2(size.x * 0.5 - 120.0, y), 110.0, HORIZONTAL_ALIGNMENT_CENTER))
	_sort_labels.append(make_label(SORT_NAMES[1], 12, ink_color, Vector2(size.x * 0.5 + 10.0, y), 110.0, HORIZONTAL_ALIGNMENT_CENTER))
	y += 20.0
	# 見出しの行
	var columns := _columns()
	for i in columns.size():
		var column : Array = columns[i]
		make_label(["No.", "DATE", "SCORE", "LEVEL", "RATE"][i], 9, dim_color, Vector2(column[0], y), column[1], column[2])
	y += 13.0
	_bar = make_bar()
	for r in LIST_ROWS:
		var labels : Array[Label] = []
		for column in columns:
			labels.append(make_label("", 10, ink_color, Vector2(column[0], y + r * ROW_STEP), column[1], column[2]))
		_rows.append(labels)
	_empty = make_label("NO RECORDS", 14, dim_color, Vector2(margin, y + 90.0), size.x - margin * 2.0, HORIZONTAL_ALIGNMENT_CENTER)
	# 詳しい内容の欄
	var top := y + LIST_ROWS * ROW_STEP + 6.0
	var line := ColorRect.new()
	line.color = Color(accent_color, 0.5)
	line.position = Vector2(28.0, top)
	line.size = Vector2(size.x - 56.0, 1.0)
	add_child(line)
	for i in 4:
		_detail.append(make_label("", 11, ink_color, Vector2(30.0, top + 5.0 + i * 15.0), size.x - 60.0))
	make_label("↑↓ 選択   ←→ 並び順   IGNITE 戻る", 10, dim_color, Vector2(margin, size.y - margin - 22.0),
		size.x - margin * 2.0, HORIZONTAL_ALIGNMENT_CENTER)

## 列の [左の位置, 幅, 揃え]
func _columns() -> Array:
	return [
		[20.0, 22.0, HORIZONTAL_ALIGNMENT_RIGHT],
		[56.0, 44.0, HORIZONTAL_ALIGNMENT_LEFT],
		[96.0, 96.0, HORIZONTAL_ALIGNMENT_RIGHT],
		[204.0, 62.0, HORIZONTAL_ALIGNMENT_LEFT],
		[268.0, 40.0, HORIZONTAL_ALIGNMENT_CENTER],
	]

func _on_open() -> void:
	_entries = ScoreBoard.load_entries()
	_row = 0
	_apply_sort()

func _handle_input() -> void:
	if pressed_up():
		_move(-1)
	elif pressed_down():
		_move(1)
	elif pressed_left() or pressed_right():
		_sort = 1 - _sort
		_row = 0
		SoundManager.play(move_sound)
		_apply_sort()
	elif pressed_back() or pressed_ok():
		close()

func _move(direction : int) -> void:
	if _sorted.is_empty():
		return
	_row = wrapi(_row + direction, 0, _sorted.size())
	SoundManager.play(move_sound)
	_refresh()

func _apply_sort() -> void:
	_sorted = _entries.duplicate()
	if _sort == 1:
		_sorted.sort_custom(func(a : Dictionary, b : Dictionary) -> bool: return int(a.get("score", 0)) > int(b.get("score", 0)))
	_refresh()

func _refresh() -> void:
	for i in _sort_labels.size():
		set_color(_sort_labels[i], accent_color if i == _sort else dim_color)
		_sort_labels[i].text = ("<  %s  >" if i == _sort else "%s") % SORT_NAMES[i]
	_empty.visible = _sorted.is_empty()
	for r in LIST_ROWS:
		var labels : Array = _rows[r]
		var has := r < _sorted.size()
		var color := Color.WHITE if r == _row and has else ink_color
		for label in labels:
			set_color(label, color)
			label.text = ""
		if not has:
			continue
		var entry : Dictionary = _sorted[r]
		labels[0].text = "%02d" % (r + 1)
		labels[1].text = _short_date(entry)
		labels[2].text = format_score(int(entry.get("score", 0)))
		labels[3].text = ScoreBoard.difficulty_name(entry)
		labels[4].text = ScoreBoard.grade(entry)
	_bar.visible = not _sorted.is_empty()
	if _sorted.is_empty():
		for label in _detail:
			label.text = ""
		_detail[0].text = "まだ記録がありません。"
		return
	var first : Label = _rows[_row][0]
	_bar.position = Vector2(margin + 8.0, first.position.y)
	_bar.size = Vector2(size.x - (margin + 8.0) * 2.0, ROW_STEP)
	_show_detail(_sorted[_row])

func _show_detail(entry : Dictionary) -> void:
	var stage := str(entry.get("stage", "---"))
	_detail[0].text = "%s    %s" % [str(entry.get("date", "")).replace("T", " ").left(16), str(entry.get("ship", "---"))]
	_detail[1].text = "%s  /  %s  /  %s" % [ScoreBoard.difficulty_name(entry), "ALL CLEAR" if entry.get("cleared", false) else stage,
		format_score(int(entry.get("score", 0)))]
	_detail[2].text = "被弾 %d    ボム %d    撃破 %d" % [int(entry.get("hits", 0)), int(entry.get("bombs", 0)), int(entry.get("kills", 0))]
	_detail[3].text = "RATE  %.1f   ( %s )" % [ScoreBoard.rate_value(entry), ScoreBoard.grade(entry)]
	set_color(_detail[3], accent_color)

func _short_date(entry : Dictionary) -> String:
	var date := str(entry.get("date", ""))
	return date.substr(5, 5).replace("-", "/") if date.length() >= 10 else "--/--"

## 1234567 → "1,234,567"
static func format_score(value : int) -> String:
	var digits := str(absi(value))
	var result := ""
	while digits.length() > 3:
		result = "," + digits.right(3) + result
		digits = digits.left(digits.length() - 3)
	return ("-" if value < 0 else "") + digits + result
