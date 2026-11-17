extends Node2D
class_name SkyBackground
## 空中戦の背景(ステージ3)。ステージのシーンに置く。カメラに映っている範囲に、奥から順に描く:
##   1. 夕焼けの空(上から下へのグラデーション)
##   2. はるか下を流れる海(絵を縦に繰り返し、夕日の色に寄せて霞ませる)
##   3. 一番下の雲: 画面の左右に寄った雲の土手(ゆっくり流れる)
##   4. 背景の敵の群れ(BackgroundSwarm。小さく薄い編隊が、雲のあいだを飛び回る)
##   5. 中層の雲: いろいろな形の雲(雲の隙間から海が見える)
##   6. 上層の雲(速く流れる。薄くして、敵や弾の邪魔をしない)
## 飛行の動き: 背景全体をゆっくり回し(ロール)、斜めに傾け(奥行き)、雲の層ごとに横へずらして(旋回)、
## 空を飛び回っているように見せる。敵・弾・自機は動かさない(背景だけ)。
## 流れる速さには、StageRunner のスクロール倍率(ScrollSpeedEvent・ボス戦の加速)が掛かる。

const CLOUD_SHADER := preload("res://Shaders/sky_clouds.gdshader")

@export_group("空")
## 空の色(上・真ん中・下)。夕暮れ
@export var sky_top : Color = Color(0.55, 0.36, 0.58)
@export var sky_middle : Color = Color(0.98, 0.62, 0.45)
@export var sky_bottom : Color = Color(1.0, 0.84, 0.62)

@export_group("海")
## はるか下の海の絵(縦につながる絵)。空なら出さない
@export var sea_texture : Texture2D
## 絵が横に何コマ並んでいるか(1コマ目を使う)
@export var sea_hframes : int = 1
## 大きさがあれば、絵のこの範囲(px)だけを切り出して、縦に繰り返す(絵の中の文字などを避ける)
@export var sea_region : Rect2i = Rect2i()
## 海の大きさの倍率と、流れる速さ(px/秒)
@export var sea_scale : float = 1.0
@export var sea_speed : float = 24.0
## 海の色(夕日の色に寄せて、霞ませる)
@export var sea_tint : Color = Color(0.55, 0.5, 0.7, 0.22)

@export_group("雲")
## 雲の色(白くて夕日がかった色)と、影の色
@export var cloud_color : Color = Color(1.0, 0.95, 0.9)
@export var cloud_shadow : Color = Color(0.96, 0.7, 0.6)
## 一番下の雲(左右に寄った雲): 量・流れる速さ・不透明度・左右に寄せる強さ
@export var side_coverage : float = 0.4
@export var side_speed : float = 0.07
@export var side_opacity : float = 0.9
@export var side_bias : float = 0.45
## 中層の雲: 量・流れる速さ(画面の高さ / 秒)・不透明度
@export var low_coverage : float = 0.3
@export var low_speed : float = 0.12
@export var low_opacity : float = 0.95
## 上の雲: 量・流れる速さ・不透明度
@export var high_coverage : float = 0.2
@export var high_speed : float = 0.35
@export var high_opacity : float = 0.35

@export_group("飛行の動き")
## 動きの強さ(0 で動かない、1 で標準)
@export var motion_strength : float = 1.0
## ロール(背景を回す)のいちばん大きい角度(度)
@export var roll_deg : float = 12.0
## 傾き(斜めにゆがめて、奥行きを出す)のいちばん大きい量
@export var skew_amount : float = 0.12
## 旋回(雲を横へ流す)の速さ(画面の幅 / 秒)
@export var yaw_speed : float = 0.09
## 背景を、画面より何倍大きく描くか(回したときに、すみが見えないように)
@export var oversize : float = 1.8
## 雑魚の場面では、ななめ上へ進む(背景がななめに流れる)。その角度(度)と、左右を切り替える間隔(秒)
@export var flow_angle_deg : float = 24.0
@export var flow_switch_time : float = 11.0
## ステージの時間がこれを過ぎたら、まっすぐ前へ進む(決戦の前)。負ならしない。
## ボス・中ボスが出ているあいだも、まっすぐ前へ進む
@export var forward_after_time : float = -1.0
## ステージの時間がこの秒数になるまでは、背景の群れ(と影)を出さない(最初のボスの顔見せを邪魔しないように)。0 なら最初から
@export var swarm_after_time : float = 0.0

@export_group("")
## 描く高さ(地面より奥。敵・弾・自機より奥)
@export var background_z : int = -20

var _rig : Node2D
var _size : Vector2 = Vector2.ONE
var _sky : TextureRect
var _sea : Sprite2D
var _sea_tex : Texture2D
var _sea_frame_w : float = 1.0
var _sea_offset : float = 0.0
var _side : ColorRect
var _side_scroll : float = 0.0
var _low : ColorRect
var _high : ColorRect
var _low_scroll : float = 0.0
var _high_scroll : float = 0.0
var _swarm : BackgroundSwarm
var _time : float = 0.0
var _yaw : float = 0.0
## 進む向き(ラジアン。0 でまっすぐ前、プラスで右ななめ上へ進む)と、目標の向き
var _heading : float = 0.0
var _heading_target : float = 0.0
var _flow_timer : float = 0.0
var _flow_side : float = 1.0
## ななめに進むぶんの、層ごとの横の流れ(画面の幅 = 1)と、海の横の流れ(絵の px)
var _flow_side_layer : float = 0.0
var _flow_low : float = 0.0
var _flow_high : float = 0.0
var _flow_sea : float = 0.0

