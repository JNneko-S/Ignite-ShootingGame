extends Node
class_name BreachSequence
## 演出のあいだの無敵・アイテム回収(新しいクラスなので、ファイルを直接読み込む)
const _Safety := preload("res://Component/Stage/cinematic_safety.gd")
## 中枢への突入の演出。タイムラインの StageSignalEvent(signal_name)で始まる。
##   1. 一瞬ためてから、背景が一気に流れる(風の筋が出て、加速しているように見せる)
##   2. 行く手の隔壁が次々に開き、自機がくぐった直後に、後ろで勢いよく閉まる
##   3. 最後の隔壁が閉まると「隔壁閉鎖」。背景はふつうの速さに戻り、次の区間へ流れていく

@export var scroller : BackgroundScroller
## これを受け取ったら始める
@export var signal_name : String = "breach"
## 隔壁の位置(背景から見た y。上へ行くほど小さい)と、横の中心
@export var door_ys : Array[float] = [-7200.0, -7700.0, -8200.0]
@export var door_x : float = 242.0
## 突入のあいだ、自機を運んでおく高さ(画面の高さに対する割合。上が 0)
@export var player_hold_ratio : float = 0.68
## 加速が終わったとき、最後の隔壁が止まる位置(自機から下へ、画面の高さに対する割合)
@export var last_door_below_player : float = 0.17
## ためる時間・一気に流れる時間(秒)
@export var windup_time : float = 0.5
@export var dash_time : float = 2.6
## 突入のあとに流れていく先(背景から見た上の端)と、そこへ着くステージ時刻
@export var next_top : float = -19760.0
@export var next_arrive_time : float = 300.0
## 突入のはじめと、隔壁が閉まったときに出す文字
@export var start_text : String = ""
@export var sealed_text : String = ""

const SND_DASH := "res://Assets/Sounds/Graze/AS_151526_シャッ（ライターを使って火を付ける）.mp3"
const SND_SLAM := "res://Assets/Sounds/Explosive/AS_1474525_爆発01-1（短）.mp3"
const SND_SEAL := "res://Assets/Sounds/Explosive/AS_833264_フィルターが掛かったような爆破音.mp3"

var _doors : Array[BlastDoor] = []
var _closed : Array[bool] = []
var _opened : Array[bool] = []
var _running : bool = false
var _carried : Player

func _ready() -> void:
	_connect_runner.call_deferred()

func _connect_runner() -> void:
	var runner := get_tree().get_first_node_in_group("stage_runner") as StageRunner
	if runner:
		runner.stage_signal.connect(_on_stage_signal)
	if scroller == null:
		scroller = get_tree().get_first_node_in_group("background_scroller") as BackgroundScroller
	# 隔壁は最初から置いておく(ボス戦の画面の上の端に、少し見えていてもよい)
	if scroller:
		for y in door_ys:
			var door := BlastDoor.new()
			door.position = Vector2(door_x, y)
			door.open_amount = 0.0
			scroller.add_child(door)
			_doors.append(door)
			_closed.append(false)
			_opened.append(false)
	# 途中から始めたとき(ボスへジャンプ・プラクティスなど): 突入がもう済んでいれば、突入したあとの位置へ背景を置く
	if runner and scroller and runner.signal_passed(signal_name):
		_skip_to_after(runner)

## 突入を飛ばした: 突入の時刻に背景がいたはずの位置から、一気に流れた先(最後の隔壁が自機の下)を求め、
## そこから next_top へ流れていく途中の、今の時刻の位置にする(隔壁は閉じたまま)
func _skip_to_after(runner : StageRunner) -> void:
	if not scroller._initialized:
		scroller._initialize()
	var signal_at := runner.signal_time(signal_name)
	if signal_at < 0.0 or _doors.is_empty():
		return
	var span := maxf(scroller.arrive_at_time, 0.001)
	var y_at_signal := lerpf(scroller._start_y, scroller._end_y, clampf(signal_at / span, 0.0, 1.0)) if scroller.arrive_at_time > 0.0 else scroller.position.y
	var view := CameraView.visible_rect(scroller)
	var hold_y := view.position.y + view.size.y * player_hold_ratio
	var door_y := minf(hold_y + view.size.y * last_door_below_player, view.end.y - view.size.y * 0.05)
	var last := _doors[_doors.size() - 1]
	var last_at_signal := last.global_position.y + (y_at_signal - scroller.position.y)
	scroller.position.y = y_at_signal + door_y - last_at_signal
	for i in _doors.size():
		_opened[i] = true
		_closed[i] = true
	scroller.continue_to(next_top, next_arrive_time)
	scroller._segment_start_time = signal_at + windup_time + dash_time # 突入が終わった時刻から流れはじめたことにする

func _on_stage_signal(name_ : String, _text : String) -> void:
	if name_ == signal_name and not _running:
		start()

