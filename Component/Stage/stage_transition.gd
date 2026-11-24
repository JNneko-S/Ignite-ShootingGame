extends Node
class_name StageTransition
## (新しく足したクラスは、エディタがクラス名を覚える前でも動くように、ファイルを直接読み込んで使う)
const _CloudOverlay := preload("res://Component/Stage/cloud_overlay.gd")
## ステージとステージをつなぐ部品。ステージのシーンに置く。
##
## このステージをクリアしたとき(Next Stage を設定してあれば):
##   1. クリアのボーナス表示のあいだ待つ(Clear Wait)
##   2. 自機が操作できなくなり、画面の真ん中あたりへすっと動く。曲が消えていく
##   3. 霧が画面の上のほうまで降りてきて、背景の流れが速くなり、風の筋が流れ始める
##   4. 自機が少し沈んでから、加速して霧に突っ込む。突っ込んだところで「ぼふっ」と霧が弾けて、自機は霧の中に消える
##   5. 霧が画面を覆いきったら、自機と点数の状態(StageCarry)を覚えて、次のステージのシーンに切り替える
## 前のステージから来たとき:
##   6. 霧に覆われた中で(自機は霧の中に隠れている)、覚えた状態(点数・残機・イグナイトゲージ・ショット・子機・ロック速度)を入れる
##   7. 霧がちぎれるように消えていき、霧の中から自機が現れる。風の筋もおさまる
##   8. 自機が最初の位置へ降りてきて、操作できるようになり、ステージが始まる(出撃の演出はしない)
## StageIntro は、前のステージから来たとき(StageCarry.arriving)は何もせず、この部品が終わってからステージを始める。

## 次のステージのシーン。空なら、クリアしても次へは移らない
@export_file("*.tscn") var next_stage : String = ""
## 次のステージへ、霧ではなく雲を抜けて降りていく(雲の切れ間から、次のステージの地上が見えてくる)。
## 出ていくステージで設定する。入ってくるステージは、前のステージがどちらだったかを StageCarry から知る
@export var through_clouds : bool = false
## クリアしてから霧が出始めるまでの時間(秒。クリアのボーナス表示のあいだ)
@export var clear_wait : float = 4.0
## クリアのボーナス表示は、この秒数たったら、ショットで先へ進める(待たされないように)
@export var clear_skip_after : float = 1.0
@export var skip_action : StringName = &"UI_Shoot"
## 霧が降りてくる時間・覆われたまま飛ぶ時間(秒)
@export var fog_in_time : float = 2.0
@export var fog_hold_time : float = 0.6
## 次のステージで、霧の中を飛ぶ時間・霧が晴れる時間・自機が最初の位置へ降りる時間(秒)
@export var arrive_hold_time : float = 0.5
@export var fog_out_time : float = 2.0
@export var descend_time : float = 1.3
## 霧の中を飛ぶときの、自機の高さ(画面の上 = 0、下 = 1)
@export_range(0.1, 0.9, 0.05) var cruise_height : float = 0.6

@export_group("霧に突っ込む")
## 突っ込む前に、霧がここまで降りてくる(画面の上 = 0、下 = 1)と、降りてくる時間(秒)
@export_range(0.1, 0.8, 0.05) var fog_reach : float = 0.35
@export var fog_reach_time : float = 1.0
## 突っ込む前に沈む距離(px)と時間(秒)・突っ込む時間(秒)
@export var dip_distance : float = 22.0
@export var dip_time : float = 0.22
@export var dash_time : float = 0.3
## 霧の中に入る高さ(画面の上 = 0、下 = 1)。次のステージでは、この高さの霧の中から現れる
@export_range(0.0, 0.6, 0.05) var dash_height : float = 0.2
## 霧に突っ込むあいだの、背景の流れの速さ(倍)
@export var dash_scroll : float = 3.0
## 霧がちぎれて消える時間(秒。次のステージ)
@export var dissolve_time : float = 2.0
## 霧のあいだに曲を消す時間(秒)
@export var music_fade_time : float = 2.0

## 霧(FogOverlay)か、雲(CloudOverlay)。どちらも descend_to / descend / cover / dissolve で動かす
var _fog

func _ready() -> void:
	_arrive.call_deferred()
	_connect.call_deferred()

func _connect() -> void:
	if next_stage == "":
		# 最後のステージ: クリアしたら、全クリアとしてスコアボードに記録する
		var last_runner := get_tree().get_first_node_in_group("stage_runner") as StageRunner
		if last_runner:
			last_runner.stage_cleared.connect(func() -> void: ScoreBoard.finish_run(get_tree(), true), CONNECT_ONE_SHOT)
		return
	var runner := get_tree().get_first_node_in_group("stage_runner") as StageRunner
	if runner:
		runner.stage_cleared.connect(_on_stage_cleared, CONNECT_ONE_SHOT)

# ---------------------------------------------------------------- 出ていく

