extends Node2D
class_name WarpGate
## ワープゲート。ノードを置いて open_gate() / close_gate() を呼ぶ(見た目はシェーダーで作る)。
## 開いている間は、周りの光の粒(オーブ)がゲートへ吸い込まれる。

const GATE_SHADER : Shader = preload("res://Shaders/warp_gate.gdshader")

## ゲートの半径(px、全開のときの横幅の半分)
@export var radius : float = 120.0
## 縦横の比(0.55 なら横長の楕円)
@export var squash : float = 0.55
@export var ring_color : Color = Color(0.55, 0.9, 1.0)
@export var core_color : Color = Color(0.35, 0.2, 0.9)

var _rect : ColorRect
var _material : ShaderMaterial
var _gather : OrbParticles
var _burst : OrbParticles

func _ready() -> void:
	_material = ShaderMaterial.new()
	_material.shader = GATE_SHADER
	_material.set_shader_parameter("squash", squash)
	_material.set_shader_parameter("ring_color", ring_color)
	_material.set_shader_parameter("core_color", core_color)
	_material.set_shader_parameter("rect_size", Vector2.ONE * radius * 2.4)
	_rect = ColorRect.new()
	_rect.material = _material
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.size = Vector2.ONE * radius * 2.4
	_rect.position = -_rect.size * 0.5
	add_child(_rect)
	_set_open(0.0)

	_gather = OrbParticles.new()
	_gather.mode = OrbParticles.Mode.GATHER
	_gather.radius = radius * 1.3
	_gather.orb_color = ring_color
	_gather.emitting = false
	add_child(_gather)

	_burst = OrbParticles.new()
	_burst.mode = OrbParticles.Mode.BURST
	_burst.radius = radius
	_burst.speed = 320.0
	_burst.orb_color = ring_color
	add_child(_burst)

## ゲートを開く。返り値の Tween を待てば、開き終わるまで待てる
func open_gate(duration : float = 0.6) -> Tween:
	_gather.emitting = true
	var tween := create_tween()
	tween.tween_method(_set_open, 0.0, 1.0, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tween

## 光の粒を、ゲートから一気に弾けさせる(何かが出てくる瞬間に)
func flash() -> void:
	_burst.burst()

## ゲートを閉じる
func close_gate(duration : float = 0.4) -> Tween:
	_gather.emitting = false
	var tween := create_tween()
	tween.tween_method(_set_open, 1.0, 0.0, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	return tween

func _set_open(value : float) -> void:
	_material.set_shader_parameter("open", value)
