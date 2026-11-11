extends Node
class_name ScoreReward
## 倒したときの点数の部品。敵の子に置く。ScoreSystem が、倒された敵からこれを探して点を決める。
## 置いていない敵は、点が入らない。

## 倒したときの基本点(雑魚 100 / 中型 300 / 砲台 400 / 中ボス 1000)。
## ボスの時間ボーナスは、SpawnEvent の Boss Time Bonus で使う(そのときはこの値を使わない)
@export var score_value : int = 100
## 0 より大きければ、イグナイトの発動中に倒したときに、さらにこの点のアイテムを落とす(イグナイト倍率が掛かる)
@export var ignite_kill_bonus : int = 0
## そのボーナスを、何個のアイテムに分けて落とすか
@export var ignite_kill_bonus_items : int = 6

enum ItemKind {
	AUTO,   ## 自動: 中ボスは大、アイテム(パワーアップなど)を落とす敵は中、ほかは小
	SMALL,  ## 小(雑魚)
	MEDIUM, ## 中
	LARGE,  ## 大
}

## 倒したときに落とすスコアアイテムの種類
@export var item_kind : ItemKind = ItemKind.AUTO
## 落とす数。0 なら自動(小は点数 ÷ 100 個、中は点数 ÷ 300 個(1〜3個)、大は ScoreSystem の Midboss Item Count)
@export var item_count : int = 0

## node の子の ScoreReward。なければ null
static func of(node : Node) -> ScoreReward:
	for child in node.get_children():
		if child is ScoreReward:
			return child
	return null
