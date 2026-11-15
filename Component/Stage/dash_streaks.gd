extends Node2D
class_name DashStreaks
## ステージのあいだで、霧へ加速して突っ込むときの、上から下へ流れる風の筋(StageTransition が作る)。
## Amount(0〜1)で濃さ・長さ・速さが変わる。霧より手前に描くので、霧の中でも速く飛んでいるのが分かる。

## 濃さ(0 = 見えない、1 = いちばん濃い)。StageTransition が tween で変える
var amount : float = 0.0
## 筋の数・いちばん速いときの速さ(画面の高さ / 秒)・長さ(画面の高さに対する割合)
@export var count : int = 40
@export var max_speed : float = 3.2
@export var max_length : float = 0.22
@export var color : Color = Color(1.0, 1.0, 1.0)

var _lines : Array[Vector3] = [] # x(0〜1)、y(0〜1)、速さの倍率

func _ready() -> void:
	z_as_relative = false
	z_index = 55 # 霧(50)より手前、自機(霧の上を飛ぶとき 70)より奥
	for i in count:
		_lines.append(Vector3(randf(), randf(), randf_range(0.6, 1.4)))

func _process(delta : float) -> void:
	for i in _lines.size():
		var l := _lines[i]
		l.y += max_speed * amount * l.z * delta
		if l.y > 1.3:
			l = Vector3(randf(), -0.3, randf_range(0.6, 1.4))
		_lines[i] = l
	queue_redraw()

func _draw() -> void:
	if amount <= 0.01:
		return
	var view := CameraView.visible_rect(self)
	var inv := get_global_transform().affine_inverse()
	for l in _lines:
		var top := view.position + Vector2(l.x * view.size.x, l.y * view.size.y)
		var length := view.size.y * max_length * amount * l.z
		var a := inv * top
		var b := inv * (top + Vector2(0.0, length))
		draw_line(a, b, Color(color, 0.5 * amount), 2.0)
