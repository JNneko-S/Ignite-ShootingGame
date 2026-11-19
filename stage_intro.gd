extends Node2D
class_name StageIntro
## ステージ開始の登場演出。シーン(GameScene/Intro/stage_intro.tscn)を、ステージのシーンに置いて使う。
## 暗い画面に READY? が出たあと、雲の中、画面の下のワープゲートから母艦が自機をアームでつかんだまま現れ、
## アームを伸ばして自機を切り離し、加速して画面の上へ飛び去る。全部で約5秒(READY? を含めて6秒以内)。
## 演出が終わったら、自機を操作できるようにして、StageRunner を開始する。
##
## 使い方: ステージのシーンに置き、StageRunner の Autostart をオフにする。
## ノードの順番は、背景より後、Player より前にする(雲が背景の上、自機の下に出る)。
##
## 見た目と配置は、シーンの中で変える:
##   Clouds        雲(scrolling_clouds.gdshader)。演出の始めに、画面に合わせて広げる
##   Mist / Wind   霧と風のパーティクル
##   Gate          ワープゲート(warp_gate.tscn)。演出では、画面の下(Gate Bottom Margin)へ動かして使う
##   Mothership    母艦。この位置まで上がって止まる。子の Sprite が見た目、Thruster が噴射、
##                 CableAnchorL / R がアームの付け根
##   GateSparkle / GateStreak   ゲートのきらめきと、母艦が出る瞬間の光の筋
##   CableL / R    アーム(Line2D)
##   DetachSparks / DetachTwinkle   切り離しの火花と、自機のまわりのきらめき
##
## 流れ(秒は目安):
##   0.0  シャッターが開くと、画面は暗いまま。真ん中に電光掲示板の READY? が出て、点滅する(Ready Time 秒)
##   1.0  画面が明るくなる。雲が地面の12倍の速さで流れ、画面の下でワープゲートが開く
##   1.35 パァン! とゲートが弾け、きらめきの中から、自機をアームでつかんだ母艦が現れて上がってくる
##   2.55 アームを下へ伸ばして、自機を定位置まで降ろす
##   3.45 ガチン! と火花を散らして切り離す
##   3.7  母艦が加速して画面の上へ飛び去り、雲が晴れる → 自機を操作できるようになり、ステージが始まる

signal finished

## false なら演出をせず、すぐにステージを始める(テスト用)
@export var play_intro : bool = true
## 未設定なら "stage_runner" グループから探す
@export var stage_runner : StageRunner
## 未設定なら "player" グループから探す
@export var player : Player

@export_group("READY?")
## 暗い画面に READY? を出しておく時間(秒)
@export var ready_time : float = 1.0
@export var ready_text : String = "READY?"
@export var ready_color : Color = Color(1.0, 0.75, 0.25)
## 暗い画面が明るくなるまでの時間(秒)
@export var brighten_time : float = 0.35

@export_group("UI が出るとき")
## 演出が終わって UI が出るとき、画面の幅のこの割合だけ横から滑り込む。かかる時間(秒)と、UI ごとのずらし(秒)
@export var ui_slide_distance : float = 0.6
@export var ui_slide_time : float = 0.45
@export var ui_slide_stagger : float = 0.07

@export_group("アーム")
## アームを付ける自機の位置(自機の中心から。x は左右対称に使う)
@export var cable_hook : Vector2 = Vector2(6, -8)
## つかんでいるあいだの、アームの付け根から自機までの距離(px)
@export var hold_gap : float = 22.0

@export_group("母艦")
## ゲートから出る瞬間の大きさ(止まったときの大きさに対する割合)。自機も同じ割合で小さく出る
@export var emerge_start_scale : float = 0.3
## 去りぎわに大きくなる割合(手前を通り過ぎるように見せる)
@export var depart_scale : float = 1.12
## ゲートを置く位置(画面の下の端から上へ、px)
@export var gate_bottom_margin : float = 70.0

@export_group("時間(秒)")
## ゲートが開くまでの時間(画面が明るくなるのと同時に始まる)
@export var gate_open_time : float = 0.35
## 母艦がゲートから現れて、止まる位置まで上がる時間
@export var emerge_time : float = 1.2
## アームを伸ばして、自機を定位置まで降ろす時間
@export var lower_time : float = 0.9
## 切り離してから、母艦が去り始めるまでの待ち
@export var hold_time : float = 0.25
## 母艦が加速して画面の上へ去る時間
@export var depart_time : float = 1.1
## 雲が薄れて消えるまでの時間(母艦が去り始めると同時に始まる)
@export var clear_time : float = 1.3

