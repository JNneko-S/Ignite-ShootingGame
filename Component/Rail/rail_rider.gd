extends Node
class_name RailRider
## 敵(列車のボスなど)を、線路の上に乗せる部品。敵の子に置く。横の位置を線路(RailGround)に合わせる。
##   Span >= 0   … となり合う2本の線路のあいだをまたいで走る(とても大きな列車。ステージ2は 0〜4:
##                  0 = 左の画面の真ん中 / 1 = 左と中央の境目 / 2 = 中央 / 3 = 中央と右の境目 / 4 = 右の画面の真ん中)
##   Bundle >= 0 … その束(2本並んだ線路)にまたがって走る(ステージ2は 0〜5: 左の画面 0,1 / 中央 2,3 / 右 4,5)
##   Bundle = -1 … 出てきた位置にいちばん近い束
##   Rail >= 0  … 1本の線路の上(いちばん優先)
## 移動パターンを使う敵なら、Path Offset の横のずれを足して、移動パターンの x が線路の真ん中に来るようにする
## (なので、移動パターンは縦だけに動かす)。前後の動きと線路を移るのは TrainBossMover が受け持つ。

@export var span : int = -1
@export var bundle : int = -1
@export var rail : int = -1

func _ready() -> void:
	# 親の Enemy の _ready(移動パターンの開始)より先に呼ばれるので、ここで位置を直す
	var enemy := get_parent() as Node2D
	var ground := RailGround.of(self)
	if enemy == null or ground == null:
		return
	var x0 := enemy.global_position.x
	if enemy is Enemy and enemy.pattern and enemy.pattern.override_start_position:
		x0 = enemy._convert_absolute(enemy.pattern.start_position).x
	var x := 0.0
	if rail >= 0:
		x = ground.rail_x(rail)
	elif span >= 0:
		x = ground.span_x(span)
	else:
		if bundle < 0:
			bundle = ground.nearest_bundle(x0)
		x = ground.bundle_x(bundle)
	if enemy is Enemy:
		enemy.path_offset.x += x - x0
	enemy.global_position.x += x - x0
