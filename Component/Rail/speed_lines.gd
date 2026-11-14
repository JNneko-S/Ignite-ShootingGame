extends Node2D
class_name SpeedLines
## 高速で飛んでいる感じを出す、風の筋。ステージのシーンに置く(ステージ2)。
## 線路の地面(RailGround)の流れが速いほど、筋が濃く・長く・速くなる。ふつうの速さ(Show From 以下)では出ない。
## カメラに映っている範囲に、上から下へ流れる白い筋を描く(_draw)。

## 筋の数
@export var count : int = 46
## 筋が出始める速さと、いちばん濃くなる速さ(地面の流れ、px/秒)
@export var show_from : float = 200.0
@export var full_at : float = 360.0
## 筋の流れる速さ(地面の流れの何倍か)
@export var speed_scale : float = 2.6
## 筋の長さ(地面の流れ 1px/秒 あたり)と、いちばん濃いときの不透明度
@export var length_scale : float = 0.32
@export var max_alpha : float = 0.55
@export var color : Color = Color(0.9, 0.95, 1.0)
## 描く高さ(敵の絵より上、敵の弾より下)
@export var lines_z_index : int = 4

var _lines : Array[Vector3] = [] # x(0〜1), y(0〜1), 速さの倍率
var _amount : float = 0.0

func _ready() -> void:
	z_as_relative = false
	z_index = lines_z_index
	for i in count:
		_lines.append(Vector3(randf(), randf(), randf_range(0.7, 1.3)))

func _process(delta : float) -> void:
	var ground := RailGround.of(self)
	var speed := ground.current_speed if ground else 0.0
	var wanted := clampf((speed - show_from) / maxf(full_at - show_from, 1.0), 0.0, 1.0)
	_amount = move_toward(_amount, wanted, delta * 1.5) # ふわっと出て、ふわっと消える
	if _amount <= 0.001:
		if visible:
			visible = false
		return
	visible = true
	var view := CameraView.visible_rect(self)
	for i in _lines.size():
		var l := _lines[i]
		l.y += speed * speed_scale * l.z * delta / maxf(view.size.y, 1.0)
		if l.y > 1.2:
			l = Vector3(randf(), randf_range(-0.4, -0.1), randf_range(0.7, 1.3))
		_lines[i] = l
	queue_redraw()

func _draw() -> void:
	var view := CameraView.visible_rect(self)
	var ground := RailGround.of(self)
	var speed := ground.current_speed if ground else 0.0
	var inv := get_global_transform().affine_inverse()
	for l in _lines:
		var length := speed * length_scale * l.z
		var head := inv * (view.position + Vector2(l.x * view.size.x, l.y * view.size.y))
		var a := max_alpha * _amount * clampf(l.z - 0.5, 0.3, 1.0)
		draw_line(head - Vector2(0.0, length), head, Color(color, a), 2.0)
		draw_line(head - Vector2(0.0, length * 0.4), head, Color(color, minf(a * 1.4, 1.0)), 3.0)
