extends Node
class_name ScoreSystem
## スコアの計算。ステージのシーンに置く("score_system" グループに入る)。
##
## 点数:
##   敵の撃破   … 敵の ScoreReward 部品の Score Value(雑魚 100 / 中型 300 / 砲台 400 / 中ボス 1000)
##                × グレイズ倍率 × イグナイト倍率 × 反射弾ボーナス。
##                その場では入らず、スコアアイテムになって落ちる(拾うと入る)。
##                Ignite Kill Bonus のある敵は、イグナイトの発動中に倒すと、さらにボーナスのアイテムを落とす
##   グレイズ   … 1発 10 点。弾が自機のかなり近くまで来たら 20 点
##   焼いた弾   … スコアアイテムになり、拾うと 10 点 × 消費したレベル(Lv5 で 50 点)
##   背景の物   … イグナイトでだけ壊せる背景のオブジェクト(IgniteTarget)が、スコアアイテムを落とす
## スコアアイテムは、拾うと 点数 × 連続取得の倍率 が入る。
##   画面の下へ落とさずに拾い続けると、1個ごとに倍率が上がる(item_chain_step、上限 item_chain_max)。
##   1個でも落とすと、倍率は 1.0 に戻る。
##   ボス       … 20000 × (ボス到達までの時間 − ボス戦の時間) × 残機
##   クリア     … ノーミス・グレイズ数・残っているゲージ・イグナイトの使用回数のボーナス
##
## グレイズ倍率(1.0〜2.0):
##   弾をグレイズできる距離にいる間に敵を倒すと上がる。一番近い弾が近いほど、大きく上がる。
##   時間では下がらない。被弾すると下がり、撃墜されると death_multiplier に戻る。
## イグナイト倍率: イグナイトの発動中だけ、消費したレベルに応じて掛かる(最大 5 倍)。
## 近距離撃破: 自機のショットで、近づいて倒すと close_kill_bonus 点(爆発も曲線に並んで豪華になる)。
## 吸い寄せ: スコアアイテムは自機が近づくと吸い寄せられる。イグナイト中は、焼いた弾の数だけ範囲が広がる。
## 残機: スコアが extend_every を超えるごとに 1 増える。

signal score_changed(score : int)
signal hi_score_changed(hi_score : int)
## グレイズ倍率・イグナイト倍率が変わったとき(UI 用)
signal multiplier_changed(graze_multiplier : float, ignite_multiplier : float)
## 点が入ったとき(at: 点が入った場所。演出用)
signal points_awarded(amount : int, at : Vector2)
signal extended(lives : int)
## アイテムの連続取得の数と倍率が変わったとき(UI 用)
signal item_chain_changed(chain : int, multiplier : float)
## イグナイトの発動中に、ボーナスのある敵を倒したとき(演出用)
signal ignite_bonus_killed(at : Vector2)
## ステージクリアのボーナス。lines は [[項目名, 点数], ...]
signal stage_bonus(lines : Array, total : int)
## 近づいて撃って倒したとき(演出用)
signal close_killed(at : Vector2)
## 今の発動で焼いた弾の数が増えたとき / 発動が終わったとき(「238 BURN!」の表示用)
signal burn_count_changed(count : int)
signal burn_finished(count : int)

## 未設定なら、親(GameManager)・"player"・"stage_runner" グループから探す
@export var game_manager : GameManager
@export var player : Player
@export var stage_runner : StageRunner

@export_group("グレイズ")
@export var graze_points : int = 10
## 弾の中心と自機の中心がこの距離(px)より近づいたら「かなり近い」(当たり判定は約 10px)
@export var close_graze_distance : float = 14.0
@export var close_graze_points : int = 20

