extends GPUParticles2D
class_name WindParticles
## 風(高速で流れる細い線)のパーティクル。雲の中を飛んでいる速さを出す。
## ノードを置くだけで使える(見た目はコードで作る)。このノードの位置を、線が出る帯の中心にする。

## 線が出る帯の幅(px)。画面の幅に合わせる
@export var width : float = 460.0
## 線の流れる向き(既定は下向き = 自機が上へ進んでいるように見える)
@export var flow_direction : Vector2 = Vector2.DOWN
## 線の速さ(px/秒)
@export var speed : float = 1100.0
## 線の長さ(px)
@export var streak_length : float = 56.0
@export var streak_color : Color = Color(1, 1, 1, 0.55)

func _ready() -> void:
	if process_material == null:
		_build()

func _build() -> void:
	texture = _streak_texture()
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = add

	var m := ParticleProcessMaterial.new()
	m.gravity = Vector3.ZERO
	m.particle_flag_disable_z = true
	m.particle_flag_align_y = true # 線を、流れる向きにそろえる
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(width * 0.5, 8.0, 0.0)
	m.direction = Vector3(flow_direction.x, flow_direction.y, 0.0)
	m.spread = 1.5
	m.initial_velocity_min = speed * 0.75
	m.initial_velocity_max = speed * 1.25
	m.scale_min = 0.6
	m.scale_max = 1.2
	m.color = streak_color
	m.color_ramp = OrbParticles._fade_ramp()
	process_material = m
	amount = 36
	lifetime = 0.7

## 縦長で、両端が透明な線
func _streak_texture() -> Texture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 0))
	gradient.set_color(1, Color(1, 1, 1, 0))
	gradient.add_point(0.7, Color(1, 1, 1, 1))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill_from = Vector2(0.5, 0.0)
	tex.fill_to = Vector2(0.5, 1.0)
	tex.width = 2
	tex.height = int(maxf(streak_length, 4.0))
	return tex
