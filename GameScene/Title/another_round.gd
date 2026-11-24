extends CanvasLayer
class_name AnotherRound
## 二周目(Another Round)に入る合図。タイトル画面(TitleScreen)が、ノーコンティニューで最終面をクリアしたあとに出す。
##   1. 画面にグリッチが走る(横に裂けて、色がずれる)。タイトルの曲が歪んで止まる
##   2. WARNING と同じように、画面の上下に赤い帯が出て、「WELCOME TO ANOTHER ROUND」が流れる
##   3. 真ん中に、ANOTHER の文字が、赤と水色の残像を引きずって震えながら大きく出る(ときどき裂ける)
##   4. 白く光って消え、finished を出す(TitleScreen が二周目の一面へ進む)

signal finished

## 全体の長さ(秒)。帯と文字が出ているあいだ
@export var hold_time : float = 3.6
## 警告音(1回鳴らす)
@export var alarm_sound : AudioStream = preload("res://Assets/Sounds/Warn/AS_816725_アラーム_警告音（ループ） (1).mp3")
## ANOTHER の文字のフォント
@export var title_font : Font = preload("res://Assets/Fonts/DIGITEK.TTF")

const RED := Color(1.0, 0.22, 0.16)
const DARK := Color(0.08, 0.0, 0.0, 0.88)
const CYAN := Color(0.3, 0.95, 1.0)
const MARQUEE := "WELCOME TO [color=#ff3b2f]ANOTHER[/color] ROUND   ◆   "

var _glitch : ColorRect
var _glitch_mat : ShaderMaterial
var _root : Control
var _bands : Array[Control] = []
var _marquees : Array[RichTextLabel] = []
var _another : Control
var _layers : Array[Label] = [] # 赤の残像・水色の残像・本体
var _slice : ColorRect
var _time : float = 0.0
var _running : bool = false

func _ready() -> void:
	layer = 80
	_build()

## 合図を最初から最後まで流す(終わったら finished)
func play() -> void:
	_running = true
	var tree := get_tree()
	_play_alarm()
	# 1. グリッチが走る
	var g := create_tween()
	g.tween_method(_set_glitch, 0.0, 1.0, 0.25)
	g.tween_method(_set_glitch, 1.0, 0.35, 0.6)
	await g.finished
	# 2. 上下の帯が、画面の外から滑り込む
	var view := _root.size
	var bands_in := create_tween().set_parallel(true).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	bands_in.tween_property(_bands[0], "position:y", 0.0, 0.35)
	bands_in.tween_property(_bands[1], "position:y", view.y - _bands[1].size.y, 0.35)
	await bands_in.finished
	# 3. ANOTHER が、叩きつけるように大きく出る
	_another.visible = true
	_another.scale = Vector2(2.4, 0.2)
	_another.modulate.a = 0.0
	var slam := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	slam.tween_property(_another, "scale", Vector2.ONE, 0.32)
	slam.tween_property(_another, "modulate:a", 1.0, 0.12)
	_set_glitch(1.0)
	var calm := create_tween()
	calm.tween_method(_set_glitch, 1.0, 0.18, 0.5)
	await tree.create_timer(hold_time, false).timeout
	# 4. 白く光って、全部消える
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(flash)
	var out := create_tween()
	out.tween_property(flash, "color:a", 1.0, 0.18)
	out.parallel().tween_method(_set_glitch, 0.18, 1.0, 0.18)
	await out.finished
	_running = false
	finished.emit()

func _process(delta : float) -> void:
	_time += delta
	if _glitch_mat:
		_glitch_mat.set_shader_parameter("time_seed", _time)
	# 帯の文字が流れる(上は左へ、下は右へ)
	for i in _marquees.size():
		var m := _marquees[i]
		var w := m.size.x * 0.5
		var dir := -1.0 if i == 0 else 1.0
		m.position.x = fposmod(m.position.x + dir * 70.0 * delta, w) - w
	if _another and _another.visible:
		# 赤と水色の残像が、ばらばらに震える。ときどき大きく裂ける
		var tear := 1.0 if fmod(_time, 0.9) < 0.07 else 0.0
		var jitter := 1.5 + tear * 7.0
		_layers[0].position = Vector2(randf_range(-jitter, -0.5) - 2.0, randf_range(-1.0, 1.0))
		_layers[1].position = Vector2(randf_range(0.5, jitter) + 2.0, randf_range(-1.0, 1.0))
		_layers[2].position = Vector2(tear * randf_range(-4.0, 4.0), 0.0)
		_slice.visible = tear > 0.0 or randf() < 0.04
		_slice.position.y = randf_range(0.0, _another.size.y - _slice.size.y)

func _set_glitch(value : float) -> void:
	if _glitch_mat:
		_glitch_mat.set_shader_parameter("strength", value)

