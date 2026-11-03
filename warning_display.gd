extends CanvasLayer
class_name WarningDisplay
## ボス出現前の「WARNING」表示。ステージのシーンに置いて、このスクリプトをアタッチするだけで使える
## (表示は全てコードで作る。シーンに子ノードは不要)。
##
## 使い方:
##   ・ステージに StageSignalEvent を置き、Signal Name を "warning" にする(Text を入れると、WARNING の代わりに出る)
##   ・手動なら show_warning() を呼ぶ
##
##   /////////////////   ← 斜線の帯(上下で逆向きに流れる)
##        WARNING        ← 点滅する
##   /////////////////

signal finished

const SIGNAL_NAME : String = "warning"
const STRIPE_TEXT : String = "/"
const COLOR_TEXT : Color = Color(1.0, 0.25, 0.2)
const COLOR_BAND : Color = Color(0.5, 0.0, 0.0, 0.45)

## 未設定なら、"stage_runner" グループから探す
@export var stage_runner : StageRunner
## 表示している時間(秒)。出る・消える演出を含む
@export var duration : float = 3.0
@export var font_size : int = 40
@export var stripe_font_size : int = 16
## 斜線が流れる速さ(px/秒)
@export var stripe_speed : float = 60.0

var _root : Control
var _band : ColorRect
var _title : Label
var _stripes : Array[Label] = []
var _tween : Tween
var _blink_tween : Tween
var _stripe_width : float = 0.0

func _ready() -> void:
	layer = 21
	_build()
	_root.visible = false
	_connect_runner.call_deferred() # 全ノードの準備が終わってから探す

func _connect_runner() -> void:
	if stage_runner:
		stage_runner.stage_signal.connect(_on_stage_signal)
		return
	for node in get_tree().get_nodes_in_group("stage_runner"):
		(node as StageRunner).stage_signal.connect(_on_stage_signal)

func _on_stage_signal(signal_name : String, text : String) -> void:
	if signal_name == SIGNAL_NAME:
		show_warning(text)

# ---------------------------------------------------------------- 組み立て

func _build() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.size = viewport_size
	add_child(_root)

	var band_height := font_size + stripe_font_size * 2.0 + 24.0
	_band = ColorRect.new()
	_band.color = COLOR_BAND
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_band.position = Vector2(0.0, (viewport_size.y - band_height) / 2.0)
	_band.size = Vector2(viewport_size.x, band_height)
	_root.add_child(_band)

	# 斜線は画面幅の2倍ぶん並べて、1周分(画面幅)ずつ流すと、継ぎ目なくループする
	_stripe_width = viewport_size.x
	var count := int(viewport_size.x * 2.0 / (stripe_font_size * 0.3)) + 2
	for i in 2:
		var stripe := _label(STRIPE_TEXT.repeat(count), stripe_font_size)
		stripe.position = Vector2(0.0, 4.0 if i == 0 else band_height - stripe_font_size - 8.0)
		_band.add_child(stripe)
		_stripes.append(stripe)

	_title = _label("WARNING", font_size)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.size = Vector2(viewport_size.x, font_size + 8.0)
	_title.position = Vector2(0.0, (band_height - font_size - 8.0) / 2.0)
	_band.add_child(_title)

func _label(text : String, size : int) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", COLOR_TEXT)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	return label

# ---------------------------------------------------------------- 表示

## text が空なら WARNING と出す
func show_warning(text : String = "") -> void:
	_title.text = text if text != "" else "WARNING"
	_root.visible = true
	_root.modulate.a = 0.0
	_band.scale = Vector2(1.0, 0.0)
	_band.pivot_offset = _band.size / 2.0

	if _tween:
		_tween.kill()
	_tween = create_tween()
	# 帯が上下に開く → 表示 → 閉じる
	_tween.tween_property(_root, "modulate:a", 1.0, 0.2)
	_tween.parallel().tween_property(_band, "scale:y", 1.0, 0.25)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(maxf(duration - 0.55, 0.0))
	_tween.tween_property(_band, "scale:y", 0.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(_root, "modulate:a", 0.0, 0.3)
	_tween.tween_callback(_hide)

	if _blink_tween:
		_blink_tween.kill()
	_blink_tween = create_tween().set_loops()
	_blink_tween.tween_property(_title, "modulate:a", 0.25, 0.25)
	_blink_tween.tween_property(_title, "modulate:a", 1.0, 0.25)

func _process(delta : float) -> void:
	if not _root.visible:
		return
	# 上の帯は左へ、下の帯は右へ流れる
	for i in _stripes.size():
		var stripe := _stripes[i]
		var direction := -1.0 if i == 0 else 1.0
		stripe.position.x = fposmod(stripe.position.x + direction * stripe_speed * delta, _stripe_width) - _stripe_width

func _hide() -> void:
	_root.visible = false
	if _blink_tween:
		_blink_tween.kill()
	finished.emit()
