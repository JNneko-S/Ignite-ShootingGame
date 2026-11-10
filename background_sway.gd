extends Node
class_name BackgroundSway
## 自機がカメラの左端・右端に寄ると、背景を少し横にずらす。
## (カメラが自機を少し追いかけているように見せて、画面の左右に広がりを出す)
##
## 使い方:
##   シーンに置き、Targets にずらしたい背景(Parallax2D / BackgroundScroller / Sprite2D など)を入れる。
##   Depth Scales で層ごとの動く量を変えると、奥の層ほど動かない「奥行き」が出る。
##
## 地上の敵は SwayFollow(敵の子に置く部品)で、このずれについてくる。
## Parallax2D は scroll_offset を、それ以外の Node2D は position.x を動かす
## (縦のスクロールなど、ほかのスクリプトが動かしている分とは打ち消し合わない)。

## 横にずらす背景
@export var targets : Array[Node2D] = []
## 背景ごとの動く量の倍率(targets と同じ順番)。足りない分は 1.0
@export var depth_scales : Array[float] = []
## 自機が端にいるときに、背景がずれる最大の距離(px)。
## 背景の横幅がカメラより広い分(片側)より小さくしないと、背景の外側が見えてしまう
@export var sway_distance : float = 16.0
## true なら、自機と逆向きに動く(カメラが自機を追いかけているように見える)
@export var move_opposite : bool = true
## 画面中央からの距離の割合(0.0〜1.0)。ここより端に寄ったときだけ背景が動き始める。0 なら中央から少しずつ動く
@export_range(0.0, 0.95, 0.05) var edge_start : float = 0.3
## 背景が追いつく速さ。大きいほど自機にきびきびついてくる
@export var follow_speed : float = 4.0
## 自機が動ける範囲の、カメラの端からの余白(px)。Player の screen_margin があれば自動でそれを使う
@export var edge_margin : float = 16.0
## ずらす対象の自機。未設定なら "player" グループから探す
@export var player : Node2D

var current_offset : float = 0.0
var _applied : Array[float] = []

func _ready() -> void:
	add_to_group("background_sway") # SwayFollow(地上の敵)が、ずれの量を読みに来る
	_applied.resize(targets.size())
	_applied.fill(0.0)

func _process(delta : float) -> void:
	if player == null or not is_instance_valid(player):
		player = _find_player()
	var target_offset := 0.0
	if player and player.is_inside_tree():
		target_offset = _target_offset()
	current_offset = lerpf(current_offset, target_offset, 1.0 - exp(-follow_speed * delta))
	for i in targets.size():
		var node := targets[i]
		if node == null or not is_instance_valid(node):
			continue
		var depth := depth_scales[i] if i < depth_scales.size() else 1.0
		var offset := current_offset * depth
		if node is Parallax2D:
			var layer := node as Parallax2D
			layer.scroll_offset.x += offset - _applied[i]
		else:
			node.position.x += offset - _applied[i]
		_applied[i] = offset

func _target_offset() -> float:
	var view := CameraView.visible_rect(player)
	var margin : float = player.get("screen_margin") if player.get("screen_margin") != null else edge_margin
	var half_width := view.size.x / 2.0 - margin
	if half_width <= 0.0:
		return 0.0
	var ratio := clampf((player.global_position.x - view.get_center().x) / half_width, -1.0, 1.0)
	# edge_start より内側では動かず、そこから端に向かってなめらかに強くなる
	var strength := smoothstep(edge_start, 1.0, absf(ratio)) if edge_start > 0.0 else absf(ratio)
	var offset := signf(ratio) * strength * sway_distance
	return -offset if move_opposite else offset

func _find_player() -> Node2D:
	# "player" グループには Player 以外(ShootTimer)も入っているので、Node2D だけを探す
	for node in get_tree().get_nodes_in_group("player"):
		if node is Node2D:
			return node
	return null
