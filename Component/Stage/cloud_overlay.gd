extends Node2D
class_name CloudOverlay
## ステージとステージのあいだの雲(霧の代わりに、雲を抜けて次のステージへ降りていく)。StageTransition が作る。
## FogOverlay と同じ使い方: descend_to() / descend() で雲が湧いて画面が覆われ、cover() で覆われた状態から始め、
## dissolve() で雲がちぎれて消えていく。雲は 3面の空と同じシェーダー(sky_clouds)で描く。
## 雲の下には、薄い「もや」を重ねる。雲が切れていくと、もやの向こうに次のステージの地上が見え、もやも晴れていく
## (雲の切れ間から、下の建物が見えるように)。

const CLOUD_SHADER := preload("res://Shaders/sky_clouds.gdshader")

## 前のステージの雲の色(次のステージで、同じ色の雲から始めるため。シーンを切り替えても残る)
static var carried_light : Color = Color(0.96, 0.66, 0.52)
static var carried_shadow : Color = Color(0.69, 0.5, 0.53)

## 晴れていくあいだに移っていく、次のステージの雲の色(白っぽい昼の雲)
@export var clear_light : Color = Color(0.95, 0.95, 0.97)
@export var clear_shadow : Color = Color(0.62, 0.65, 0.74)
## もやの色(地上が、青灰色にかすんで見える)
@export var haze_color : Color = Color(0.42, 0.5, 0.58)
## 雲が流れる速さ(降りていくほど速く見える)
@export var scroll_speed : float = 0.9
## 描く高さ(自機より下、敵や背景より上。FogOverlay と同じ)
@export var cloud_z_index : int = 50

var _haze : ColorRect
var _layers : Array[ColorRect] = []
var _scroll : float = 0.0
var _speed_scale : float = 1.0
## 覆っている量(0 = 晴れ、1 = 画面がすべて雲)
var _amount : float = 0.0

func _ready() -> void:
	z_as_relative = false
	z_index = cloud_z_index
	_haze = ColorRect.new()
	_haze.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_haze.color = Color(haze_color, 0.0)
	add_child(_haze)
	# 奥の大きな雲と、手前の速い雲の2層
	for i in 2:
		var rect := ColorRect.new()
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var material := ShaderMaterial.new()
		material.shader = CLOUD_SHADER
		material.set_shader_parameter("sky_alpha", 0.0) # 雲の隙間から、下が見える
		material.set_shader_parameter("cloud_scale", 1.5 if i == 0 else 2.2)
		material.set_shader_parameter("light_dir", Vector2(0.6, -0.7))
		rect.material = material
		add_child(rect)
		_layers.append(rect)
	_set_colors(carried_light, carried_shadow)
	_apply()
	_follow_camera()

## 今のステージの空の雲の色を覚える(SkyBackground があれば、その色)。次のステージの雲が、同じ色から始まる
static func remember_colors(tree : SceneTree) -> void:
	for node in tree.current_scene.find_children("*", "", true, false):
		if node is SkyBackground:
			carried_light = node.cloud_color
			carried_shadow = node.cloud_shadow
			return

func _process(delta : float) -> void:
	_scroll += scroll_speed * _speed_scale * delta
	for i in _layers.size():
		(_layers[i].material as ShaderMaterial).set_shader_parameter("scroll", _scroll * (1.0 if i == 0 else 1.7))
	_follow_camera()

func _follow_camera() -> void:
	var view := CameraView.visible_rect(self)
	_haze.global_position = view.position
	_haze.size = view.size
	for rect in _layers:
		rect.global_position = view.position
		rect.size = view.size
		var material := rect.material as ShaderMaterial
		material.set_shader_parameter("rect_size", view.size)
		material.set_shader_parameter("aspect", view.size.x / maxf(view.size.y, 1.0))

func _set_colors(light : Color, shadow : Color) -> void:
	for rect in _layers:
		var material := rect.material as ShaderMaterial
		material.set_shader_parameter("cloud_color", light)
		material.set_shader_parameter("highlight_color", light.lightened(0.15))
		material.set_shader_parameter("mid_color", light.lerp(shadow, 0.5))
		material.set_shader_parameter("shadow_color", shadow)
		material.set_shader_parameter("deep_color", shadow.darkened(0.3))

## 覆っている量を、雲の量と濃さ・もやに反映する
func _apply() -> void:
	var a := clampf(_amount, 0.0, 1.0)
	for i in _layers.size():
		var material := _layers[i].material as ShaderMaterial
		var k := a if i == 0 else clampf(a * 1.3 - 0.15, 0.0, 1.0)
		material.set_shader_parameter("coverage", lerpf(0.05, 1.0, k))
		material.set_shader_parameter("opacity", clampf(k * 1.6, 0.0, 1.0))
	_haze.color.a = clampf(a * 0.85, 0.0, 0.7)

func _set_amount(value : float) -> void:
	_amount = value
	_apply()

## 雲の先が、画面の上から to の高さまで湧いてきたくらいに覆う(FogOverlay.descend_to と同じ使い方)
func descend_to(to : float, time : float) -> void:
	var tween := create_tween()
	tween.tween_method(_set_amount, _amount, clampf(to * 1.2, 0.0, 0.85), time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(self, "_speed_scale", 2.5, time)
	await tween.finished

## time 秒かけて、画面がすべて雲で覆われる
func descend(time : float) -> void:
	var tween := create_tween()
	tween.tween_method(_set_amount, _amount, 1.0, time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self, "_speed_scale", 3.5, time)
	await tween.finished

## はじめから画面が雲で覆われている(前のステージから降りてきたところ)
func cover() -> void:
	_speed_scale = 3.5
	_set_amount(1.0)

## time 秒かけて、雲がちぎれるように切れていき、もやの向こうに地上が見えてくる。色は昼の雲へ移る。晴れたら消える
func dissolve(time : float) -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_method(_set_amount, 1.0, 0.0, time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "_speed_scale", 1.0, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_method(func(t : float) -> void: _set_colors(carried_light.lerp(clear_light, t), carried_shadow.lerp(clear_shadow, t)),
			0.0, 1.0, time * 0.7)
	await tween.finished
	queue_free()

## FogOverlay と同じ問い合わせ(覆っている量)
func front_edge() -> float:
	return _amount
