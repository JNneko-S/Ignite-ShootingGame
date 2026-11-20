extends Node
class_name BoostDrop
## (ANOTHER)倒されたら、連射速度UP か 威力UP を必ず落とす部品。ハザードキャリアに置く。
## どちらを落とすかは HazardRank.drop_boost が決める(段階の低いほう。両方とも最大なら落とさない)

## オフなら落とさない(アイテムを落とさない版のキャリアなど)
@export var enabled : bool = true

func _ready() -> void:
	var enemy := get_parent() as Enemy
	if enemy:
		enemy.died.connect(_on_died)

func _on_died(enemy : Enemy) -> void:
	if not enabled:
		return
	HazardRank.drop_boost(get_tree(), enemy.global_position)
