extends Node2D
## 裏ボス Union の、独自の青いエネルギー弾の見た目(E_Blue_Energy の子に置く)。絵は使わず、描いて作る。
##   ・青い光のにじみが、脈打つ
##   ・まわりを、細い光の輪が2本、逆向きに回る
##   ・ぎざぎざの青白い放電が、ぱちぱちと走る
##   ・真ん中は、白く光る芯
## 光は加算で重ねる(暗い空で、よく光る)

## 光のにじみの大きさ(弾の大きさ 1 のときの px)
@export var glow_radius : float = 13.0

var _t : float = 0.0
var _rng := RandomNumberGenerator.new()
var _spark_seed : int = 0
var _spark_wait : float = 0.0

func _ready() -> void:
	_t = randf() * 10.0
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive

func _process(delta : float) -> void:
	_t += delta
	_spark_wait -= delta
	if _spark_wait <= 0.0:
		_spark_wait = 0.06
		_spark_seed += 1 # 放電の形を、ときどき変える
	queue_redraw()

func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_t * 9.0)
	# 光のにじみ(外ほど薄い)
	for i in 5:
		var r := glow_radius * (1.0 - 0.15 * i) + pulse * 1.5
		draw_circle(Vector2.ZERO, r, Color(0.08, 0.35, 1.0, 0.07 + 0.04 * i))
	# 逆向きに回る、光の輪
	var spin := _t * 4.0
	draw_arc(Vector2.ZERO, glow_radius * 0.72 + pulse, spin, spin + PI * 1.3, 24, Color(0.45, 0.85, 1.0, 0.9), 1.4, true)
	draw_arc(Vector2.ZERO, glow_radius * 0.6, -spin * 1.3, -spin * 1.3 + PI, 24, Color(0.25, 0.55, 1.0, 0.8), 1.0, true)
	# 放電(ぎざぎざの線が、芯から外へ)
	_rng.seed = _spark_seed
	for k in 3:
		var a := _rng.randf() * TAU
		var points := PackedVector2Array()
		var segs := 4
		for s in segs + 1:
			var f := float(s) / segs
			var d := lerpf(glow_radius * 0.35, glow_radius * 1.05, f)
			points.append(Vector2.from_angle(a + _rng.randf_range(-0.35, 0.35) * f) * d)
		draw_polyline(points, Color(0.7, 0.92, 1.0, 0.85), 1.0, true)
	# 芯
	draw_circle(Vector2.ZERO, glow_radius * 0.42, Color(0.3, 0.7, 1.0, 0.95))
	draw_circle(Vector2.ZERO, glow_radius * 0.25 + pulse * 0.6, Color(0.92, 0.98, 1.0, 1.0))
