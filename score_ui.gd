extends CanvasLayer
class_name ScoreUI
## スコアの表示。シーン(GameScene/UI/score_ui.tscn)を置いて使う。ScoreSystem の値を、画面の右上に出す。
## 見た目(文字の大きさ・位置)は、シーンの中で変える。リザルトの行だけは、出すときにコードで作る。
##   HI      ハイスコア
##   SCORE   今のスコア(増えるときは数字が回って追いつく)
##   ×1.45  グレイズ倍率。イグナイトの発動中は、その倍率も並べて出す
## 残機が増えたときの EXTEND と、ステージクリアのボーナスの内訳も出す。
## "hud" グループに入るので、HudFader で半透明にできる。

## 未設定なら "score_system" グループから探す
@export var score_system : ScoreSystem
## 数字が追いつく速さ(1秒あたり、差の何割を縮めるか)
@export var roll_speed : float = 12.0
@export var digits : int = 9

const COLOR_TEXT := Color(1.0, 1.0, 1.0)
const COLOR_HI := Color(1.0, 0.85, 0.45)
const COLOR_MULT := Color(0.55, 0.95, 1.0)
const COLOR_IGNITE := Color(1.0, 0.55, 0.2)

@onready var _root : Control = $Root
@onready var _hi_label : Label = $Root/HiLabel
@onready var _score_label : Label = $Root/ScoreLabel
@onready var _mult_label : Label = $Root/MultLabel
@onready var _chain_label : Label = $Root/ChainLabel
@onready var _extend_label : Label = $Root/ExtendLabel
@onready var _result : VBoxContainer = $Root/Result
@onready var _burn_label : Label = $BurnLayer/BurnLabel # 半透明にならないよう、別のレイヤーに置く
## 「238 BURN!」を、自機のこの位置(画面のpx)に出す
@export var burn_label_offset : Vector2 = Vector2(0, -56)

var _target : int = 0
var _shown : float = 0.0
var _mult_tween : Tween
var _burn_tween : Tween
var _burn_fade : Tween
var _player : Node2D

func _enter_tree() -> void:
	add_to_group("hud")

func _ready() -> void:
	_extend_label.visible = false
	_result.visible = false
	_connect.call_deferred()

func _connect() -> void:
	if score_system == null:
		score_system = get_tree().get_first_node_in_group("score_system") as ScoreSystem
	if score_system == null:
		push_warning("ScoreUI: ScoreSystem が見つかりません")
		return
	score_system.score_changed.connect(_on_score_changed)
	score_system.hi_score_changed.connect(_on_hi_score_changed)
	score_system.multiplier_changed.connect(_on_multiplier_changed)
	score_system.extended.connect(_on_extended)
	score_system.stage_bonus.connect(_on_stage_bonus)
	score_system.item_chain_changed.connect(_on_item_chain_changed)
	score_system.burn_count_changed.connect(_on_burn_count_changed)
	score_system.burn_finished.connect(_on_burn_finished)
	_player = get_tree().get_first_node_in_group("player") as Node2D
	_on_item_chain_changed(0, 1.0)
	_on_score_changed(score_system.score)
	_shown = _target
	_on_hi_score_changed(score_system.hi_score)
	_on_multiplier_changed(score_system.graze_multiplier, score_system.current_ignite_multiplier())

func _process(delta : float) -> void:
	_follow_player()
	if _shown < _target:
		var gap := float(_target) - _shown
		_shown = minf(_shown + maxf(gap * minf(roll_speed * delta, 1.0), 1.0), float(_target))
	_score_label.text = _format(int(_shown))

func _format(value : int) -> String:
	return str(value).pad_zeros(digits)

# ---------------------------------------------------------------- リザルトの行

func _label(font_size : int, color : Color, align : HorizontalAlignment, parent : Control = null) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	(parent if parent else _root).add_child(label)
	return label

# ---------------------------------------------------------------- 更新

func _on_score_changed(value : int) -> void:
	_target = value

func _on_hi_score_changed(value : int) -> void:
	_hi_label.text = "HI " + _format(value)

func _on_multiplier_changed(graze_multiplier : float, ignite_multiplier : float) -> void:
	var text := "x%.2f" % graze_multiplier
	if ignite_multiplier > 1.0:
		text = "IGNITE x%.1f  " % ignite_multiplier + text
		_mult_label.add_theme_color_override("font_color", COLOR_IGNITE)
	elif graze_multiplier >= 1.995:
		_mult_label.add_theme_color_override("font_color", COLOR_HI) # 最大
	else:
		_mult_label.add_theme_color_override("font_color", COLOR_MULT)
	if _mult_label.text == text:
		return
	_mult_label.text = text
	if _mult_tween:
		_mult_tween.kill()
	_mult_label.scale = Vector2(1.25, 1.25)
	_mult_tween = create_tween()
	_mult_tween.tween_property(_mult_label, "scale", Vector2.ONE, 0.15)

