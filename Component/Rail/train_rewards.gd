extends Node
class_name TrainRewards
## 倒したときのごほうび(援護で来る列車など)。敵(Enemy)の子に置く。
## 倒すと、最後に壊した部位のあたり(画面の中に寄せる)に、次のものを落とす:
##   ・パワーアップアイテム(Power Up Scene)
##   ・イグナイトゲージを回復するアイテム(Ignite Items 個。合計でレベル Ignite Levels 段ぶん)
##   ・大量のスコアアイテム(Score Total 点を Score Items 個に分けて)
## 列車の位置(先頭)は画面の外のことが多いので、落とす場所は部位の位置から決める。

@export var power_up_scene : PackedScene = preload("res://GameScene/Item/power_up_option.tscn")
@export var ignite_item_scene : PackedScene = preload("res://GameScene/Item/ignite_item.tscn")
## イグナイトの回復アイテムの数と、合計で回復するレベルの数(1.0 なら今のレベル1段ぶん)
@export var ignite_items : int = 5
@export var ignite_levels : float = 1.0
## 1 以上なら、今のレベルに関係なく、Lv0 から このレベルまで上がるぶんを回復する(Ignite Levels の代わり)
@export var ignite_fixed_levels : int = 0
## スコアアイテムの合計の点数と、数
@export var score_total : int = 40000
@export var score_items : int = 40
## 倒したときに出す文字。空なら出さない
@export var label : String = "援護撃破!"

var _enemy : Enemy
var _last_part_at : Vector2 = Vector2.INF

func _ready() -> void:
	_enemy = get_parent() as Enemy
	if _enemy == null:
		return
	_enemy.died.connect(_on_died)
	_watch_parts.call_deferred()

func _watch_parts() -> void:
	for node in _enemy.find_children("*", "", true, false):
		if node is EnemyPart:
			node.destroyed.connect(func(part : EnemyPart) -> void: _last_part_at = part.global_position)

func _on_died(_e : Enemy) -> void:
	var tree := get_tree()
	var view := CameraView.visible_rect(_enemy)
	var at := _last_part_at if _last_part_at != Vector2.INF else _enemy.global_position
	at = at.clamp(view.position + Vector2(40, 60), view.end - Vector2(40, 120))
	# スコアアイテム
	var score_system := tree.get_first_node_in_group("score_system") as ScoreSystem
	if score_system and score_total > 0:
		score_system.spawn_items(at, score_total, score_items, 1.8)
	# パワーアップ
	if power_up_scene:
		var item := power_up_scene.instantiate()
		if item is Node2D:
			item.position = at
		tree.current_scene.add_child.call_deferred(item)
	# イグナイトの回復
	_drop_ignite(tree, at)
	if label != "":
		FloatingText.spawn(tree, at + Vector2(0, -30), label)

func _drop_ignite(tree : SceneTree, at : Vector2) -> void:
	if ignite_item_scene == null or ignite_items <= 0:
		return
	var game_manager := StageCarry._game_manager(tree)
	var player := StageCarry.find_player(tree)
	if game_manager == null or player == null:
		return
	var gauge := game_manager.ignite
	var level := mini(gauge.level, IgniteGauge.MAX_LEVEL - 1)
	var span := gauge.threshold(level + 1) - gauge.threshold(level)
	var total := span * ignite_levels
	if ignite_fixed_levels > 0:
		total = gauge.threshold(ignite_fixed_levels) - gauge.threshold(0)
	var each := total / ignite_items
	for i in ignite_items:
		var item := ignite_item_scene.instantiate() as IgniteItem
		var angle := TAU * (float(i) + randf() * 0.6) / ignite_items
		item.setup(player, each, Vector2.from_angle(angle) * randf_range(160.0, 300.0))
		item.collected.connect(gauge.add_value)
		tree.current_scene.add_child(item)
		item.global_position = at
