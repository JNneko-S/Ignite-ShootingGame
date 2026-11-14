extends Node2D
class_name LevelUpPopup
## 自機の後ろに、斜めに流れながら出て、しゅっと消える知らせ(「LEVEL UP!!!」「EXTEND!!」など)。
## 自機より奥に、半透明で出すので、弾や敵を見るじゃまにならない。
##   LevelUpPopup.show_image(tree, at, texture) … 絵で出す(イグナイトのレベルが上がったとき)
##   LevelUpPopup.show_text(tree, at, text)     … 文字で出す(残機が増えたとき)

const LEVEL_UP_PATH := "res://Assets/UI/level_up.png"
const FONT := preload("res://Assets/Fonts/micronian.ttf")

## 流れる距離(右上へ)と、時間(秒)
const DRIFT := Vector2(70.0, -70.0)
const SHOW_TIME := 0.75
const VANISH_TIME := 0.14
## 濃さ(じゃまにならないように、少し透かす)
const ALPHA := 0.75

## 自機の後ろ(at の位置)に、絵を出す
static func show_image(tree : SceneTree, at : Vector2, texture : Texture2D = null, size : float = 110.0) -> void:
	if texture == null:
		texture = load(LEVEL_UP_PATH) as Texture2D
	if texture == null:
		show_text(tree, at, "LEVEL UP!!!") # 絵が読めないときは文字で出す
		return
	var popup := LevelUpPopup.new()
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2.ONE * size / maxf(texture.get_width(), 1.0)
	popup.add_child(sprite)
	popup._start(tree, at)

## 自機の後ろ(at の位置)に、オレンジに黄色のふちの文字を出す(LEVEL UP の絵と同じ色合い)
static func show_text(tree : SceneTree, at : Vector2, text : String) -> void:
	var popup := LevelUpPopup.new()
	var label := Label.new()
	label.text = text
	var settings := LabelSettings.new()
	settings.font = FONT
	settings.font_size = 26
	settings.font_color = Color(1.0, 0.55, 0.1)
	settings.outline_size = 8
	settings.outline_color = Color(1.0, 0.85, 0.2)
	label.label_settings = settings
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(220, 40)
	label.position = -label.size * 0.5
	popup.add_child(label)
	popup._start(tree, at)

func _start(tree : SceneTree, at : Vector2) -> void:
	z_as_relative = false
	z_index = 0 # 自機(z 1)より奥、地面より手前
	modulate = Color(1, 1, 1, 0)
	scale = Vector2(0.6, 0.6)
	tree.current_scene.add_child(self)
	global_position = at + Vector2(-30.0, 30.0)
	var tween := create_tween()
	# ぽんと出てきて、右上へ流れる
	tween.tween_property(self, "modulate:a", ALPHA, 0.08)
	tween.parallel().tween_property(self, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "global_position", global_position + DRIFT, SHOW_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# しゅっと消える(横に細くなって、薄くなる)
	tween.tween_property(self, "scale", Vector2(1.6, 0.05), VANISH_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self, "modulate:a", 0.0, VANISH_TIME)
	tween.tween_callback(queue_free)