@export_group("雲")
## 雲の流れる速さ: 地面の流れる速さ(px/秒)の何倍か。演出の最後に clear_speed(画面の高さ / 秒)まで遅くなる
@export var ground_scroll_speed : float = 60.0
@export var cloud_speed_scale : float = 12.0
@export var clear_speed : float = 0.4
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

const BURST_SOUND : AudioStream = preload("res://Assets/Sounds/Explosive/AS_1474525_爆発01-1（短）.mp3")
const SPARKLE_SOUND : AudioStream = preload("res://Assets/Sounds/Score/AS_897229_ポチン（報酬獲得・クーポン・エントリー）.mp3")
const BEEP_SOUND : AudioStream = preload("res://Assets/Sounds/Rockon/AS_119891_コックピットなどの細かい電子音_10.mp3")

var _thrusters : Array[GPUParticles2D] = []
var _cloud_material : ShaderMaterial
## アームの、自機側の端がどこまで伸びているか(1 = 自機まで、0 = 母艦の付け根まで巻き上げた)
var _cable_reach : float = 1.0
var _scroll : float = 0.0
var _speed : float = 0.0
## 演出を飛ばしたか、終わったか。飛ばしたあとに、待っていた続きが動かないようにする
var _done : bool = false
## 演出で使っている Tween(飛ばすときに止める)
var _tweens : Array[Tween] = []
var _spawn : Vector2
var _playing_time : float = 0.0
## 母艦がアームで自機をつかんでいる(自機が母艦に付いて動く)。アームの長さ(付け根から自機まで、px)
var _holding : bool = false
var _arm_length : float = 0.0
## 暗い画面と READY? と、白い光(画面の手前に出す)
var _overlay : CanvasLayer
var _dark : ColorRect
var _flash : ColorRect
var _board : LedBoard
## 演出のあいだ隠している UI(ゲージ・スコア・残機など)。演出が終わったら出す
var _hidden_ui : Array[CanvasLayer] = []

## 次のステージ開始で、演出を飛ばす(ゲームオーバーからのやり直しで使う)
static var skip_next : bool = false
## 演出を飛ばすボタン(Input Map のアクション名)
const SKIP_ACTION : StringName = &"UI_Shoot"

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
	if StageCarry.arriving:
		# 前のステージから霧を抜けて入ってくる。演出の雲や母艦は出さず、StageTransition が終わってから _finish() を呼ぶ
		for child in get_children():
			child.queue_free()
		_cloud_material = null
		set_process(false)
		return
	if skip_next:
		skip_next = false # ゲームオーバーからのやり直しでは、出撃の演出を飛ばす
		_finish()
		return
	if DebugTools.skip_intro_once:
		DebugTools.skip_intro_once = false # デバッグパネルのジャンプでは、出撃の演出を飛ばす
		_finish()
		return
	if not play_intro or player == null:
		_finish()
		return
	_play()

func _process(delta : float) -> void:
	if not _done and _cloud_material and player and not player.is_physics_processing():
		_playing_time += delta
		# 演出の途中でショットを押すと、飛ばしてすぐ始める(押しっぱなしの誤爆を避けて、少し待ってから受け付ける)
		if _playing_time > 0.25 and InputMap.has_action(SKIP_ACTION) and Input.is_action_just_pressed(SKIP_ACTION):
			_skip()
			return
	if _cloud_material:
		_scroll += _speed * delta
		_cloud_material.set_shader_parameter("scroll", _scroll)
	if _holding and player:
		player.global_position = _anchor_center() + Vector2(0.0, _arm_length * _mothership.scale.y)
	_update_cables()

