extends Node2D
class_name SparkBurst
## バチンと散る火花。SparkBurst.spawn(親, 位置, 数, 色) で出し、すぐ消える。
## 絵は使わず、光る線を描く。線は四方へ飛び散り、だんだん遅くなって消える。

const LIFE : float = 0.35

var color : Color = Color(1.0, 0.8, 0.4)
## 火花: [位置, 速度, 残り時間]
var _sparks : Array = []

## parent の中の at(parent から見た位置)に、count 本の火花を出す
static func spawn(parent : Node, at : Vector2, count : int = 20, spark_color : Color = Color(1.0, 0.8, 0.4)) -> void:
	if parent == null:
		return
	var burst := SparkBurst.new()
	burst.color = spark_color
	burst.position = at
	for i in count:
		var velocity := Vector2.from_angle(randf() * TAU) * randf_range(120.0, 420.0)
		burst._sparks.append([Vector2.ZERO, velocity, LIFE * randf_range(0.5, 1.0)])
	parent.add_child(burst)

func _ready() -> void:
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = add

func _process(delta : float) -> void:
	for i in range(_sparks.size() - 1, -1, -1):
		var spark : Array = _sparks[i]
		spark[2] -= delta
		if spark[2] <= 0.0:
			_sparks.remove_at(i)
			continue
		spark[0] += spark[1] * delta
		spark[1] *= maxf(1.0 - 6.0 * delta, 0.0)
	if _sparks.is_empty():
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	for spark in _sparks:
		var pos : Vector2 = spark[0]
		var velocity : Vector2 = spark[1]
		var alpha := clampf(spark[2] / (LIFE * 0.5), 0.0, 1.0)
		var tail := pos - velocity * 0.05
		draw_line(tail, pos, Color(color, 0.5 * alpha), 3.0)
		draw_line(tail.lerp(pos, 0.4), pos, Color(1.0, 1.0, 0.95, alpha), 1.2)
