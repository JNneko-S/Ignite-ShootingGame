extends Node2D
class_name FogOverlay
## ステージとステージのあいだの霧。ステージのシーンに置く(StageTransition が作る)。
## カメラに映っている範囲に、霧の帯(Shaders/fog_band.gdshader)を描く。
## Z Index は自機より下にするので、自機は霧の上を飛んでいるように見える(StageTransition が自機を上にする)。
##   descend() … 霧が上から降りてきて、画面が覆われる
##   cover()   … はじめから画面が覆われている
##   clear()   … 霧の終わりが上から下へ過ぎていき、晴れる(霧を抜ける)

const SHADER := preload("res://Shaders/fog_band.gdshader")

## 霧の模様が流れる速さ(画面の高さ / 秒)。速いほど、霧の中を駆け抜けている感じになる
@export var scroll_speed : float = 1.2
## 描く高さ(自機より下、敵や背景より上)
@export var fog_z_index : int = 50

var _rect : ColorRect
var _material : ShaderMaterial
var _scroll : float = 0.0

func _ready() -> void:
	z_as_relative = false
	z_index = fog_z_index
	_rect = ColorRect.new()
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_rect.material = _material
	add_child(_rect)
	_set_band(0.0, -0.5) # まだ霧はない
	_follow_camera()

func _process(delta : float) -> void:
	_scroll += scroll_speed * delta
	_material.set_shader_parameter("scroll", _scroll)
	_follow_camera()

## カメラに映っている範囲いっぱいに広げる
func _follow_camera() -> void:
	var view := CameraView.visible_rect(self)
	_rect.global_position = view.position
	_rect.size = view.size
	_material.set_shader_parameter("rect_size", view.size)
	_material.set_shader_parameter("aspect", view.size.x / maxf(view.size.y, 1.0))

func _set_band(front : float, back : float) -> void:
	_material.set_shader_parameter("front", front)
	_material.set_shader_parameter("back", back)

func _set_front(value : float) -> void:
	_material.set_shader_parameter("front", value)

func _set_back(value : float) -> void:
	_material.set_shader_parameter("back", value)

## time 秒かけて、霧が上から降りてきて画面を覆う
func descend(time : float) -> void:
	_set_band(-0.2, -0.5)
	var tween := create_tween()
	tween.tween_method(_set_front, -0.2, 1.25, time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tween.finished

## はじめから画面が覆われている
func cover() -> void:
	_set_band(1.25, -0.25)

## time 秒かけて、霧の終わりが上から下へ過ぎていき、晴れる。晴れたら消える
func clear(time : float) -> void:
	var tween := create_tween()
	tween.tween_method(_set_back, -0.25, 1.25, time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween.finished
	queue_free()

## 霧の終わり(晴れたところとの境目)の高さ(画面の上 = 0、下 = 1)
func back_edge() -> float:
	return float(_material.get_shader_parameter("back"))
