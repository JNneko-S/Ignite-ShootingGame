extends Node
class_name EndingSequence
## ラストステージのエンディング。ステージのシーンに置く(StageRunner の Final Boss Clear Delay は大きくしておき、
## ステージクリアは、このノードが最後に出す)。文字は出さない(演出は光・音・爆発だけ)。
##
##   1. ラスボスの最期(NucleoFinale)が終わるのを待つ
##   2. 緊急事態: 警報が鳴り、画面が赤く明滅し、ステージのあちこちが爆発しはじめる。自機が反転する(下を向く)
##   3. 脱出: 背景が、来た道を逆に流れて、ステージの最初まで戻っていく。追ってきた敵が後ろ(画面の上)から来るので、
##      弾幕を避けながら、オプション(と自機のショット)で撃ち落とす
##   4. ステージの最初(地上の出口)を抜けると雲の上へ。自機は上を向き直し、上から降りてきた母艦のアームに回収される
##   5. 母艦と一緒に飛び去って、白くなり、ゲームクリア(タイトルへ)
##   Bエンド(GameManager.end_b_conditions_met)のときは、回収されようとした瞬間に、変化が起きる(_b_end_event)

const INTRO_SCENE := preload("res://GameScene/Intro/stage_intro.tscn")
const ALARM_SOUND := preload("res://Assets/Sounds/Warn/AS_816725_アラーム_警告音（ループ） (1).mp3")
const BEE := preload("res://GameScene/Enemy/Stage4/bee_worker.tscn")
const FORMATION := preload("res://GameScene/Enemy/Stage4/formation_kai.tscn")
const GUNSHIP := preload("res://GameScene/Enemy/Stage4/gunship_kai.tscn")
const BOMBER := preload("res://GameScene/Enemy/Stage4/bomber_kai.tscn")
const M_STRIKE := preload("res://Resources/MovePatterns/Stage4/m4_scramble_strike.tres")
const M_HOLD := preload("res://Resources/MovePatterns/Stage4/m4_scramble_hold.tres")
const M_BOMBER := preload("res://Resources/MovePatterns/Stage4/m4_bomber_down.tres")

## 脱出(ステージの最初まで戻る)にかける時間(秒)
@export var escape_time : float = 40.0
## 緊急事態から、反転して逃げ出すまでの時間(秒)
@export var emergency_time : float = 2.6
## ステージの爆発の間隔(秒)
@export var quake_interval : float = 0.18
## タイトル画面(ゲームクリアのあと)
@export_file("*.tscn") var title_scene : String = "res://title.tscn"

var _runner : StageRunner
var _player : Player
var _b_end : bool = false
var _quaking : bool = false
var _alarm_layer : CanvasLayer
var _alarm_rect : ColorRect
var _siren : AudioStreamPlayer
var _intro : Node2D
var _cloud_material : ShaderMaterial
var _cloud_scroll : float = 0.0
var _cloud_speed : float = 0.0
var _cables : Array[Line2D] = []
var _anchors : Array[Node2D] = []
var _cable_reach : float = 0.0

func _ready() -> void:
	_connect.call_deferred()

func _connect() -> void:
	_runner = get_tree().get_first_node_in_group("stage_runner") as StageRunner
	if _runner:
		_runner.final_boss_defeated.connect(_on_final_boss_defeated, CONNECT_ONE_SHOT)

func _process(delta : float) -> void:
	if _cloud_material:
		_cloud_scroll += _cloud_speed * delta
		_cloud_material.set_shader_parameter("scroll", _cloud_scroll)
	if not _cables.is_empty() and is_instance_valid(_player):
		for i in _cables.size():
			var side := -1.0 if i == 0 else 1.0
			var top := _anchors[i].global_position
			var hook := _player.global_position + Vector2(8.0 * side, -6.0)
			_cables[i].points = PackedVector2Array([top, top.lerp(hook, _cable_reach)])

func _on_final_boss_defeated() -> void:
	var gm := get_tree().current_scene as GameManager
	_b_end = gm != null and gm.end_b_conditions_met()
	_player = get_tree().get_first_node_in_group("player") as Player
	# 1. ラスボスの最期を待つ
	var finale : NucleoFinale = null
	for node in get_tree().current_scene.find_children("*", "NucleoFinale", true, false):
		finale = node
	if finale:
		await finale.finished
	else:
		await get_tree().create_timer(5.0, false).timeout
	await _emergency()
	await _escape()
	await _pickup()

