extends GPUParticles2D
class_name EffectParticles
## 演出用のパーティクル。ノードを置いて kind を選ぶだけで使える(見た目はコードで作る)。
##
## Kind:
##   MIST     : 大きくて薄い霧のかたまりが、速く流れ去る(雲の中を飛んでいる奥行き)
##   THRUSTER : 噴射の炎。下向き(rotation で向きを変える)に出て、白 → 橙 → 赤 と冷めて消える
##   STREAK   : 中心から光の筋が放射状に飛び散る(ワープの出口が開いた瞬間など)。burst() で鳴らす
##   SPARKLE  : 十字にきらめく星が、範囲の中でまたたく

enum Kind { MIST, THRUSTER, STREAK, SPARKLE }

@export var kind : Kind = Kind.SPARKLE
## MIST: 流れる幅 / STREAK・SPARKLE: 出る範囲の半径 / THRUSTER: 噴射口の幅
@export var radius : float = 80.0
@export var tint : Color = Color(1.0, 1.0, 1.0)
## 粒の大きさの目安(px)
@export var size : float = 12.0
## 速さの目安(px/秒)
@export var speed : float = 300.0

func _ready() -> void:
	if process_material == null:
		_build()

## STREAK のとき、1回飛び散らせる
func burst() -> void:
	restart()
	emitting = true

func _build() -> void:
	var m := ParticleProcessMaterial.new()
	m.gravity = Vector3.ZERO
	m.particle_flag_disable_z = true
	m.color = tint
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	match kind:
		Kind.MIST:
			texture = _soft_texture(int(size))
			material = null # 霧は光らせず、普通に重ねる
			m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			m.emission_box_extents = Vector3(radius * 0.5, 10.0, 0.0)
			m.direction = Vector3(0, 1, 0)
			m.spread = 3.0
			m.initial_velocity_min = speed * 0.7
			m.initial_velocity_max = speed * 1.2
			m.scale_min = 0.6
			m.scale_max = 1.4
			m.angle_min = 0.0
			m.angle_max = 360.0
			m.color_ramp = _ramp([[0.0, 0.0], [0.2, 1.0], [0.8, 1.0], [1.0, 0.0]])
			amount = 14
			lifetime = 1.4
		Kind.THRUSTER:
			texture = _soft_texture(int(size))
			material = add
			m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			m.emission_box_extents = Vector3(radius * 0.5, 1.0, 0.0)
			m.direction = Vector3(0, 1, 0)
			m.spread = 6.0
			m.initial_velocity_min = speed * 0.8
			m.initial_velocity_max = speed * 1.2
			m.scale_min = 0.8
			m.scale_max = 1.2
			m.scale_curve = _curve([[0.0, 1.0], [1.0, 0.2]]) # 噴き出してから細くなる
			m.color_ramp = _color_ramp([
				[0.0, Color(1.0, 1.0, 0.95, 1.0)],
				[0.25, Color(1.0, 0.75, 0.3, 0.9)],
				[0.6, Color(1.0, 0.3, 0.1, 0.6)],
				[1.0, Color(0.6, 0.1, 0.05, 0.0)]])
			m.color = Color.WHITE
			amount = 40
			lifetime = 0.35
		Kind.STREAK:
			texture = _streak_texture(int(size))
			material = add
			m.particle_flag_align_y = true # 筋を、飛ぶ向きにそろえる
			m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			m.emission_sphere_radius = radius * 0.3
			m.direction = Vector3(0, -1, 0)
			m.spread = 180.0
			m.initial_velocity_min = speed * 0.7
			m.initial_velocity_max = speed * 1.3
			m.damping_min = speed * 0.6
			m.damping_max = speed * 1.0
			m.scale_min = 0.6
			m.scale_max = 1.3
			m.color_ramp = _ramp([[0.0, 1.0], [0.5, 0.8], [1.0, 0.0]])
			amount = 36
			lifetime = 0.6
			one_shot = true
			explosiveness = 1.0
			emitting = false
		Kind.SPARKLE:
			texture = _star_texture(int(size))
			material = add
			m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			m.emission_sphere_radius = radius
			m.direction = Vector3(0, -1, 0)
			m.spread = 180.0
			m.initial_velocity_min = speed * 0.02
			m.initial_velocity_max = speed * 0.08
			m.scale_min = 0.5
			m.scale_max = 1.2
			m.scale_curve = _curve([[0.0, 0.0], [0.3, 1.0], [0.5, 0.4], [0.7, 1.0], [1.0, 0.0]]) # 2回またたく
			m.angle_min = -15.0
			m.angle_max = 15.0
			amount = 26
			lifetime = 1.2
	process_material = m

# ---------------------------------------------------------------- 見た目

## 中心が濃く、外側へ透明になる丸
func _soft_texture(px : int) -> Texture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = maxi(px, 2)
	tex.height = maxi(px, 2)
	return tex

## 細長い光の筋(縦向き)
func _streak_texture(length : int) -> Texture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 0))
	gradient.set_color(1, Color(1, 1, 1, 0))
	gradient.add_point(0.6, Color(1, 1, 1, 1))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill_from = Vector2(0.5, 0.0)
	tex.fill_to = Vector2(0.5, 1.0)
	tex.width = 2
	tex.height = maxi(length, 4)
	return tex

## 十字のきらめき(ドット絵に合わせて、画素で描く)
func _star_texture(px : int) -> Texture2D:
	px = maxi(px | 1, 5) # 真ん中の画素があるよう、奇数にする
	var image := Image.create(px, px, false, Image.FORMAT_RGBA8)
	var c := px / 2
	for i in px:
		var d := absi(i - c)
		var a := clampf(1.0 - float(d) / float(c + 1), 0.0, 1.0)
		image.set_pixel(i, c, Color(1, 1, 1, a))
		image.set_pixel(c, i, Color(1, 1, 1, a))
	for dx in [-1, 1]:
		for dy in [-1, 1]:
			image.set_pixel(c + dx, c + dy, Color(1, 1, 1, 0.5))
	return ImageTexture.create_from_image(image)

## [[位置, 透明度], ...] の、白の透明度だけ変わる色の変化
static func _ramp(points : Array) -> GradientTexture1D:
	var colors := []
	for p in points:
		colors.append([p[0], Color(1, 1, 1, p[1])])
	return _color_ramp(colors)

static func _color_ramp(points : Array) -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array()
	gradient.colors = PackedColorArray()
	for p in points:
		gradient.add_point(p[0], p[1])
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	return ramp

static func _curve(points : Array) -> CurveTexture:
	var curve := Curve.new()
	for p in points:
		curve.add_point(Vector2(p[0], p[1]))
	var tex := CurveTexture.new()
	tex.curve = curve
	return tex
