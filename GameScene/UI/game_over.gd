extends CanvasLayer
class_name GameOverScreen
## ゲームオーバーの画面。シーン(GameScene/UI/game_over.tscn)を GameManager が出す(Game Over Scene)。
##
## 流れ:
##   1. 自機が最後の残機で撃墜される → Appear Delay 秒(爆発を見せる)のあいだ、ゲームはそのまま動く。BGM は消えていく
##   2. 上下からシャッターが降りてきて、真ん中でガシャンと閉まる(画面が揺れる)。同時に画面にノイズが掛かり、周りが暗くなる
##   3. ゲームが止まり、閉まったシャッターの真ん中に電光掲示板が出て、GAME OVER が右から流れてきて、点滅する
##   4. スコアと「PRESS SHOT TO RETRY」が出る。Retry Action を押すと、ステージを最初からやり直す:
##      映像が大きく乱れて掲示板が消え → ステージを読み直し → シャッターが開いて、新しいステージが見える
##
## 見た目(シャッターの色・板の高さ・警告の帯、ノイズの強さ、掲示板の色・文字)は、シーンの中のノードとシェーダーの値で変える。

## 撃墜されてから、シャッターが降り始めるまでの時間(秒)
@export var appear_delay : float = 1.2
## シャッターが閉まるまでの時間(秒)。最後に少し跳ねる
@export var shutter_time : float = 0.75
## 閉まったときの揺れの強さ(px)
@export var shake_strength : float = 6.0
## 掲示板の文字が流れる速さ(1秒に進む点の列の数)と、止まってから点滅する回数
@export var marquee_speed : float = 75.0
@export var blink_count : int = 3
## BGM が消えていく時間(秒)
@export var music_fade_time : float = 1.5
## やり直すボタン(Input Map のアクション名)
@export var retry_action : StringName = &"UI_Shoot"
## やり直すときに、映像が乱れている時間と、シャッターが開くまでの時間(秒)
@export var glitch_time : float = 0.35
@export var open_time : float = 0.6
## シャッターが閉まった音と、掲示板が点いた音(シーンに置いた AudioStreamPlayer)
@export var slam_sound : AudioStreamPlayer
@export var board_sound : AudioStreamPlayer

@onready var _root : Control = $Root
@onready var _top : ColorRect = $Root/ShutterTop
@onready var _bottom : ColorRect = $Root/ShutterBottom
@onready var _board : LedBoard = $Root/Board
@onready var _score_label : Label = $Root/ScoreLabel
@onready var _prompt_label : Label = $Root/PromptLabel
@onready var _fx : ColorRect = $Root/ScreenFx

var _started : bool = false
var _can_retry : bool = false
var _prompt_blink : Tween
var _fx_defaults : Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # ゲームを止めたあとも動く
	visible = false

