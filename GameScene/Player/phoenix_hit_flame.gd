extends Node
class_name PhoenixHitFlame
## 自機(フェニックス)が被弾したときの、炎のパーティクル。Player の子に置く(ノード名は HitFlame)。
##   ・被弾して生き残ったとき(イグナイトが残っている) → 弾が飛んできた向きの先へ、炎が「ぼっ」と噴き出す
##     (右上から撃たれたら、炎は左下へ飛ぶ)
##   ・やられたとき(イグナイトがない) → 爆発が起きて、炎が四方へ散る
## 絵は使わず、丸い光の粒を重ねて描く。粒は 白 → 黄 → 橙 → 赤 と色を変えて消える。
## 粒は自機ではなくステージに置くので、自機が消えたあとも最後まで見える。

@export_group("被弾(生き残ったとき)")
## 炎の粒の数
@export var hit_amount : int = 40
## 炎が消えるまでの時間(秒)
@export var hit_lifetime : float = 0.5
## 炎の広がり(度)。弾が飛んできた向きを中心に、±この角度へ広がる
@export var hit_spread_deg : float = 26.0
## 炎が飛び出す速さ(px/秒)。いちばん遅い粒と、いちばん速い粒
@export var hit_speed_min : float = 120.0
@export var hit_speed_max : float = 420.0
## 炎の粒の大きさの倍率
@export var hit_scale : float = 1.0
## 火の粉(小さくて、遠くまで飛ぶ粒)の数
@export var hit_ember_amount : int = 16
## 被弾したときの効果音(AudioStreamPlayer)。空なら鳴らさない
@export var hit_sound : AudioStreamPlayer

@export_group("やられたとき")
## 四方へ散る炎の粒の数
@export var death_amount : int = 80
## 炎が消えるまでの時間(秒)
@export var death_lifetime : float = 0.9
## 炎が散る速さ(px/秒)
@export var death_speed_min : float = 100.0
@export var death_speed_max : float = 460.0
## 炎の粒の大きさの倍率
@export var death_scale : float = 1.3
## ゆっくり落ちていく火の粉の数
@export var death_ember_amount : int = 46
## 爆発の絵の大きさの倍率(0 なら爆発の絵を出さない)
@export var death_explosion_scale : float = 2.2
## やられたときの効果音(AudioStreamPlayer)。空なら鳴らさない
@export var death_sound : AudioStreamPlayer

@export_group("見た目")
## 描く順番。自機(1〜2)より上、敵弾(5)より下にしてあるので、炎で弾が隠れない
@export var z : int = 3
## 炎の色(出たとき → 消えるとき)
@export var color_core : Color = Color(1.0, 0.98, 0.85)
@export var color_hot : Color = Color(1.0, 0.82, 0.3)
@export var color_mid : Color = Color(1.0, 0.5, 0.12)
@export var color_edge : Color = Color(0.95, 0.18, 0.1)

static var _texture : GradientTexture2D
static var _material : CanvasItemMaterial

## 被弾して生き残ったとき。at から、direction(弾が進んでいた向き)へ炎を噴き出す
func burst(at : Vector2, direction : Vector2) -> void:
	if direction.length_squared() < 0.0001:
		direction = Vector2.DOWN
	direction = direction.normalized()
	# 当たった瞬間の、ぱっと広がる光
	_emit(at, direction, 180.0, 10, 0.18, 20.0, 90.0, hit_scale * 1.7, 0.0, Vector2.ZERO)
	# 炎の本体
	_emit(at, direction, hit_spread_deg, hit_amount, hit_lifetime, hit_speed_min, hit_speed_max,
		hit_scale, 340.0, Vector2(0.0, -70.0))
	# 火の粉
	_emit(at, direction, hit_spread_deg * 1.5, hit_ember_amount, hit_lifetime * 1.5,
		hit_speed_max * 0.6, hit_speed_max * 1.4, hit_scale * 0.3, 380.0, Vector2.ZERO)
	SoundManager.play(hit_sound)

## やられたとき。at で爆発して、炎が四方へ散る
func scatter(at : Vector2) -> void:
	if death_explosion_scale > 0.0:
		Explosion.spawn(get_tree(), Explosion.EXPLOSIVE, at, death_explosion_scale)
		Explosion.spawn(get_tree(), Explosion.ZAKO, at, death_explosion_scale * 1.3)
	# 爆発の中心の光
	_emit(at, Vector2.UP, 180.0, 8, 0.25, 20.0, 100.0, death_scale * 1.8, 0.0, Vector2.ZERO)
	# 四方へ散る炎
	_emit(at, Vector2.UP, 180.0, death_amount, death_lifetime, death_speed_min, death_speed_max,
		death_scale, 420.0, Vector2(0.0, -40.0))
	# ゆっくり落ちていく火の粉(羽根が燃えながら落ちるように)
	_emit(at, Vector2.UP, 180.0, death_ember_amount, death_lifetime * 1.8,
		death_speed_min * 0.5, death_speed_max * 0.7, death_scale * 0.3, 260.0, Vector2(0.0, 150.0))
	SoundManager.play(death_sound)

## 粒をまとめて一度に出す。終わったら自分で消える
func _emit(at : Vector2, direction : Vector2, spread_deg : float, amount : int, lifetime : float,
		speed_min : float, speed_max : float, size : float, damping : float, gravity : Vector2) -> void:
	var tree := get_tree()
	if amount <= 0 or tree == null or tree.current_scene == null:
		return
	var p := CPUParticles2D.new()
	p.z_as_relative = false
	p.z_index = z
	p.texture = _get_texture()
	p.material = _get_material()
	p.emitting = false
	p.one_shot = true
	p.amount = amount
	p.lifetime = lifetime
	p.explosiveness = 0.92 # ほぼ同時に出す(「ぼっ」と燃える感じ)
	p.lifetime_randomness = 0.45
	p.direction = direction
	p.spread = spread_deg
	p.initial_velocity_min = speed_min
	p.initial_velocity_max = speed_max
	p.damping_min = damping * 0.7
	p.damping_max = damping
	p.gravity = gravity
	p.scale_amount_min = size * 0.55
	p.scale_amount_max = size * 1.2
	p.scale_amount_curve = _shrink_curve()
	p.color_ramp = _color_ramp()
	tree.current_scene.add_child(p)
	p.global_position = at
	p.emitting = true
	p.finished.connect(p.queue_free)

## 出たときに少しふくらみ、消えるまでに小さくなる
func _shrink_curve() -> Curve:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.7))
	curve.add_point(Vector2(0.15, 1.0))
	curve.add_point(Vector2(1.0, 0.15))
	return curve

func _color_ramp() -> Gradient:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.18, 0.45, 0.75, 1.0])
	gradient.colors = PackedColorArray([
		color_core, color_hot, color_mid, Color(color_edge, 0.8), Color(color_edge.darkened(0.5), 0.0)])
	return gradient

## 真ん中が明るく、外へ行くほど薄くなる丸
static func _get_texture() -> GradientTexture2D:
	if _texture == null:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		gradient.colors = PackedColorArray([Color(1, 1, 1, 0.7), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0)])
		_texture = GradientTexture2D.new()
		_texture.gradient = gradient
		_texture.fill = GradientTexture2D.FILL_RADIAL
		_texture.fill_from = Vector2(0.5, 0.5)
		_texture.fill_to = Vector2(1.0, 0.5)
		_texture.width = 28
		_texture.height = 28
	return _texture

## 重なったところが明るくなる(炎らしく光る)
static func _get_material() -> CanvasItemMaterial:
	if _material == null:
		_material = CanvasItemMaterial.new()
		_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _material
