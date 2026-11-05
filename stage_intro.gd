extends Node2D
class_name StageIntro
## ステージ開始の登場演出。雲の中にワープゲートが開いて母艦が現れ、ワイヤーで自機を降ろして切り離し、去っていく。
## 演出が終わったら、自機を操作できるようにして、StageRunner を開始する。
##
## 使い方: ステージのシーンに置き、StageRunner の Autostart をオフにする。
## ノードの順番は、背景より後、Player より前にする(雲が背景の上、自機の下に出る)。
##
## 流れ:
##   1. 画面が雲で覆われ、雲と風が上から下へ速く流れる
##   2. ワープゲートが開き、光の粒が吸い込まれる
##   3. ゲートから母艦が現れ(光の粒が弾ける)、ゲートが閉じる
##   4. 母艦から2本のワイヤーで自機が吊り下ろされ、定位置で切り離される
##   5. 母艦が加速して上へ去り、雲と風が薄れて流れ去る
##   6. 自機を操作できるようになり、ステージが始まる

signal finished

## false なら演出をせず、すぐにステージを始める(テスト用)
@export var play_intro : bool = true
## 未設定なら "stage_runner" グループから探す
@export var stage_runner : StageRunner
## 未設定なら "player" グループから探す
@export var player : Player

@export_group("母艦")
@export var mothership_texture : Texture2D = preload("res://Assets/Designer.png")
## 母艦の大きさ。画面の幅(448px)に対して、少し小さいくらい
@export var mothership_scale : float = 0.32
## 母艦が止まる位置(画面の中心からのずれ)
@export var mothership_stop_offset : Vector2 = Vector2(0, -60)
## ゲートの位置(母艦が止まる位置からのずれ)。母艦はここから現れて、止まる位置まで上がる
@export var gate_offset : Vector2 = Vector2(0, 70)
@export var gate_radius : float = 130.0

@export_group("ワイヤー")
## ワイヤーを付ける母艦の位置(母艦の中心から。x は左右対称に使う)
@export var cable_anchor : Vector2 = Vector2(22, 150)
## ワイヤーを付ける自機の位置(自機の中心から。x は左右対称に使う)
@export var cable_hook : Vector2 = Vector2(6, -8)
@export var cable_width : float = 3.0
@export var cable_color : Color = Color(0.22, 0.24, 0.28) # 白い雲の上でも見えるよう、暗めにする

## 噴射口の位置(母艦の画像の px、中心から)。後ろ(下)の4つのポッド
@export var thruster_points : Array[Vector2] = [Vector2(-200, 540), Vector2(200, 540), Vector2(-360, 330), Vector2(360, 330)]

@export_group("時間(秒)")
## 雲だけが流れている時間
@export var clouds_only_time : float = 0.5
## ゲートが開くまでの時間
@export var gate_open_time : float = 0.6
## 母艦がゲートから現れて、止まる位置まで上がる時間
@export var emerge_time : float = 1.4
## 自機がワイヤーで吊り下ろされる時間
@export var lower_time : float = 1.1
## 切り離してから、母艦が去り始めるまでの待ち
@export var hold_time : float = 0.5
## 母艦が加速して画面の上へ去る時間
@export var depart_time : float = 1.3
## 雲が薄れて消えるまでの時間(母艦が去り始めると同時に始まる)
@export var clear_time : float = 2.2

@export_group("雲")
## 雲の流れる速さ(画面の高さ / 秒)。演出の最後に clear_speed まで遅くなる
@export var cloud_speed : float = 1.4
@export var clear_speed : float = 0.5
## 演出の始めの雲の量(0〜1)
@export var cloud_coverage : float = 0.55

const CLOUD_SHADER : Shader = preload("res://Shaders/scrolling_clouds.gdshader")