func _on_stage_cleared() -> void:
	await _wait_or_skip(clear_wait, clear_skip_after)
	if not is_inside_tree():
		return
	var player := StageCarry.find_player(get_tree())
	var view := CameraView.visible_rect(get_tree().current_scene as CanvasItem)
	var cruise := Vector2(view.get_center().x, view.position.y + view.size.y * cruise_height)
	if player:
		_lock_player(player)
		var glide := create_tween()
		glide.tween_property(player, "global_position", cruise, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_fade_music()
	# 霧が画面の上のほうまで降りてきて、速さが上がっていく
	_fog = _make_fog(through_clouds)
	var streaks := _make_streaks()
	var runner := get_tree().get_first_node_in_group("stage_runner") as StageRunner
	if runner:
		runner.set_scroll_speed(dash_scroll, fog_reach_time + dip_time + dash_time)
	_tween_streaks(streaks, 0.6, fog_reach_time)
	await _fog.descend_to(fog_reach, fog_reach_time)
	# 少し沈んでから、加速して霧に突っ込む
	if player and is_instance_valid(player):
		var dip := create_tween()
		dip.tween_property(player, "global_position:y", player.global_position.y + dip_distance, dip_time)			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		await dip.finished
		_tween_streaks(streaks, 1.0, dash_time)
		view = CameraView.visible_rect(get_tree().current_scene as CanvasItem)
		var dash := create_tween()
		dash.tween_property(player, "global_position:y", view.position.y + view.size.y * dash_height, dash_time)			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		await dash.finished
		# ぼふっ: 霧が弾けて、自機は霧の中に消える
		FogPuff.spawn(get_tree(), player.global_position, 1.3)
		_hide_in_fog(player)
		var camera := StageCamera.of(self)
		if camera:
			camera.shake(4.0, 0.25)
	await _fog.descend(fog_in_time * 0.6)
	await get_tree().create_timer(fog_hold_time, false).timeout
	if through_clouds:
		_CloudOverlay.remember_colors(get_tree())
	StageCarry.save(get_tree())
	StageCarry.through_clouds = through_clouds
	StageCarry.arriving = true
	StageCarry.cruise_height = dash_height
	SceneSwitcher.change(next_stage) # つなぎ目なく(霧の画面のまま)次のステージへ

# ---------------------------------------------------------------- 入ってくる

## 前のステージから来たときは、霧の中から始めて、霧を抜けてからステージを始める
func _arrive() -> void:
	if not StageCarry.arriving:
		return
	var player := StageCarry.find_player(get_tree())
	var view := CameraView.visible_rect(get_tree().current_scene as CanvasItem)
	var start := Vector2.ZERO
	if player:
		start = player.global_position # シーンに置いてある最初の位置
		_lock_player(player)
		_hide_in_fog(player) # 霧の中に隠れている
		player.global_position = Vector2(view.get_center().x, view.position.y + view.size.y * StageCarry.cruise_height)
	_fog = _make_fog(StageCarry.through_clouds)
	_fog.cover()
	StageCarry.through_clouds = false
	var streaks := _make_streaks()
	streaks.amount = 1.0
	await get_tree().process_frame # ScoreSystem などの準備(call_deferred)が終わってから
	if not is_inside_tree():
		return
	StageCarry.apply(get_tree())
	await get_tree().create_timer(arrive_hold_time, false).timeout
	# 霧がちぎれるように消えていき、霧の中から自機が現れる
	_tween_streaks(streaks, 0.0, dissolve_time, true)
	await _fog.dissolve(dissolve_time)
	if player and is_instance_valid(player):
		var down := create_tween()
		down.tween_property(player, "global_position", start, descend_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await down.finished
		_unlock_player(player)
	StageCarry.arriving = false
	# 出撃の演出の代わりに、ここでステージを始める
	var intro := get_tree().current_scene.find_children("*", "StageIntro", true, false)
	if not intro.is_empty():
		intro[0]._finish()
	else:
		var runner := get_tree().get_first_node_in_group("stage_runner") as StageRunner
		if runner:
			runner.start()

# ---------------------------------------------------------------- 共通

## seconds 秒待つ。skip_after 秒たってからショットを押したら、そこで終わる
func _wait_or_skip(seconds : float, skip_after : float) -> void:
	var t := 0.0
	var tree := get_tree()
	while t < seconds and is_inside_tree():
		await tree.process_frame
		t += get_process_delta_time()
		if t >= skip_after and InputMap.has_action(skip_action) and Input.is_action_just_pressed(skip_action):
			return

func _make_fog(clouds : bool = false) -> Node2D:
	var fog : Node2D = _CloudOverlay.new() if clouds else FogOverlay.new()
	get_tree().current_scene.add_child(fog)
	return fog

func _make_streaks() -> DashStreaks:
	var streaks := DashStreaks.new()
	get_tree().current_scene.add_child(streaks)
	return streaks

## 風の筋の濃さを、time 秒かけて to にする。free_after なら、終わったら消す
func _tween_streaks(streaks : DashStreaks, to : float, time : float, free_after : bool = false) -> void:
	if not is_instance_valid(streaks):
		return
	var tween := streaks.create_tween()
	tween.tween_property(streaks, "amount", to, time)
	if free_after:
		tween.tween_callback(streaks.queue_free)

## 自機を霧より奥に描く(霧の中に隠れる)。霧が消えると見えてくる
func _hide_in_fog(player : Player) -> void:
	player.z_as_relative = false
	player.z_index = 45 # 霧(50)より奥、敵や弾より手前

## 自機を操作できなくして、霧より上に描く
func _lock_player(player : Player) -> void:
	player.set_physics_process(false)
	player.velocity = Vector2.ZERO
	player.z_as_relative = false
	player.z_index = 70 # 霧(50)より上

func _unlock_player(player : Player) -> void:
	player.z_index = 0
	player.z_as_relative = true
	player.set_physics_process(true)

func _fade_music() -> void:
	for node in get_tree().current_scene.find_children("*", "AudioStreamPlayer", true, false):
		var music := node as AudioStreamPlayer
		if music.playing and music.get_script() and music.get_script().resource_path.ends_with("stage_bgm.gd"):
			var tween := create_tween()
			tween.tween_property(music, "volume_db", -60.0, music_fade_time)
