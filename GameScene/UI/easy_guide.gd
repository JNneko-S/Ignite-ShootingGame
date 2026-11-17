extends CanvasLayer
class_name EasyGuide
## EASY のときだけ出す、遊び方の案内。GameManager が置く。
## 画面の上のほうに、右から滑り込んで数秒出て、左へ抜けていく。
## 案内は、それが役に立つ瞬間に出す:
##   グレイズ   … 初めてグレイズしたとき(しなくても、ステージ開始から graze_fallback_time 秒で出す)
##   レベル     … グレイズの案内のすぐあと
##   被弾       … 初めて被弾したとき
##   イグナイト … ステージの ignite_time 秒(1面は、弾の壁が来る場面)
## それぞれ、ゲームを起動しているあいだに一度だけ出す(やり直しのたびには出さない)。

## 案内の文。[color=...] で色を付けられる
const TIPS := {
	"graze": "弾をギリギリで避ける([color=#7fe0ff]グレイズ[/color])と\n左上のゲージが回復！",
	"level": "ゲージのレベルは[color=#ff8080]体力[/color]でもあり、\n[color=#ffc04d]イグナイト[/color]の使用回数でもある！",
	"hit": "被弾すればレベルは[color=#ff8080]1下がる[/color]ぞ！",
	"ignite": "[color=#ffc04d]イグナイト[/color]は一定時間\n敵の弾を跳ね返すことができる！",
}
## 一度出した案内(ゲームを起動しているあいだ覚えておく)
static var _shown : Dictionary = {}

## 初めてのグレイズがなくても、ステージ開始からこの秒数でグレイズの案内を出す
@export var graze_fallback_time : float = 6.0
## イグナイトの案内を出すステージの時間(秒)。0 以下なら出さない
@export var ignite_time : float = 16.0
## 1つの案内を出しておく秒数
@export var show_time : float = 3.5
## 滑り込む・抜けていく時間
@export var slide_time : float = 0.4
## 案内の真ん中の高さ(画面の px)
@export var center_y : float = 92.0
@export var font_size : int = 11

var player : Player
var _runner : StageRunner
var _queue : Array[String] = []
var _busy : bool = false
var _panel : PanelContainer
var _body : RichTextLabel
var _tween : Tween
var _home : Vector2
var _leaving : bool = false
## その場で伝えたい案内(出ている案内を引っ込めて、先に出す)
const URGENT := ["hit", "ignite"]

func _ready() -> void:
	layer = 26
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_build()
	if player:
		player.graze_hit.connect(func(_p, _d): _request("graze"))
		player.damaged.connect(func(): _request("hit"))

func _build() -> void:
	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.04, 0.1, 0.82)
	style.border_color = Color(1.0, 0.7, 0.25, 0.9)
	style.set_border_width_all(1)
	style.border_width_left = 3
	style.set_corner_radius_all(3)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 4
	style.content_margin_bottom = 6
	_panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	_panel.add_child(box)

	var header := Label.new()
	header.text = "HINT"
	var header_settings := LabelSettings.new()
	header_settings.font = load("res://Assets/Fonts/micronian.ttf")
	header_settings.font_size = 8
	header_settings.font_color = Color(1.0, 0.75, 0.3)
	header.label_settings = header_settings
	box.add_child(header)

	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.scroll_active = false
	_body.autowrap_mode = TextServer.AUTOWRAP_OFF
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Yu Gothic UI", "Meiryo", "Hiragino Sans", "Noto Sans CJK JP", "MS Gothic"])
	font.font_weight = 700
	font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	_body.add_theme_font_override("normal_font", font)
	_body.add_theme_font_size_override("normal_font_size", font_size)
	_body.add_theme_color_override("default_color", Color.WHITE)
	_body.add_theme_constant_override("outline_size", 3)
	_body.add_theme_color_override("font_outline_color", Color.BLACK)
	_body.add_theme_constant_override("line_separation", 1)
	box.add_child(_body)

	_panel.visible = false
	add_child(_panel)

func _process(_delta : float) -> void:
	if _runner == null:
		_runner = get_tree().get_first_node_in_group("stage_runner") as StageRunner
	if _runner == null or not _runner._running:
		return
	if _runner.stage_time >= graze_fallback_time:
		_request("graze")
	if ignite_time > 0.0 and _runner.stage_time >= ignite_time:
		_request("ignite")
	if not _busy and not _queue.is_empty() and _can_show():
		_show(_queue.pop_front())

## 案内を出したい(まだ出していなければ、順番待ちに入れる)
func _request(id : String) -> void:
	if _shown.has(id):
		return
	_shown[id] = true
	# 被弾とイグナイトの案内は、その場で伝えたいので、待っている案内より先に出し、
	# いま出ている案内は早めに引っ込める
	if URGENT.has(id):
		_queue.push_front(id)
		_dismiss()
	else:
		_queue.append(id)
	if id == "graze":
		_queue.append("level")
		_shown["level"] = true

## いま出ている案内を、すぐに引っ込める
func _dismiss() -> void:
	if not _busy or _tween == null or _leaving:
		return
	_tween.kill()
	_leave()

func _leave() -> void:
	_leaving = true
	var width := get_viewport().get_visible_rect().size.x
	_tween = create_tween()
	_tween.tween_property(_panel, "position", _home - Vector2(width, 0), slide_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_tween.tween_callback(func():
		_panel.visible = false
		_leaving = false
		_busy = false)

## 演出中(登場・ステージクリア)や、自機が消えているあいだは出さない
func _can_show() -> bool:
	return is_instance_valid(player) and player.visible and not player.ignite_blocked()

func _show(id : String) -> void:
	_busy = true
	_body.text = TIPS[id]
	_panel.visible = true
	_panel.reset_size()
	var width := get_viewport().get_visible_rect().size.x
	_home = Vector2((width - _panel.size.x) * 0.5, center_y - _panel.size.y * 0.5).round()
	_panel.position = _home + Vector2(width, 0)
	_tween = create_tween()
	_tween.tween_property(_panel, "position", _home, slide_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(show_time)
	_tween.tween_callback(_leave)

## テスト用: 一度出した記録を消す
static func reset_shown() -> void:
	_shown.clear()
