extends Node2D
class_name GameManager
## ScrollTest(ステージのルート)にアタッチする配線役。
## ゲージ(体力)・難易度・イグナイトの発動・スコアをまとめて管理する。
##
## イグナイト:
##   ボタンを単押しすると、レベルを1つ消費して発動する。
##   長押し(1.5秒)すると、そのとき持っているレベルを全て消費して発動する。
##   消費したレベルの数で、効果の範囲・時間・連鎖が決まる。
##   発動中は、グレイズしてもゲージが増えない。

enum Difficulty { EASY, NORMAL, HARD }

signal score_changed(score : int)

## 未設定なら "player" グループから探す
@export var player : Player
## 未設定なら子の "UI" を使う
@export var ui : IgniteUI
## 残機を表示するラベル(任意)
@export var lives_label : LivesLabel

@export var difficulty : Difficulty = Difficulty.NORMAL

@export_group("難易度別(EASY, NORMAL, HARD の順)")
## 開始・復活時のレベル
@export var start_levels : Array[int] = [5, 3, 0]
## 被弾1回で減るレベル。1ならレベルの数 = 耐えられる被弾回数。減らした結果が0未満なら死亡
@export var miss_penalties : Array[int] = [1, 1, 1]
## グレイズ範囲の倍率(初心者ほど大きい。仮の値)
@export var graze_radius_scales : Array[float] = [1.5, 1.25, 1.0]

@export_group("ゲージ")
## Lv1 に到達するのに必要なグレイズ量(Lv n に上がるには n 倍。累計は 20, 60, 120, 200, 300)
@export var graze_per_level : float = 20.0
@export var density_bonus : float = 0.05

@export_group("イグナイト(消費したレベル 1〜5 の順)")
## 焼却範囲が一瞬だけ広がる最大半径(px)。0 なら画面全体
@export var burn_max_radius : Array[float] = [50.0, 75.0, 100.0, 125.0, 0.0]
## 縮んだあとの半径(px)。0 なら最大半径の半分
@export var burn_final_radius : Array[float] = [0.0, 0.0, 0.0, 0.0, 150.0]
## 効果の時間(秒)
@export var ignite_durations : Array[float] = [1.0, 2.0, 3.0, 4.0, 5.0]
## 連鎖が使える、消費したレベルの数
@export var chain_min_level : int = 5

@export_group("被弾時の補給アイテム")
## 被弾したとき、自機の位置から散らばるアイテムの数
@export var hit_item_count : int = 6
## アイテム1個で増えるゲージの量(Lv1まで20、Lv5まで300)
@export var hit_item_value : float = 6.0

@export_group("レベルによる能力(Lv0〜Lv5の順)")
## 移動速度の倍率。高レベルほど速い
@export var move_speed_scales : Array[float] = [1.0, 1.05, 1.1, 1.15, 1.2, 1.25]
## ショットの威力の倍率。低レベルほど強い
@export var shot_power_scales : Array[float] = [1.5, 1.4, 1.3, 1.2, 1.1, 1.0]

@export_group("エンディング条件(エンドB)")
## エンドBの選択条件①: 点火の使用回数(Lv5を長押しで全消費した回数)がこれ以上
@export var end_b_use_count_required : int = 30
## エンドBの選択条件②: 被弾(当たった回数)がこれ以下
@export var end_b_max_hits : int = 3
## エンドBの選択条件のうち、満たす必要がある数
@export var end_b_optional_required : int = 2

@export_group("スコア")
## 焼却した弾1発あたりの点数
@export var score_per_burned_bullet : int = 10

## true なら、発動・被弾の結果を出力する
@export var debug_ignite : bool = false

var ignite : IgniteGauge = IgniteGauge.new()
var score : int = 0
## 被弾した回数(死亡に至らなかったものも含む)
var hit_count : int = 0
## 死亡した回数(ノーデスの判定用)
var death_count : int = 0
## Lv5を長押しで全消費した回数(点火の使用回数)
var full_use_count : int = 0

var _ignite_time_left : float = 0.0

func _ready() -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Player
	if ui == null:
		ui = get_node_or_null("UI") as IgniteUI

	ignite.graze_per_level = graze_per_level
	ignite.density_bonus = density_bonus
	ignite.level_changed.connect(_on_level_changed)
	ignite.configure(_by_difficulty(start_levels), _by_difficulty(miss_penalties))

	if ui:
		ui.bind(ignite)
	else:
		push_warning("GameManager: IgniteUI が見つかりません")

	if player == null:
		push_warning("GameManager: Player が見つかりません")
		return

	player.graze_radius_scale = _by_difficulty(graze_radius_scales)
	player.graze_hit.connect(_on_player_graze_hit)
	player.damaged.connect(_on_player_damaged)
	player.respawned.connect(_on_player_respawned)
	player.ignite_requested.connect(_on_ignite_requested)
	player.ignite_toggled.connect(_on_ignite_toggled)
	if player.ignite_aura:
		player.ignite_aura.burned.connect(_on_bullet_burned)
	if lives_label:
		lives_label.bind(player)
	_apply_level_stats()

func _by_difficulty(values : Array):
	return values[clampi(int(difficulty), 0, values.size() - 1)]

func _at_level(values : Array, index : int):
	return values[clampi(index, 0, values.size() - 1)]

