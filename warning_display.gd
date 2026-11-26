extends CanvasLayer
class_name WarningDisplay
## ボス出現前の「WARNING」表示。シーン(GameScene/UI/warning_display.tscn)をステージのシーンに置いて使う。
## 見た目は、タイトル画面と同じ「紙・墨・朱」の画風。Root は普段は非表示。
##
## 使い方:
##   ・ステージに StageSignalEvent を置き、Signal Name を "warning" にする(Text を入れると、WARNING の代わりに出る)
##   ・手動なら show_warning() を呼ぶ
##
## 流れ:
##   1. 画面に砂嵐のノイズが走り、映像が乱れる
##   2. WARNING の文字が、大きさ・色・縦の伸び方を変えて、画面じゅうに何枚も重なって出ては消える(何回か)
##   3. 真ん中に回る輪と、横に走る朱の線が出る
##   4. 真ん中の紙の帯に、残像を引いた WARNING が落ち着いて点滅する
##   5. もう一度ノイズが走って消える

signal finished

const SIGNAL_NAME : String = "warning"
const FX_SHADER := preload("res://GameScene/UI/game_over_screen_fx.gdshader")

## 未設定なら、"stage_runner" グループから探す
@export var stage_runner : StageRunner
## 表示している時間(秒)。出る・消える演出を含む
@export var duration : float = 3.4
## 斜線が流れる速さ(px/秒)
@export var stripe_speed : float = 60.0

@export_group("色(タイトルと同じ)")
@export var accent_color : Color = Color(0.85, 0.16, 0.07)
@export var ink_color : Color = Color(0.1, 0.07, 0.07)
@export var paper_color : Color = Color(1.0, 0.99, 0.97)
## 画面じゅうに重なる文字の色(朱・墨・濃い赤紫)。ランダムに選ぶ
@export var flood_colors : Array[Color] = [Color(0.92, 0.16, 0.08), Color(0.92, 0.16, 0.08), Color(0.1, 0.07, 0.07), Color(0.45, 0.06, 0.22)]

## WARNING を出す前に、画面の敵弾を消して、出しているあいだ敵に撃たせない(警告の最中に被弾しないように)
@export var clear_bullets : bool = true
## 弾が消えてから WARNING が出るまでの時間(秒)
@export var clear_wait : float = 0.4
## オンなら、画面ぜんたいにグリッチが走る(四角いかたまりのずれ・色ずれ・反転・文字化け)。裏ボスの WARNING に使う
@export var glitch : bool = false

@export_group("文字のあふれ")
## 1回にあふれる文字の数と、あふれる時刻(表示を始めてからの秒)
@export var flood_count : int = 14
@export var flood_times : Array[float] = [0.05, 0.55, 1.25, 2.05]

@export_group("警告音")
## WARNING が出たときに鳴らす警告音(ループする音でもよい)。空なら鳴らさない
@export var alarm_sound : AudioStream = preload("res://Assets/Sounds/Warn/AS_816725_アラーム_警告音（ループ） (1).mp3")
@export var alarm_volume_db : float = -8.0
## 警告音が何回うなったら止めるか、と、1回のうなりの長さ(秒)
@export var alarm_cycles : int = 2
@export var alarm_cycle_time : float = 1.23

@onready var _root : Control = $Root
@onready var _band : ColorRect = $Root/Band
@onready var _title : Label = $Root/Band/Title
@onready var _stripes : Array[Label] = [$Root/Band/StripeTop, $Root/Band/StripeBottom]
var _tween : Tween
var _blink_tween : Tween
var _stripe_width : float = 0.0
var _alarm : AudioStreamPlayer
var _alarm_tween : Tween
## 画面の乱れ(砂嵐)・回る輪・横に走る線・文字があふれる層・真ん中の文字の残像
var _fx : ColorRect
var _fx_material : ShaderMaterial
var _rings : WarningRings
var _scan : ColorRect
var _flood_layer : Control
var _echoes : Array[Label] = []
var _time : float = 0.0
var _serial : int = 0
## WARNING のあとに出てくるボスの名前(帯の下に出す)
var _boss_label : Label
var _boss_line : ColorRect
var _runner : StageRunner
var _glitch_rect : ColorRect
var _glitch_material : ShaderMaterial
var _glitch_amount : float = 0.0
var _glitch_next : float = 0.0
var _word : String = ""
const GLITCH_SHADER_PATH := "res://Shaders/warning_glitch.gdshader"
const GLITCH_CHARS := "#%&@$!?/|_=+*"

