extends CanvasLayer
class_name IgniteHint
## イグナイトのボタンを、一度だけ教える表示。まだイグナイトを使ったことがないプレイヤーにだけ出る(GameManager が置く)。
## 自機のすぐ上に「B IGNITE!」のように出る。ボタン名は、最後に触ったのがゲームパッドかキーボードかで変わる。
## 出す条件: イグナイトが使える(ゲージ Lv1 以上)のに、自機の近くに敵弾がたくさん迫っている。
## イグナイトを使ったら消えて、記録する(TutorialProgress)。そのあとは、どのステージでも二度と出ない。

## 自機からこの距離(px、ワールド)の中に、この数より多く敵弾があったら出す
@export var danger_radius : float = 110.0
@export var danger_bullets : int = 10
## 一度出したら、少なくともこの秒数は出しておく(ちらつかないように)
@export var min_show_time : float = 1.6
## 自機の中心から、表示の中心までのずれ(画面の px)
@export var label_offset : Vector2 = Vector2(0, -34)
@export var color : Color = Color(1.0, 0.75, 0.3)

var player : Player
## このステージの時間(秒)になるまでは出さない
var show_after : float = 0.0
var _runner : StageRunner
var _label : Label
var _shown_for : float = 0.0
var _time : float = 0.0
var _use_pad : bool = false

func _ready() -> void:
	layer = 25
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.size = Vector2(140, 18)
	var settings := LabelSettings.new()
	settings.font = load("res://Assets/Fonts/micronian.ttf")
	settings.font_size = 12
	settings.font_color = color
	settings.outline_size = 4
	settings.outline_color = Color(0, 0, 0, 1)
	_label.label_settings = settings
	_label.visible = false
	add_child(_label)
	_use_pad = not Input.get_connected_joypads().is_empty()

func _input(event : InputEvent) -> void:
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5):
		_use_pad = true
	elif event is InputEventKey:
		_use_pad = false

func _process(delta : float) -> void:
	_time += delta
	if not is_instance_valid(player):
		_label.visible = false
		return
	if player.is_igniting:
		TutorialProgress.mark_ignite_used()
		queue_free()
		return
	if show_after > 0.0:
		if _runner == null:
			_runner = get_tree().get_first_node_in_group("stage_runner") as StageRunner
		if _runner and _runner.stage_time < show_after:
			_label.visible = false
			return
	var wanted := player.ignite_available and player.visible and _danger()
	if wanted:
		_shown_for = maxf(_shown_for, min_show_time)
	_shown_for -= delta
	var show := player.ignite_available and _shown_for > 0.0
	_label.visible = show
	if not show:
		return
	_label.text = ("B" if _use_pad else "E") + "  IGNITE!"
	var at := player.get_global_transform_with_canvas().origin + label_offset
	_label.position = at - _label.size * 0.5
	# 目に入るように、小さく弾むように点滅する
	_label.modulate.a = 0.55 + 0.45 * absf(sin(_time * 7.0))
	_label.scale = Vector2.ONE * (1.0 + 0.08 * absf(sin(_time * 7.0)))
	_label.pivot_offset = _label.size * 0.5

## 自機の近くに、敵弾がたくさん迫っているか
func _danger() -> bool:
	var count := 0
	var r2 := danger_radius * danger_radius
	for bullet in get_tree().get_nodes_in_group("enemy_bullet"):
		var node := bullet as Node2D
		if node and node.global_position.distance_squared_to(player.global_position) <= r2:
			count += 1
			if count > danger_bullets:
				return true
	return false
