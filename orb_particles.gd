extends GPUParticles2D
class_name OrbParticles
## 光の粒(オーブ)のパーティクル。ノードを置くだけで使える(見た目はコードで作る)。
##
## Mode:
##   GATHER : 輪の上に出て、中心へ吸い込まれていく(ワープゲートなど)
##   BURST  : 中心から一気に弾ける(出現・切り離しの火花など)。burst() で何度でも鳴らせる
##   FLOAT  : 範囲の中で、ゆっくり漂う(雰囲気づくり)

enum Mode { GATHER, BURST, FLOAT }

@export var mode : Mode = Mode.GATHER
## GATHER: 粒が出る輪の半径 / BURST・FLOAT: 粒が出る範囲の半径
@export var radius : float = 90.0
## 粒の色(中心が白く、外側がこの色になる)
@export var orb_color : Color = Color(0.45, 0.85, 1.0)
## 粒の大きさ(px)
@export var orb_size : float = 10.0
## 粒の速さの目安(px/秒)
@export var speed : float = 160.0

func _ready() -> void:
	if process_material == null:
		_build()

## BURST のとき、1回弾けさせる
func burst() -> void:
	restart()
	emitting = true

func _build() -> void:
	texture = _orb_texture()
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD # 重なるほど明るく光る
	material = add

	var m := ParticleProcessMaterial.new()
	m.gravity = Vector3.ZERO
	m.particle_flag_disable_z = true
	m.scale_min = 0.5
	m.scale_max = 1.0
	m.color = orb_color
	m.color_ramp = _fade_ramp()
	match mode:
		Mode.GATHER:
			m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
			m.emission_ring_axis = Vector3(0, 0, 1)
			m.emission_ring_radius = radius
			m.emission_ring_inner_radius = radius * 0.85
			m.emission_ring_height = 0.0
			m.radial_accel_min = -speed * 1.6 # 中心へ吸い込まれる
			m.radial_accel_max = -speed * 1.2
			m.tangential_accel_min = speed * 0.4 # 渦を巻きながら
			m.tangential_accel_max = speed * 0.7
			amount = 48
			lifetime = 0.9
		Mode.BURST:
			m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			m.emission_sphere_radius = radius * 0.2
			m.direction = Vector3(0, -1, 0)
			m.spread = 180.0
			m.initial_velocity_min = speed * 0.6
			m.initial_velocity_max = speed * 1.4
			m.damping_min = speed * 0.8 # 弾けてから、すっと止まる
			m.damping_max = speed * 1.2
			amount = 40
			lifetime = 0.8
			one_shot = true
			explosiveness = 1.0
			emitting = false
		Mode.FLOAT:
			m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			m.emission_sphere_radius = radius
			m.direction = Vector3(0, -1, 0)
			m.spread = 180.0
			m.initial_velocity_min = speed * 0.1
			m.initial_velocity_max = speed * 0.3
			amount = 24
			lifetime = 2.5
	process_material = m

## 中心が白く、外側へ透明になる丸
func _orb_texture() -> Texture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	gradient.add_point(0.35, Color(1, 1, 1, 0.8))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = int(maxf(orb_size, 2.0))
	tex.height = int(maxf(orb_size, 2.0))
	return tex

## 出てすぐ明るくなり、消えるときに薄れる
static func _fade_ramp() -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 0))
	gradient.set_color(1, Color(1, 1, 1, 0))
	gradient.add_point(0.15, Color(1, 1, 1, 1))
	gradient.add_point(0.7, Color(1, 1, 1, 0.8))
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	return ramp
