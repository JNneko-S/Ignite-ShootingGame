extends RefCounted
class_name CinematicSafety
## 演出(強制移動・突入など)で、自機が理不尽に当たらないようにする道具。
##   begin(): 自機を無敵にし、画面の敵弾をスコアアイテムに変え(convert_bullets)、落ちているアイテムを全部回収する
##   end():   無敵を解き(少しだけ無敵が残る)、もう一度アイテムを全部回収する
## begin と end は、同じ数だけ呼ぶ(重なってもよい)。

## 敵弾1発がスコアアイテムになったときの点
const BULLET_ITEM_POINTS : int = 10

static func begin(tree : SceneTree, convert_bullets : bool) -> void:
	var player := tree.get_first_node_in_group("player") as Player
	if player:
		player.begin_guard()
	if convert_bullets:
		bullets_to_items(tree)
	collect_items(tree)

static func end(tree : SceneTree, convert_bullets : bool = false) -> void:
	var player := tree.get_first_node_in_group("player") as Player
	if player:
		player.end_guard()
	if convert_bullets:
		bullets_to_items(tree) # 演出のあいだに撃たれた弾も、アイテムに変えてから操作を返す
	collect_items(tree)

## 画面の敵弾を、全部スコアアイテムに変える(弾は光って消え、その場にアイテムが出て、自機へ吸い寄せられる)
static func bullets_to_items(tree : SceneTree) -> void:
	var score_system := tree.get_first_node_in_group("score_system") as ScoreSystem
	for node in tree.get_nodes_in_group("enemy_bullet"):
		var bullet := node as EnemyBullet
		if bullet == null or not bullet.is_normal():
			continue
		if score_system:
			for item in score_system.spawn_items(bullet.global_position, BULLET_ITEM_POINTS, 1, 0.4):
				item.collect_now()
		bullet.vanish(0.0)

## 落ちているスコアアイテムを、距離に関係なく全部自機へ吸い寄せる
static func collect_items(tree : SceneTree) -> void:
	for node in tree.get_nodes_in_group("score_item"):
		if node is ScoreItem:
			(node as ScoreItem).collect_now()
