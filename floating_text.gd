extends Node2D
class_name FloatingText
## 画面(ワールド)の位置に、ふわっと浮かんで消える文字を出す(全滅ボーナスなど)。
## 使い方: FloatingText.spawn(get_tree(), 位置, "全滅 +1000", 色)

## 浮かぶ距離(px)と、消えるまでの時間(秒)
const RISE : float = 28.0
const LIFE : float = 1.1

static func spawn(tree : SceneTree, at : Vector2, text : String, color : Color = Color(1.0, 0.9, 0.4), font_size : int = 14) -> FloatingText:
	var root := tree.current_scene
	if root == null:
		return null
	var node := FloatingText.new()
	node.z_index = 40
	node.top_level = true
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	node.add_child(label)
	root.add_child(node)
	label.reset_size()
	label.position = -label.size * 0.5
	node.global_position = at
	node.scale = Vector2.ONE * 0.4
	var tween := node.create_tween()
	tween.tween_property(node, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(node, "global_position:y", at.y - RISE, LIFE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(node, "modulate:a", 0.0, LIFE * 0.4).set_delay(LIFE * 0.6)
	tween.tween_callback(node.queue_free)
	return node