var _clouds : ColorRect
var _cloud_material : ShaderMaterial
var _wind : WindParticles
var _mist : EffectParticles
var _gate_sparkle : EffectParticles
var _gate_streak : EffectParticles
var _thrusters : Array[EffectParticles] = []
var _gate : WarpGate
var _mothership : Sprite2D
var _cables : Array[Line2D] = []
## ワイヤーの、自機側の端がどこまで伸びているか(1 = 自機まで、0 = 母艦の付け根まで巻き上げた)
var _cable_reach : float = 1.0
var _scroll : float = 0.0
var _speed : float = 0.0

func _ready() -> void:
	# 全ノードの準備(Player・StageRunner の _ready)が終わってから始める
	_begin.call_deferred()

func _begin() -> void:
	if stage_runner == null:
		stage_runner = get_tree().get_first_node_in_group("stage_runner") as StageRunner
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Player
	if not play_intro or player == null:
		_finish()
		return
	_play()

func _process(delta : float) -> void:
	if _cloud_material:
		_scroll += _speed * delta
		_cloud_material.set_shader_parameter("scroll", _scroll)
	_update_cables()
	_update_thrusters()

func _play() -> void:
	var area := CameraView.visible_rect(self)
	var stop := area.get_center() + mothership_stop_offset
	_build_clouds(area)
	_build_gate(stop + gate_offset)
	_build_mothership(stop + gate_offset)
	_build_wind(area)
	_build_effects(area, stop + gate_offset)
	_build_cables()

	# 自機は演出のあいだ動かさず(撃たず)、見えないようにしておく
	var spawn := player.global_position
	player.set_physics_process(false)
	player.visible = false
	_speed = cloud_speed

	# 1〜2. 雲と風が流れ、ゲートが開く
	await get_tree().create_timer(clouds_only_time).timeout
	_gate_sparkle.emitting = true # 開くゲートのまわりで、星がまたたく
	await _gate.open_gate(gate_open_time).finished

	# 3. ゲートから母艦が現れる(小さく光った状態から、大きくなりながら上がる)
	_gate.flash()
	_gate_streak.burst() # 光の筋が放射状に飛び散る
	_mothership.visible = true
	for thruster in _thrusters:
		thruster.emitting = true
	var emerge := create_tween().set_parallel(true)
	emerge.tween_property(_mothership, "scale", Vector2.ONE * mothership_scale, emerge_time)\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	emerge.tween_property(_mothership, "global_position", stop, emerge_time)\
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	emerge.tween_property(_mothership, "modulate", Color.WHITE, emerge_time * 0.6)
	await get_tree().create_timer(emerge_time * 0.5).timeout
	_gate.close_gate()
	_gate_sparkle.emitting = false
	await emerge.finished

	# 4. ワイヤーで自機を吊り下ろして、切り離す
	player.global_position = _anchor_point(0.0) + Vector2(0.0, 10.0)
	player.modulate.a = 0.0
	player.visible = true
	_cable_reach = 1.0
	for cable in _cables:
		cable.visible = true
	var lower := create_tween()
	lower.tween_property(player, "modulate:a", 1.0, 0.25)
	lower.parallel().tween_property(player, "global_position", spawn, lower_time)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await lower.finished
	_detach(spawn)
	await get_tree().create_timer(hold_time).timeout

	# 5. 母艦が加速して去り、雲と風が薄れて流れ去る
	var half_height := mothership_texture.get_height() * mothership_scale * 0.5
	var depart := create_tween().set_parallel(true)
	depart.tween_property(_mothership, "global_position:y", area.position.y - half_height - 40.0, depart_time)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# 去りぎわに、母艦が少し大きくなって、手前を通り過ぎるように見せる
	depart.tween_property(_mothership, "scale", Vector2.ONE * mothership_scale * 1.08, depart_time)
	depart.tween_property(self, "_speed", clear_speed, clear_time)
	depart.tween_method(_set_cloud_param.bind("coverage"), cloud_coverage, 0.0, clear_time)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	depart.tween_method(_set_cloud_param.bind("sky_alpha"), 1.0, 0.0, clear_time * 0.6)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	depart.tween_property(_wind, "modulate:a", 0.0, clear_time * 0.8)
	depart.tween_property(_mist, "modulate:a", 0.0, clear_time * 0.6)
	for thruster in _thrusters:
		thruster.speed_scale = 1.6 # 去りぎわに、噴射を強める
	await depart.finished

	# 6. 操作を返して、ステージを始める
	_finish()