## ゲームオーバーを始める。score は最後のスコア
func play(score : int) -> void:
	if _started:
		return
	_started = true
	_fade_music()
	await _wait(appear_delay)
	_layout()
	_score_label.text = "SCORE %09d" % score
	_score_label.visible = false
	_prompt_label.visible = false
	_board.visible = false
	visible = true

	# ノイズと暗さが、だんだん掛かる
	_set_fx(0.0)
	create_tween().tween_method(_set_fx, 0.0, 1.0, shutter_time + 0.3)

	# シャッターが降りる(最後にガシャンと跳ねる)
	var half := _top.size.y
	_top.position.y = -half
	_bottom.position.y = half * 2.0
	var shutter := create_tween().set_parallel(true).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	shutter.tween_property(_top, "position:y", 0.0, shutter_time)
	shutter.tween_property(_bottom, "position:y", half, shutter_time)
	await _wait(shutter_time * 0.36) # 跳ねる動きで、最初に閉まりきる時刻
	SoundManager.play(slam_sound)
	_shake()
	await shutter.finished

	get_tree().paused = true # ゲームを止める
	await _wait(0.3)

	# 電光掲示板が点いて、GAME OVER が流れてくる
	_board.visible = true
	_board.scale = Vector2(1.0, 0.0)
	var pop := create_tween()
	pop.tween_property(_board, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await pop.finished
	SoundManager.play(board_sound)
	await _board.run_marquee(marquee_speed)
	await _board.blink(blink_count)

	_score_label.visible = true
	await _wait(0.4)
	_prompt_label.visible = true
	for key in _GLITCH:
		_fx_default(key) # 乱す前の値を覚えておく
	_prompt_blink = create_tween().set_loops()
	_prompt_blink.tween_property(_prompt_label, "modulate:a", 0.15, 0.5)
	_prompt_blink.tween_property(_prompt_label, "modulate:a", 1.0, 0.5)
	_can_retry = true

func _process(_delta : float) -> void:
	if _can_retry and InputMap.has_action(retry_action) and Input.is_action_just_pressed(retry_action):
		_can_retry = false
		_retry()

## やり直し: 映像が乱れて掲示板が消え、ステージを読み直してから、シャッターが開いて新しいステージが見える
func _retry() -> void:
	if _prompt_blink:
		_prompt_blink.kill()
	_score_label.visible = false
	_prompt_label.visible = false
	SoundManager.play(board_sound, 0.55)
	# 映像が大きく乱れる
	var glitch := create_tween().set_parallel(true)
	for key in _GLITCH:
		glitch.tween_method(_set_fx_param.bind(key), _fx_default(key), _GLITCH[key], glitch_time)
	_board.flicker_off()
	await _wait(glitch_time + 0.15)

	# ステージを読み直す。この画面は、読み直しても消えないように、ステージの外(ルート)へ移しておく
	reparent(get_tree().root)
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()
	await get_tree().process_frame
	await get_tree().process_frame
	_board.visible = false

	# シャッターが開く(上は上へ、下は下へ。巻き上げるように、だんだん速く)。乱れは収まっていく
	SoundManager.play(slam_sound, 1.4, -6.0)
	var half := _top.size.y
	var open := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	open.tween_property(_top, "position:y", -half - 4.0, open_time)
	open.tween_property(_bottom, "position:y", half * 2.0 + 4.0, open_time)
	var calm := create_tween().set_parallel(true)
	for key in _GLITCH:
		calm.tween_method(_set_fx_param.bind(key), _GLITCH[key], _fx_default(key), open_time * 0.6)
	calm.chain().tween_method(_set_fx, 1.0, 0.0, open_time * 0.6)
	await open.finished
	await calm.finished
	queue_free()

## やり直すときの、乱れたときのシェーダーの値
const _GLITCH : Dictionary = {
	"noise_amount": 0.5,
	"tear_amount": 0.09,
	"tear_chance": 0.55,
	"desaturate": 0.8,
}

## シーンに入れてある、シェーダーのもとの値
func _fx_default(key : String) -> float:
	if not _fx_defaults.has(key):
		_fx_defaults[key] = float((_fx.material as ShaderMaterial).get_shader_parameter(key))
	return _fx_defaults[key]

func _set_fx_param(value : float, key : String) -> void:
	(_fx.material as ShaderMaterial).set_shader_parameter(key, value)

## 画面の大きさに合わせて、シャッター・掲示板・文字を並べる
func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	var half := ceilf(view.y * 0.5)
	for shutter in [_top, _bottom]:
		shutter.size = Vector2(view.x, half)
		shutter.position.x = 0.0
		(shutter.material as ShaderMaterial).set_shader_parameter("rect_size", shutter.size)
	var board_width := view.x - 24.0
	_board.size = Vector2(board_width, _board.height_for(board_width))
	_board.position = Vector2((view.x - board_width) * 0.5, half - _board.size.y * 0.5)
	_board.pivot_offset = _board.size * 0.5
	var below := _board.position.y + _board.size.y
	for label in [_score_label, _prompt_label]:
		label.position.x = 0.0
		label.size.x = view.x
	_score_label.position.y = below + 14.0
	_prompt_label.position.y = below + 36.0
	_fx.position = Vector2.ZERO
	_fx.size = view

func _set_fx(value : float) -> void:
	(_fx.material as ShaderMaterial).set_shader_parameter("strength", value)

## 閉まった衝撃で、だんだん弱く揺れる
func _shake() -> void:
	if shake_strength <= 0.0:
		return
	var tween := create_tween()
	for i in 6:
		var power := shake_strength * (1.0 - i / 6.0)
		tween.tween_property(_root, "position", Vector2(randf_range(-0.4, 0.4) * power, randf_range(-1.0, 1.0) * power), 0.035)
	tween.tween_property(_root, "position", Vector2.ZERO, 0.04)

## ステージの BGM(ステージ直下で鳴っている AudioStreamPlayer)を消していく
func _fade_music() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	for node in scene.get_children():
		var music := node as AudioStreamPlayer
		if music and music.playing:
			var tween := create_tween()
			tween.tween_property(music, "volume_db", -60.0, music_fade_time)
			tween.tween_callback(music.stop)

## ゲームを止めていても進むタイマーで待つ
func _wait(seconds : float) -> void:
	if seconds > 0.0:
		await get_tree().create_timer(seconds, true).timeout