func _play() -> void:
	var area := CameraView.visible_rect(self)
	_fit_clouds(area)
	var stop := _mothership.global_position # シーンで置いた位置が、母艦の止まる位置
	var gate_at := Vector2(area.get_center().x, area.end.y - gate_bottom_margin)
	_gate.global_position = gate_at
	_gate_sparkle.global_position = gate_at
	_gate_streak.global_position = gate_at

	# 母艦と自機は、ゲートが弾けるまで出さない。自機は演出のあいだ動かさない(撃たない)
	_mothership.visible = false
	_mothership.global_position = gate_at
	_mothership.scale = Vector2.ONE * emerge_start_scale
	_mothership.modulate = Color(3.0, 3.0, 3.0) # ゲートから出る瞬間は白く光る
	_spawn = player.global_position
	player.set_physics_process(false)
	player.visible = false
	_speed = 0.0

	_hide_ui()
	# 1. 暗い画面に READY?
	_make_overlay()
	_board.visible = true
	_play_sound(BEEP_SOUND, 1.3, -6.0)
	# ポンと出て点いたまま、最後に素早く2回点滅する
	_board.pivot_offset = _board.size * 0.5
	_board.scale = Vector2(1.0, 0.0)
	_tween().tween_property(_board, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await _wait(maxf(ready_time - 0.32, 0.0))
	if _done:
		return
	_board.blink(2, 0.06, 0.1)
	await _wait(minf(0.32, ready_time))
	if _done:
		return

	# 2. 画面が明るくなり、雲が速く流れ、画面の下でゲートが開く
	_speed = ground_scroll_speed * cloud_speed_scale / maxf(area.size.y, 1.0)
	var light := _tween().set_parallel(true)
	light.tween_property(_dark, "color:a", 0.0, brighten_time)
	light.tween_property(_board, "modulate:a", 0.0, brighten_time * 0.6)
	_gate_sparkle.emitting = true # 開くゲートのまわりで、星がまたたく
	await _gate.open_gate(gate_open_time).finished
	if _done:
		return

	# 3. パァン! ゲートが弾け、きらめきの中から、自機をつかんだ母艦が現れて上がってくる
	_gate.flash()
	_gate_streak.restart() # 光の筋が放射状に飛び散る
	_flash_screen(0.55, 0.3)
	_play_sound(BURST_SOUND, 1.5, -2.0)
	for n in 3: # キラキラ…
		get_tree().create_timer(0.12 + n * 0.11).timeout.connect(_play_sound.bind(SPARKLE_SOUND, 1.7 + n * 0.25, -12.0))
	_mothership.visible = true
	for thruster in _thrusters:
		thruster.emitting = true
	_arm_length = hold_gap
	_holding = true
	_cable_reach = 1.0
	for cable in _cables:
		cable.visible = true
		cable.modulate.a = 1.0
	player.visible = true
	player.modulate = Color(3.0, 3.0, 3.0)
	player.scale = Vector2.ONE * emerge_start_scale
	var emerge := _tween().set_parallel(true)
	emerge.tween_property(_mothership, "scale", Vector2.ONE, emerge_time)\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	emerge.tween_property(_mothership, "global_position", stop, emerge_time)\
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	emerge.tween_property(_mothership, "modulate", Color.WHITE, emerge_time * 0.5)
	emerge.tween_property(player, "scale", Vector2.ONE, emerge_time)\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	emerge.tween_property(player, "modulate", Color.WHITE, emerge_time * 0.5)
	await _wait(emerge_time * 0.45)
	if _done:
		return
	_gate.close_gate()
	_gate_sparkle.emitting = false
	await emerge.finished
	if _done:
		return

	# 4. アームを下へ伸ばして、自機を定位置まで降ろす
	var reach := maxf(_spawn.y - _anchor_center().y, hold_gap)
	var lower := _tween()
	lower.tween_property(self, "_arm_length", reach, lower_time)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await lower.finished
	if _done:
		return

	# 5. ガチン! 火花を散らして切り離す
	_holding = false
	player.global_position = Vector2(_anchor_center().x, _spawn.y)
	_spawn = player.global_position
	_detach(_spawn)
	await _wait(hold_time)
	if _done:
		return

	# 6. 母艦が加速して画面の上へ飛び去り、雲と風が薄れて流れ去る
	#    (EASY・NORMAL ではじめての出撃なら、母艦が去ったあと、雲が晴れる前に、雲の上で操作チュートリアルをする)
	var tutorial_first := IntroTutorial.should_run() and player != null
	var half_height := _ship_sprite.texture.get_height() * _ship_sprite.scale.y * depart_scale * 0.5
	var depart := _tween().set_parallel(true)
	depart.tween_property(_mothership, "global_position:y", area.position.y - half_height - 60.0, depart_time)		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	depart.tween_property(_mothership, "scale", Vector2.ONE * depart_scale, depart_time)
	if not tutorial_first:
		_clear_clouds(depart)
	for thruster in _thrusters:
		thruster.speed_scale = 2.0 # 去りぎわに、噴射を強める
	await depart.finished
	if _done:
		return
	if tutorial_first:
		# 雲の上で操作チュートリアル(自機を動かせるあいだは、ショットで演出を飛ばす処理は働かない)
		_show_ui()
		player.set_physics_process(true)
		var tutorial := IntroTutorial.new()
		tutorial.player = player
		get_tree().current_scene.add_child(tutorial)
		await tutorial.run()
		if _done:
			return
		var clear := _tween().set_parallel(true)
		_clear_clouds(clear)
		await clear.finished
		if _done:
			return

	# 7. 操作を返して、ステージを始める
	_finish()

## 雲と風を薄れさせ、流れを遅くする(雲が晴れる)。tween は並列のもの
func _clear_clouds(tween : Tween) -> void:
	tween.tween_property(self, "_speed", clear_speed, clear_time)
	tween.tween_method(_set_cloud_param.bind("coverage"), cloud_coverage, 0.0, clear_time)		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_method(_set_cloud_param.bind("sky_alpha"), 1.0, 0.0, clear_time * 0.6)		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_wind, "modulate:a", 0.0, clear_time * 0.8)
	tween.tween_property(_mist, "modulate:a", 0.0, clear_time * 0.6)

