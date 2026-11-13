extends Control
class_name LedBoard
## 電光掲示板。Text を、光る点(LED)を並べた文字で表示する。GameOverScreen や ShipSelect が使う。
## 絵は使わず、点を描く。文字は 5×7 の点の文字(使える文字は、下の FONT にあるものだけ)。
##   run_marquee(): 右から流れてきて、真ん中で止まる
##   blink()      : 何回か消えて点く
##   set_text()   : 文字を変える(収まらない文字は、流し続ける)
## 大きさ(Size)に合わせて、点の間隔が決まる。

## 表示する文字
@export var text : String = "GAME OVER"
## 点いている点の色と、消えている点の色
@export var lit_color : Color = Color(1.0, 0.42, 0.1)
@export var dim_color : Color = Color(0.2, 0.05, 0.03)
## 枠の色
@export var housing_color : Color = Color(0.06, 0.06, 0.07)
@export var frame_color : Color = Color(0.42, 0.44, 0.48)
## 文字の左右に、少なくともこれだけ空ける点の数
@export var side_padding : int = 2
## 点の間隔(px)。0 なら、文字が横に収まる大きさに自動で決める。
## 決めておくと、文字を変えても掲示板の高さが変わらない(収まらない文字は流れる)
@export var fixed_pitch : float = 0.0
## 収まらない文字が流れる速さ(1秒に進む点の列の数)
@export var scroll_speed : float = 28.0
## 枠の太さ(px)
@export var margin : float = 6.0

const ROWS : int = 7
## 文字の上下に空ける点の数
const ROW_PADDING : int = 1

