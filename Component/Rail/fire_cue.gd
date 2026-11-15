extends Node2D
class_name FireCue
## 列車のボスが止まってから撃ち始めるまでに、撃つ砲口に出す合図。
## 輪が砲口へ縮みながら集まり、砲口の光がだんだん強くなる。最後に一瞬光って消える(TrainBossMover が作って消す)。
## 砲口が動いても付いていくように、毎フレーム砲口の位置に描く。

var _guns : Array[Node2D] = []
var _life : float = 0.8
var _age : float = 0.0
var _color : Color = Color(1.0, 0.35, 0.15)

## enemy の近く(シーンの直下)に、guns の砲口の合図を time 秒出す
static func spawn(enemy : Node, guns : Array[Node2D], time : float, color : Color) -> FireCue:
	if enemy == null or not enemy.is_inside_tree() or guns.is_empty():
		return null
	var cue := FireCue.new()
	cue._guns = guns
	cue._life = maxf(time, 0.05)
	cue._color = color
	cue.z_as_relative = false
	cue.z_index = 6 # 弾(5)より手前
	enemy.get_tree().current_scene.add_child(cue)
	return cue

func _process(delta : float) -> void:
	_age += delta
	if _age >= _life:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var t := clampf(_age / _life, 0.0, 1.0)
	var points : Array[Vector2] = []
	for gun in _guns:
		if not is_instance_valid(gun) or not gun.is_inside_tree():
			continue
		var p := gun.global_position - global_position
		# 同じ所にある砲口は、1つにまとめる(重ねると濃くなりすぎる)
		var dup := false
		for q in points:
			if q.distance_to(p) < 12.0:
				dup = true
				break
		if not dup:
			points.append(p)
	var blink := 0.6 + 0.4 * absf(sin(_age * TAU * 4.0))
	for p in points:
		# 外から集まってくる輪(2つ、少しずらして)
		for k in 2:
			var s := fmod(t * 2.0 + k * 0.5, 1.0)
			var r := lerpf(40.0, 6.0, s)
			draw_arc(p, r, 0.0, TAU, 32, Color(_color, (0.25 + 0.6 * s) * blink), 2.5)
		# 砲口の光(だんだん大きく、強く)
		draw_circle(p, lerpf(3.0, 9.0, t), Color(_color.lightened(0.4), (0.35 + 0.55 * t) * blink))
		draw_circle(p, lerpf(1.5, 4.0, t), Color(1.0, 1.0, 1.0, 0.5 + 0.5 * t))
		# 撃つ直前に、一瞬白く光る
		if t > 0.85:
			var f := (t - 0.85) / 0.15
			draw_circle(p, lerpf(10.0, 18.0, f), Color(1.0, 1.0, 1.0, 0.6 * (1.0 - f)))