@export_group("グレイズ倍率")
@export var graze_multiplier_max : float = 2.0
## グレイズしながら1体倒したときに上がる量。一番近い弾がグレイズの外側ぎりぎりなら min、自機に触れる寸前なら max
@export var graze_multiplier_step_min : float = 0.02
@export var graze_multiplier_step_max : float = 0.1
## 敵弾の当たり判定の半径(px)。グレイズできる距離の計算に使う
@export var bullet_radius : float = 5.0
## 自機が弾に当たる距離(弾と自機の中心の距離、px)。これに近いほど倍率が大きく上がる
@export var hit_distance : float = 10.0
## 被弾で下がる量
@export var hit_multiplier_penalty : float = 0.5
## 撃墜されたときの倍率(1.0 = 倍率なしに戻る。0 にすると、倍率が上がるまで撃破の点が入らない)
@export var death_multiplier : float = 1.0

@export_group("イグナイト倍率")
## 発動中に掛かる倍率(消費したレベル 1〜5 の順)
@export var ignite_multipliers : Array[float] = [1.5, 2.0, 3.0, 4.0, 5.0]
## 反射弾で倒したときの倍率
@export var reflect_kill_multiplier : float = 1.5

@export_group("近距離撃破")
## 自機と敵の距離がこれ以下(px)のときに、自機のショットで倒すと「近距離撃破」(反射弾で倒したときは入らない)
@export var close_kill_distance : float = 96.0
## 近距離撃破で、さらに入る点
@export var close_kill_bonus : int = 50

@export_group("スコアアイテム")
@export var score_item_scene : PackedScene = preload("res://GameScene/Item/score_item.tscn")
## 自機が近づくと吸い寄せられ始める距離(px)
@export var item_magnet_radius : float = 44.0
## イグナイトの発動中は、焼いた弾1発ごとに、吸い寄せられる距離がこれだけ広がる(px)
@export var burn_magnet_per_bullet : float = 2.0
## 広がった吸い寄せ距離の上限(px)
@export var burn_magnet_max : float = 600.0
## 焼いた弾1個の点数 = これ × 消費したレベル
@export var burn_points_per_level : int = 10
## 敵1体から出るアイテムの最大数(基本点 100 ごとに1個)
@export var max_kill_items : int = 10
## 画面の下へ落とさずに拾い続けると、1個ごとに倍率がこれだけ上がる
@export var item_chain_step : float = 0.01
## 連続取得の倍率の上限
@export var item_chain_max : float = 3.0
## 一度に出ているアイテムの上限(超えた分は、すぐに点にする)
@export var max_score_items : int = 400

@export_group("ボス")
## ボスの点 = これ × (ボス到達までの時間 − ボス戦の時間) × 残機
@export var boss_bonus_base : int = 20000
## 残機がこれより少なくても、これとして数える(1 なら、残機 0 でもボーナスが入る)
@export var boss_bonus_min_lives : int = 1

@export_group("ステージクリア")
@export var no_miss_bonus : int = 1000000
@export var graze_bonus_each : int = 1000
## 残っているゲージ 1 レベル分の点(途中の進捗も割合で入る)
@export var gauge_bonus_per_level : int = 200000
@export var ignite_use_bonus_each : int = 20000

@export_group("残機")
## この点数ごとに残機が 1 増える
@export var extend_every : int = 100000000

@export_group("ハイスコア")
@export var save_path : String = "user://score.cfg"
## 保存するときの名前(ステージや難易度ごとに分けるなら変える)
@export var save_key : String = "stage1"

var score : int = 0
var hi_score : int = 0
var graze_multiplier : float = 1.0
## 撃破の内訳(デバッグ・リザルト用)
var kill_count : int = 0
## スコアアイテムを、画面の下へ落とさずに拾い続けた数
var item_chain : int = 0
## 今の発動で焼いた弾の数(発動していなければ、直前の発動の数)
var burn_count : int = 0
var _burning : bool = false

var _next_extend : int = 0
## 「かなり近い」の判定待ちの弾
var _watching : Dictionary = {}
var _item_count : int = 0
var _last_ignite_multiplier : float = 1.0

func _enter_tree() -> void:
	add_to_group("score_system")