func _ready() -> void:
	add_to_group("background_scroller") # StageRunner が、スクロールする背景があると分かるように
	add_to_group("sky_background")
	z_as_relative = false
	z_index = background_z
	_rig = Node2D.new()
	add_child(_rig)
	# 1. 空
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gradient.colors = PackedColorArray([sky_top, sky_middle, sky_bottom])
	var gradient_texture := GradientTexture2D.new()
	gradient_texture.gradient = gradient
	gradient_texture.fill_from = Vector2(0.5, 0.0)
	gradient_texture.fill_to = Vector2(0.5, 1.0)
	gradient_texture.width = 8
	gradient_texture.height = 128
	_sky = TextureRect.new()
	_sky.texture = gradient_texture
	_sky.stretch_mode = TextureRect.STRETCH_SCALE
	_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rig.add_child(_sky)
	# 2. 海
	if sea_texture:
		_sea_tex = sea_texture
		_sea_frame_w = float(sea_texture.get_width()) / maxi(sea_hframes, 1)
		if sea_region.size.x > 0 and sea_region.size.y > 0:
			var image := sea_texture.get_image()
			if image:
				if image.is_compressed():
					image.decompress()
				_sea_tex = ImageTexture.create_from_image(image.get_region(sea_region))
				_sea_frame_w = float(sea_region.size.x)
		_sea = Sprite2D.new()
		_sea.texture = _sea_tex
		_sea.centered = false
		_sea.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_sea.texture_repeat = CanvasItem.TEXTURE_REPEAT_MIRROR # 鏡写しで繰り返して、つなぎ目で途切れないように
		_sea.region_enabled = true
		_sea.modulate = sea_tint
		_rig.add_child(_sea)
	# 3. 一番下の雲(左右)
	_side = _make_clouds(side_coverage, side_opacity)
	var side_material := _side.material as ShaderMaterial
	side_material.set_shader_parameter("side_bias", side_bias)
	side_material.set_shader_parameter("side_width", 0.42) # 背景を大きく描くぶん、端の雲を広めに
	side_material.set_shader_parameter("cloud_scale", 1.3)
	# 4. 背景の敵の群れ
	_swarm = BackgroundSwarm.new()
	_swarm.quiet = swarm_after_time > 0.0
	_rig.add_child(_swarm)
	# 5・6. 中層・上層の雲
	_low = _make_clouds(low_coverage, low_opacity)
	_high = _make_clouds(high_coverage, high_opacity)
	_follow_view()
	_connect_runner.call_deferred()

## 背景から出てくる敵がもうすぐ来ると知らせてもらう(背景に同じ編隊の影を出す)
func _connect_runner() -> void:
	var runner := get_tree().get_first_node_in_group("stage_runner") as StageRunner
	if runner and not runner.enemy_incoming.is_connected(_on_enemy_incoming):
		runner.enemy_incoming.connect(_on_enemy_incoming)
	if runner and not runner.stage_signal.is_connected(_on_stage_signal):
		runner.stage_signal.connect(_on_stage_signal)

## ボス・中ボスの WARNING が出たら、背景の群れは画面の外へ去っていく
func _on_stage_signal(signal_name : String, _text : String) -> void:
	if signal_name == "warning" and _swarm:
		_swarm.scatter()

## 敵のシーンの絵・大きさ・移動パターン(影を作るために、1回だけ調べて覚えておく)
var _scene_info : Dictionary = {}

func _info(scene : PackedScene) -> Dictionary:
	if _scene_info.has(scene):
		return _scene_info[scene]
	var info := {"texture": null, "scale": 1.0, "pattern": null}
	var enemy := scene.instantiate() as Node2D
	if enemy:
		var sprite := enemy.get_node_or_null("Sprite2D") as Sprite2D
		if sprite:
			info["texture"] = sprite.texture
			info["scale"] = absf(sprite.scale.x * enemy.scale.x)
		info["pattern"] = enemy.get("pattern")
		enemy.free()
	_scene_info[scene] = info
	return info

func _on_enemy_incoming(event : SpawnEvent, seconds : float) -> void:
	if _swarm == null or event.enemy_scene == null:
		return
	var info := _info(event.enemy_scene)
	var pattern : MovePattern = event.move_pattern if event.move_pattern else info["pattern"]
	var base := Vector2(240.0, 140.0)
	if pattern:
		base = pattern.start_position
		for step in pattern.steps:
			if step.mode != MoveStep.Mode.CHASE:
				base = base + step.target if step.relative else step.target
			break
	var points : Array[Vector2] = []
	for i in event.unit_count():
		var world := base + event.offset + event.offset_step * i
		points.append(_swarm.to_local(world))
	_swarm.foreshadow(info["texture"], points, seconds, info["scale"])