## 切り離し: 付け根で火花が散り、ワイヤーが母艦へ巻き上がって消える。自機は反動で少し沈む
func _detach(spawn : Vector2) -> void:
	var sparks := OrbParticles.new()
	sparks.mode = OrbParticles.Mode.BURST
	sparks.radius = 16.0
	sparks.speed = 140.0
	sparks.orb_size = 6.0
	sparks.orb_color = Color(1.0, 0.8, 0.4)
	sparks.amount = 16
	add_child(sparks)
	sparks.global_position = player.global_position + Vector2(0.0, cable_hook.y)
	sparks.burst()
	get_tree().create_timer(1.5).timeout.connect(sparks.queue_free)

	# 切り離された自機のまわりで、星がまたたく
	var twinkle := EffectParticles.new()
	twinkle.kind = EffectParticles.Kind.SPARKLE
	twinkle.radius = 26.0
	twinkle.size = 9.0
	twinkle.tint = Color(1.0, 0.9, 0.6)
	twinkle.amount = 10
	add_child(twinkle)
	twinkle.global_position = spawn
	get_tree().create_timer(0.8).timeout.connect(func() -> void: twinkle.emitting = false)
	get_tree().create_timer(2.2).timeout.connect(twinkle.queue_free)

	var retract := create_tween().set_parallel(true)
	retract.tween_property(self, "_cable_reach", 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	for cable in _cables:
		retract.tween_property(cable, "modulate:a", 0.0, 0.35)
	var bob := create_tween()
	bob.tween_property(player, "global_position", spawn + Vector2(0.0, 6.0), 0.12).set_ease(Tween.EASE_OUT)
	bob.tween_property(player, "global_position", spawn, 0.25).set_trans(Tween.TRANS_SINE)

func _set_cloud_param(value : float, param : String) -> void:
	_cloud_material.set_shader_parameter(param, value)

## 母艦側のワイヤーの付け根。side は -1 (左) / 1 (右)、0 なら真ん中
func _anchor_point(side : float) -> Vector2:
	var scale_ratio := _mothership.scale.x / mothership_scale
	return _mothership.global_position + Vector2(cable_anchor.x * side, cable_anchor.y) * scale_ratio

func _update_cables() -> void:
	if _cables.is_empty() or not _cables[0].visible or player == null:
		return
	for i in _cables.size():
		var side := -1.0 if i == 0 else 1.0
		var top := _anchor_point(side)
		var hook := player.global_position + Vector2(cable_hook.x * side, cable_hook.y)
		_cables[i].points = PackedVector2Array([top, top.lerp(hook, _cable_reach)])

## 画面全体を覆う雲。背景より上・自機より下に出るよう、このノードの子にする
func _build_clouds(area : Rect2) -> void:
	_cloud_material = ShaderMaterial.new()
	_cloud_material.shader = CLOUD_SHADER
	_cloud_material.set_shader_parameter("coverage", cloud_coverage)
	_cloud_material.set_shader_parameter("sky_alpha", 1.0)
	_cloud_material.set_shader_parameter("aspect", area.size.x / area.size.y)
	_cloud_material.set_shader_parameter("rect_size", area.size)
	_clouds = ColorRect.new()
	_clouds.material = _cloud_material
	_clouds.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clouds.global_position = area.position
	_clouds.size = area.size
	add_child(_clouds)

func _build_gate(at : Vector2) -> void:
	_gate = WarpGate.new()
	_gate.radius = gate_radius
	add_child(_gate)
	_gate.global_position = at

func _build_mothership(at : Vector2) -> void:
	_mothership = Sprite2D.new()
	_mothership.texture = mothership_texture
	_mothership.scale = Vector2.ONE * mothership_scale * 0.05
	_mothership.modulate = Color(3.0, 3.0, 3.0) # ゲートから出る瞬間は白く光る
	_mothership.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_mothership.visible = false # ゲートが開くまでは出さない
	add_child(_mothership)
	_mothership.global_position = at

## 風は画面の上の端から、下へ流れる
func _build_wind(area : Rect2) -> void:
	_wind = WindParticles.new()
	_wind.width = area.size.x + 40.0
	add_child(_wind)
	_wind.global_position = Vector2(area.get_center().x, area.position.y - 30.0)
	_wind.lifetime = (area.size.y + 60.0) / _wind.speed

## 霧・ゲートのきらめきと光の筋・母艦の噴射
func _build_effects(area : Rect2, gate_at : Vector2) -> void:
	# 霧: 大きく薄いかたまりが、風より少し遅く流れる(雲の中を飛ぶ奥行き)
	_mist = EffectParticles.new()
	_mist.kind = EffectParticles.Kind.MIST
	_mist.radius = area.size.x + 120.0
	_mist.size = 140.0
	_mist.speed = 650.0
	_mist.tint = Color(0.88, 0.9, 0.97, 0.22)
	add_child(_mist)
	_mist.global_position = Vector2(area.get_center().x, area.position.y - 80.0)
	_mist.lifetime = (area.size.y + 200.0) / _mist.speed
	move_child(_mist, _clouds.get_index() + 1) # 雲のすぐ上(ゲート・母艦より下)

	_gate_sparkle = EffectParticles.new()
	_gate_sparkle.kind = EffectParticles.Kind.SPARKLE
	_gate_sparkle.radius = gate_radius * 1.1
	_gate_sparkle.size = 11.0
	_gate_sparkle.tint = Color(0.7, 0.95, 1.0)
	_gate_sparkle.emitting = false
	add_child(_gate_sparkle)
	_gate_sparkle.global_position = gate_at
	_gate_sparkle.scale = Vector2(1.0, 0.6) # ゲートと同じ、横長の範囲

	_gate_streak = EffectParticles.new()
	_gate_streak.kind = EffectParticles.Kind.STREAK
	_gate_streak.radius = gate_radius * 0.5
	_gate_streak.size = 36.0
	_gate_streak.speed = 900.0
	_gate_streak.tint = Color(0.75, 0.95, 1.0)
	add_child(_gate_streak)
	_gate_streak.global_position = gate_at

	# 噴射: 母艦より下に描く(母艦の後ろから噴き出して見える)
	for point in thruster_points:
		var thruster := EffectParticles.new()
		thruster.kind = EffectParticles.Kind.THRUSTER
		thruster.radius = 10.0
		thruster.size = 14.0
		thruster.speed = 260.0
		thruster.emitting = false
		thruster.set_meta(&"point", point)
		add_child(thruster)
		move_child(thruster, _mothership.get_index())
		_thrusters.append(thruster)

## 噴射口を、母艦の今の位置と大きさに合わせる
func _update_thrusters() -> void:
	if _thrusters.is_empty() or not is_instance_valid(_mothership):
		return
	var ratio := _mothership.scale.x / mothership_scale
	for thruster in _thrusters:
		thruster.global_position = _mothership.global_position + (thruster.get_meta(&"point") as Vector2) * _mothership.scale.x
		thruster.scale = Vector2.ONE * maxf(ratio, 0.05)

func _build_cables() -> void:
	for i in 2:
		var cable := Line2D.new()
		cable.width = cable_width
		cable.default_color = cable_color
		cable.visible = false
		add_child(cable)
		_cables.append(cable)

func _finish() -> void:
	if player:
		player.visible = true
		player.modulate.a = 1.0
		player.set_physics_process(true)
	for node in [_clouds, _wind, _mist, _gate_sparkle, _gate_streak, _gate, _mothership]:
		if node:
			node.queue_free()
	for thruster in _thrusters:
		thruster.queue_free()
	_thrusters.clear()
	for cable in _cables:
		cable.queue_free()
	_cables.clear()
	_cloud_material = null
	if stage_runner:
		stage_runner.start()
	finished.emit()