func _ready() -> void:
	_next_extend = extend_every
	_load_hi_score()
	_connect.call_deferred() # 全ノードの準備が終わってから探す

func _connect() -> void:
	if game_manager == null:
		game_manager = get_parent() as GameManager
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Player
	if stage_runner == null:
		stage_runner = get_tree().get_first_node_in_group("stage_runner") as StageRunner
	if player:
		player.grazed_bullet.connect(_on_grazed_bullet)
		player.game_over.connect(save_hi_score)
	if stage_runner:
		stage_runner.stage_cleared.connect(_on_stage_cleared)
	score_changed.emit(score)
	hi_score_changed.emit(hi_score)
	multiplier_changed.emit(graze_multiplier, 1.0)

func _exit_tree() -> void:
	save_hi_score()

func _physics_process(_delta : float) -> void:
	_check_close_grazes()
	var ignite_multiplier := current_ignite_multiplier()
	if not is_equal_approx(ignite_multiplier, _last_ignite_multiplier):
		_last_ignite_multiplier = ignite_multiplier
		multiplier_changed.emit(graze_multiplier, ignite_multiplier)

# ---------------------------------------------------------------- 点を足す

## 点を足す(倍率なし)
func add_points(amount : int, at : Vector2 = Vector2.ZERO) -> void:
	if amount <= 0:
		return
	score += amount
	score_changed.emit(score)
	points_awarded.emit(amount, at)
	if score > hi_score:
		hi_score = score
		hi_score_changed.emit(hi_score)
	_check_extend()

func _check_extend() -> void:
	if extend_every <= 0:
		return
	while score >= _next_extend:
		_next_extend += extend_every
		if is_instance_valid(player):
			player.add_life(1)
			extended.emit(player.lives)

func current_ignite_multiplier() -> float:
	if game_manager == null or game_manager.ignite_level_in_use <= 0 or ignite_multipliers.is_empty():
		return 1.0
	return ignite_multipliers[clampi(game_manager.ignite_level_in_use - 1, 0, ignite_multipliers.size() - 1)]

# ---------------------------------------------------------------- 撃破

## Enemy._die から呼ばれる
func on_enemy_killed(enemy : Enemy) -> void:
	kill_count += 1
	if enemy.boss_reach_time >= 0.0:
		add_points(_boss_bonus(enemy), enemy.global_position)
		return
	var reward := ScoreReward.of(enemy)
	if reward == null:
		return # 点数の部品がない敵は、点が入らない
	if enemy.close_kill:
		add_points(close_kill_bonus, enemy.global_position) # 近づいて倒したご褒美は、その場で入る
		close_killed.emit(enemy.global_position)
	_raise_graze_multiplier()
	var ignite_multiplier := current_ignite_multiplier()
	var points := float(reward.score_value) * graze_multiplier * ignite_multiplier
	if enemy.killed_by_reflect:
		points *= reflect_kill_multiplier
	# 点はその場で入らず、アイテムになって落ちる(大きい敵ほど数が多い)
	var count := clampi(roundi(float(reward.score_value) / 100.0), 1, max_kill_items)
	spawn_items(enemy.global_position, roundi(points), count)
	# イグナイトの発動中に倒すと、さらにボーナスのアイテムが出る敵がいる
	if reward.ignite_kill_bonus > 0 and ignite_multiplier > 1.0:
		spawn_items(enemy.global_position, roundi(reward.ignite_kill_bonus * ignite_multiplier),
			maxi(reward.ignite_kill_bonus_items, 1), 1.6)
		ignite_bonus_killed.emit(enemy.global_position)

## ボスの点 = 基本点 × (ボス到達までの時間 − ボス戦の時間) × 残機。時間は秒(小数は切り捨て)
func _boss_bonus(enemy : Enemy) -> int:
	var seconds := maxi(floori(enemy.boss_reach_time - enemy.alive_time), 0)
	var lives := boss_bonus_min_lives
	if is_instance_valid(player):
		lives = maxi(player.lives, boss_bonus_min_lives)
	return boss_bonus_base * seconds * lives

