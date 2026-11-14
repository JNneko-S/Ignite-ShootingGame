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
## Lv1 に到達するのに必要なグレイズ量(Lv n に上がるには n 倍)。
## 20 なら累計 20, 60, 120, 200, 300。12 なら累計 12, 36, 72, 120, 180
@export var graze_per_levels : Array[float] = [12.0, 16.0, 20.0]
## グレイズ範囲の倍率(初心者ほど大きい。仮の値)
@export var graze_radius_scales : Array[float] = [1.5, 1.25, 1.0]

@export_group("ゲージ")
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
## 効果が時間切れで終わったあとの無敵時間(秒)。死亡で終わったときは付かない
@export var post_ignite_invincible_time : float = 1.0
## 焼いた弾1発ごとに、効果の残り時間をこれだけ延ばす(秒)。焼くほど、イグナイトの消費が遅くなる
@export var burn_extend_time : float = 0.02
## 1回の発動で延ばせる時間の上限(元の効果時間に対する割合。1.0 なら最大で2倍の長さ)
@export var burn_extend_max_ratio : float = 1.0
## 画面演出のシーン(衝撃波・ヒットストップ・画面のふちの光)。空なら演出なし
@export var screen_effect_scene : PackedScene = preload("res://GameScene/Effect/ignite_screen_effect.tscn")

@export_group("ゲームオーバー")
## 残機が尽きたときに出す画面(ルートが GameOverScreen)。空なら何も出さない
@export var game_over_scene : PackedScene = preload("res://GameScene/UI/game_over.tscn")

@export_group("被弾時の補給アイテム")
## 散らばるアイテムのシーン(ルートが IgniteItem)。見た目はこのシーンの Sprite2D で変える
@export var hit_item_scene : PackedScene = preload("res://GameScene/Item/ignite_item.tscn")
## 被弾したときのレベル内の進捗(%)のうち、アイテムで取り戻せる割合。
## 0.5 なら、Lv2 の 80% で被弾 → Lv1 の 0% に下がり、全部拾うと Lv1 の 40% まで戻る
@export_range(0.0, 1.0, 0.05) var hit_item_recover_rate : float = 0.5
## 被弾したときのレベルがこれより低いと、アイテムは出ない(2 なら、Lv1 以下で被弾したときは出ない)
@export_range(0, 5) var hit_item_min_level : int = 2
## 被弾したときの進捗がこれ以下なら、アイテムは出ない(0 なら、進捗による制限なし)
@export_range(0.0, 1.0, 0.05) var hit_item_min_progress : float = 0.0
## アイテム1個あたりの、取り戻せる進捗(0.05 = 5%)。合計をこれで割った数だけ出す
@export_range(0.01, 1.0, 0.01) var hit_item_progress_each : float = 0.05
## 一度に出るアイテムの最大数(合計の量は変わらず、1個あたりが増える)
@export var hit_item_max_count : int = 6

@export_group("復活")
## 復活してから、敵が弾を撃たない時間(秒)。死んでから復活するまでのあいだも撃たない
@export var respawn_ceasefire_time : float = 3.0

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
## 点数の計算をする ScoreSystem。未設定なら "score_system" グループから探す(なければスコアなし)
@export var score_system : ScoreSystem

## true なら、発動・被弾の結果を出力する
@export var debug_ignite : bool = false

var ignite : IgniteGauge = IgniteGauge.new()
## 最後に知らせたイグナイトのレベル(上がったときだけ LEVEL UP を出すため)
var _shown_level : int = 99
## 今のスコア(ScoreSystem の値を写したもの)
var score : int = 0
## 今の発動で消費したレベルの数(発動中でなければ 0)。スコアの倍率に使う
var ignite_level_in_use : int = 0
## 発動した回数(単押しも長押しも数える)。ステージクリアのボーナスに使う
var ignite_activation_count : int = 0
## 被弾した回数(死亡に至らなかったものも含む)
var hit_count : int = 0
## 死亡した回数(ノーデスの判定用)
var death_count : int = 0
## Lv5を長押しで全消費した回数(点火の使用回数)
var full_use_count : int = 0

var _ignite_time_left : float = 0.0
## 今の発動で、まだ延ばせる時間(秒)
var _extend_left : float = 0.0
## このフレームで延びたか(演出の残り時間を、1フレームに1回だけ合わせ直す)
var _extended : bool = false
var _screen_effect : IgniteScreenEffect

func _enter_tree() -> void:
	# 機体選択の画面を通って出撃したときは、そこで選んだ難易度にする。
	# 敵の砲口(子)の _ready より先に、弾幕の難易度を決めておく
	if RunConfig.has_selection:
		difficulty = clampi(RunConfig.difficulty, 0, 2) as Difficulty
	DifficultyTuning.level = int(difficulty)

