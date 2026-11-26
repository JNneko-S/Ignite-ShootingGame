extends Node2D
class_name UnionView
## 裏ボス Union(3D のモデル)の姿を、2D の画面に出す。
## 自分の中に小さな 3D の世界(SubViewport)を作って Union の 3D シーンを置き、映った映像を Sprite2D で表示する。
## 3D シーン(GameScene/Enemy/SECRET/Union.tscn)のカメラと、アニメーション(Awake / Open / Close / Idle / RageStart / Raging / RageEnd)を使う。

const UNION_3D := preload("res://GameScene/Enemy/SECRET/Union.tscn")

## 3D を描く大きさ(px)と、画面に出す大きさ(直径 px)
@export var view_size : Vector2i = Vector2i(512, 512)
@export var display_size : float = 270.0
## 明かり(3D シーンには明かりがないので、ここで足す)
@export var light_energy : float = 1.3
@export var light_color : Color = Color(1.0, 0.92, 0.95)
@export var ambient_color : Color = Color(0.55, 0.45, 0.6)
@export var ambient_energy : float = 0.8
## 最初に流すアニメーション
@export var start_animation : StringName = &"Idle"

var _viewport : SubViewport
var _sprite : Sprite2D
var _anim : AnimationPlayer
var _model : Node3D

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return # 画面のない実行(テスト)では、3D を描かない(描く先がない)。当たり判定などはそのまま
	_viewport = SubViewport.new()
	_viewport.size = view_size
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.msaa_3d = Viewport.MSAA_4X
	add_child(_viewport)
	_model = UNION_3D.instantiate() as Node3D
	_viewport.add_child(_model)
	var light := DirectionalLight3D.new()
	light.light_energy = light_energy
	light.light_color = light_color
	_viewport.add_child(light)
	light.look_at_from_position(Vector3(12.0, 7.0, 5.0), Vector3.ZERO) # カメラ(+x の側)の、斜め上から照らす
	var rim := DirectionalLight3D.new()
	rim.light_energy = light_energy * 0.5
	rim.light_color = Color(0.85, 0.2, 0.35)
	_viewport.add_child(rim)
	rim.look_at_from_position(Vector3(-6.0, -4.0, -8.0), Vector3.ZERO) # 後ろ下から、赤い縁の光
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient_color
	env.ambient_light_energy = ambient_energy
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	_viewport.add_child(world_env)
	_sprite = Sprite2D.new()
	_sprite.texture = _viewport.get_texture()
	_sprite.scale = Vector2.ONE * (display_size / float(view_size.x))
	add_child(_sprite)
	_anim = _model.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if _anim:
		for loop_name in [&"Idle", &"Raging"]:
			if _anim.has_animation(loop_name):
				_anim.get_animation(loop_name).loop_mode = Animation.LOOP_LINEAR
	play(start_animation)

## アニメーションを流す(名前がなければ何もしない)
func play(anim_name : StringName, blend : float = 0.15) -> void:
	if _anim and _anim.has_animation(anim_name):
		_anim.play(anim_name, blend)

## 今のアニメーションが終わったら、次に流す
func queue(anim_name : StringName) -> void:
	if _anim and _anim.has_animation(anim_name):
		_anim.queue(anim_name)

## アニメーションの長さ(秒。なければ 0)
func length_of(anim_name : StringName) -> float:
	if _anim and _anim.has_animation(anim_name):
		return _anim.get_animation(anim_name).length
	return 0.0

## 画面に出している半径(px。当たり判定の目安)
func radius() -> float:
	return display_size * 0.5

## 向きを変える(度。0 で正面、90 で右向き、-90 で左向き。横向きにすると、口が進む向きに開く)
func set_facing(degrees : float, time : float = 0.0) -> void:
	var legion := _model.get_node_or_null("legion") as Node3D if _model else null
	if legion == null:
		return
	if time <= 0.0:
		legion.rotation_degrees.y = degrees
		return
	var tween := legion.create_tween()
	tween.tween_property(legion, "rotation_degrees:y", degrees, time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## 口の開き方を、アニメーションを止めて直に決める(kuti: 口の縁が開く / hiraku: 上下にあごが開く。どちらも 0〜1)
func set_jaw(kuti : float, hiraku : float) -> void:
	var mesh := _mesh()
	if mesh == null:
		return
	if _anim:
		_anim.stop(true)
	mesh.set("blend_shapes/kuti", kuti)
	mesh.set("blend_shapes/hiraku", hiraku)

## 今の口の開き方 [kuti, hiraku]
func jaw() -> Vector2:
	var mesh := _mesh()
	if mesh == null:
		return Vector2.ZERO
	return Vector2(float(mesh.get("blend_shapes/kuti")), float(mesh.get("blend_shapes/hiraku")))

func _mesh() -> Node3D:
	return _model.get_node_or_null("legion/球_003") as Node3D if _model else null

## 今の姿を写した絵(残像に使う)。画面のない実行では null
func snapshot() -> Texture2D:
	if _viewport == null:
		return null
	return ImageTexture.create_from_image(_viewport.get_texture().get_image())

## 姿の Sprite2D の大きさ(残像を同じ大きさで出すのに使う)
func sprite_scale() -> Vector2:
	return _sprite.scale if _sprite else Vector2.ONE