func _play_alarm() -> void:
	if alarm_sound == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = alarm_sound
	player.volume_db = -6.0
	player.bus = &"SE" if AudioServer.get_bus_index(&"SE") >= 0 else &"Master"
	add_child(player)
	player.play()
	# 長い警告音なので、少しだけ鳴らして消す
	get_tree().create_timer(2.2, false).timeout.connect(func() -> void:
		if is_instance_valid(player):
			var t := player.create_tween()
			t.tween_property(player, "volume_db", -60.0, 0.6)
			t.tween_callback(player.queue_free))

# ---------------------------------------------------------------- 組み立て

func _build() -> void:
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var view := get_viewport().get_visible_rect().size
	_root.size = view
	# グリッチ(画面の上にかぶせる)
	_glitch = ColorRect.new()
	_glitch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glitch.set_anchors_preset(Control.PRESET_FULL_RECT)
	_glitch_mat = ShaderMaterial.new()
	_glitch_mat.shader = preload("res://GameScene/Title/another_round_glitch.gdshader")
	_glitch.material = _glitch_mat
	_root.add_child(_glitch)
	# 上下の帯
	for i in 2:
		var band := _make_band(view.x)
		band.position.y = -band.size.y if i == 0 else view.y
		_root.add_child(band)
		_bands.append(band)
	# 真ん中の ANOTHER
	_another = Control.new()
	_another.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_another.size = Vector2(view.x, 150.0)
	_another.position = Vector2(0.0, view.y * 0.5 - 75.0)
	_another.pivot_offset = _another.size * 0.5
	_another.visible = false
	_root.add_child(_another)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.size = Vector2(view.x, 120.0)
	dim.position = Vector2(0.0, 15.0)
	_another.add_child(dim)
	_another.add_child(_small_label("WELCOME TO", Vector2(0.0, 22.0), 13, Color(1, 1, 1, 0.9)))
	# ANOTHER が画面の幅(左右に余白)に収まる大きさにする
	var font_size := 58
	while font_size > 20 and title_font.get_string_size("ANOTHER", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 12.0 > view.x - 28.0:
		font_size -= 2
	for c in [RED, CYAN, Color(1.0, 0.97, 0.95)]:
		var label := Label.new()
		label.text = "ANOTHER"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.size = Vector2(view.x, 70.0)
		label.add_theme_font_override("font", title_font)
		label.add_theme_font_size_override("font_size", font_size)
		label.add_theme_color_override("font_color", c if c != RED else Color(RED, 0.85))
		if c == RED or c == CYAN:
			label.modulate.a = 0.75
		else:
			label.add_theme_color_override("font_outline_color", Color(0.45, 0.0, 0.0))
			label.add_theme_constant_override("outline_size", 6)
		var holder := Control.new()
		holder.position = Vector2(0.0, 40.0)
		holder.add_child(label)
		_another.add_child(holder)
		_layers.append(label)
	# 文字を横に裂く、白い光の筋
	_slice = ColorRect.new()
	_slice.color = Color(1.0, 0.9, 0.9, 0.85)
	_slice.size = Vector2(view.x, 3.0)
	_slice.visible = false
	_another.add_child(_slice)
	# ── ROUND ──
	_another.add_child(_small_label("━━━━  ROUND  ━━━━", Vector2(0.0, 108.0), 13, RED))

func _small_label(text : String, at : Vector2, font_size : int, color : Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(get_viewport().get_visible_rect().size.x, 20.0)
	label.position = at
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	return label

## WARNING と同じような帯: 暗い赤の地に、斜線の縞と、流れる文字
func _make_band(width : float) -> Control:
	var band := ColorRect.new()
	band.color = DARK
	band.size = Vector2(width, 46.0)
	band.clip_contents = true
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for y in [0.0, 36.0]:
		var stripe := Label.new()
		stripe.text = "/".repeat(120)
		stripe.position = Vector2(-4.0, y - 4.0)
		stripe.add_theme_font_size_override("font_size", 10)
		stripe.add_theme_color_override("font_color", RED)
		band.add_child(stripe)
	var marquee := RichTextLabel.new()
	marquee.bbcode_enabled = true
	marquee.scroll_active = false
	marquee.autowrap_mode = TextServer.AUTOWRAP_OFF
	marquee.fit_content = true
	marquee.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marquee.text = MARQUEE.repeat(8)
	marquee.add_theme_font_size_override("normal_font_size", 14)
	marquee.add_theme_color_override("default_color", Color(1, 0.92, 0.9))
	marquee.add_theme_color_override("font_outline_color", Color.BLACK)
	marquee.add_theme_constant_override("outline_size", 3)
	marquee.position = Vector2(0.0, 13.0)
	marquee.size = Vector2(width * 4.0, 22.0)
	band.add_child(marquee)
	_marquees.append(marquee)
	return band
