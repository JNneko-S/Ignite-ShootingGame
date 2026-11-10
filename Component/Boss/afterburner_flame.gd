extends ContactHitbox
class_name AfterburnerFlame
## エンジンから下へ噴き出す炎。触れると自機がやられる。AfterburnerDive が作って動かす(自分で置く必要はない)。
## 絵は使わず、炎の玉をたくさん重ねて描く。玉は噴射口から下へ流れ、ゆらゆら形を変えながら、
## 白 → 黄 → 橙 → 赤 と色を変えて、先のほうで消えていく。

## 噴射の強さ(0〜1)。1 で Length いっぱいまで伸びる
var power : float = 0.0
## 伸びきったときの長さ(px)と太さ(px)
var length : float = 460.0
var width : float = 42.0
## この強さ以上で、当たり判定が出る(弱いあいだは、予告のための見せかけ)
var hurt_power : float = 0.7
## 炎の玉が流れる速さ(px/秒)
var flow_speed : float = 700.0

## 炎の色(噴射口から先へ)
const WHITE := Color(1.0, 0.98, 0.85)
const YELLOW := Color(1.0, 0.82, 0.3)
const ORANGE := Color(1.0, 0.5, 0.12)
const RED := Color(0.95, 0.18, 0.1)
const DARK := Color(0.45, 0.06, 0.06)

var _time : float = 0.0
var _rect : RectangleShape2D

func _init() -> void:
	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	_rect = RectangleShape2D.new()
	shape.shape = _rect
	add_child(shape)
	damage = 1
	damage_source_type = DamageSourceType.Trap
	collision_layer = 32 # 敵の弾と同じ層(自機の Hurtbox が反応する)
	collision_mask = 16  # 自機の Hurtbox(触れ続けているかを見る)
	start_active = false
	z_as_relative = false
	z_index = 2 # 自機(1)より上、敵弾(5)より下。ボスの絵は、あとに並ぶので炎の上に描かれる

func _physics_process(delta : float) -> void:
	_time += delta
	set_active(power >= hurt_power)
	# 当たりは、炎の濃いところ(先の消えかけを除く)
	var hit_length := _current_length() * 0.85
	_rect.size = Vector2(width * 0.55, maxf(hit_length - 12.0, 1.0))
	collision_shape.position = Vector2(0.0, 12.0 + _rect.size.y * 0.5)
	super._physics_process(delta)
	queue_redraw()

func _current_length() -> float:
	return length * power * (1.0 + 0.05 * sin(_time * 17.0) + 0.03 * sin(_time * 41.0))

func _draw() -> void:
	if power <= 0.01:
		return
	var l := _current_length()
	var w := width * lerpf(0.6, 1.0, minf(power, 1.0))
	var spacing := maxf(w * 0.2, 4.0)
	var flowed := _time * flow_speed
	var first := floori(flowed / spacing) # いちばん噴射口に近い玉の番号(玉ごとに形のゆらぎを固定する)
	var count := int(l / spacing) + 2
	# 外の光 → 赤橙 → 黄 → 白い芯 の順に重ねる
	for layer in 4:
		for i in count:
			var y := float(i) * spacing + fmod(flowed, spacing) - spacing * 0.5
			if y < 0.0:
				continue
			var t := y / l
			if t >= 1.0:
				break
			var id := first - i
			var n := _hash(id)
			var radius := w * 0.5 * _envelope(t) * (0.8 + 0.4 * n)
			var x := sin(float(id) * 1.7 + _time * 7.0) * w * 0.14 * t # 先ほど左右に揺れる
			var color := _layer_color(layer, t)
			if color.a <= 0.01:
				continue
			radius *= [1.45, 1.0, 0.68, 0.38][layer]
			draw_circle(Vector2(x, y), radius, color)

## 噴射口で細く、すぐ太くなり、先へ行くほど細くなる
func _envelope(t : float) -> float:
	if t < 0.12:
		return lerpf(0.45, 1.0, t / 0.12)
	if t < 0.55:
		return 1.0
	return lerpf(1.0, 0.3, (t - 0.55) / 0.45)

func _layer_color(layer : int, t : float) -> Color:
	match layer:
		0: # まわりの、ぼんやりした光
			return Color(ORANGE, 0.16 * (1.0 - smoothstep(0.5, 0.9, t)))
		1: # 外側: 橙 → 赤 → 暗い赤で消える
			var c := ORANGE.lerp(RED, smoothstep(0.1, 0.55, t)).lerp(DARK, smoothstep(0.65, 1.0, t))
			return Color(c, 0.92 * (1.0 - smoothstep(0.75, 1.0, t)))
		2: # 中: 黄 → 橙
			var c2 := YELLOW.lerp(ORANGE, smoothstep(0.15, 0.6, t))
			return Color(c2, 1.0 - smoothstep(0.45, 0.75, t))
		_: # 芯: 白
			return Color(WHITE, 1.0 - smoothstep(0.25, 0.5, t))

## 玉の番号から、0〜1 の決まった値を作る(玉ごとの大きさのばらつき)
func _hash(id : int) -> float:
	var v := sin(float(id) * 12.9898) * 43758.5453
	return v - floorf(v)