func _physics_process(delta : float) -> void:
	if player == null:
		return
	# 発動の効果時間を数える。終わったら効果を止める
	if player.is_igniting and _ignite_time_left > 0.0:
		_ignite_time_left -= delta
		if _ignite_time_left <= 0.0:
			player.set_igniting(false) # → _on_ignite_toggled(false) で効果が止まる
	# Lv1以上で、効果中でなければ、発動できる(Player が入力を受け付ける)
	player.ignite_available = ignite.level >= 1 and not player.is_igniting

# ---------------------------------------------------------------- グレイズ・被弾

func _on_player_graze_hit(_bullet_position : Vector2, density : int) -> void:
	# イグナイトの効果中は、グレイズしてもゲージが増えない
	if player.is_igniting:
		return
	ignite.add_graze(density)

## 被弾: ゲージ(体力)が減る。0未満になったら死亡
func _on_player_damaged() -> void:
	hit_count += 1
	player.reset_shot_power()
	var level_before := ignite.level
	var dead := ignite.on_miss()
	if debug_ignite:
		print("[Ignite] 被弾 Lv%d → %s" % [level_before, "死亡" if dead else "Lv%d" % ignite.level])
	if dead:
		death_count += 1
		player.die() # 発動中なら、効果も止まる
	else:
		_scatter_items()

## 被弾の位置から、ゲージの補給アイテムを散らばらせる
func _scatter_items() -> void:
	for i in hit_item_count:
		var item := IgniteItem.new()
		var angle := TAU * (float(i) + randf() * 0.6) / maxf(hit_item_count, 1)
		item.setup(player, hit_item_value, Vector2.from_angle(angle) * randf_range(160.0, 340.0))
		item.collected.connect(ignite.add_value)
		get_tree().current_scene.add_child(item)
		item.global_position = player.global_position

## 復活: ゲージは開始レベルに戻る
func _on_player_respawned() -> void:
	ignite.reset_to_start()

func _on_level_changed(_level : int) -> void:
	_apply_level_stats()

## レベルに応じて、移動速度とショットの威力を変える
func _apply_level_stats() -> void:
	if player == null:
		return
	player.level_move_scale = _at_level(move_speed_scales, ignite.level)
	player.level_power_scale = _at_level(shot_power_scales, ignite.level)

# ---------------------------------------------------------------- イグナイト

## 発動の要求。単押し(full=false)は1レベル、長押し(full=true)は全レベルを消費する
func _on_ignite_requested(full : bool) -> void:
	if player.is_igniting or ignite.level < 1:
		if debug_ignite:
			print("[Ignite] 発動できません: 発動中=%s / レベル=%d" % [player.is_igniting, ignite.level])
		return
	var used := ignite.consume_levels(ignite.level if full else 1)
	if used <= 0:
		return
	if full and used >= IgniteGauge.MAX_LEVEL:
		full_use_count += 1
	_start_ignite_effect(used)

func _start_ignite_effect(levels : int) -> void:
	var max_radius : float = _at_level(burn_max_radius, levels - 1)
	if max_radius <= 0.0:
		max_radius = CameraView.visible_rect(self).size.length() # 画面(Camera2D に映っている範囲)全体を覆う半径
	var final_radius : float = _at_level(burn_final_radius, levels - 1)
	if final_radius <= 0.0:
		final_radius = max_radius * 0.5
	var duration : float = _at_level(ignite_durations, levels - 1)
	if debug_ignite:
		print("[Ignite] 発動 %dレベル消費 → 残りLv%d / 範囲%.0f→%.0f / %.1f秒" % [
			levels, ignite.level, max_radius, final_radius, duration])

	_ignite_time_left = duration
	EnemyBullet.set_chain_allowed(levels >= chain_min_level)
	player.set_igniting(true)
	if player.ignite_aura:
		player.ignite_aura.apply_level(levels, max_radius, final_radius, duration)

## 効果の開始・終了。終了(時間切れ、または死亡)で、焼却範囲とフレアを止める
func _on_ignite_toggled(on : bool) -> void:
	if on:
		return
	_ignite_time_left = 0.0
	EnemyBullet.set_chain_allowed(false)
	if player.ignite_aura:
		player.ignite_aura.stop()
	if debug_ignite:
		print("[Ignite] 終了")

func _on_bullet_burned(_bullet_position : Vector2) -> void:
	add_score(score_per_burned_bullet)

func add_score(amount : int) -> void:
	if amount <= 0:
		return
	score += amount
	score_changed.emit(score)

# ---------------------------------------------------------------- ストーリー連動

## ゲージを消費している状態か(発動の効果中)。炎弾・とどめの判定に使う
func is_consuming() -> bool:
	return player != null and player.is_igniting

## 点火の使用回数(Lv5を長押しで全消費した回数)
func ignite_use_count() -> int:
	return full_use_count

## とどめの瞬間のステートがイグナイトか。ボスを倒した瞬間に呼ぶ
func is_finisher_state() -> bool:
	return is_consuming()

## エンドBの選択条件を、いくつ満たしているか(①使用回数 ②被弾数 ③HARD)
func end_b_optional_count() -> int:
	var count := 0
	if ignite_use_count() >= end_b_use_count_required:
		count += 1
	if hit_count <= end_b_max_hits:
		count += 1
	if difficulty == Difficulty.HARD:
		count += 1
	return count

## 最終兵器を倒した瞬間に呼ぶ。エンドBの条件(とどめ+選択条件)を満たすか
func end_b_conditions_met() -> bool:
	return is_finisher_state() and end_b_optional_count() >= end_b_optional_required
