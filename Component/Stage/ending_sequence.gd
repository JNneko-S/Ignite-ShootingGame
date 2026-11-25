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

const STAFF_ROLL := "res://GameScene/Ending/staff_roll.tscn"
const INTRO_SCENE := preload("res://GameScene/Intro/stage_intro.tscn")
const ALARM_SOUND := preload("res://Assets/Sounds/Warn/AS_816725_アラーム_警告音（ループ） (1).mp3")
const BEE := preload("res://GameScene/Enemy/Stage4/bee_worker.tscn")
const FORMATION := preload("res://GameScene/Enemy/Stage4/formation_kai.tscn")
const GUNSHIP := preload("res://GameScene/Enemy/Stage4/gunship_kai.tscn")
const BOMBER := preload("res://GameScene/Enemy/Stage4/bomber_kai.tscn")
const M_STRIKE := preload("res://Resources/MovePatterns/Stage4/m4_scramble_strike.tres")
const M_HOLD := preload("res://Resources/MovePatterns/Stage4/m4_scramble_hold.tres")
const M_BOMBER := preload("res://Resources/MovePatterns/Stage4/m4_bomber_down.tres")
## 裏ボス Union(Bエンド)。重い(3D のモデル)ので、Bエンドのときだけ、ラスボスを倒したところで読み込む
const UNION_SCENE := "res://GameScene/Enemy/SECRET/union_boss.tscn"
const WARNING_SCENE := preload("res://GameScene/UI/warning_display.tscn")
const _BlackWave := preload("res://GameScene/Effect/black_wave.gd")
const ROAR_SOUNDS : Array[AudioStream] = [
	preload("res://Assets/Sounds/Explosive/AS_833264_フィルターが掛かったような爆破音.mp3"),
	preload("res://Assets/Sounds/Explosive/AS_1373492_爆発／攻撃／破壊／爆破／ドカーン.mp3"),
]

## 脱出(ステージの最初まで戻る)にかける時間(秒)
@export var escape_time : float = 40.0
## 緊急事態から、反転して逃げ出すまでの時間(秒)
@export var emergency_time : float = 2.6
## ステージの爆発の間隔(秒)
@export var quake_interval : float = 0.18
## タイトル画面(ゲームクリアのあと)
@export_file("*.tscn") var title_scene : String = "res://title.tscn"
## 裏ボス Union 戦の曲
@export var union_music : AudioStream = preload("res://Assets/Sounds/Music/AS_1259553_テンポ速めのメタルドラムンベース.mp3")

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
var _union_scene : PackedScene
## 裏ボス戦が終わった(勝ったら true。負けたら false で、A エンドで終える)
signal union_battle_over(won : bool)
var _union_over : bool = false

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
	# Bエンド(裏ボス Union)は、HARD と ANOTHER だけ。EASY・NORMAL は、条件を満たしても A エンド
	_b_end = (gm != null and gm.end_b_conditions_met() and DifficultyTuning.chosen() >= 2) or DebugTools.force_b_end
	DebugTools.force_b_end = false
	_player = get_tree().get_first_node_in_group("player") as Player
	if DebugTools.union_direct:
		# デバッグ: 裏ボス Union 戦へすぐ(ラスボスの最期・緊急事態・脱出を飛ばす)
		DebugTools.union_direct = false
		_b_end = true
		_union_scene = load(UNION_SCENE) as PackedScene
		_quiet_alarm()
		if gm and gm.ignite:
			gm.ignite.value = gm.ignite.max_value() # 脱出のあとと同じく、ゲージは最大
			gm.ignite._update(true)
		if is_instance_valid(_player):
			_player.rotation_degrees = 180.0 # 脱出のあとと同じ向き(回収の場面で、上を向き直す)
		await get_tree().create_timer(1.5, false).timeout
		await _pickup()
		return
	# 1. ラスボスの最期を待つ
	var finale : NucleoFinale = null
	for node in get_tree().current_scene.find_children("*", "", true, false):
		if node is NucleoFinale:
			finale = node
	if _b_end:
		_union_scene = load(UNION_SCENE) as PackedScene # 裏ボスを先に読み込んでおく(画面が揺れている今のうちに)
	if finale:
		await finale.finished
	else:
		await get_tree().create_timer(5.0, false).timeout
	await _emergency()
	await _escape()
	await _pickup()

# ---------------------------------------------------------------- 2. 緊急事態

