extends Node2D
class_name HitboxMarker
## 低速移動中に、自機の当たり判定を分かりやすく表示する印。Player が自動で作る。

var radius : float = 4.0
var alpha : float = 0.0 :
	set(value):
		if not is_equal_approx(alpha, value):
			alpha = value
			queue_redraw()

func _draw() -> void:
	if alpha <= 0.0:
		return
	# 外側の光る輪 → 赤い縁 → 白い芯(芯が実際の当たり判定の大きさ)
	draw_arc(Vector2.ZERO, radius + 6.0, 0.0, TAU, 32, Color(1.0, 0.3, 0.3, alpha * 0.45), 2.0)
	draw_circle(Vector2.ZERO, radius + 2.0, Color(1.0, 0.15, 0.15, alpha))
	draw_circle(Vector2.ZERO, radius, Color(1.0, 1.0, 1.0, alpha))
