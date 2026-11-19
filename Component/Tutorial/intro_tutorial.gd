extends CanvasLayer
class_name IntroTutorial
## 出撃のときの操作チュートリアル。EASY・NORMAL で、はじめて出撃したときだけ、雲の上で行う(StageIntro が置く)。
## 母艦が自機を切り離して去ったあと、雲が晴れる前に、実際に操作させて覚えてもらう:
##   1. 移動        … 決まった距離を動く
##   2. 低速移動    … 低速ボタンを押しながら動く
##   3. ショット    … 出てきた的を3つ壊す
##   4. グレイズ    … 画面の上から撃たれる弾をかすめる(レベルが上がるとショットも強くなる、も伝える)
##   5. イグナイト  … ゲージのレベルを使って、弾を跳ね返す
## 説明の文は、最後に触ったのがキーボードかコントローラーかで切り替わる。
## ポーズのボタン(Esc / START)で、いつでもスキップできる。終えたか飛ばしたら、次からは出さない(TutorialProgress)。
## 練習で増えたゲージとスコアは、終わったら元に戻す。

signal finished

## 動いているあいだ true(ポーズ画面は開かない。ポーズのボタンはスキップに使う)
static var active : bool = false

const SKIP_ACTION : StringName = &"UI_Pause"
## キーボード / コントローラーの、ボタンの呼び方
const KEYS := {
	"move": "W A S D", "focus": "Shift", "shoot": "Space", "ignite": "E", "skip": "Esc",
}
const PAD := {
	"move": "左スティック / 十字キー", "focus": "X / LB / LT", "shoot": "A / RB", "ignite": "B / Y / RT", "skip": "START",
}
const PRACTICE_BULLET : PackedScene = preload("res://GameScene/Bullet/E_Red_Normal.tscn")
## このチュートリアルで教える、EASY の案内
const TUTORED_TIPS := ["graze", "level", "ignite"]
const OK_SOUND : AudioStream = preload("res://Assets/Sounds/Score/AS_897229_ポチン（報酬獲得・クーポン・エントリー）.mp3")

## 移動で動く距離(px)、低速で動く時間(秒)、壊す的の数と体力、グレイズする回数
@export var move_goal : float = 450.0
@export var focus_goal : float = 1.2
@export var target_count : int = 3
@export var target_hp : int = 40
@export var graze_goal : int = 8
## グレイズの練習の長さの上限(秒)。かすめられなくても、これで次へ進む
@export var graze_timeout : float = 25.0

var player : Player
## 練習の弾を撃つ場所。空なら、画面の上の真ん中から撃つ
var mothership : Node2D

var _pad : bool = false
var _skipped : bool = false
var _step_title : String = ""
var _step_key : String = ""
var _progress : String = ""
var _panel : PanelContainer
var _title : Label
var _body : RichTextLabel
var _status : Label
var _skip_label : Label
var _ok_player : AudioStreamPlayer
var _targets : Array[Node2D] = []
var _grazes : int = 0
var _ignited : bool = false
var _was_invincible : bool = false

## このプレイで、チュートリアルをするか(EASY・NORMAL で、まだ終えていない)
static func should_run() -> bool:
	return RunConfig.difficulty <= 1 and not TutorialProgress.intro_done()

func _ready() -> void:
	layer = 27
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_pad = not Input.get_connected_joypads().is_empty()
	_build()

## チュートリアルをする。終わる(か、飛ばす)まで await できる
func run() -> void:
	active = true
	_was_invincible = DebugTools.invincible
	DebugTools.invincible = true # 練習の弾に当たっても、やられない(グレイズはできる)
	# EASY の案内(グレイズ・レベル・イグナイト)は、ここで教えるので出さない(飛ばしたら、元どおり出す)
	for tip in TUTORED_TIPS:
		EasyGuide._shown[tip] = true
	if player:
		player.graze_hit.connect(_on_graze)
		player.ignite_toggled.connect(_on_ignite_toggled)
	await _step_move()
	await _step_focus()
	await _step_shoot()
	await _step_graze()
	await _step_ignite()
	if not _skipped:
		_show_step("準備完了!", "", "健闘を祈る!")
		_ok()
		await _wait(1.4)
	_cleanup()

# ---------------------------------------------------------------- 手順