## グレイズできる距離に弾があれば、一番近い弾の近さに応じて倍率を上げる
func _raise_graze_multiplier() -> void:
	var closeness := _nearest_bullet_closeness()
	if closeness < 0.0:
		return
	var step := lerpf(graze_multiplier_step_min, graze_multiplier_step_max, closeness)
	_set_graze_multiplier(graze_multiplier + step)

## 一番近い敵弾の近さ(0 = グレイズできる距離の外側ぎりぎり、1 = 当たる寸前)。グレイズできる距離に弾がなければ -1
func _nearest_bullet_closeness() -> float:
	if not _player_active():
		return -1.0
	var center := player.global_position
	var reach := _graze_reach()
	var nearest := INF
	for bullet in get_tree().get_nodes_in_group("enemy_bullet"):
		var distance : float = center.distance_to(bullet.global_position)
		if distance < nearest:
			nearest = distance
	if nearest >= reach:
		return -1.0
	return clampf((reach - nearest) / maxf(reach - hit_distance, 1.0), 0.0, 1.0)

## 弾の中心がこの距離より近ければ、グレイズできる距離
func _graze_reach() -> float:
	var circle := player.graze_shape.shape as CircleShape2D if player.graze_shape else null
	var radius := circle.radius if circle else 24.0
	return radius + bullet_radius

func _set_graze_multiplier(value : float) -> void:
	value = clampf(value, minf(death_multiplier, 1.0), graze_multiplier_max)
	if is_equal_approx(value, graze_multiplier):
		return
	graze_multiplier = value
	multiplier_changed.emit(graze_multiplier, current_ignite_multiplier())

## GameManager から呼ばれる。被弾で倍率が下がり、撃墜されると death_multiplier に戻る
func on_player_hit(dead : bool) -> void:
	if dead:
		graze_multiplier = death_multiplier
		multiplier_changed.emit(graze_multiplier, current_ignite_multiplier())
	else:
		_set_graze_multiplier(maxf(graze_multiplier - hit_multiplier_penalty, 1.0))

func _player_active() -> bool:
	return is_instance_valid(player) and player.visible and player._is_alive

# ---------------------------------------------------------------- グレイズ

func _on_grazed_bullet(bullet : Area2D) -> void:
	add_points(graze_points, bullet.global_position)
	_watching[bullet] = true

## グレイズした弾が、さらに自機のかなり近くまで来たら、差の分(20 − 10 点)を足す
func _check_close_grazes() -> void:
	if _watching.is_empty():
		return
	if not _player_active():
		_watching.clear()
		return
	var center := player.global_position
	var reach := _graze_reach()
	for bullet in _watching.keys():
		if not is_instance_valid(bullet):
			_watching.erase(bullet)
			continue
		var distance := center.distance_to((bullet as Node2D).global_position)
		if distance <= close_graze_distance:
			_watching.erase(bullet)
			add_points(close_graze_points - graze_points, bullet.global_position)
		elif distance > reach + 8.0:
			_watching.erase(bullet) # グレイズの外に出た

# ---------------------------------------------------------------- 焼いた弾

## 焼いた弾の位置に、スコアアイテムを出す。level: 今の発動で消費したレベル
func spawn_burn_item(at : Vector2, level : int) -> void:
	spawn_items(at, burn_points_per_level * maxi(level, 1), 1, 0.5)
	if _burning:
		burn_count += 1
		burn_count_changed.emit(burn_count)

## GameManager から呼ばれる。イグナイトの発動が始まった / 終わった
func begin_burn() -> void:
	_burning = true
	burn_count = 0
	collect_all_items() # 発動した瞬間に、画面のスコアアイテムを1回だけ全部回収する

## 今出ているスコアアイテムを、全部自機へ吸い寄せる(このあと出たアイテムは、いつもどおり)
func collect_all_items() -> void:
	get_tree().call_group("score_item", "collect_now")

