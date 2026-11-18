extends CanvasLayer
class_name ScreenFlash
## 画面全体のフラッシュ。白一色だと明るい画面で見えず、慣れてしまうので、明るい色と暗い色を交互に出す。
## ScreenFlash.play(get_tree(), 強さ) で呼ぶ。ヒットストップ中も、実際の時間で進む。

## 明るい色・暗い色
const LIGHT := Color(1.0, 0.97, 0.9)
const DARK := Color(0.05, 0.02, 0.08)

var _rect : ColorRect
var _strength : float = 1.0

## 画面をフラッシュさせる。strength: 0〜1(1 でいちばん強い)
static func play(tree : SceneTree, strength : float = 1.0) -> void:
	if tree == null or tree.current_scene == null:
		return
	var flash := ScreenFlash.new()
	flash._strength = clampf(strength, 0.0, 1.0)
	tree.current_scene.add_child(flash)

func _ready() -> void:
	layer = 30 # ゲーム画面より手前、文字(40)より奥
	_rect = ColorRect.new()
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.color = Color(LIGHT, 0.0)
	add_child(_rect)
	var a := 0.75 * _strength
	var tween := create_tween().set_ignore_time_scale(true) # ヒットストップ中も進める
	tween.tween_property(_rect, "color", Color(LIGHT, a), 0.03)
	tween.tween_property(_rect, "color", Color(DARK, a * 0.6), 0.05)
	tween.tween_property(_rect, "color", Color(LIGHT, a * 0.7), 0.04)
	tween.tween_property(_rect, "color", Color(LIGHT, 0.0), 0.25)
	tween.tween_callback(queue_free)