## 警報の画面と音を、鳴らさずに用意する(緊急事態を飛ばしたとき。回収の場面が、これを静める)
func _quiet_alarm() -> void:
	_alarm_layer = CanvasLayer.new()
	_alarm_layer.layer = 9
	add_child(_alarm_layer)
	_alarm_rect = ColorRect.new()
	_alarm_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_alarm_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_alarm_rect.color = Color(0.9, 0.05, 0.02, 0.0)
	_alarm_layer.add_child(_alarm_rect)
	_siren = AudioStreamPlayer.new()
	_siren.volume_db = -60.0
	add_child(_siren)

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
	_set_banner()
	_enter_second_loop_if_allowed()
	_to_staff_roll()

## ノーコンティニューの一周目なら、二周目(Another Round)へ: 自機と点数を覚えて、タイトルで合図を見せてから一面へ(A エンド)
func _enter_second_loop_if_allowed() -> void:
	if RunConfig.can_enter_second_loop():
		StageCarry.save(get_tree())
		RunConfig.loop = 2
		if HazardRank.active:
			HazardRank.start_black_loop() # ANOTHER の二周目は BLACK ANOTHER
		TitleScreen.another_round_pending = true

## Bエンド: 回収されようとした瞬間、画面の横から裏ボス Union が母艦を貫いて壊す。
## Union は弧を描いて戻り、画面の上の真ん中で止まる → 黒い WARNING → 口を開いて叫ぶ(画面が揺れ、黒い波動) → 裏ボス戦。
## 倒すと、クリア(ボーナスの集計 → スタッフロール)
func _b_end_event(mothership : Node2D) -> void:
	var tree := get_tree()
	var view := CameraView.visible_rect(get_tree().current_scene as CanvasItem)
	var union := _spawn_union()
	if union == null:
		push_warning("EndingSequence: Union を出せませんでした")
		await _plain_b_end()
		return
	Achievements.on_hidden_boss_appeared()
	var ub := union.get_node_or_null("UnionBoss")
	var uview := union.get_node_or_null("UnionView")
	var height := mothership.global_position.y + 10.0
	union.global_position = Vector2(view.position.x - 240.0, height)
	# 一瞬の静けさ: 母艦が赤く明滅する
	var flicker := create_tween().set_loops(4)
	flicker.tween_property(mothership, "modulate", Color(2.0, 0.3, 0.3), 0.06)
	flicker.tween_property(mothership, "modulate", Color.WHITE, 0.06)
	await tree.create_timer(0.6, false).timeout
	# 1. 横から突っ込んで、母艦を貫く
	var dash := create_tween()
	dash.tween_property(union, "global_position:x", view.end.x + 260.0, 0.6).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN_OUT)
	await tree.create_timer(0.3, false).timeout
	_destroy_mothership(mothership)
	await dash.finished
	await tree.create_timer(0.5, false).timeout
	# 2. 弧を描いて戻ってきて、画面の上の真ん中で止まる
	var home := Vector2(view.get_center().x, view.position.y + view.size.y * 0.24)
	var from := Vector2(view.end.x + 200.0, view.position.y + view.size.y * 0.55)
	var bend := Vector2(view.end.x - view.size.x * 0.05, view.position.y - view.size.y * 0.15)
	union.global_position = from
	if uview:
		uview.play(&"Awake", 0.1)
	var arc := create_tween()
	arc.tween_method(func(t : float) -> void:
		if is_instance_valid(union):
			union.global_position = from.lerp(bend, t).lerp(bend.lerp(home, t), t), 0.0, 1.0, 1.8)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await arc.finished
	# 3. 黒い WARNING
	await _black_warning()
	# 4. 口を開いて、叫ぶ
	await _roar(union, uview)
	# 5. 裏ボス戦。負けたら(残機が尽きたら)、ゲームオーバーにせず A エンドで終える
	var gm := get_tree().current_scene as GameManager
	if gm:
		gm.game_over_handler = _on_union_lost.bind(union)
	union.died.connect(func(_e : Enemy) -> void:
		if not _union_over:
			_union_over = true
			union_battle_over.emit(true), CONNECT_ONE_SHOT)
	_start_union_fight(union, ub, home)
	var won : bool = await union_battle_over
	if gm:
		gm.game_over_handler = Callable()
	if won:
		Achievements.unlock("b_end")
		Achievements.on_hidden_boss_defeated()
		await tree.create_timer(5.0, false).timeout
	else:
		await tree.create_timer(2.5, false).timeout
	if _runner:
		_runner.stage_cleared.emit()
	await tree.create_timer(4.0, false).timeout
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
	_set_banner()
	if not won:
		_enter_second_loop_if_allowed() # 負けたら A エンドと同じ
	_to_staff_roll()