func end_burn() -> void:
	if not _burning:
		return
	_burning = false
	burn_finished.emit(burn_count)

## スコアアイテムが吸い寄せられ始める距離。発動中は、焼いた弾の数だけ広がる
func current_magnet_radius() -> float:
	if not _burning:
		return item_magnet_radius
	return minf(item_magnet_radius + burn_count * burn_magnet_per_bullet, burn_magnet_max)

## 近距離撃破か: 自機のショットで倒し、そのとき自機が close_kill_distance 以内にいた
func is_close_kill(enemy : Enemy) -> bool:
	if enemy.killed_by_reflect or not _player_active():
		return false
	return enemy.global_position.distance_to(player.global_position) <= close_kill_distance

## スコアアイテムを count 個出す。total を count 個で分ける。spread: 弾ける勢い(1 で普通)
func spawn_items(at : Vector2, total : int, count : int = 1, spread : float = 1.0) -> void:
	count = maxi(count, 1)
	var each := maxi(total / count, 1)
	for i in count:
		if score_item_scene == null or _item_count >= max_score_items:
			add_points(each, at) # 出し過ぎのときは、その場で点にする
			continue
		var item := score_item_scene.instantiate() as ScoreItem
		item.setup(player, each, spread)
		item.score_system = self
		item.collected.connect(_on_item_collected)
		item.missed.connect(_on_item_missed)
		item.tree_exited.connect(func() -> void: _item_count -= 1)
		_item_count += 1
		get_tree().current_scene.add_child.call_deferred(item) # 物理の処理中に出ることが多いので、後で足す
		item.position = at

## 拾った: 点数 × 連続取得の倍率 が入り、連続取得が1つ増える
func _on_item_collected(item : ScoreItem) -> void:
	add_points(roundi(item.value * item_chain_multiplier()), item.global_position)
	item_chain += 1
	item_chain_changed.emit(item_chain, item_chain_multiplier())

## 画面の下へ落とした: 連続取得が途切れる
func _on_item_missed(_item : ScoreItem) -> void:
	if item_chain == 0:
		return
	item_chain = 0
	item_chain_changed.emit(item_chain, item_chain_multiplier())

## アイテムの連続取得の倍率
func item_chain_multiplier() -> float:
	return minf(1.0 + item_chain * item_chain_step, item_chain_max)

# ---------------------------------------------------------------- ステージクリア

func _on_stage_cleared() -> void:
	var lines : Array = []
	var deaths := game_manager.death_count if game_manager else 0
	if deaths == 0:
		lines.append(["NO MISS", no_miss_bonus])
	var grazes := player.graze_count if is_instance_valid(player) else 0
	lines.append(["GRAZE %d" % grazes, grazes * graze_bonus_each])
	if game_manager:
		var gauge := minf(float(game_manager.ignite.level) + game_manager.ignite.ratio(), float(IgniteGauge.MAX_LEVEL)) # Lv5 が満タンでも 5.0 まで
		lines.append(["GAUGE Lv%.1f" % gauge, roundi(gauge * gauge_bonus_per_level)])
		var uses := game_manager.ignite_activation_count
		lines.append(["IGNITE x%d" % uses, uses * ignite_use_bonus_each])
	var total := 0
	for line in lines:
		total += int(line[1])
	add_points(total)
	stage_bonus.emit(lines, total)
	save_hi_score()

# ---------------------------------------------------------------- ハイスコア

func _load_hi_score() -> void:
	var config := ConfigFile.new()
	if config.load(save_path) == OK:
		hi_score = int(config.get_value("hi_score", save_key, 0))

func save_hi_score() -> void:
	var config := ConfigFile.new()
	config.load(save_path) # なければ新しく作る
	if hi_score <= int(config.get_value("hi_score", save_key, 0)):
		return
	config.set_value("hi_score", save_key, hi_score)
	config.save(save_path)