func _step_move() -> void:
	if _skipped:
		return
	_show_step("1/5  移動", "move", "[color=#ffd060]{move}[/color] で自機を動かそう")
	var moved := 0.0
	var last := player.global_position
	while not _skipped and moved < move_goal:
		await get_tree().process_frame
		moved += player.global_position.distance_to(last)
		last = player.global_position
		_set_progress("%d%%" % mini(int(moved / move_goal * 100.0), 100))
	await _done_step()

func _step_focus() -> void:
	if _skipped:
		return
	_show_step("2/5  低速移動", "focus", "[color=#ffd060]{focus}[/color] を押しながら動くと、ゆっくり動ける\n弾のすき間を、細かくよけるときに使おう")
	var held := 0.0
	var last := player.global_position
	while not _skipped and held < focus_goal:
		await get_tree().process_frame
		var moving := player.global_position.distance_to(last) > 0.2
		last = player.global_position
		if moving and Input.is_action_pressed(&"UI_Focus"):
			held += get_process_delta_time()
		_set_progress("%d%%" % mini(int(held / focus_goal * 100.0), 100))
	await _done_step()

func _step_shoot() -> void:
	if _skipped:
		return
	_show_step("3/5  ショット", "shoot", "[color=#ffd060]{shoot}[/color] でショット!\n的を %d つ壊そう" % target_count)
	_spawn_targets()
	while not _skipped:
		var left := _targets.filter(func(t) -> bool: return is_instance_valid(t)).size()
		_set_progress("のこり %d" % left)
		if left == 0:
			break
		await get_tree().process_frame
	await _done_step()

func _step_graze() -> void:
	if _skipped:
		return
	_show_step("4/5  グレイズ", "", "弾のギリギリをかすめる([color=#7fe0ff]グレイズ[/color])と\n左上のゲージが溜まる\nゲージは[color=#ff8080]体力[/color]と[color=#ffc04d]イグナイト[/color]の回数を兼ねている\nレベルが上がれば[color=#ffd060]ショットもグレードアップ[/color]していくぞ!\n(この練習では、当たってもやられない)")
	_grazes = 0
	var elapsed := 0.0
	var next_volley := 0.6
	while not _skipped and _grazes < graze_goal and elapsed < graze_timeout:
		await get_tree().process_frame
		var delta := get_process_delta_time()
		elapsed += delta
		next_volley -= delta
		if next_volley <= 0.0:
			next_volley = 0.9
			_fire_practice(5, 46.0, 120.0)
		_set_progress("%d / %d" % [mini(_grazes, graze_goal), graze_goal])
	await _done_step()

func _step_ignite() -> void:
	if _skipped:
		return
	_show_step("5/5  イグナイト", "ignite", "ゲージのレベルが1以上なら [color=#ffd060]{ignite}[/color] で[color=#ffc04d]イグナイト[/color]!\nまわりの弾を跳ね返して、敵にぶつけられる\n迫ってくる弾の壁を、跳ね返してみよう")
	_ensure_ignite_level()
	_ignited = false
	var next_volley := 0.2
	while not _skipped and not _ignited:
		await get_tree().process_frame
		_ensure_ignite_level()
		next_volley -= get_process_delta_time()
		if next_volley <= 0.0:
			next_volley = 1.4
			_fire_practice(15, 120.0, 90.0)
		_set_progress("")
	if not _skipped:
		await _wait(1.2) # 跳ね返すところを見せる
	await _done_step()

## 1つの手順ができた: 合図を出して、少し待つ
func _done_step() -> void:
	if _skipped:
		return
	_set_progress("OK!")
	_ok()
	await _wait(0.7)

# ---------------------------------------------------------------- 練習の的と弾

func _spawn_targets() -> void:
	var view := CameraView.visible_rect(player)
	for i in target_count:
		var target := Node2D.new()
		target.z_as_relative = false
		target.z_index = 30 # 母艦の絵より手前に出す
		var sprite := TargetMark.new() # 赤白の輪の的(一目で「的」と分かるように)
		target.add_child(sprite)
		var hurtbox := (load("res://Component/Hurtbox/hurtbox.tscn") as PackedScene).instantiate() as Hurtbox
		hurtbox.collision_layer = 64 # 敵の当たり(自機の弾が当たる)
		hurtbox.collision_mask = 8
		var shape := CircleShape2D.new()
		shape.radius = 16.0
		hurtbox.get_node("CollisionShape2D").shape = shape
		target.add_child(hurtbox)
		target.set_meta("hp", target_hp)
		hurtbox.recieved_damage.connect(func(damage) -> void: _hit_target(target, sprite, int(damage)))
		get_tree().current_scene.add_child(target)
		target.global_position = Vector2(view.position.x + view.size.x * (0.25 + 0.25 * i), view.position.y + view.size.y * 0.32)
		# ふわふわ浮かぶ
		var bob := target.create_tween().set_loops()
		bob.tween_property(sprite, "position:y", -6.0, 0.6 + 0.1 * i).set_trans(Tween.TRANS_SINE)
		bob.tween_property(sprite, "position:y", 6.0, 0.6 + 0.1 * i).set_trans(Tween.TRANS_SINE)
		_targets.append(target)

