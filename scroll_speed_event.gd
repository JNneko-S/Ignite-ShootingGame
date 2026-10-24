@tool
extends StageEvent
class_name ScrollSpeedEvent
## 背景のスクロール速度を変える(Parallax2D の autoscroll を、倍率で変える)。

## 1.0 = 元の速度。0 で停止(ボス戦など)、2.0 で2倍
@export var speed_multiplier : float = 1.0
## 変化にかける時間(秒)。0 なら即座に変わる
@export var duration : float = 1.0

func execute(runner : StageRunner, _unit_index : int) -> void:
	runner.set_scroll_speed(speed_multiplier, duration)
