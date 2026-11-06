extends CanvasLayer
class_name WarningDisplay
## ボス出現前の「WARNING」表示。シーン(GameScene/UI/warning_display.tscn)をステージのシーンに置いて使う。
## 見た目(帯の色・文字の大きさ・位置)は、シーンの中で変える。Root は普段は非表示。
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

## 未設定なら、"stage_runner" グループから探す
@export var stage_runner : StageRunner
## 表示している時間(秒)。出る・消える演出を含む
@export var duration : float = 3.0
## 斜線が流れる速さ(px/秒)
@export var stripe_speed : float = 60.0

@onready var _root : Control = $Root
@onready var _band : ColorRect = $Root/Band
@onready var _title : Label = $Root/Band/Title
@onready var _stripes : Array[Label] = [$Root/Band/StripeTop, $Root/Band/StripeBottom]
var _tween : Tween
var _blink_tween : Tween
var _stripe_width : float = 0.0

func _ready() -> void:
	_root.visible = false
	# 斜線は画面幅の2倍ぶん並んでいて、1周分(画面幅)ずつ流すと、継ぎ目なくループする
	_stripe_width = get_viewport().get_visible_rect().size.x
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