## 裏ボス戦で負けた(残機が尽きた): Union は去り、ゲームオーバーにはせず、A エンドとしてクリアにする
func _on_union_lost(union : Enemy) -> void:
	if _union_over:
		return
	_union_over = true
	var tree := get_tree()
	EnemyShooter.hold_fire(60.0)
	tree.call_group("enemy_bullet", "vanish", 0.2)
	if is_instance_valid(union) and not union._is_dead:
		var hp := union.get_node_or_null("HPComponent") as HPComponent
		if hp:
			hp.damage_lock = true
		for node in union.find_children("*", "", true, false):
			if node is EnemyShooter:
				(node as EnemyShooter).suppressed = true
				(node as EnemyShooter).stop()
		var ub := union.get_node_or_null("UnionBoss")
		if ub:
			ub.set_physics_process(false)
		var leave := union.create_tween().set_parallel(true)
		leave.tween_property(union, "global_position:y", union.global_position.y - 520.0, 2.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		leave.tween_property(union, "modulate:a", 0.0, 2.2)
		leave.chain().tween_callback(union.queue_free)
	union_battle_over.emit(false)

## Union を出す(StageRunner から、ボスとして出す。HP のゲージが出る)
func _spawn_union() -> Enemy:
	if _union_scene == null:
		_union_scene = load(UNION_SCENE) as PackedScene
	if _union_scene == null or _runner == null:
		return null
	var event := SpawnEvent.new()
	event.enemy_scene = _union_scene
	event.is_boss = true
	event.boss_name = "UNION"
	event.boss_phase_thresholds = [0.66, 0.33]
	event.tag = "union"
	var spawned : Array[Enemy] = []
	var grab := func(enemy : Enemy, _boss_name : String, _t : Array[float]) -> void: spawned.append(enemy)
	_runner.boss_spawned.connect(grab)
	_runner.spawn(event, 0)
	_runner.boss_spawned.disconnect(grab)
	if spawned.is_empty():
		for node in get_tree().get_nodes_in_group("enemy"):
			if node is Enemy and node.scene_file_path == UNION_SCENE:
				spawned.append(node)
	if spawned.is_empty():
		return null
	var union := spawned[0]
	# ボスの登場の演出(ふつうのボス用)は使わない
	for child in union.get_children():
		if child is BossEntranceFx:
			child.queue_free()
	return union

## 母艦が貫かれて、爆発しながら墜ちていく。アームはちぎれる
func _destroy_mothership(mothership : Node2D) -> void:
	var tree := get_tree()
	for cable in _cables:
		cable.visible = false
	_cables.clear()
	ScreenFlash.play(tree, 1.0)
	HitStop.apply(tree, 0.15)
	var camera := StageCamera.of(get_tree().current_scene)
	if camera:
		camera.shake(14.0, 1.2)
	var at := mothership.global_position
	Explosion.spawn(tree, Explosion.WAVE, at, 2.6)
	for i in 6:
		Explosion.spawn(tree, Explosion.EXPLOSIVE, at + Vector2(randf_range(-90.0, 90.0), randf_range(-30.0, 30.0)), randf_range(1.2, 2.0))
	var fall := create_tween().set_parallel(true)
	fall.tween_property(mothership, "global_position", at + Vector2(-40.0, 520.0), 2.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_property(mothership, "rotation_degrees", -28.0, 2.6)
	fall.tween_property(mothership, "modulate", Color(0.35, 0.2, 0.2, 0.0), 2.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.chain().tween_callback(mothership.hide)
	_mothership_blasts(mothership)

func _mothership_blasts(mothership : Node2D) -> void:
	var tree := get_tree()
	for i in 14:
		if not is_instance_valid(mothership) or not mothership.visible:
			return
		var at := mothership.global_position + Vector2(randf_range(-110.0, 110.0), randf_range(-40.0, 40.0))
		Explosion.spawn(tree, Explosion.EXPLOSIVE if randf() < 0.6 else Explosion.ZAKO, at, randf_range(0.9, 1.6))
		await tree.create_timer(0.16, false).timeout

## 黒い WARNING(いつもの WARNING を、黒と深紅の色にして出す)
func _black_warning() -> void:
	var warning := WARNING_SCENE.instantiate() as WarningDisplay
	warning.paper_color = Color(0.03, 0.0, 0.04)
	warning.ink_color = Color(0.0, 0.0, 0.0)
	warning.accent_color = Color(0.78, 0.0, 0.12)
	warning.flood_colors = [Color(0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0), Color(0.6, 0.0, 0.1), Color(0.3, 0.0, 0.3)]
	warning.clear_bullets = false
	warning.duration = 4.0
	get_tree().current_scene.add_child(warning)
	warning.show_warning("WARNING")
	await warning.finished
	warning.queue_free()

## 口を開いて叫ぶ: 画面が揺れ、黒い波動が何度も広がる
func _roar(union : Enemy, uview : Node) -> void:
	var tree := get_tree()
	if uview:
		uview.play(&"Open", 0.05)
	await tree.create_timer(0.35, false).timeout
	var pitches := [0.42, 0.55]
	for i in ROAR_SOUNDS.size():
		var roar := AudioStreamPlayer.new()
		roar.stream = ROAR_SOUNDS[i]
		roar.pitch_scale = pitches[i]
		roar.volume_db = 2.0
		roar.bus = &"SFX"
		add_child(roar)
		roar.play()
		roar.finished.connect(roar.queue_free)
	var camera := StageCamera.of(get_tree().current_scene)
	if camera:
		camera.shake(16.0, 2.4)
	var dark := ColorRect.new()
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dark.set_anchors_preset(Control.PRESET_FULL_RECT)
	dark.color = Color(0.0, 0.0, 0.0, 0.0)
	_alarm_layer.add_child(dark)
	var pulse := create_tween().set_loops(3)
	pulse.tween_property(dark, "color:a", 0.45, 0.2)
	pulse.tween_property(dark, "color:a", 0.1, 0.4)
	for i in 6:
		if is_instance_valid(union):
			_BlackWave.spawn(tree, union.global_position, 360.0 + 60.0 * i, 1.1, 40.0 + 6.0 * i)
		await tree.create_timer(0.38, false).timeout
	pulse.kill()
	var clear := create_tween()
	clear.tween_property(dark, "color:a", 0.0, 0.5)
	clear.tween_callback(dark.queue_free)
	await tree.create_timer(0.4, false).timeout

## 裏ボス戦を始める: 自機を動かせるようにして、イグナイトを使えるようにし、Union が撃ち始める
func _start_union_fight(union : Enemy, ub : Node, home : Vector2) -> void:
	if is_instance_valid(_player):
		_player.set_physics_process(true)
		_player.ignite_locked = false
		_player.start_invincibility(2.0)
	EnemyShooter.release_fire()
	_cloud_speed = 1.4
	for node in get_tree().current_scene.find_children("*", "StageBGM", true, false):
		var bgm := node as StageBGM
		bgm._kill_fade()
		bgm._play_music(union_music)
	if ub:
		ub.begin_fight(home)

## Union を出せなかったとき(読み込めないなど): 前の B エンド(暗転して終わる)
func _plain_b_end() -> void:
	var tree := get_tree()
	for cable in _cables:
		cable.visible = false
	_cables.clear()
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
	_set_banner()
	_to_staff_roll()

## クリアの合図: 一周目は NORMAL ROUND CLEAR!(黄)、二周目は ANOTHER ROUND CLEAR!(赤)、
## 隠しボスを倒して二周目を終えたら congratulation!
func _set_banner() -> void:
	if RunConfig.loop >= 2:
		StaffRoll.banner = "congratulation!" if RunConfig.hidden_boss_defeated else "ANOTHER ROUND CLEAR!"
		StaffRoll.banner_color = Color(0.85, 0.08, 0.05)
	else:
		StaffRoll.banner = "NORMAL ROUND CLEAR!"
		StaffRoll.banner_color = Color(0.86, 0.62, 0.0)
	Achievements.on_round_clear()

## エンディング(スタッフロール)へ。終わったらタイトルへ(二周目へ進むときは、タイトルが合図を見せて一面へ)
func _to_staff_roll() -> void:
	StaffRoll.next_scene = title_scene
	SceneSwitcher.change(STAFF_ROLL, 1.0)

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