func _hit_target(target : Node2D, sprite : Node2D, damage : int) -> void:
	if not is_instance_valid(target):
		return
	var hp : int = target.get_meta("hp", 0) - damage
	target.set_meta("hp", hp)
	if hp > 0:
		sprite.modulate = Color(2.0, 2.0, 2.0)
		sprite.create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.08)
		return
	Explosion.spawn(get_tree(), Explosion.ZAKO, target.global_position, 1.2)
	target.queue_free()

## 母艦から、ゆっくりの弾を自機へ撃つ(count 発を spread 度に広げて)
func _fire_practice(count : int, spread : float, speed : float) -> void:
	if not is_instance_valid(player):
		return
	var from := mothership.global_position + Vector2(0.0, 40.0) if is_instance_valid(mothership) \
		else CameraView.visible_rect(player).position + Vector2(CameraView.visible_rect(player).size.x * 0.5, 60.0)
	var pattern := ShotPattern.new()
	pattern.bullet_scene = PRACTICE_BULLET
	pattern.bullet_count = count
	pattern.spread_angle = spread
	pattern.aim_at_player = true
	pattern.bullet_speed = speed
	var aim := (player.global_position - from).angle()
	EnemyShooter.spawn_bullets(pattern, 0, aim, from, get_tree().current_scene, PRACTICE_BULLET)

func _on_graze(_at : Vector2, _density : int) -> void:
	_grazes += 1

func _on_ignite_toggled(on : bool) -> void:
	if on:
		_ignited = true

## イグナイトの練習: ゲージのレベルを1以上にしておく
func _ensure_ignite_level() -> void:
	var manager := _manager()
	if manager and manager.ignite.level < 1:
		manager.ignite.add_value(manager.ignite.threshold(1) - manager.ignite.value + 0.1)

func _manager() -> GameManager:
	for node in get_tree().current_scene.find_children("*", "", true, false):
		if node is GameManager:
			return node
	return null

# ---------------------------------------------------------------- 終わり・スキップ

func _process(_delta : float) -> void:
	if active and not _skipped and InputMap.has_action(SKIP_ACTION) and Input.is_action_just_pressed(SKIP_ACTION):
		_skipped = true

## 最後に触ったのがキーボードかコントローラーかで、説明の文を切り替える
func _input(event : InputEvent) -> void:
	var pad := _pad
	if event is InputEventKey or event is InputEventMouseButton:
		pad = false
	elif event is InputEventJoypadButton:
		pad = true
	elif event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.5:
		pad = true
	if pad != _pad:
		_pad = pad
		_refresh()

func _cleanup() -> void:
	active = false
	if _skipped:
		for tip in TUTORED_TIPS:
			EasyGuide._shown.erase(tip)
	DebugTools.invincible = _was_invincible
	for target in _targets:
		if is_instance_valid(target):
			target.queue_free()
	if is_instance_valid(player):
		EnemyBullet.vanish_all(get_tree(), player.global_position)
		if player.graze_hit.is_connected(_on_graze):
			player.graze_hit.disconnect(_on_graze)
		if player.ignite_toggled.is_connected(_on_ignite_toggled):
			player.ignite_toggled.disconnect(_on_ignite_toggled)
	# 練習で増えたゲージとスコアは、元に戻す
	var manager := _manager()
	if manager:
		manager.ignite.reset_to_start()
	var score := get_tree().get_first_node_in_group("score_system") as ScoreSystem
	if score:
		score.score = 0
		score.graze_multiplier = 1.0
		score.score_changed.emit(0)
		score.multiplier_changed.emit(1.0, 1.0)
	TutorialProgress.mark_intro_done()
	var fade := create_tween()
	fade.tween_property(_panel, "modulate:a", 0.0, 0.25)
	fade.parallel().tween_property(_skip_label, "modulate:a", 0.0, 0.25)
	await fade.finished
	finished.emit()
	queue_free()