# ---------------------------------------------------------------- 2. 緊急事態

func _emergency() -> void:
	var tree := get_tree()
	# 警報と、赤い明滅
	_alarm_layer = CanvasLayer.new()
	_alarm_layer.layer = 9
	add_child(_alarm_layer)
	_alarm_rect = ColorRect.new()
	_alarm_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_alarm_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_alarm_rect.color = Color(0.9, 0.05, 0.02, 0.0)
	_alarm_layer.add_child(_alarm_rect)
	var pulse := create_tween().set_loops()
	pulse.tween_property(_alarm_rect, "color:a", 0.28, 0.35).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(_alarm_rect, "color:a", 0.04, 0.35).set_trans(Tween.TRANS_SINE)
	_siren = AudioStreamPlayer.new()
	_siren.stream = ALARM_SOUND
	_siren.volume_db = -6.0
	_siren.bus = &"SFX"
	add_child(_siren)
	_siren.play()
	_siren.finished.connect(_siren.play)
	# ステージが爆発しはじめる
	_quaking = true
	_quake()
	var camera := StageCamera.of(get_tree().current_scene)
	if camera:
		camera.shake(8.0, emergency_time)
	await tree.create_timer(emergency_time * 0.6, false).timeout
	# 自機が反転する(下を向いて、逃げる向きへ)
	if is_instance_valid(_player):
		var turn := create_tween()
		turn.tween_property(_player, "rotation_degrees", 180.0, 0.5).from(0.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tree.create_timer(emergency_time * 0.4, false).timeout

## ステージのあちこちが爆発し続ける(画面の中のランダムな所。ときどき大きいもの)
func _quake() -> void:
	var tree := get_tree()
	while _quaking and is_inside_tree():
		var view := CameraView.visible_rect(get_tree().current_scene as CanvasItem)
		var at := Vector2(randf_range(view.position.x, view.end.x), randf_range(view.position.y, view.end.y))
		if is_instance_valid(_player) and at.distance_to(_player.global_position) < 60.0:
			at.y -= 120.0 # 自機に重ねない(見えにくくしない)
		var big := randf() < 0.12
		Explosion.spawn(tree, Explosion.WAVE if big else (Explosion.EXPLOSIVE if randf() < 0.4 else Explosion.ZAKO), at, randf_range(1.6, 2.4) if big else randf_range(0.9, 1.6))
		if big:
			var camera := StageCamera.of(get_tree().current_scene)
			if camera:
				camera.shake(6.0, 0.3)
		await tree.create_timer(quake_interval * randf_range(0.6, 1.4), false).timeout

# ---------------------------------------------------------------- 3. 脱出

func _escape() -> void:
	var tree := get_tree()
	EnemyShooter.release_fire() # 追ってくる敵は撃ってくる
	# 脱出のあいだは、イグナイトを思いきり使えるように、ゲージを最大にする
	var gm := tree.current_scene as GameManager
	if gm and gm.ignite:
		gm.ignite.value = gm.ignite.max_value()
		gm.ignite._update(true)
	var scroller := tree.get_first_node_in_group("background_scroller") as BackgroundScroller
	var back : Tween = scroller.run_back(escape_time) if scroller else null
	# 追ってくる敵(後ろ = 画面の上から)
	var waves : Array = [
		[2.0, BEE, null, 8, 0.12, Vector2(-150, 0), Vector2(42, 0), 0],
		[6.0, FORMATION, M_STRIKE, 8, 0.16, Vector2(-30, 0), Vector2(20, 4), 3],
		[10.0, GUNSHIP, M_HOLD, 2, 0.4, Vector2(-130, 0), Vector2(260, 0), 3],
		[13.0, BEE, null, 10, 0.1, Vector2(160, 0), Vector2(-36, 0), 0],
		[17.0, BOMBER, M_BOMBER, 4, 0.0, Vector2(-180, 0), Vector2(120, 0), 0],
		[21.0, FORMATION, M_STRIKE, 10, 0.13, Vector2(-160, 0), Vector2(35, 3), 3],
		[25.0, BEE, null, 12, 0.09, Vector2(-170, 0), Vector2(31, 0), 0],
		[28.0, GUNSHIP, M_HOLD, 2, 0.4, Vector2(-130, 0), Vector2(260, 0), 3],
		[31.0, BEE, null, 10, 0.1, Vector2(160, 0), Vector2(-36, 0), 0],
	]
	for wave in waves:
		_spawn_later(wave)
	if back:
		await back.finished
	else:
		await tree.create_timer(escape_time, false).timeout

func _spawn_later(wave : Array) -> void:
	await get_tree().create_timer(wave[0], false).timeout
	if _runner == null or not is_instance_valid(_runner):
		return
	var event := SpawnEvent.new()
	event.enemy_scene = wave[1]
	event.move_pattern = wave[2]
	event.count = wave[3]
	event.interval = wave[4]
	event.offset = wave[5]
	event.offset_step = wave[6]
	event.emerge = wave[7]
	event.alternate_mirror = wave[1] == FORMATION
	for i in event.unit_count():
		if i > 0:
			await get_tree().create_timer(event.interval, false).timeout
		_runner.spawn(event, i)

# ---------------------------------------------------------------- 4. 雲の上へ・母艦に回収

func _pickup() -> void:
	var tree := get_tree()
	_quaking = false
	# 残っている敵は去る(消える)
	for node in tree.get_nodes_in_group("enemy"):
		if node is Node2D:
			var fade := (node as Node2D).create_tween()
			fade.tween_property(node, "modulate:a", 0.0, 0.6)
			fade.tween_callback(node.queue_free)
	tree.call_group("enemy_bullet", "vanish", 0.2)
	EnemyShooter.hold_fire(60.0)
	# 警報が止む
	var calm := create_tween().set_parallel(true)
	calm.tween_property(_alarm_rect, "modulate:a", 0.0, 1.2)
	calm.tween_property(_siren, "volume_db", -60.0, 1.5)
	# 雲の上へ(出撃のときの雲と母艦を、もう一度出す)
	_build_sky()
	var view := CameraView.visible_rect(get_tree().current_scene as CanvasItem)
	_cloud_speed = 0.9
	var sky := create_tween().set_parallel(true)
	sky.tween_method(_set_cloud.bind("sky_alpha"), 0.0, 1.0, 1.6)
	sky.tween_method(_set_cloud.bind("coverage"), 0.0, 0.55, 2.0)
	# 自機は操作をやめ、上を向き直して、画面の下のほうへ
	if is_instance_valid(_player):
		_player.set_physics_process(false)
		var settle := create_tween().set_parallel(true)
		settle.tween_property(_player, "rotation_degrees", 360.0, 0.6).from(180.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		settle.tween_property(_player, "global_position", Vector2(view.get_center().x, view.end.y - view.size.y * 0.22), 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tree.create_timer(1.8, false).timeout
	# 母艦が上から降りてくる
	var mothership := _intro.get_node("Mothership") as Node2D
	var stop := Vector2(view.get_center().x, view.position.y + view.size.y * 0.25)
	mothership.global_position = stop + Vector2(0.0, -view.size.y * 0.7)
	mothership.visible = true
	var descend := create_tween()
	descend.tween_property(mothership, "global_position", stop, 2.4).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	await descend.finished
	# アームが伸びて、自機をつかむ
	for cable in _cables:
		cable.visible = true
	var reach := create_tween()
	reach.tween_property(self, "_cable_reach", 1.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await reach.finished
	ScreenFlash.play(tree, 0.25)
	if _b_end:
		await _b_end_event(mothership)
		return
	# 自機を引き上げて、母艦と一緒に飛び去る
	var lift := create_tween()
	lift.tween_property(_player, "global_position", stop + Vector2(0.0, 70.0), 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await lift.finished
	var away := create_tween().set_parallel(true)
	away.tween_property(mothership, "global_position:y", stop.y - view.size.y * 1.3, 2.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	away.tween_property(_player, "global_position:y", stop.y + 70.0 - view.size.y * 1.3, 2.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	away.tween_property(self, "_cloud_speed", 4.0, 2.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	# 雲の上で、ステージのボーナスの集計を見せる(スコアボードへの記録もここ)
	if _runner:
		_runner.stage_cleared.emit()
	await tree.create_timer(4.0, false).timeout
	# 5. 白くなって、ゲームクリア
	var white := ColorRect.new()
	white.mouse_filter = Control.MOUSE_FILTER_IGNORE
	white.set_anchors_preset(Control.PRESET_FULL_RECT)
	white.color = Color(1.0, 1.0, 1.0, 0.0)
	_alarm_layer.layer = 90
	_alarm_layer.add_child(white)
	var fade_white := create_tween()
	fade_white.tween_property(white, "color:a", 1.0, 2.0)
	await fade_white.finished
	await tree.create_timer(1.0, false).timeout
	# ノーコンティニューの一周目なら、二周目(Another Round)へ: 自機と点数を覚えて、タイトルで合図を見せてから一面へ
	if RunConfig.can_enter_second_loop():
		StageCarry.save(tree)
		RunConfig.loop = 2
		if HazardRank.active:
			HazardRank.start_black_loop() # ANOTHER の二周目は BLACK ANOTHER
		TitleScreen.another_round_pending = true
	SceneSwitcher.change(title_scene, 1.0)

## Bエンド: 回収されようとした瞬間に、変化が起きる。
## (中身はこれから決める。今は、母艦が赤く明滅して、アームがちぎれ、画面が暗転して止まる)
func _b_end_event(mothership : Node2D) -> void:
	var tree := get_tree()
	var flicker := create_tween().set_loops(8)
	flicker.tween_property(mothership, "modulate", Color(2.0, 0.3, 0.3), 0.06)
	flicker.tween_property(mothership, "modulate", Color.WHITE, 0.06)
	await tree.create_timer(1.0, false).timeout
	for cable in _cables:
		cable.visible = false
	_cables.clear()
	ScreenFlash.play(tree, 0.8)
	var camera := StageCamera.of(get_tree().current_scene)
	if camera:
		camera.shake(10.0, 0.8)
	var black := ColorRect.new()
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.color = Color(0.0, 0.0, 0.0, 0.0)
	_alarm_layer.layer = 90
	_alarm_layer.add_child(black)
	var dark := create_tween()
	dark.tween_property(black, "color:a", 1.0, 1.5)
	await dark.finished
	if _runner:
		_runner.stage_cleared.emit()
	await tree.create_timer(2.0, false).timeout
	SceneSwitcher.change(title_scene, 1.0)

## 出撃の演出のシーンを、スクリプト抜きで借りて、雲・母艦・アームだけを使う
func _build_sky() -> void:
	_intro = INTRO_SCENE.instantiate() as Node2D
	_intro.set_script(null)
	var scene := get_tree().current_scene
	scene.add_child(_intro)
	if is_instance_valid(_player):
		scene.move_child(_intro, _player.get_index()) # 背景より手前、自機より奥
	for name in ["Gate", "GateSparkle", "GateStreak", "DetachSparks", "DetachTwinkle"]:
		var node := _intro.get_node_or_null(name)
		if node:
			node.queue_free()
	var view := CameraView.visible_rect(get_tree().current_scene as CanvasItem)
	var clouds := _intro.get_node("Clouds") as ColorRect
	clouds.global_position = view.position
	clouds.size = view.size
	_cloud_material = clouds.material as ShaderMaterial
	if _cloud_material:
		_cloud_material = _cloud_material.duplicate() as ShaderMaterial
		clouds.material = _cloud_material
		_cloud_material.set_shader_parameter("aspect", view.size.x / view.size.y)
		_cloud_material.set_shader_parameter("rect_size", view.size)
		_cloud_material.set_shader_parameter("sky_alpha", 0.0)
		_cloud_material.set_shader_parameter("coverage", 0.0)
	var mothership := _intro.get_node("Mothership") as Node2D
	mothership.visible = false
	mothership.scale = Vector2.ONE
	mothership.modulate = Color.WHITE
	_anchors.assign([mothership.get_node("CableAnchorL"), mothership.get_node("CableAnchorR")])
	_cables.assign([_intro.get_node("CableL"), _intro.get_node("CableR")])
	for cable in _cables:
		cable.visible = false
	_cable_reach = 0.0

func _set_cloud(value : float, param : String) -> void:
	if _cloud_material:
		_cloud_material.set_shader_parameter(param, value)
