extends Node
class_name StageTransition
## ステージとステージをつなぐ部品。ステージのシーンに置く。
##
## このステージをクリアしたとき(Next Stage を設定してあれば):
##   1. クリアのボーナス表示のあいだ待つ(Clear Wait)
##   2. 自機が操作できなくなり、画面の真ん中あたりへすっと動く
##   3. 霧が上から降りてきて、画面が覆われる。自機は霧の上を飛び続ける(霧の中を駆け抜ける)。曲も消えていく
##   4. 自機と点数の状態(StageCarry)を覚えて、次のステージのシーンに切り替える
## 前のステージから来たとき:
##   5. 霧に覆われた中で、覚えた状態(点数・残機・イグナイトゲージ・ショット・子機・ロック速度)を入れる
##   6. 霧の終わりが上から過ぎていき、霧を抜ける
##   7. 自機が最初の位置へ降りてきて、操作できるようになり、ステージが始まる(出撃の演出はしない)
## StageIntro は、前のステージから来たとき(StageCarry.arriving)は何もせず、この部品が終わってからステージを始める。

## 次のステージのシーン。空なら、クリアしても次へは移らない
@export_file("*.tscn") var next_stage : String = ""
## クリアしてから霧が出始めるまでの時間(秒。クリアのボーナス表示のあいだ)
@export var clear_wait : float = 4.0
## 霧が降りてくる時間・覆われたまま飛ぶ時間(秒)
@export var fog_in_time : float = 2.0
@export var fog_hold_time : float = 1.5
## 次のステージで、霧の中を飛ぶ時間・霧が晴れる時間・自機が最初の位置へ降りる時間(秒)
@export var arrive_hold_time : float = 1.0
@export var fog_out_time : float = 2.0
@export var descend_time : float = 1.3
## 霧の中を飛ぶときの、自機の高さ(画面の上 = 0、下 = 1)
@export_range(0.1, 0.9, 0.05) var cruise_height : float = 0.6
## 霧のあいだに曲を消す時間(秒)
@export var music_fade_time : float = 2.0

var _fog : FogOverlay

func _ready() -> void:
	_arrive.call_deferred()
	_connect.call_deferred()

func _connect() -> void:
	if next_stage == "":
		return
	var runner := get_tree().get_first_node_in_group("stage_runner") as StageRunner
	if runner:
		runner.stage_cleared.connect(_on_stage_cleared, CONNECT_ONE_SHOT)

# ---------------------------------------------------------------- 出ていく

func _on_stage_cleared() -> void:
	await get_tree().create_timer(clear_wait, false).timeout
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
	_fog = _make_fog()
	await _fog.descend(fog_in_time)
	await get_tree().create_timer(fog_hold_time, false).timeout
	StageCarry.save(get_tree())
	StageCarry.arriving = true
	StageCarry.cruise_height = cruise_height
	get_tree().change_scene_to_file(next_stage)

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
		player.global_position = Vector2(view.get_center().x, view.position.y + view.size.y * StageCarry.cruise_height)
	_fog = _make_fog()
	_fog.cover()
	await get_tree().process_frame # ScoreSystem などの準備(call_deferred)が終わってから
	StageCarry.apply(get_tree())
	await get_tree().create_timer(arrive_hold_time, false).timeout
	await _fog.clear(fog_out_time)
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

func _make_fog() -> FogOverlay:
	var fog := FogOverlay.new()
	get_tree().current_scene.add_child(fog)
	return fog

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
