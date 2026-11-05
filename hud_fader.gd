extends Node
class_name HudFader
## 自機が画面の上半分に入ったら、UI を半透明にする(弾や敵が UI に隠れて見えなくならないように)。
##
## 対象: "hud" グループの CanvasLayer と、layers に入れた CanvasLayer。
## CanvasLayer には透明度がないので、始めに中身をまとめて1つの Control(HudFade)に入れ、その透明度を変える。

## "hud" グループのほかに、半透明にする CanvasLayer
@export var layers : Array[CanvasLayer] = []
## 未設定なら "player" グループから探す
@export var player : Node2D
## 上半分にいるときの透明度
@export_range(0.0, 1.0, 0.05) var faded_alpha : float = 0.35
## 画面の上からこの割合より上にいたら半透明にする(0.5 = 上半分)
@export_range(0.0, 1.0, 0.05) var threshold : float = 0.5
## 透明度が変わる速さ(1秒あたり)
@export var fade_speed : float = 4.0

var _wrappers : Array[Control] = []
var _alpha : float = 1.0

func _ready() -> void:
	_setup.call_deferred() # 各 UI が中身を作り終えてから包む

func _setup() -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Node2D
	var targets : Array[CanvasLayer] = layers.duplicate()
	for node in get_tree().get_nodes_in_group("hud"):
		if node is CanvasLayer and not targets.has(node):
			targets.append(node)
	for target in targets:
		_wrappers.append(_wrap(target))

## CanvasLayer の中身を、1つの Control にまとめる(位置は変わらない)
func _wrap(target : CanvasLayer) -> Control:
	var wrapper := Control.new()
	wrapper.name = "HudFade"
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.size = get_viewport().get_visible_rect().size
	var children := target.get_children()
	target.add_child(wrapper)
	for child in children:
		if child is CanvasItem:
			child.reparent(wrapper, false)
	return wrapper

func _process(delta : float) -> void:
	if _wrappers.is_empty():
		return
	var wanted := 1.0
	if is_instance_valid(player) and player.visible:
		var area := CameraView.visible_rect(player)
		if player.global_position.y < area.position.y + area.size.y * threshold:
			wanted = faded_alpha
	_alpha = move_toward(_alpha, wanted, fade_speed * delta)
	for wrapper in _wrappers:
		if is_instance_valid(wrapper):
			wrapper.modulate.a = _alpha
