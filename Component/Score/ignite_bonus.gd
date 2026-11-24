extends Node
## イグナイトのチャンス(おとりの雑魚)。敵(Enemy)の子に置く。
## 反射弾(イグナイトで返した弾)か、イグナイトの発動中に倒されると、「COUNTER!」と出て、スコアアイテムがたくさん出る。
## 倒した数は RunConfig.ignite_counter_kills に数える(エンドBの選択条件の1つ)。

## 出す点の合計と、アイテムの数
@export var bonus_points : int = 30000
@export var item_count : int = 24
## ふつうに倒したとき(イグナイトを使わなかったとき)のアイテムの数(点はふつうの撃破のまま)
@export var plain_item_count : int = 0

var _enemy : Enemy

func _ready() -> void:
	_enemy = get_parent() as Enemy
	if _enemy:
		_enemy.died.connect(_on_died)

func _on_died(_e : Enemy) -> void:
	var countered : bool = _enemy.killed_by_reflect or _enemy.ignite_kill
	if not countered:
		return
	RunConfig.ignite_counter_kills += 1
	var tree := get_tree()
	var score_system := tree.get_first_node_in_group("score_system") as ScoreSystem
	if score_system:
		score_system.spawn_items(_enemy.global_position, bonus_points, item_count, 1.7, ScoreItem.Kind.MEDIUM)
	FloatingText.spawn(tree, _enemy.global_position + Vector2(0, -18), "COUNTER!", Color(1.0, 0.6, 0.2), 16)
	ScreenFlash.play(tree, 0.12)
