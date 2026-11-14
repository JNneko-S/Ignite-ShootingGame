extends Sprite2D
class_name RailGround
## 左右にも上下にもつながる線路の地面(ステージ2)。Sprite2D にアタッチし、Texture に「Loop this at the end.png」を入れる。
## 絵を横に Tiles X 枚並べ、縦はカメラに映る分だけ並べて、下へ流れ続ける(StageRunner のスクロール倍率が効く)。
##
## 線路の位置: Track X(絵の中の、線路の中心の x。テクスチャの px)から、ワールドの x を出す。
##   rail_x(i) … 左から i 番目の線路(0 から)。線路の束は2本の線路が並んだもので、1画面に束が2つ = 線路が4本。
##   ステージ2の3画面なら 0〜11(左の画面に 0〜3 / 中央に 4〜7 / 右に 8〜11)。
##   束の左の線路(偶数)は上へ、右の線路(奇数)は下へ列車が走る
## 列車(Train)は、これを見て線路の上を走る。"rail_ground" グループに入る。
## 地上の敵(戦車など、GroundUnit)用に、地面と一緒に流れる GroundLayer(Node2D)を自分で作る。
## GroundLayer は "ground" と "ground_layer" グループに入るので、戦車はそこに出て、地面と一緒に流れる。

## 横に並べる枚数(奇数にすると、このノードの位置が真ん中の1枚の中心になる)
@export var tiles_x : int = 5
## 1秒あたりに流れる距離(px、ワールド)。StageRunner のスクロール倍率が掛かる
@export var scroll_speed : float = 60.0
## 絵の中の線路の中心(テクスチャの px、絵の左の端から)。2本のレールの外側の端と端の真ん中
@export var track_x : Array[float] = [46.5, 67.5, 165.5, 186.5]
## rail_x(0) にする線路が、真ん中の1枚から数えて何枚左の絵にあるか
@export var first_tile : int = -1

## 今までに流れた距離(列車などが、地面に合わせて動くのに使う)
var scrolled : float = 0.0
## 今の1秒あたりの流れる速さ(倍率込み)
var current_speed : float = 0.0

var _runner : StageRunner
var _tile : Vector2
## 線路1本の幅の半分(テクスチャの px。枕木の端まで)。地上の敵が線路にかぶらないようにするのに使う
@export var track_half_width : float = 11.0
## 地面と一緒に流れるノード(戦車などが乗る)
var ground_layer : Node2D

func _ready() -> void:
	add_to_group("rail_ground")
	centered = false
	region_enabled = true
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	if texture:
		_tile = texture.get_size()
	_update_region()
	ground_layer = Node2D.new()
	ground_layer.name = "GroundLayer"
	ground_layer.top_level = true # 自分(毎フレームカメラに合わせて動く)とは別に、地面の流れだけで動く
	ground_layer.z_as_relative = false
	ground_layer.z_index = -5 # 地面より上、列車(z 1)より下
	ground_layer.add_to_group("ground")
	ground_layer.add_to_group("ground_layer")
	add_child(ground_layer)
	# 隠してある別の地面(継承元のステージの Scroller など)が同じグループにいると、戦車がそちらに出てしまうので外す
	for group in ["ground", "ground_layer"]:
		for node in get_tree().get_nodes_in_group(group):
			if node != ground_layer and node is CanvasItem and not (node as CanvasItem).is_visible_in_tree():
				node.remove_from_group(group)

static func of(node : Node) -> RailGround:
	if node == null or not node.is_inside_tree():
		return null
	return node.get_tree().get_first_node_in_group("rail_ground") as RailGround

## 線路の数
func rail_count() -> int:
	return track_x.size() * 3

## 左から i 番目の線路の、ワールドの x
func rail_x(i : int) -> float:
	if track_x.is_empty() or _tile.x <= 0.0:
		return global_position.x
	var per_tile := track_x.size()
	var tile := first_tile + floori(float(i) / per_tile)
	var local_x := track_x[posmod(i, per_tile)] - _tile.x * 0.5 + tile * _tile.x
	return global_position.x + local_x * global_scale.x

