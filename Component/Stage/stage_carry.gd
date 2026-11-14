extends RefCounted
class_name StageCarry
## 次のステージへ持ち越す、自機と点数の状態。シーンを切り替えても残る(static)。
## StageTransition が、ステージをクリアして次へ移るときに save() し、次のステージで apply() する。

## 持ち越す状態があるか(次のステージで apply() したら消える)
static var pending : bool = false
## 前のステージから霧を抜けて入ってくるところか(StageTransition が終わるまで。StageIntro は何もしない)
static var arriving : bool = false
## 霧の中を飛んでいた自機の高さ(画面の上 = 0、下 = 1)
static var cruise_height : float = 0.6

static var score : int = 0
static var next_extend : int = 0
static var lives : int = 3
static var ignite_value : float = 0.0
static var shot_stage : int = 0
static var option_count : int = 0
static var lock_speed_level : int = 0

## 今のステージの状態を覚える
static func save(tree : SceneTree) -> void:
	var score_system := tree.get_first_node_in_group("score_system") as ScoreSystem
	var player := find_player(tree)
	var game_manager := _game_manager(tree)
	if score_system:
		score = score_system.score
		next_extend = score_system._next_extend
	if player:
		lives = player.lives
		shot_stage = player.shot_stage
		option_count = player.options.size()
		lock_speed_level = player.lock_speed_level
	if game_manager:
		ignite_value = game_manager.ignite.value
	pending = true

## 覚えた状態を、新しいステージに入れる。全ノードの準備が終わってから呼ぶ
static func apply(tree : SceneTree) -> void:
	if not pending:
		return
	pending = false
	var score_system := tree.get_first_node_in_group("score_system") as ScoreSystem
	var player := find_player(tree)
	var game_manager := _game_manager(tree)
	if score_system:
		score_system.score = score
		score_system._next_extend = maxi(next_extend, score_system._next_extend)
		score_system.score_changed.emit(score)
	if player:
		player.lives = lives
		player.lives_changed.emit(lives)
		for i in shot_stage:
			player.power_up_shot()
		for i in option_count:
			player.add_option()
		for i in lock_speed_level:
			player.upgrade_lock_speed()
	if game_manager:
		game_manager._shown_level = 99 # 持ち越したレベルを入れるときは、LEVEL UP を出さない
		game_manager.ignite.value = ignite_value
		game_manager.ignite._update(true)

static func find_player(tree : SceneTree) -> Player:
	for node in tree.get_nodes_in_group("player"):
		if node is Player:
			return node
	return null

static func _game_manager(tree : SceneTree) -> GameManager:
	var root := tree.current_scene
	if root is GameManager:
		return root
	if root == null:
		root = tree.root
	var found := root.find_children("*", "GameManager", true, false)
	return found[0] as GameManager if not found.is_empty() else null