func _ready() -> void:
	_root.visible = false
	# 斜線は画面幅の2倍ぶん並んでいて、1周分(画面幅)ずつ流すと、継ぎ目なくループする
	_stripe_width = get_viewport().get_visible_rect().size.x
	_connect_runner.call_deferred() # 全ノードの準備が終わってから探す
	_alarm = AudioStreamPlayer.new()
	_alarm.bus = SoundManager.SFX_BUS if AudioServer.get_bus_index(SoundManager.SFX_BUS) >= 0 else &"Master"
	add_child(_alarm)
	_build()

func _connect_runner() -> void:
	if stage_runner:
		_runner = stage_runner
		stage_runner.stage_signal.connect(_on_stage_signal)
		return
	for node in get_tree().get_nodes_in_group("stage_runner"):
		(node as StageRunner).stage_signal.connect(_on_stage_signal)
		_runner = node as StageRunner

func _on_stage_signal(signal_name : String, text : String) -> void:
	if signal_name == SIGNAL_NAME:
		show_warning(text)

# ---------------------------------------------------------------- 組み立て

func _build() -> void:
	var size := get_viewport().get_visible_rect().size
	# 砂嵐(後ろのゲームの映像を乱す)。いちばん下に置く
	_fx = ColorRect.new()
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.size = size
	_fx_material = ShaderMaterial.new()
	_fx_material.shader = FX_SHADER
	_fx_material.set_shader_parameter("strength", 0.0)
	_fx_material.set_shader_parameter("desaturate", 0.2)
	_fx_material.set_shader_parameter("vignette", 0.8)
	_fx.material = _fx_material
	_root.add_child(_fx)
	_root.move_child(_fx, 0)
	# 回る輪
	_rings = WarningRings.new()
	_rings.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rings.size = size
	_rings.accent = accent_color
	_rings.ink = ink_color
	_root.add_child(_rings)
	_root.move_child(_rings, 1)
	# 横に走る朱の線
	_scan = ColorRect.new()
	_scan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scan.color = accent_color
	_scan.size = Vector2(size.x, 2.0)
	_root.add_child(_scan)
	_root.move_child(_scan, 2)
	# あふれる文字の層
	_flood_layer = Control.new()
	_flood_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flood_layer.size = size
	_root.add_child(_flood_layer)
	_root.move_child(_flood_layer, 3)
	# 真ん中の帯: 紙の帯に、朱の斜線と、墨の縁の朱の文字
	_band.color = Color(paper_color, 0.88)
	_title.add_theme_color_override("font_color", accent_color)
	_title.add_theme_color_override("font_outline_color", ink_color)
	_title.add_theme_constant_override("outline_size", 6)
	for stripe in _stripes:
		stripe.add_theme_color_override("font_color", accent_color)
		stripe.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))
	# ボスの名前(帯の下に、朱の細い線と一緒に出す)
	_boss_line = ColorRect.new()
	_boss_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_line.color = accent_color
	_root.add_child(_boss_line)
	_boss_label = Label.new()
	_boss_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_label.add_theme_font_size_override("font_size", 22)
	_boss_label.add_theme_color_override("font_color", paper_color)
	_boss_label.add_theme_color_override("font_outline_color", ink_color)
	_boss_label.add_theme_constant_override("outline_size", 6)
	_root.add_child(_boss_label)
	# 文字の残像(右へ尾を引く。後ろほど薄く、赤紫に)
	for i in 5:
		var echo := _title.duplicate() as Label
		echo.name = "Echo%d" % i
		var t := float(i + 1) / 5.0
		echo.add_theme_color_override("font_color", Color(accent_color.lerp(flood_colors[3], t), 0.55 * (1.0 - t * 0.8)))
		echo.add_theme_constant_override("outline_size", 0)
		_band.add_child(echo)
		_band.move_child(echo, _title.get_index()) # 本体の文字の後ろ
		_echoes.append(echo)
	# グリッチ(いちばん手前。帯も文字も、まとめて壊す)
	if glitch:
		_glitch_rect = ColorRect.new()
		_glitch_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_glitch_rect.size = size
		_glitch_material = ShaderMaterial.new()
		_glitch_material.shader = load(GLITCH_SHADER_PATH)
		_glitch_rect.material = _glitch_material
		# 帯と文字を描いたあとの画面を、もう一度写してから壊す(写さないと、砂嵐の層が写した、帯と文字のない画面になる)
		var copy := BackBufferCopy.new()
		copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
		_root.add_child(copy)
		_glitch_rect.visible = false
		_root.add_child(_glitch_rect)