func _ready() -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Player
	if ui == null:
		ui = get_node_or_null("UI") as IgniteUI
	if score_system == null:
		score_system = get_tree().get_first_node_in_group("score_system") as ScoreSystem
	if score_system:
		score_system.score_changed.connect(_on_score_changed)

	ignite.graze_per_level = _by_difficulty(graze_per_levels)
	ignite.density_bonus = density_bonus
	ignite.level_changed.connect(_on_level_changed)
	ignite.configure(_by_difficulty(start_levels), _by_difficulty(miss_penalties))

	if screen_effect_scene:
		_screen_effect = screen_effect_scene.instantiate() as IgniteScreenEffect
		add_child(_screen_effect)

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
	player.game_over.connect(_on_game_over)
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
		if _extended:
			_extended = false
			_apply_extension()
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
	var progress_before := ignite.ratio() # 被弾したときのレベル内の進捗(アイテムの量に使う)
	var dead := ignite.on_miss()
	if debug_ignite:
		print("[Ignite] 被弾 Lv%d → %s" % [level_before, "死亡" if dead else "Lv%d" % ignite.level])
	if score_system:
		score_system.on_player_hit(dead) # 被弾で倍率が下がる。撃墜なら倍率がなくなる
	if dead:
		death_count += 1
		# 復活するまで(と、復活して少しのあいだ)、敵に撃たせない
		EnemyShooter.hold_fire(player.respawn_delay + respawn_ceasefire_time)
		player.die() # 発動中なら、効果も止まる
	else:
		_scatter_items(level_before, progress_before)

## 被弾の位置から、ゲージの補給アイテムを散らばらせる。
## 量は「被弾したときの進捗 × hit_item_recover_rate」を、下がったあとのレベルの幅で換算したもの
func _scatter_items(level_before : int, progress_before : float) -> void:
	if level_before < hit_item_min_level:
		return
	if progress_before <= 0.0 or progress_before <= hit_item_min_progress:
		return
	var recover := progress_before * hit_item_recover_rate
	var span := ignite.threshold(mini(ignite.level + 1, IgniteGauge.MAX_LEVEL)) - ignite.threshold(ignite.level)
	var total := recover * span
	var count := clampi(ceili(recover / hit_item_progress_each - 0.0001), 1, maxi(hit_item_max_count, 1))
	if debug_ignite:
		print("[Ignite] 補給アイテム %d個 / 合計 %.1f (Lv%d の %.0f%%)" % [count, total, ignite.level, recover * 100.0])
	for i in count:
		var item := hit_item_scene.instantiate() as IgniteItem if hit_item_scene else IgniteItem.new()
		var angle := TAU * (float(i) + randf() * 0.6) / count
		item.setup(player, total / count, Vector2.from_angle(angle) * randf_range(160.0, 340.0))
		item.collected.connect(ignite.add_value)
		get_tree().current_scene.add_child(item)
		item.global_position = player.global_position

## 残機が尽きた: ゲームオーバーの画面を出す
func _on_game_over() -> void:
	if game_over_scene == null:
		return
	var screen := game_over_scene.instantiate() as GameOverScreen
	add_child(screen)
	screen.play(score_system.score if score_system else score)

## 復活: ゲージは開始レベルに戻る
func _on_player_respawned() -> void:
	ignite.reset_to_start()
	# 復活の瞬間に残っている敵弾を消して、しばらく撃たせない
	get_tree().call_group("enemy_bullet", "queue_free")
	EnemyShooter.hold_fire(respawn_ceasefire_time)

func _on_level_changed(level : int) -> void:
	_apply_level_stats()
	# レベルが上がったら、自機の後ろに「LEVEL UP!!!」を出す(下がったときは出さない)
	if level > _shown_level and is_instance_valid(player) and player.visible:
		LevelUpPopup.show_image(get_tree(), player.global_position)
	_shown_level = level

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
	_extend_left = duration * burn_extend_max_ratio
	_extended = false
	ignite_level_in_use = levels
	ignite_activation_count += 1
	if score_system:
		score_system.begin_burn() # 焼いた弾の数を、0 から数え直す
	EnemyBullet.set_chain_allowed(levels >= chain_min_level)
	player.set_igniting(true)
	if player.ignite_aura:
		player.ignite_aura.apply_level(levels, max_radius, final_radius, duration)
	if _screen_effect:
		_screen_effect.start(player.global_position, max_radius, duration)

## 効果の開始・終了。終了(時間切れ、または死亡)で、焼却範囲とフレアを止める
func _on_ignite_toggled(on : bool) -> void:
	if on:
		return
	_ignite_time_left = 0.0
	_extend_left = 0.0
	ignite_level_in_use = 0
	if score_system:
		score_system.end_burn() # 「238 BURN!」の表示を締める
	EnemyBullet.set_chain_allowed(false)
	if player.ignite_aura:
		player.ignite_aura.stop()
	if _screen_effect:
		_screen_effect.stop()
	if player._is_alive:
		player.start_invincibility(post_ignite_invincible_time) # 終わった直後に、弾に当たらないように
	if debug_ignite:
		print("[Ignite] 終了")

## 焼いた弾は、その場でスコアアイテムになる(点数は ScoreSystem が決める)。
## 発動中なら、焼いた分だけ効果の残り時間が延びる(イグナイトの消費が遅くなる)
func _on_bullet_burned(bullet_position : Vector2) -> void:
	if score_system:
		score_system.spawn_burn_item(bullet_position, ignite_level_in_use)
	if player.is_igniting and _extend_left > 0.0:
		var add := minf(burn_extend_time, _extend_left)
		_extend_left -= add
		_ignite_time_left += add
		_extended = true

## 延びた残り時間に、画面のふちの光とオーラの点滅(終わり際の合図)を合わせ直す
func _apply_extension() -> void:
	if _screen_effect:
		_screen_effect.extend_to(_ignite_time_left)
	if player.ignite_aura and player.ignite_aura.visual:
		player.ignite_aura.visual.reschedule_blink(_ignite_time_left)

## 点数を足す(倍率なし)
func add_score(amount : int) -> void:
	if score_system:
		score_system.add_points(amount)

func _on_score_changed(value : int) -> void:
	score = value
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