func _make_clouds(coverage : float, opacity : float) -> ColorRect:
	var rect := ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = CLOUD_SHADER
	material.set_shader_parameter("cloud_color", cloud_color)
	material.set_shader_parameter("shadow_color", cloud_shadow)
	material.set_shader_parameter("coverage", coverage)
	material.set_shader_parameter("sky_alpha", 0.0) # 雲の隙間から、下が見える
	material.set_shader_parameter("opacity", opacity)
	rect.material = material
	_rig.add_child(rect)
	return rect

## 背景の敵の群れ(雲のあいだを飛ぶ)
func swarm() -> BackgroundSwarm:
	return _swarm

func _process(delta : float) -> void:
	_time += delta
	var runner := get_tree().get_first_node_in_group("stage_runner") as StageRunner
	var speed := runner.scroll_multiplier if runner else 1.0
	_sea_offset += sea_speed * speed * delta
	_side_scroll += side_speed * speed * delta
	_low_scroll += low_speed * speed * delta
	_high_scroll += high_speed * speed * delta
	# 旋回: ゆっくり左右に向きを変えながら、雲を横へ流す
	var k := motion_strength
	_yaw += yaw_speed * k * (sin(_time * 0.11) + 0.6 * sin(_time * 0.29 + 2.0)) * delta
	# 進む向き: 雑魚の場面はななめ上(ときどき左右を切り替える)、ボス・中ボスのときと決戦の前はまっすぐ前
	var forward := (forward_after_time >= 0.0 and runner and runner.stage_time >= forward_after_time) 		or not get_tree().get_nodes_in_group("stage_boss").is_empty() 		or not get_tree().get_nodes_in_group("stage_midboss").is_empty()
	_flow_timer -= delta
	if _flow_timer <= 0.0:
		_flow_timer = flow_switch_time * randf_range(0.8, 1.2)
		_flow_side = -_flow_side
	_heading_target = 0.0 if forward else deg_to_rad(flow_angle_deg) * _flow_side * k
	_heading = move_toward(_heading, _heading_target, delta * 0.35)
	# ななめに進むぶん、背景を横へも流す(縦に流れた量 × tan(向き)。画面の幅に直す)
	var slant := tan(_heading) * (_size.y / maxf(_size.x, 1.0))
	_flow_side_layer += slant * side_speed * speed * delta
	_flow_low += slant * low_speed * speed * delta
	_flow_high += slant * high_speed * speed * delta
	_flow_sea += tan(_heading) * sea_speed * speed * delta
	(_side.material as ShaderMaterial).set_shader_parameter("scroll", _side_scroll)
	(_low.material as ShaderMaterial).set_shader_parameter("scroll", _low_scroll)
	(_high.material as ShaderMaterial).set_shader_parameter("scroll", _high_scroll)
	(_side.material as ShaderMaterial).set_shader_parameter("drift", _yaw * 0.5 + _flow_side_layer)
	(_low.material as ShaderMaterial).set_shader_parameter("drift", _yaw * 1.0 + _flow_low)
	(_high.material as ShaderMaterial).set_shader_parameter("drift", _yaw * 1.7 + _flow_high)
	if _swarm:
		_swarm.scroll_speed = speed
		_swarm.quiet = swarm_after_time > 0.0 and (runner == null or runner.stage_time < swarm_after_time)
	_follow_view()

## カメラに映っている範囲の真ん中に、背景を回して・傾けて置く
func _follow_view() -> void:
	var view := CameraView.visible_rect(self)
	var k := motion_strength
	_size = view.size * oversize
	_rig.global_position = view.get_center()
	# ロール(ゆっくり大きく + 少し速く小さく)と、傾き(奥行き)と、ほんの少しの遠近(寄ったり離れたり)
	_rig.rotation = deg_to_rad(roll_deg) * k * (0.7 * sin(_time * 0.19) + 0.3 * sin(_time * 0.47 + 1.3)) - _heading * 0.35 # 進む向きへ少し傾く
	_rig.skew = skew_amount * k * sin(_time * 0.15 + 0.7)
	var zoom := 1.0 + 0.05 * k * sin(_time * 0.23 + 0.4)
	_rig.scale = Vector2(zoom, zoom)
	var corner := -_size * 0.5
	_sky.position = corner
	_sky.size = _size
	if _sea:
		var frame_w := _sea_frame_w
		var s := maxf(_size.x / frame_w, sea_scale)
		_sea.scale = Vector2(s, s)
		_sea.position = corner
		# 縦に繰り返す絵を下へ流し、旋回にあわせて少し横へずらす
		_sea.region_rect = Rect2(_yaw * 0.3 * frame_w + _flow_sea / s, -_sea_offset / s, frame_w, _size.y / s)
	for rect in [_side, _low, _high]:
		rect.position = corner
		rect.size = _size
		var material := rect.material as ShaderMaterial
		material.set_shader_parameter("rect_size", _size)
		material.set_shader_parameter("aspect", _size.x / maxf(_size.y, 1.0))
	if _swarm:
		_swarm.area = Rect2(corner, _size)
