extends Node2D
class_name RailSparks
## 車輪とレールがこすれて飛ぶ火花。短く光る線が、飛び散って、すぐ消える。
## RailSparks.emit() で出す(シーンに1つだけ自動で作る)。爆発の絵を使わないので、軽くて火花らしく見える。

const MAX_SPARKS : int = 600

## 火花の色(先が白く、尾が橙)
@export var head_color : Color = Color(1.0, 0.98, 0.85)
@export var tail_color : Color = Color(1.0, 0.55, 0.15)

var _sparks : Array[Dictionary] = [] # { p, v, life, max }

func _ready() -> void:
	z_as_relative = false
	z_index = 0 # 地面より上、列車(z 1)より下(車輪の下から飛び散るように見せる)

## at から、dir の向きを中心に、count 個の火花を飛ばす(dir の長さは速さ px/秒)
static func emit(tree : SceneTree, at : Vector2, dir : Vector2, count : int = 4, spread_deg : float = 50.0) -> void:
	var node := tree.get_first_node_in_group("rail_sparks") as RailSparks
	if node == null:
		node = RailSparks.new()
		node.add_to_group("rail_sparks")
		tree.current_scene.add_child(node)
	for i in count:
		if node._sparks.size() >= MAX_SPARKS:
			node._sparks.pop_front()
		var v := dir.rotated(deg_to_rad(randf_range(-spread_deg, spread_deg) * 0.5)) * randf_range(0.5, 1.2)
		var life := randf_range(0.12, 0.32)
		node._sparks.append({"p": at, "v": v, "life": life, "max": life})

func _process(delta : float) -> void:
	for i in range(_sparks.size() - 1, -1, -1):
		var s := _sparks[i]
		s["life"] -= delta
		if s["life"] <= 0.0:
			_sparks.remove_at(i)
			continue
		s["v"] *= 1.0 - 3.0 * delta # すぐに減速する
		s["p"] += s["v"] * delta
	queue_redraw()

func _draw() -> void:
	var inv := get_global_transform().affine_inverse()
	for s in _sparks:
		var k : float = s["life"] / s["max"]
		var p : Vector2 = inv * s["p"]
		var tail : Vector2 = p - s["v"] * 0.035
		draw_line(tail, p, Color(tail_color, k), 2.0)
		draw_line(p - s["v"] * 0.012, p, Color(head_color, k), 2.5)