## 暗い画面・READY? の電光掲示板・白い光を、画面の手前に作る
func _make_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = 70 # ゲームの UI より手前、ポーズ(80)より奥
	add_child(_overlay)
	var view := get_viewport().get_visible_rect().size
	_dark = ColorRect.new()
	_dark.color = Color(0.0, 0.0, 0.0, 1.0)
	_dark.size = view
	_dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(_dark)
	_board = LedBoard.new()
	_board.text = ready_text
	_board.lit_color = ready_color
	_board.dim_color = Color(ready_color.r * 0.12, ready_color.g * 0.12, ready_color.b * 0.12)
	_board.fixed_pitch = 5.0
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(_board)
	var width := view.x - 60.0
	_board.size = Vector2(width, _board.height_for(width))
	_board.position = (view - _board.size) * 0.5
	_board.set_text(ready_text, false) # 文字を点の列にして、真ん中に出す
	_board.visible = false
	_flash = ColorRect.new()
	_flash.color = Color(1.0, 1.0, 1.0, 0.0)
	_flash.size = view
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(_flash)

## 演出のあいだ、ゲームの UI(ゲージ・スコア・残機・ボスのゲージなど)を隠す。
## ステージの中の CanvasLayer のうち、演出の暗幕(70)より奥のものが対象(ポーズ・ゲームオーバーは対象外)
func _hide_ui() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	for node in scene.find_children("*", "CanvasLayer", true, false):
		var layer := node as CanvasLayer
		if layer.visible and layer.layer < 70 and not is_ancestor_of(layer):
			layer.visible = false
			_hidden_ui.append(layer)