## アイテムの連続取得。途切れたら、少しのあいだ赤く BREAK と出す
func _on_item_chain_changed(chain : int, multiplier : float) -> void:
	if chain == 0:
		if _chain_label.text.begins_with("ITEM"):
			_chain_label.text = "BREAK"
			_chain_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
			var tween := create_tween()
			tween.tween_interval(0.8)
			tween.tween_callback(func() -> void:
				if _chain_label.text == "BREAK":
					_chain_label.text = "")
		return
	_chain_label.add_theme_color_override("font_color", COLOR_HI)
	_chain_label.text = "ITEM %d  x%.2f" % [chain, multiplier]

func _on_extended(_lives : int) -> void:
	_extend_label.visible = true
	_extend_label.modulate.a = 1.0
	var tween := create_tween()
	for i in 4:
		tween.tween_property(_extend_label, "modulate:a", 0.2, 0.15)
		tween.tween_property(_extend_label, "modulate:a", 1.0, 0.15)
	tween.tween_interval(0.6)
	tween.tween_property(_extend_label, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func() -> void: _extend_label.visible = false)

## ステージクリアのボーナスを、1行ずつ出していく
func _on_stage_bonus(lines : Array, total : int) -> void:
	for child in _result.get_children():
		child.queue_free()
	_result.visible = true
	var title := _label(20, COLOR_HI, HORIZONTAL_ALIGNMENT_CENTER, _result)
	title.text = "STAGE CLEAR"
	var rows : Array[Control] = [title]
	for line in lines:
		rows.append(_row(str(line[0]), int(line[1]), COLOR_TEXT))
	rows.append(_row("BONUS", total, COLOR_HI))
	for row in rows:
		row.modulate.a = 0.0
	var tween := create_tween()
	for row in rows:
		tween.tween_property(row, "modulate:a", 1.0, 0.15)
		tween.tween_interval(0.25)

func _row(name_text : String, value : int, color : Color) -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_result.add_child(row)
	var name_label := _label(13, color, HORIZONTAL_ALIGNMENT_LEFT, row)
	name_label.text = name_text
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var value_label := _label(13, color, HORIZONTAL_ALIGNMENT_RIGHT, row)
	value_label.text = str(value)
	return row

# ---------------------------------------------------------------- 焼いた弾の数

## 「238 BURN!」を、自機の少し上に出し続ける
func _follow_player() -> void:
	if not _burn_label.visible or not is_instance_valid(_player):
		return
	var at := _player.get_global_transform_with_canvas().origin + burn_label_offset
	var screen := get_viewport().get_visible_rect().size
	var pos := at - _burn_label.size * 0.5
	# 画面の端で切れないよう、内側に収める
	pos.x = clampf(pos.x, 4.0, screen.x - _burn_label.size.x - 4.0)
	pos.y = clampf(pos.y, 4.0, screen.y - _burn_label.size.y - 4.0)
	_burn_label.position = pos

func _on_burn_count_changed(count : int) -> void:
	if _burn_fade:
		_burn_fade.kill()
	_burn_label.visible = true
	_burn_label.modulate.a = 1.0
	_burn_label.text = "%d BURN!" % count
	_follow_player()
	# 数が増えるたびに、少し弾む
	if _burn_tween:
		_burn_tween.kill()
	_burn_label.scale = Vector2(1.25, 1.25)
	_burn_tween = create_tween()
	_burn_tween.tween_property(_burn_label, "scale", Vector2.ONE, 0.12)

## 発動が終わったら、最終の数を大きく見せてから消す
func _on_burn_finished(count : int) -> void:
	if count <= 0:
		_burn_label.visible = false
		return
	_burn_label.text = "%d BURN!" % count
	if _burn_tween:
		_burn_tween.kill()
	if _burn_fade:
		_burn_fade.kill()
	_burn_fade = create_tween()
	_burn_fade.tween_property(_burn_label, "scale", Vector2(1.5, 1.5), 0.1)
	_burn_fade.tween_property(_burn_label, "scale", Vector2.ONE, 0.2)
	_burn_fade.tween_interval(0.8)
	_burn_fade.tween_property(_burn_label, "modulate:a", 0.0, 0.4)
	_burn_fade.tween_callback(func() -> void: _burn_label.visible = false)
