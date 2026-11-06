extends Node2D
class_name StageIntro
## ステージ開始の登場演出。シーン(GameScene/Intro/stage_intro.tscn)を、ステージのシーンに置いて使う。
## 雲の中にワープゲートが開いて母艦が現れ、ワイヤーで自機を降ろして切り離し、去っていく。
## 演出が終わったら、自機を操作できるようにして、StageRunner を開始する。
##
## 使い方: ステージのシーンに置き、StageRunner の Autostart をオフにする。
## ノードの順番は、背景より後、Player より前にする(雲が背景の上、自機の下に出る)。
##
## 見た目と配置は、すべてシーンの中で変える:
##   Clouds        雲(scrolling_clouds.gdshader)。演出の始めに、画面に合わせて広げる
##   Mist / Wind   霧と風のパーティクル
##   Gate          ワープゲート(warp_gate.tscn)。この位置から母艦が現れる
##   Mothership    母艦。この位置まで上がって止まる。子の Sprite が見た目、Thruster が噴射、
##                 CableAnchorL / R がワイヤーの付け根
##   GateSparkle / GateStreak   ゲートのきらめきと、母艦が出る瞬間の光の筋
##   CableL / R    ワイヤー(Line2D)
##   DetachSparks / DetachTwinkle   切り離しの火花と、自機のまわりのきらめき
##
## 流れ:
##   1. 画面が雲で覆われ、雲と風が上から下へ速く流れる
##   2. ワープゲートが開き、光の粒が吸い込まれる
##   3. ゲートから母艦が現れ(光の粒と光の筋が弾ける)、ゲートが閉じる
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

@export_group("ワイヤー")
## ワイヤーを付ける自機の位置(自機の中心から。x は左右対称に使う)
@export var cable_hook : Vector2 = Vector2(6, -8)

@export_group("母艦")
## ゲートから出る瞬間の大きさ(止まったときの大きさに対する割合)
@export var emerge_start_scale : float = 0.05
## 去りぎわに大きくなる割合(手前を通り過ぎるように見せる)
@export var depart_scale : float = 1.08

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

@onready var _clouds : ColorRect = $Clouds
@onready var _mist : GPUParticles2D = $Mist
@onready var _wind : GPUParticles2D = $Wind
@onready var _gate : WarpGate = $Gate
@onready var _mothership : Node2D = $Mothership
@onready var _ship_sprite : Sprite2D = $Mothership/Sprite
@onready var _anchors : Array[Node2D] = [$Mothership/CableAnchorL, $Mothership/CableAnchorR]
@onready var _cables : Array[Line2D] = [$CableL, $CableR]
@onready var _gate_sparkle : GPUParticles2D = $GateSparkle
@onready var _gate_streak : GPUParticles2D = $GateStreak
@onready var _detach_sparks : GPUParticles2D = $DetachSparks
@onready var _detach_twinkle : GPUParticles2D = $DetachTwinkle

var _thrusters : Array[GPUParticles2D] = []
var _cloud_material : ShaderMaterial
## ワイヤーの、自機側の端がどこまで伸びているか(1 = 自機まで、0 = 母艦の付け根まで巻き上げた)
var _cable_reach : float = 1.0
var _scroll : float = 0.0
var _speed : float = 0.0

func _ready() -> void:
	_cloud_material = _clouds.material as ShaderMaterial
	for child in _mothership.get_children():
		if child is GPUParticles2D:
			_thrusters.append(child)
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

func _play() -> void:
	var area := CameraView.visible_rect(self)
	_fit_clouds(area)
	var stop := _mothership.global_position # シーンで置いた位置が、母艦の止まる位置
	var gate_at := _gate.global_position

	# 母艦は、ゲートが開くまで出さない
	_mothership.visible = false
	_mothership.global_position = gate_at
	_mothership.scale = Vector2.ONE * emerge_start_scale
	_mothership.modulate = Color(3.0, 3.0, 3.0) # ゲートから出る瞬間は白く光る

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
	_gate_streak.restart() # 光の筋が放射状に飛び散る
	_mothership.visible = true
	for thruster in _thrusters:
		thruster.emitting = true
	var emerge := create_tween().set_parallel(true)
	emerge.tween_property(_mothership, "scale", Vector2.ONE, emerge_time)\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	emerge.tween_property(_mothership, "global_position", stop, emerge_time)\
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	emerge.tween_property(_mothership, "modulate", Color.WHITE, emerge_time * 0.6)
	await get_tree().create_timer(emerge_time * 0.5).timeout
	_gate.close_gate()
	_gate_sparkle.emitting = false
	await emerge.finished

	# 4. ワイヤーで自機を吊り下ろして、切り離す
	player.global_position = _anchor_center() + Vector2(0.0, 10.0)
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
	var half_height := _ship_sprite.texture.get_height() * _ship_sprite.scale.y * 0.5
	var depart := create_tween().set_parallel(true)
	depart.tween_property(_mothership, "global_position:y", area.position.y - half_height - 40.0, depart_time)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	depart.tween_property(_mothership, "scale", Vector2.ONE * depart_scale, depart_time)
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

## 雲を、カメラに映る範囲いっぱいに広げる
func _fit_clouds(area : Rect2) -> void:
	_clouds.global_position = area.position
	_clouds.size = area.size
	_cloud_material.set_shader_parameter("coverage", cloud_coverage)
	_cloud_material.set_shader_parameter("sky_alpha", 1.0)
	_cloud_material.set_shader_parameter("aspect", area.size.x / area.size.y)
	_cloud_material.set_shader_parameter("rect_size", area.size)

## 切り離し: 付け根で火花が散り、ワイヤーが母艦へ巻き上がって消える。自機は反動で少し沈む
func _detach(spawn : Vector2) -> void:
	_detach_sparks.global_position = player.global_position + Vector2(0.0, cable_hook.y)
	_detach_sparks.restart()
	# 切り離された自機のまわりで、星がまたたく
	_detach_twinkle.global_position = spawn
	_detach_twinkle.emitting = true
	get_tree().create_timer(0.8).timeout.connect(func() -> void: _detach_twinkle.emitting = false)

	var retract := create_tween().set_parallel(true)
	retract.tween_property(self, "_cable_reach", 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	for cable in _cables:
		retract.tween_property(cable, "modulate:a", 0.0, 0.35)
	var bob := create_tween()
	bob.tween_property(player, "global_position", spawn + Vector2(0.0, 6.0), 0.12).set_ease(Tween.EASE_OUT)
	bob.tween_property(player, "global_position", spawn, 0.25).set_trans(Tween.TRANS_SINE)

func _set_cloud_param(value : float, param : String) -> void:
	_cloud_material.set_shader_parameter(param, value)

## 2本のワイヤーの付け根の真ん中
func _anchor_center() -> Vector2:
	return (_anchors[0].global_position + _anchors[1].global_position) * 0.5

func _update_cables() -> void:
	if not _cables[0].visible or player == null:
		return
	for i in _cables.size():
		var side := -1.0 if i == 0 else 1.0
		var top := _anchors[i].global_position
		var hook := player.global_position + Vector2(cable_hook.x * side, cable_hook.y)
		_cables[i].points = PackedVector2Array([top, top.lerp(hook, _cable_reach)])

func _finish() -> void:
	if player:
		player.visible = true
		player.modulate.a = 1.0
		player.set_physics_process(true)
	# 演出のノードは、もう使わないので消す(このノード自身は残す)
	for child in get_children():
		child.queue_free()
	_cloud_material = null
	set_process(false)
	if stage_runner:
		stage_runner.start()
	finished.emit()
