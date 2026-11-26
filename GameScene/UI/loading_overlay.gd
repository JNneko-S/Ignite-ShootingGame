extends CanvasLayer
class_name LoadingOverlay
## ロード画面。閉じたシャッターや暗転の上に出して、そのあいだに PreloadCache でゲームのリソースを読み込む。
## 見た目はタイトルと同じ: 墨の帯に、明朝の「NOW LOADING」、朱の細いゲージ、回る輪。
##   await LoadingOverlay.run(get_tree())   … 読み込みが終わって、画面が消えるまで待つ(もう読み込んでいたら、すぐ戻る)

const _Preload := preload("res://Component/Scene/preload_cache.gd")
const TITLE_FONT := preload("res://Assets/Fonts/ShitataruMinchoShogo-EB.otf")
const SMALL_FONT := preload("res://Assets/Fonts/micronian.ttf")

## 1フレームで読み込みに使う時間(マイクロ秒)。大きいほど早く終わるが、画面の動きがかくつく
const BUDGET_USEC : int = 14000
## 読み込みがすぐ終わっても、この時間は出しておく(ちらつかないように)
const MIN_TIME : float = 0.6

const PAPER := Color(1.0, 0.99, 0.97)
const INK := Color(0.1, 0.07, 0.07)
const VERMILION := Color(0.85, 0.16, 0.07)

signal finished

var _bar : ColorRect
var _bar_width : float = 0.0
var _percent : Label
var _ring : Control
var _root : Control
var _progress : float = 0.0
var _shown : float = 0.0
var _time : float = 0.0

## ロード画面を出して読み込み、終わるまで待つ
static func run(tree : SceneTree) -> void:
	if _Preload.is_warm():
		return
	var overlay : CanvasLayer = (load("res://GameScene/UI/loading_overlay.gd") as GDScript).new()
	tree.root.add_child(overlay)
	await overlay.finished

func _ready() -> void:
	layer = 120 # シャッター(90〜99)より手前
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_Preload.begin()

func _build() -> void:
	var size := get_viewport().get_visible_rect().size
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.size = size
	add_child(_root)
	# 真ん中の墨の帯
	var band := ColorRect.new()
	band.color = Color(INK, 0.92)
	band.size = Vector2(size.x, 92.0)
	band.position = Vector2(0.0, size.y * 0.5 - 46.0)
	_root.add_child(band)
	for y in [band.position.y, band.position.y + band.size.y - 1.0]:
		var line := ColorRect.new()
		line.color = VERMILION
		line.size = Vector2(size.x, 1.0)
		line.position = Vector2(0.0, y)
		_root.add_child(line)
	# 回る輪(墨の帯の左)
	_ring = Control.new()
	_ring.position = Vector2(40.0, size.y * 0.5)
	_ring.draw.connect(_draw_ring)
	_root.add_child(_ring)
	var title := Label.new()
	title.text = "NOW LOADING"
	title.add_theme_font_override("font", TITLE_FONT)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", PAPER)
	title.position = Vector2(72.0, size.y * 0.5 - 30.0)
	_root.add_child(title)
	# 朱の細いゲージ
	_bar_width = size.x - 72.0 - 30.0
	var back := ColorRect.new()
	back.color = Color(PAPER, 0.18)
	back.size = Vector2(_bar_width, 2.0)
	back.position = Vector2(72.0, size.y * 0.5 + 12.0)
	_root.add_child(back)
	_bar = ColorRect.new()
	_bar.color = VERMILION
	_bar.size = Vector2(0.0, 2.0)
	_bar.position = back.position
	_root.add_child(_bar)
	_percent = Label.new()
	_percent.add_theme_font_override("font", SMALL_FONT)
	_percent.add_theme_font_size_override("font_size", 10)
	_percent.add_theme_color_override("font_color", Color(PAPER, 0.7))
	_percent.position = Vector2(72.0, size.y * 0.5 + 18.0)
	_root.add_child(_percent)
	_root.modulate.a = 0.0
	var fade_in := create_tween()
	fade_in.tween_property(_root, "modulate:a", 1.0, 0.15)

func _draw_ring() -> void:
	var spin := _time * 4.0
	_ring.draw_arc(Vector2.ZERO, 13.0, spin, spin + PI * 1.4, 24, VERMILION, 2.0, true)
	_ring.draw_arc(Vector2.ZERO, 8.0, -spin * 1.4, -spin * 1.4 + PI, 18, Color(PAPER, 0.6), 1.2, true)

func _process(delta : float) -> void:
	_time += delta
	_ring.queue_redraw()
	if _progress < 1.0:
		_progress = _Preload.step(BUDGET_USEC)
	_shown = move_toward(_shown, _progress, delta * 2.5) # ゲージは、なめらかに伸ばす
	_bar.size.x = _bar_width * _shown
	_percent.text = "%3d%%" % int(round(_shown * 100.0))
	if _progress >= 1.0 and _shown >= 1.0 and _time >= MIN_TIME:
		set_process(false)
		var fade := create_tween()
		fade.tween_interval(0.12)
		fade.tween_property(_root, "modulate:a", 0.0, 0.18)
		await fade.finished
		finished.emit()
		queue_free()