# ---------------------------------------------------------------- 表示

## text が空なら WARNING と出す
func show_warning(text : String = "") -> void:
	_serial += 1
	var serial := _serial
	if clear_bullets:
		# 先に弾を消す(画面の真ん中から広がるように消える)。表示が終わるまで、敵は撃たない
		var view := CameraView.visible_rect(get_tree().current_scene as CanvasItem) if get_tree().current_scene is CanvasItem else Rect2()
		EnemyBullet.vanish_all(get_tree(), view.get_center())
		EnemyShooter.hold_fire(clear_wait + duration)
		await get_tree().create_timer(clear_wait, false).timeout
		if serial != _serial:
			return
	var word := text if text != "" else "WARNING"
	_word = word
	_glitch_amount = 1.0 if glitch else 0.0 # 出た瞬間は、いちばん強く壊れる
	_glitch_next = 0.3
	_title.text = word
	for echo in _echoes:
		echo.text = word
	_time = 0.0
	_root.visible = true
	_root.modulate.a = 1.0
	_band.scale = Vector2(1.0, 0.0)
	_band.pivot_offset = _band.size / 2.0
	_rings.modulate.a = 0.0
	_scan.modulate.a = 0.0
	_show_boss_name(serial)
	for child in _flood_layer.get_children():
		child.queue_free()

	if _tween:
		_tween.kill()
	_tween = create_tween()
	# 砂嵐が走る
	_tween.tween_method(_set_noise, 1.0, 0.25, 0.45)
	# 輪と線が出て、真ん中の帯が開く
	_tween.parallel().tween_property(_rings, "modulate:a", 1.0, 0.3).set_delay(0.25)
	_tween.parallel().tween_property(_scan, "modulate:a", 1.0, 0.1).set_delay(0.2)
	_tween.tween_interval(0.35)
	_tween.tween_property(_band, "scale:y", 1.0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(maxf(duration - 1.75, 0.2))
	# もう一度ノイズが走って、消える
	_tween.tween_method(_set_noise, 0.25, 1.0, 0.15)
	_tween.parallel().tween_property(_band, "scale:y", 0.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(_rings, "modulate:a", 0.0, 0.2)
	_tween.parallel().tween_property(_scan, "modulate:a", 0.0, 0.2)
	_tween.tween_method(_set_noise, 1.0, 0.0, 0.35)
	_tween.tween_callback(_hide)

	if _blink_tween:
		_blink_tween.kill()
	_blink_tween = create_tween().set_loops()
	_blink_tween.tween_property(_title, "modulate:a", 0.35, 0.18)
	_blink_tween.tween_property(_title, "modulate:a", 1.0, 0.18)
	# 文字があふれる(何回か)。途中の短いノイズも一緒に
	for at in flood_times:
		get_tree().create_timer(at, false).timeout.connect(_flood.bind(word, serial))
	_play_alarm()

## 帯が開いたあと、帯の下にボスの名前を出す(左から朱の線が伸びて、名前が浮かび上がる)
func _show_boss_name(serial : int) -> void:
	var boss_name := _runner.upcoming_boss_name() if is_instance_valid(_runner) else ""
	_boss_label.text = boss_name
	_boss_label.visible = boss_name != ""
	_boss_line.visible = boss_name != ""
	_boss_label.modulate.a = 0.0
	if boss_name == "":
		return
	var width := _root.size.x
	var top := _band.position.y + _band.size.y + 10.0
	_boss_label.position = Vector2(0.0, top + 4.0)
	_boss_label.size = Vector2(width, 30.0)
	_boss_line.position = Vector2(width * 0.2, top)
	_boss_line.size = Vector2(0.0, 1.0)
	await get_tree().create_timer(0.55, false).timeout
	if serial != _serial:
		return
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_boss_line, "size:x", width * 0.6, 0.35).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(_boss_label, "modulate:a", 1.0, 0.3).set_delay(0.15)
	tween.tween_property(_boss_label, "position:y", top + 4.0, 0.3).from(top + 14.0).set_delay(0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

## WARNING の文字を、画面じゅうに何枚も重ねて出す。少しずつずれながら消えていく
func _flood(word : String, serial : int) -> void:
	if serial != _serial or not _root.visible:
		return
	var size := _flood_layer.size
	for i in flood_count:
		var label := Label.new()
		label.text = word
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var font_size := randi_range(34, 72)
		label.add_theme_font_size_override("font_size", font_size)
		var color : Color = flood_colors[randi() % flood_colors.size()]
		label.add_theme_color_override("font_color", Color(color, randf_range(0.55, 1.0)))
		# 墨の文字には紙の縁、朱の文字には墨の縁(重なっても読める)
		var outline := paper_color if color.get_luminance() < 0.15 else ink_color
		label.add_theme_color_override("font_outline_color", Color(outline, 0.7))
		label.add_theme_constant_override("outline_size", 3)
		_flood_layer.add_child(label)
		var text_size := label.get_minimum_size()
		label.pivot_offset = text_size * 0.5
		# 縦に引き伸ばした文字を混ぜる(画面を埋める感じ)
		label.scale = Vector2(randf_range(0.8, 1.3), randf_range(1.0, 3.2))
		label.position = Vector2(randf_range(-text_size.x * 0.4, size.x - text_size.x * 0.6),
			randf_range(-20.0, size.y - text_size.y))
		var drift := randf_range(-50.0, 50.0)
		var life := randf_range(0.35, 0.8)
		var tween := label.create_tween().set_parallel(true)
		tween.tween_property(label, "position:x", label.position.x + drift, life)
		tween.tween_property(label, "modulate:a", 0.0, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.chain().tween_callback(label.queue_free)
	# 文字があふれた瞬間に、ノイズが一瞬強くなる
	var spike := create_tween()
	spike.tween_method(_set_noise, 0.85, 0.25, 0.18)

func _set_noise(value : float) -> void:
	_fx_material.set_shader_parameter("strength", clampf(value * 1.4, 0.0, 1.0))
	_fx_material.set_shader_parameter("noise_amount", value)
	_fx_material.set_shader_parameter("tear_amount", 0.08 * value)
	_fx_material.set_shader_parameter("tear_chance", 0.6 * value)
	_fx_material.set_shader_parameter("scanline_amount", 0.15 + 0.3 * value)

## 警告音を鳴らし、alarm_cycles 回うなったところで、すっと消す
func _play_alarm() -> void:
	if alarm_sound == null or alarm_cycles <= 0:
		return
	if _alarm_tween:
		_alarm_tween.kill()
	_alarm.stream = alarm_sound
	_alarm.volume_db = alarm_volume_db
	_alarm.play()
	var fade := 0.12
	_alarm_tween = create_tween()
	_alarm_tween.tween_interval(maxf(alarm_cycles * alarm_cycle_time - fade, 0.0))
	_alarm_tween.tween_property(_alarm, "volume_db", -60.0, fade)
	_alarm_tween.tween_callback(_alarm.stop)

func _process(delta : float) -> void:
	if not _root.visible:
		return
	_time += delta
	# 上の帯は左へ、下の帯は右へ流れる
	for i in _stripes.size():
		var stripe := _stripes[i]
		var direction := -1.0 if i == 0 else 1.0
		stripe.position.x = fposmod(stripe.position.x + direction * stripe_speed * delta, _stripe_width) - _stripe_width
	# 残像は、本体の文字から右へ少しずつずれて、揺れる
	for i in _echoes.size():
		var echo := _echoes[i]
		echo.position = _title.position + Vector2((i + 1) * (6.0 + 2.0 * sin(_time * 9.0 + i)), 0.0)
		echo.visible = _title.modulate.a > 0.5 or i < 2
	# 横の線は、上下に走る
	var size := _flood_layer.size
	_scan.position.y = size.y * 0.5 + sin(_time * 3.1) * size.y * 0.32
	_rings.spin = _time
	if glitch:
		_update_glitch(delta)

func _hide() -> void:
	_root.visible = false
	_set_noise(0.0)
	if _glitch_rect:
		_glitch_rect.visible = false
		_glitch_amount = 0.0
	if _blink_tween:
		_blink_tween.kill()
	for child in _flood_layer.get_children():
		child.queue_free()
	finished.emit()

## 画面の真ん中に、回る輪(朱と墨の弧)を描く
class WarningRings extends Control:
	var spin : float = 0.0:
		set(value):
			spin = value
			queue_redraw()
	var accent : Color = Color.RED
	var ink : Color = Color.BLACK

	func _draw() -> void:
		var center := size * 0.5
		# 外側の太い朱の輪(欠けながら回る)
		_arcs(center, 92.0, 6.0, accent, 3, spin * 1.2, 0.75)
		# 墨の細い輪(逆回り)
		_arcs(center, 76.0, 2.0, Color(ink, 0.8), 6, -spin * 1.8, 0.6)
		# 内側の朱の輪
		_arcs(center, 58.0, 3.0, Color(accent, 0.85), 4, spin * 2.6, 0.5)
		# 十字の目盛り
		for k in 4:
			var dir := Vector2.from_angle(spin * 0.6 + k * PI * 0.5)
			draw_line(center + dir * 100.0, center + dir * 116.0, accent, 3.0)

	## 半径 radius の輪を count 個の弧に分けて描く。fill は弧の長さの割合
	func _arcs(center : Vector2, radius : float, width : float, color : Color, count : int, offset : float, fill : float) -> void:
		var step := TAU / count
		for i in count:
			var from := offset + i * step
			draw_arc(center, radius, from, from + step * fill, 24, color, width)

## グリッチ: ときどき強く壊れる(壊れ具合はすぐ引いて、弱いざらつきが残る)。強いときは、文字も化ける
func _update_glitch(delta : float) -> void:
	if _glitch_material == null:
		return
	_glitch_next -= delta
	if _glitch_next <= 0.0:
		_glitch_next = randf_range(0.14, 0.55)
		_glitch_amount = maxf(_glitch_amount, randf_range(0.5, 1.0))
	_glitch_amount = move_toward(_glitch_amount, 0.12, delta * 3.5)
	_glitch_material.set_shader_parameter("amount", _glitch_amount)
	_glitch_rect.visible = _glitch_amount > 0.01
	# 文字化け: 強く壊れているあいだ、何文字かが記号に化ける
	var text := _word
	if _glitch_amount > 0.45 and text != "":
		var chars := text.split("")
		for k in randi_range(1, 3):
			var at := randi() % chars.size()
			chars[at] = GLITCH_CHARS[randi() % GLITCH_CHARS.length()]
		text = "".join(chars)
	if _title.text != text:
		_title.text = text
		for echo in _echoes:
			echo.text = text
