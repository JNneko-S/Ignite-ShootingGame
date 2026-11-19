extends Node2D
class_name AfterburnerFlame
## 敵の後ろに出す、アフターバーナーの炎(コードで描く)。BackgroundEmerge の「発進」で使う。
## 炎は、親から見て -y の向き(機首の反対)へ伸びる。amount(0〜1)で長さと明るさが変わる

var amount : float = 0.0
## 炎の根元(親から見た位置)。機体の後ろの端に合わせる
var root_offset : float = 12.0
## 炎の長さ(amount = 1 のとき)と、太さ
var length : float = 46.0
var width : float = 7.0
## 炎の数(双発なら 2)と、その間隔
var engines : int = 2
var spacing : float = 8.0
var color : Color = Color(1.0, 0.55, 0.2)

var _time : float = 0.0

func _ready() -> void:
	show_behind_parent = true
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat

func _process(delta : float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	if amount <= 0.01:
		return
	for e in engines:
		var x := (float(e) - float(engines - 1) * 0.5) * spacing
		var flick := 0.8 + 0.2 * sin(_time * 47.0 + e * 1.7) * sin(_time * 31.0)
		var len := length * amount * flick
		var root := Vector2(x, -root_offset)
		var tip := root + Vector2(0.0, -len)
		var w := width * (0.6 + 0.4 * amount)
		# 外側の炎(橙) → 内側の芯(白っぽい青)
		draw_colored_polygon(PackedVector2Array([root + Vector2(-w, 0), root + Vector2(w, 0), tip]),
			Color(color, 0.55 * amount))
		var core_tip := root + Vector2(0.0, -len * 0.55)
		draw_colored_polygon(PackedVector2Array([root + Vector2(-w * 0.45, 0), root + Vector2(w * 0.45, 0), core_tip]),
			Color(0.85, 0.92, 1.0, 0.8 * amount))
		draw_circle(root, w * 1.1, Color(color.lerp(Color.WHITE, 0.4), 0.45 * amount))