## 線路の束(2本並んだ線路)の数と、左から b 番目の束の真ん中の x。大きな列車(ボス)は、束の2本にまたがって走る
func bundle_count() -> int:
	return rail_count() / 2

func bundle_x(b : int) -> float:
	return (rail_x(b * 2) + rail_x(b * 2 + 1)) * 0.5

## またぐ位置(とても大きな列車が、となり合う2本の線路のあいだをまたいで走る位置)の数と、その x。
## 束と束のあいだ(線路 2k+1 と 2k+2 のまん中)。ステージ2は 0〜4:
##   0 = 左の画面の真ん中 / 1 = 左と中央の境目 / 2 = 中央の画面の真ん中 / 3 = 中央と右の境目 / 4 = 右の画面の真ん中
func span_count() -> int:
	return maxi(rail_count() / 2 - 1, 0)

func span_x(k : int) -> float:
	return (rail_x(k * 2 + 1) + rail_x(k * 2 + 2)) * 0.5

func nearest_span(x : float) -> int:
	var best := 0
	var best_d := INF
	for k in span_count():
		var d := absf(span_x(k) - x)
		if d < best_d:
			best_d = d
			best = k
	return best

## x を、線路にかぶらない地面(束と束のあいだの土の帯)の中に寄せる。half_width は置くものの幅の半分(px)
## (戦車などの地上の敵が、列車の走る線路の上に出ないように)
func clamp_off_rails(x : float, half_width : float) -> float:
	var margin := track_half_width * global_scale.x + half_width
	var best := x
	var best_d := INF
	# となり合う線路のうち、あいだが広いところ(束と束のあいだ)が土の帯
	for i in rail_count() - 1:
		var left := rail_x(i) + margin
		var right := rail_x(i + 1) - margin
		if right < left:
			continue # 同じ束の2本のあいだ(狭くて置けない)
		var c := clampf(x, left, right)
		var d := absf(c - x)
		if d < best_d:
			best_d = d
			best = c
	return best

## いちばん近い束の番号
func nearest_bundle(x : float) -> int:
	var best := 0
	var best_d := INF
	for b in bundle_count():
		var d := absf(bundle_x(b) - x)
		if d < best_d:
			best_d = d
			best = b
	return best

## いちばん近い線路の番号
func nearest_rail(x : float) -> int:
	var best := 0
	var best_d := INF
	for i in rail_count():
		var d := absf(rail_x(i) - x)
		if d < best_d:
			best_d = d
			best = i
	return best

func _process(delta : float) -> void:
	if not is_instance_valid(_runner):
		_runner = get_tree().get_first_node_in_group("stage_runner") as StageRunner
	current_speed = scroll_speed * (_runner.scroll_multiplier if _runner else 1.0)
	scrolled += current_speed * delta
	_update_region()
	if ground_layer:
		ground_layer.global_position = Vector2(0.0, scrolled)

## 絵の範囲: 横は Tiles X 枚、縦はカメラに映る範囲 + 1枚。流れた分は、絵の切り出す位置をずらして見せる
func _update_region() -> void:
	if _tile.x <= 0.0:
		return
	var view := CameraView.visible_rect(self)
	var s := global_scale
	var width := _tile.x * tiles_x
	var height := ceilf(view.size.y / (_tile.y * s.y) + 2.0) * _tile.y
	var shift := fposmod(scrolled / s.y, _tile.y)
	region_rect = Rect2(0.0, -shift, width, height)
	offset = Vector2(-width * 0.5, 0.0)
	# 縦は、カメラの上の端より1枚上から並べる(このノードの y はカメラに合わせて動かす)
	global_position.y = view.position.y - _tile.y * s.y