# ---------------------------------------------------------------- 表示

func _show_step(title : String, key : String, body : String) -> void:
	_step_title = title
	_step_key = key
	_body.set_meta("template", body)
	_progress = ""
	_refresh()
	_skip_label.reset_size()
	_panel.modulate.a = 0.0
	create_tween().tween_property(_panel, "modulate:a", 1.0, 0.2)

func _set_progress(text : String) -> void:
	if text == _progress:
		return
	_progress = text
	_status.text = text

func _refresh() -> void:
	var names : Dictionary = PAD if _pad else KEYS
	_title.text = _step_title
	_body.text = String(_body.get_meta("template", "")).format(names)
	_status.text = _progress
	_skip_label.text = "スキップ: %s" % names["skip"]

func _ok() -> void:
	if _ok_player:
		_ok_player.play()

func _wait(seconds : float) -> void:
	await get_tree().create_timer(seconds, false).timeout

func _build() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Yu Gothic UI", "Meiryo", "Hiragino Sans", "Noto Sans CJK JP", "MS Gothic"])
	font.font_weight = 700
	font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	var view := get_viewport().get_visible_rect().size

	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.04, 0.1, 0.85)
	style.border_color = Color(0.45, 0.85, 1.0, 0.9)
	style.set_border_width_all(1)
	style.border_width_top = 3
	style.set_corner_radius_all(3)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 8
	_panel.add_theme_stylebox_override("panel", style)
	_panel.position = Vector2(16.0, view.y * 0.5)
	_panel.custom_minimum_size = Vector2(view.x - 32.0, 0.0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	_panel.add_child(box)

	_title = Label.new()
	var title_settings := LabelSettings.new()
	title_settings.font = font
	title_settings.font_size = 14
	title_settings.font_color = Color(0.5, 0.9, 1.0)
	title_settings.outline_size = 3
	title_settings.outline_color = Color.BLACK
	_title.label_settings = title_settings
	box.add_child(_title)

	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.scroll_active = false
	_body.add_theme_font_override("normal_font", font)
	_body.add_theme_font_size_override("normal_font_size", 12)
	_body.add_theme_color_override("default_color", Color.WHITE)
	_body.add_theme_constant_override("outline_size", 3)
	_body.add_theme_color_override("font_outline_color", Color.BLACK)
	box.add_child(_body)

	_status = Label.new()
	var status_settings := LabelSettings.new()
	status_settings.font = font
	status_settings.font_size = 13
	status_settings.font_color = Color(0.6, 1.0, 0.6)
	status_settings.outline_size = 3
	status_settings.outline_color = Color.BLACK
	_status.label_settings = status_settings
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(_status)
	add_child(_panel)

	_skip_label = Label.new()
	var skip_settings := LabelSettings.new()
	skip_settings.font = font
	skip_settings.font_size = 11
	skip_settings.font_color = Color(1.0, 1.0, 1.0, 0.75)
	skip_settings.outline_size = 3
	skip_settings.outline_color = Color.BLACK
	_skip_label.label_settings = skip_settings
	add_child(_skip_label)
	# 説明の枠のすぐ下、右寄せ(自機と重ならないように)
	_panel.resized.connect(func() -> void:
		_skip_label.position = Vector2(_panel.position.x + _panel.size.x - _skip_label.size.x, _panel.position.y + _panel.size.y + 4.0))

	_ok_player = AudioStreamPlayer.new()
	_ok_player.stream = OK_SOUND
	_ok_player.volume_db = -8.0
	add_child(_ok_player)

## 練習の的の見た目: 赤と白の輪
class TargetMark extends Node2D:
	const RADIUS : float = 17.0
	func _draw() -> void:
		draw_circle(Vector2.ZERO, RADIUS + 2.0, Color(0.0, 0.0, 0.0, 0.6))
		draw_circle(Vector2.ZERO, RADIUS, Color(0.95, 0.2, 0.2))
		draw_circle(Vector2.ZERO, RADIUS * 0.68, Color(1.0, 1.0, 1.0))
		draw_circle(Vector2.ZERO, RADIUS * 0.38, Color(0.95, 0.2, 0.2))
