extends Control
class_name TitlePanel
## タイトル画面の上に開く、紙のような板(OPTION / SCORE BOARD の元)。
## 白い紙に、赤い枠の線を描く。中の文字は、継いだスクリプトが make_label() で作る。
## open() で開き、close() で閉じる(閉じたら closed が出る)。

signal closed

## 文字のフォント
@export var font : Font
## 文字の色・薄い文字の色・赤(選んでいる項目の帯と、見出し)
@export var ink_color : Color = Color(0.12, 0.09, 0.09)
@export var dim_color : Color = Color(0.55, 0.5, 0.5)
@export var accent_color : Color = Color(0.8, 0.14, 0.06)
## 紙の色
@export var paper_color : Color = Color(1.0, 0.99, 0.97, 0.95)
## 画面の端から、紙の端までの距離(px)
@export var margin : float = 12.0
## 選ぶものを変えたとき・決めたとき・戻ったとき(シーンに置いた AudioStreamPlayer)
@export var move_sound : AudioStreamPlayer
@export var confirm_sound : AudioStreamPlayer
@export var back_sound : AudioStreamPlayer

var is_open : bool = false
## 開いたフレーム(開くのに使ったボタンを、そのまま中の決定にしないため)
var _opened_frame : int = -1
var _time : float = 0.0

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()

func _process(delta : float) -> void:
	_time += delta
	if is_open and Engine.get_process_frames() != _opened_frame:
		_handle_input()

## 中身を作る(継いだスクリプトで書く)
func _build() -> void:
	pass

## 開いているあいだ、毎フレーム呼ばれる(継いだスクリプトで書く)
func _handle_input() -> void:
	pass

## 開いたとき(継いだスクリプトで書く)
func _on_open() -> void:
	pass

func open() -> void:
	is_open = true
	visible = true
	_opened_frame = Engine.get_process_frames()
	_on_open()
	pivot_offset = size * 0.5
	scale = Vector2(1.0, 0.05)
	modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.12)

func close() -> void:
	is_open = false
	SoundManager.play(back_sound)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.0, 0.05), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.12)
	await tween.finished
	visible = false
	closed.emit()

func _draw() -> void:
	var rect := Rect2(Vector2(margin, margin), size - Vector2(margin, margin) * 2.0)
	draw_rect(rect, paper_color)
	draw_rect(rect, accent_color, false, 1.0)
	draw_rect(rect.grow(-3.0), Color(accent_color, 0.35), false, 1.0)
	# 四隅の、赤い印
	var corner := 10.0
	for point in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		var sx := 1.0 if point.x < rect.get_center().x else -1.0
		var sy := 1.0 if point.y < rect.get_center().y else -1.0
		draw_line(point, point + Vector2(corner * sx, 0.0), accent_color, 3.0)
		draw_line(point, point + Vector2(0.0, corner * sy), accent_color, 3.0)

## 見出し(真ん中ぞろえ)と、その下の赤い線を作る。線の下の y を返す
func make_heading(text : String, y : float) -> float:
	make_label(text, 20, accent_color, Vector2(margin, y), size.x - margin * 2.0, HORIZONTAL_ALIGNMENT_CENTER)
	var line := ColorRect.new()
	line.color = accent_color
	line.position = Vector2(size.x * 0.5 - 70.0, y + 28.0)
	line.size = Vector2(140.0, 1.0)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(line)
	return y + 34.0

## 文字を置く。width が 0 なら、幅は文字に合わせる
func make_label(text : String, font_size : int, color : Color, at : Vector2, width : float = 0.0,
		align : HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	if width > 0.0:
		label.size.x = width
	label.horizontal_alignment = align
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	return label

## 選んでいる項目の後ろに敷く、赤い帯を作る
func make_bar() -> ColorRect:
	var bar := ColorRect.new()
	bar.color = accent_color
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	return bar

static func set_color(label : Label, color : Color) -> void:
	label.add_theme_color_override("font_color", color)

func pressed(actions : Array) -> bool:
	for action in actions:
		if InputMap.has_action(action) and Input.is_action_just_pressed(action):
			return true
	return false

func pressed_up() -> bool:
	return pressed(["UI_Forward", "UI_StickUp", "ui_up"])

func pressed_down() -> bool:
	return pressed(["UI_Back", "UI_StickDown", "ui_down"])

func pressed_left() -> bool:
	return pressed(["UI_Left", "UI_StickLeft", "ui_left"])

func pressed_right() -> bool:
	return pressed(["UI_Right", "UI_StickRight", "ui_right"])

func pressed_ok() -> bool:
	return pressed(["UI_Shoot", "ui_accept"])

func pressed_back() -> bool:
	return pressed(["UI_Ignite", "ui_cancel"])