## 5×7 の点の文字。"#" が点く(英大文字・数字・いくつかの記号。小文字は大文字で出る)
const FONT : Dictionary = {
	"A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
	"B": ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
	"C": [".###.", "#...#", "#....", "#....", "#....", "#...#", ".###."],
	"D": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
	"E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
	"F": ["#####", "#....", "#....", "####.", "#....", "#....", "#...."],
	"G": [".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".####"],
	"H": ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
	"I": [".###.", "..#..", "..#..", "..#..", "..#..", "..#..", ".###."],
	"J": ["..###", "...#.", "...#.", "...#.", "...#.", "#..#.", ".##.."],
	"K": ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
	"L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
	"M": ["#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#"],
	"N": ["#...#", "#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#"],
	"O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
	"P": ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
	"Q": [".###.", "#...#", "#...#", "#...#", "#.#.#", "#..#.", ".##.#"],
	"R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
	"S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
	"T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
	"U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
	"V": ["#...#", "#...#", "#...#", "#...#", "#...#", ".#.#.", "..#.."],
	"W": ["#...#", "#...#", "#...#", "#.#.#", "#.#.#", "#.#.#", ".#.#."],
	"X": ["#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#"],
	"Y": ["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."],
	"Z": ["#####", "....#", "...#.", "..#..", ".#...", "#....", "#####"],
	"0": [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."],
	"1": ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
	"2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
	"3": ["#####", "...#.", "..#..", "...#.", "....#", "#...#", ".###."],
	"4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
	"5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
	"6": ["..##.", ".#...", "#....", "####.", "#...#", "#...#", ".###."],
	"7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
	"8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
	"9": [".###.", "#...#", "#...#", ".####", "....#", "...#.", ".##.."],
	"-": ["...", "...", "...", "###", "...", "...", "..."],
	"!": ["#", "#", "#", "#", "#", ".", "#"],
	".": [".", ".", ".", ".", ".", ".", "#"],
	":": [".", "#", ".", ".", ".", "#", "."],
	"?": [".###.", "#...#", "....#", "...#.", "..#..", ".....", "..#.."],
	"/": ["....#", "....#", "...#.", "..#..", ".#...", "#....", "#...."],
	"<": ["...#", "..#.", ".#..", "#...", ".#..", "..#.", "...#"],
	">": ["#...", ".#..", "..#.", "...#", "..#.", ".#..", "#..."],
	" ": ["...", "...", "...", "...", "...", "...", "..."],
}

## 文字を、縦1列ずつの点の並びにしたもの(列ごとに、点く行を bit で持つ)
var _columns : PackedInt32Array = []
## 文字の先頭の列が、掲示板の何列目にあるか
var _offset : float = 0.0
var _on : bool = true
var _time : float = 0.0
## 文字が掲示板に収まらないときは、右から左へ流し続ける
var _scrolling : bool = false

func _ready() -> void:
	_build_columns()
	_offset = _board_cols() # 最初は右の外(何も見えない)

func _process(delta : float) -> void:
	_time += delta
	if _scrolling:
		_offset -= scroll_speed * delta
		if _offset < -_columns.size():
			_offset = _board_cols() # 流れきったら、また右から
	queue_redraw()

## 文字を変える。収まる文字は真ん中に止めて出し、収まらない文字は流し続ける。
## animate がオンなら、いったん消えてから点く
func set_text(new_text : String, animate : bool = true) -> void:
	text = new_text
	_build_columns()
	if animate:
		_on = false
		await get_tree().create_timer(0.08).timeout
		_on = true
	show_now()

## 今の文字を、すぐに出す(収まるなら真ん中、収まらないなら右から流し始める)
func show_now() -> void:
	var cols := _board_cols()
	_scrolling = _columns.size() > cols
	_offset = float(cols) if _scrolling else floorf((cols - _columns.size()) / 2.0)

## 文字を点の列にする
func _build_columns() -> void:
	_columns.clear()
	for i in text.length():
		var glyph : Array = FONT.get(text[i].to_upper(), FONT[" "])
		var width : int = (glyph[0] as String).length()
		for x in width:
			var bits := 0
			for y in ROWS:
				if (glyph[y] as String)[x] == "#":
					bits |= 1 << y
			_columns.append(bits)
		if i < text.length() - 1:
			_columns.append(0) # 文字と文字のあいだ

## 点の間隔(px)。Fixed Pitch があればそれ、なければ文字が左右の余白込みで横に収まる大きさ
func pitch() -> float:
	return _pitch_for(size.x)

func _pitch_for(width : float) -> float:
	if fixed_pitch > 0.0:
		return fixed_pitch
	if _columns.is_empty():
		_build_columns()
	return floorf((width - margin * 2.0) / float(_columns.size() + side_padding * 2))

## この幅のときに、ちょうどよい高さ
func height_for(width : float) -> float:
	return _pitch_for(width) * (ROWS + ROW_PADDING * 2) + margin * 2.0

func _board_cols() -> int:
	return int((size.x - margin * 2.0) / maxf(pitch(), 1.0))

## 右から流れてきて、真ん中で止まる。speed は 1秒に進む列の数
func run_marquee(speed : float = 70.0) -> void:
	_scrolling = false
	var cols := _board_cols()
	var center := floorf((cols - _columns.size()) / 2.0)
	_offset = cols
	var tween := create_tween()
	tween.tween_property(self, "_offset", center, (cols - center) / maxf(speed, 1.0))
	await tween.finished

## count 回、消えて点く
func blink(count : int = 3, off_time : float = 0.12, on_time : float = 0.2) -> void:
	for i in count:
		_on = false
		await get_tree().create_timer(off_time).timeout
		_on = true
		await get_tree().create_timer(on_time).timeout

## 電源が落ちるように、ちらついてから消える
func flicker_off(count : int = 4) -> void:
	for i in count:
		_on = false
		await get_tree().create_timer(randf_range(0.02, 0.06)).timeout
		_on = true
		await get_tree().create_timer(randf_range(0.02, 0.05)).timeout
	_on = false

func _draw() -> void:
	# 枠
	draw_rect(Rect2(Vector2.ZERO, size), frame_color)
	draw_rect(Rect2(Vector2(2, 2), size - Vector2(4, 4)), frame_color.darkened(0.45))
	draw_rect(Rect2(Vector2(margin - 1.0, margin - 1.0), size - Vector2(margin - 1.0, margin - 1.0) * 2.0), housing_color)
	for corner in [Vector2(3.5, 3.5), Vector2(size.x - 3.5, 3.5), Vector2(3.5, size.y - 3.5), Vector2(size.x - 3.5, size.y - 3.5)]:
		draw_circle(corner, 1.5, frame_color.lightened(0.3)) # ねじ
	var p := pitch()
	if p < 2.0:
		return
	var cols := _board_cols()
	var rows := ROWS + ROW_PADDING * 2
	var grid := Vector2(cols, rows) * p
	var origin := Vector2(margin, margin) + (size - Vector2(margin, margin) * 2.0 - grid) * 0.5 + Vector2(p, p) * 0.5
	var radius := p * 0.38
	var start := int(floorf(_offset)) # 点の掲示板は、1列ずつカクッと進む
	var glow := 0.93 + 0.07 * sin(_time * 23.0) # ほんの少しちらつく
	var lit := Color(lit_color.r * glow, lit_color.g * glow, lit_color.b * glow)
	for c in cols:
		var text_col := c - start
		var bits := _columns[text_col] if _on and text_col >= 0 and text_col < _columns.size() else 0
		for r in rows:
			var pos := origin + Vector2(c, r) * p
			var y := r - ROW_PADDING
			if y >= 0 and y < ROWS and bits & (1 << y):
				draw_circle(pos, radius * 2.0, Color(lit, 0.3))
				draw_circle(pos, radius, lit)
				draw_circle(pos - Vector2(radius, radius) * 0.3, radius * 0.4, Color(1.0, 0.85, 0.6, 0.8))
			else:
				draw_circle(pos, radius, dim_color)
