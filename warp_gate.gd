extends Node2D
class_name WarpGate
## ワープゲート。シーン(GameScene/Intro/warp_gate.tscn)を置いて open_gate() / close_gate() を呼ぶ。
## 見た目は子の Surface(ColorRect + warp_gate.gdshader)、光の粒は Gather(吸い込み)と Burst(弾ける)。
## 大きさや色は、シーンの中で変える(Surface のシェーダーの値と、粒の ParticleProcessMaterial)。

@onready var _surface : ColorRect = $Surface
@onready var _gather : GPUParticles2D = $Gather
@onready var _burst : GPUParticles2D = $Burst

func _ready() -> void:
	_set_open(0.0)

## ゲートを開く。返り値の Tween を待てば、開き終わるまで待てる
func open_gate(duration : float = 0.6) -> Tween:
	_gather.emitting = true
	var tween := create_tween()
	tween.tween_method(_set_open, 0.0, 1.0, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tween

## 光の粒を、ゲートから一気に弾けさせる(何かが出てくる瞬間に)
func flash() -> void:
	_burst.restart()

## ゲートを閉じる
func close_gate(duration : float = 0.4) -> Tween:
	_gather.emitting = false
	var tween := create_tween()
	tween.tween_method(_set_open, 1.0, 0.0, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	return tween

func _set_open(value : float) -> void:
	(_surface.material as ShaderMaterial).set_shader_parameter("open", value)