## 隠していた UI を出す。画面の左にある UI は左から、右にある UI は右から、少し行き過ぎて戻るように滑り込む
func _show_ui() -> void:
	var width := get_viewport().get_visible_rect().size.x
	var order := 0
	for layer in _hidden_ui:
		if not is_instance_valid(layer):
			continue
		layer.visible = true
		var side := _ui_side(layer, width)
		if side == 0.0:
			continue # 自機に付いて動く表示など、場所の決まっていないものは、そのまま出す
		var home := layer.offset
		layer.offset = home + Vector2(side * width * ui_slide_distance, 0.0)
		var slide := layer.create_tween()
		slide.tween_interval(order * ui_slide_stagger)
		slide.tween_property(layer, "offset", home, ui_slide_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		order += 1
	_hidden_ui.clear()

## UI が画面の左右どちらにあるか(-1 = 左、1 = 右、0 = 決まらない)。中の表示(子を持たない Control)の真ん中で決める
func _ui_side(layer : CanvasLayer, width : float) -> float:
	if layer is IgniteHint:
		return 0.0
	var total := 0.0
	var count := 0
	for node in layer.find_children("*", "Control", true, false):
		var control := node as Control
		if not control.is_visible_in_tree() or control.size.x >= width * 0.9:
			continue
		if control.find_children("*", "Control", false, false).size() > 0:
			continue
		total += control.get_global_rect().get_center().x
		count += 1
	if count == 0:
		return 0.0
	return -1.0 if total / count < width * 0.5 else 1.0

## 画面全体を一瞬白く光らせる
func _flash_screen(strength : float, time : float) -> void:
	if _flash == null:
		return
	_flash.color.a = strength
	_tween().tween_property(_flash, "color:a", 0.0, time).set_ease(Tween.EASE_OUT)

func _play_sound(stream : AudioStream, pitch : float = 1.0, volume_db : float = 0.0) -> void:
	if _done or not is_inside_tree():
		return
	var sound := AudioStreamPlayer.new()
	sound.stream = stream
	sound.pitch_scale = pitch
	sound.volume_db = volume_db
	add_child(sound)
	sound.play()
	sound.finished.connect(sound.queue_free)

func _wait(seconds : float) -> void:
	await get_tree().create_timer(seconds).timeout

## 雲を、カメラに映る範囲いっぱいに広げる
func _fit_clouds(area : Rect2) -> void:
	_clouds.global_position = area.position
	_clouds.size = area.size
	_cloud_material.set_shader_parameter("coverage", cloud_coverage)
	_cloud_material.set_shader_parameter("sky_alpha", 1.0)
	_cloud_material.set_shader_parameter("aspect", area.size.x / area.size.y)
	_cloud_material.set_shader_parameter("rect_size", area.size)

## 切り離し: ガチン! と付け根で火花が散り、アームが母艦へ巻き上がって消える。自機は反動で少し沈む
func _detach(spawn : Vector2) -> void:
	_detach_sparks.global_position = player.global_position + Vector2(0.0, cable_hook.y)
	_detach_sparks.restart()
	_play_sound(BURST_SOUND, 2.6, -8.0)
	_play_sound(BEEP_SOUND, 0.55, -4.0)
	_flash_screen(0.25, 0.15)
	SpriteShake.shake(_mothership, 5.0)
	# 切り離された自機のまわりで、星がまたたく
	_detach_twinkle.global_position = spawn
	_detach_twinkle.emitting = true
	get_tree().create_timer(0.8).timeout.connect(func() -> void:
		if is_instance_valid(_detach_twinkle):
			_detach_twinkle.emitting = false)

	var retract := _tween().set_parallel(true)
	retract.tween_property(self, "_cable_reach", 0.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	for cable in _cables:
		retract.tween_property(cable, "modulate:a", 0.0, 0.3)
	var bob := _tween()
	bob.tween_property(player, "global_position", spawn + Vector2(0.0, 8.0), 0.1).set_ease(Tween.EASE_OUT)
	bob.tween_property(player, "global_position", spawn, 0.22).set_trans(Tween.TRANS_SINE)

func _set_cloud_param(value : float, param : String) -> void:
	_cloud_material.set_shader_parameter(param, value)

## 2本のアームの付け根の真ん中
func _anchor_center() -> Vector2:
	return (_anchors[0].global_position + _anchors[1].global_position) * 0.5

func _update_cables() -> void:
	if not _cables[0].visible or player == null:
		return
	for i in _cables.size():
		var side := -1.0 if i == 0 else 1.0
		var top := _anchors[i].global_position
		var hook := player.global_position + Vector2(cable_hook.x * side, cable_hook.y) * player.scale.x
		_cables[i].points = PackedVector2Array([top, top.lerp(hook, _cable_reach)])

## 演出で使う Tween を作る(飛ばすときに止められるように覚えておく)
func _tween() -> Tween:
	var tween := create_tween()
	_tweens.append(tween)
	return tween

## ショットで演出を飛ばす: 自機を定位置に置いてすぐ始め、雲や母艦はさっと消す
func _skip() -> void:
	for tween in _tweens:
		if tween.is_valid():
			tween.kill()
	_tweens.clear()
	_holding = false
	if player:
		player.global_position = _spawn
	_finish(0.25)

## 出撃の演出を終えて、ステージを始める。fade_time があれば、演出の雲や母艦をその時間で消していく
func _finish(fade_time : float = 0.0) -> void:
	if _done:
		return
	_done = true
	_holding = false
	_show_ui()
	if player:
		player.visible = true
		player.modulate = Color.WHITE
		player.scale = Vector2.ONE
		player.set_physics_process(true)
	# 演出のノードは、もう使わないので消す(このノード自身は残す)
	if fade_time > 0.0:
		var fade := create_tween().set_parallel(true)
		fade.tween_property(self, "modulate:a", 0.0, fade_time)
		if _dark:
			fade.tween_property(_dark, "color:a", 0.0, fade_time)
		if _board:
			fade.tween_property(_board, "modulate:a", 0.0, fade_time)
		fade.chain().tween_callback(_clear_children)
	else:
		_clear_children()
	if stage_runner:
		stage_runner.start()
	finished.emit()

func _clear_children() -> void:
	for child in get_children():
		child.queue_free()
	_cloud_material = null
	_overlay = null
	_dark = null
	_board = null
	_flash = null
	set_process(false)
	modulate.a = 1.0