func start() -> void:
	if scroller == null or _doors.is_empty():
		return
	_running = true
	# 突入の演出: 残っている敵弾はスコアアイテムに変えて全部回収し、終わるまで自機は無敵
	_Safety.begin(get_tree(), true)
	scroller.external_control = true
	_banner(start_text, Color(1.0, 0.85, 0.35), 1.6)
	var streaks := DashStreaks.new()
	streaks.count = 56
	get_tree().current_scene.add_child(streaks)

	# 最後の隔壁が last_door_screen_y に来るまで進める
	var view := CameraView.visible_rect(scroller)
	var last := _doors[_doors.size() - 1]
	var start_y := scroller.position.y
	# 自機は、突入のあいだ操作できず、くぐる高さへ運ばれる(最後の隔壁が自機の後ろで閉まるように)
	var hold_y := view.position.y + view.size.y * player_hold_ratio
	_carry_player(hold_y)
	var door_y := minf(hold_y + view.size.y * last_door_below_player, view.end.y - view.size.y * 0.05)
	var target_y := start_y + door_y - last.global_position.y

	var tween := create_tween()
	# ため: 少しだけ押し戻される
	tween.tween_property(scroller, "position:y", start_y - 18.0, windup_time)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(streaks, "amount", 0.25, windup_time)
	tween.tween_callback(_play.bind(SND_DASH, -4.0))
	tween.tween_callback(_shake.bind(3.0, 0.4))
	# 一気に流れる(はじめは鋭く加速し、最後はぐっと減速する)
	tween.tween_property(scroller, "position:y", target_y, dash_time)\
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(streaks, "amount", 1.0, dash_time * 0.35)
	tween.parallel().tween_property(streaks, "amount", 0.0, dash_time * 0.4).set_delay(dash_time * 0.6)
	tween.tween_callback(_finish.bind(streaks))

func _process(_delta : float) -> void:
	if not _running:
		return
	var view := CameraView.visible_rect(scroller)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var pass_y := view.position.y + view.size.y * 0.8
	if player and player.visible:
		pass_y = minf(player.global_position.y + 34.0, pass_y)
	for i in _doors.size():
		var door := _doors[i]
		var y := door.global_position.y
		# 画面に入る少し前に開きはじめる
		if not _opened[i] and y > view.position.y - 260.0:
			_opened[i] = true
			_open(door)
		# 自機の下を過ぎたら、閉める
		if _opened[i] and not _closed[i] and y > pass_y:
			_close(i)

## 自機を操作できなくして、y の高さへ運ぶ(横の位置はそのまま)
func _carry_player(y : float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null or not player.visible:
		return
	_carried = player
	player.set_physics_process(false)
	player.velocity = Vector2.ZERO
	var tween := player.create_tween()
	tween.tween_property(player, "global_position:y", y, windup_time + 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _release_player() -> void:
	if is_instance_valid(_carried) and _carried.visible:
		_carried.set_physics_process(true)
	_carried = null

func _finish(streaks : DashStreaks) -> void:
	_release_player()
	_Safety.end(get_tree(), true)
	for i in _doors.size():
		if not _closed[i]:
			_close(i) # 自機が画面の下のほうにいて、まだくぐっていなくても閉める
	if is_instance_valid(streaks):
		streaks.queue_free()
	_running = false
	scroller.continue_to(next_top, next_arrive_time)
	# 隔壁は画面の外へ流れたあとに消す
	var cleanup := get_tree().create_timer(12.0, false)
	cleanup.timeout.connect(func() -> void:
		for door in _doors:
			if is_instance_valid(door):
				door.queue_free())

func _open(door : BlastDoor) -> void:
	var tween := door.create_tween()
	tween.tween_property(door, "open_amount", 1.0, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _close(i : int) -> void:
	_closed[i] = true
	var door := _doors[i]
	var is_last := i == _doors.size() - 1
	var tween := door.create_tween()
	# 勢いよく閉まる(最後に少しだけ跳ね返る)
	tween.tween_property(door, "open_amount", 0.0, 0.14).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		door.seal_glow = 1.0
		_play(SND_SEAL if is_last else SND_SLAM, 0.0 if is_last else -6.0)
		_shake(11.0 if is_last else 5.0, 0.6 if is_last else 0.25)
		if is_last:
			_banner(sealed_text, Color(1.0, 0.3, 0.2), 1.8, true))
	tween.tween_property(door, "open_amount", 0.03, 0.05)
	tween.tween_property(door, "open_amount", 0.0, 0.08)
	tween.tween_property(door, "seal_glow", 0.0, 1.0)

func _shake(strength : float, time : float) -> void:
	var camera := StageCamera.of(self)
	if camera:
		camera.shake(strength, time)

func _play(path : String, volume : float) -> void:
	var stream := load(path) as AudioStream
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume
	player.bus = SoundManager.SFX_BUS if AudioServer.get_bus_index(SoundManager.SFX_BUS) >= 0 else &"Master"
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)

## 画面の中央に、大きな文字を出す(blink なら点滅する)
func _banner(text : String, color : Color, time : float, blink : bool = false) -> void:
	if text == "":
		return
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var label := Label.new()
	var settings := LabelSettings.new()
	settings.font = LevelUpPopup.FONT
	settings.font_size = 30
	settings.font_color = color
	settings.outline_size = 8
	settings.outline_color = Color(0.1, 0.02, 0.0)
	label.label_settings = settings
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var size := get_viewport().get_visible_rect().size
	label.size = Vector2(size.x, 60.0)
	label.position = Vector2(0.0, size.y * 0.32)
	label.pivot_offset = label.size * 0.5
	label.scale = Vector2(1.6, 1.6)
	label.modulate.a = 0.0
	layer.add_child(label)
	var tween := label.create_tween()
	tween.tween_property(label, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 1.0, 0.12)
	if blink:
		for k in 3:
			tween.tween_property(label, "modulate:a", 0.25, 0.12)
			tween.tween_property(label, "modulate:a", 1.0, 0.12)
	tween.tween_interval(maxf(time - (0.72 if blink else 0.0), 0.2))
	tween.tween_property(label, "modulate:a", 0.0, 0.3)
	tween.tween_callback(layer.queue_free)
