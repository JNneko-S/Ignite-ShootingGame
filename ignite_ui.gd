extends Node
class_name IgniteUI
## UIノードにアタッチ。GameManager から bind() で IgniteGauge を受け取り、
## ゲージの変化に合わせて ProgressBar と Label を更新する。

@onready var bar : ProgressBar = $CanvasLayer/ProgressBar
@onready var label : Label = $CanvasLayer/Label

var _tween : Tween

func bind(gauge : IgniteGauge) -> void:
	gauge.level_changed.connect(_on_level_changed)
	gauge.progress_changed.connect(_on_progress_changed)
	# 初期表示
	bar.max_value = 1.0
	bar.value = gauge.ratio()
	_on_level_changed(gauge.level)

func _on_level_changed(level : int) -> void:
	label.text = "Ignite %d" % level

func _on_progress_changed(ratio : float) -> void:
	# バーを少しなめらかに動かす
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(bar, "value", ratio, 0.1)
