extends Node
class_name HazardRank
## 隠し難易度 ANOTHER の「ハザードランク」(0〜500)。遊び方に応じて上がり、上がるほど敵が強くなる。
## 値は static なので、シーンを切り替えても残る(ステージをまたいで持ち越す)。
## GameManager が、ANOTHER のときにこのノードを1つ置く(時間とショットボタンでランクを上げる・デバッグ表示)。
##
## 上がる:
##   時間 … 20 秒ごとに +1(ゲームが動いているあいだ)
##   ショットボタン … 押しているあいだ 0.1 秒ごとに1回と数え、300 回ごとに +1(どの機体も同じ)
##   イグナイト … 単発(レベルを1つ使う)+2 / 全部撃ち +4
##   撃破 … 敵 100 体ごとに +1 / 中ボス +1 / ボス +5(下限も +5)
##   アイテム … 連射速度UP +3 / オプション +5 / 威力UP +6(それぞれ下限も同じだけ上がる)
## 下がる:
##   自爆(残機を失う)… 残機が少ないほど大きく下がる(5:-5 / 4:-10 / 3:-15 / 2:-30 / 1以下:-50)
## 下限:
##   ボス撃破とアイテムで上がり、次のステージに進むと +10。ランクは下限より下がらない
##   コンティニューすると、ランクは下限まで戻る(下限はそのまま)
## 弾幕: ボス・中ボスは最初から ANOTHER 用、ランク 100 から BLACK ANOTHER 用。雑魚はランク 250 から ANOTHER 用
## ランクの段階: 25 ごとに 1 段階(0〜20 段階)。段階で敵の強さが変わる(DifficultyTuning・StageRunner・Enemy が読む)

const MAX_RANK : int = 500
const STEP_SIZE : int = 25
const MAX_STEP : int = 20
## 弾幕の切り替え:
##   ボス・中ボス(分離砲台・援護の列車なども)… ANOTHER を選んだ時点から ANOTHER 用(Another Version)、
##                                              ランク BLACK_BARRAGE_RANK から BLACK ANOTHER 用(Black Version)
##   雑魚 … ランク ANOTHER_BARRAGE_RANK から ANOTHER 用
##   二周目(BLACK ANOTHER。ANOTHER をクリアしたあと)は、ボス・中ボスは最初から BLACK ANOTHER 用、雑魚は最初から ANOTHER 用
const BLACK_BARRAGE_RANK : int = 100
const ANOTHER_BARRAGE_RANK : int = 250

## 弾幕の段階(barrage_tier の値)
enum Tier { HARD, ANOTHER, BLACK }

## ランクが最大(500)のときの倍率。段階ごとに、1 からここまで等分して上がる
const HP_MAX : float = 4.0            ## 敵の硬さ(雑魚)
const BOSS_HP_MAX : float = 2.0       ## 敵の硬さ(ボス・中ボス)。長くなりすぎないように、雑魚より控えめ
## ハザードの敵(置き換わるドローン・強化アイテムを落とすキャリア)の硬さ。倒して取り返す敵なので、ほかより控えめ
const HAZARD_HP_MAX : float = 1.5
## 中ボスの硬さの、もとの倍率(3倍だと一面の中ボスが倒せないほど硬かったので、2倍にした。一面の中ボスはランク0で約10000)
const MIDBOSS_HP_BASE : float = 2.0
## ボスの硬さの、もとの倍率(強化アイテムを最大1.5倍に弱めたので、3倍から半分にした)
const BOSS_HP_BASE : float = 1.5
## ボス・中ボスは、ランクが BOSS_HP_GROW_RANK 上がるごとに、硬さが BOSS_HP_GROW 倍ずつ増えていく(ランク 500 で約 10.8 倍)
const BOSS_HP_GROW_RANK : int = 20
const BOSS_HP_GROW : float = 1.1
## ボス・中ボスが、イグナイトの反射弾から受けるダメージの倍率(反射弾だけで溶けないように)
const BOSS_REFLECT_DAMAGE : float = 0.5
## 敵弾の当たり判定の大きさ(ANOTHER は弾がとても多いので、半分にする)
const BULLET_HITBOX_SCALE : float = 0.5
const FIRE_RATE_MAX : float = 4.0     ## 雑魚の、撃つ頻度
const BOSS_FIRE_RATE_MAX : float = 2.0 ## ボス・中ボスの、撃つ頻度(ANOTHER 用の弾幕が、もともと濃いので控えめ)
const BULLET_SPEED_MAX : float = 1.3  ## 敵弾の速さ(速すぎると、超上級者でも見てよけられないので 1.3 倍まで)
const ITEM_FALL_MAX : float = 4.0     ## アイテムが落ちる速さ
## イグナイトの回復アイテム(被弾で散らばる)の、消える速さ
const IGNITE_ITEM_FADE : float = 2.0
## スコア倍率に足す量(ランク 50 ごとに)
const SCORE_BONUS_PER_50 : float = 0.5

## 強化アイテム(連射速度UP・威力UP)の最大の段階(Player.BOOST_MAX と同じ)
const BOOST_MAX : int = 5
## (preload すると、アイテム・敵のスクリプトがこのクラスを読むので、読み込みが循環する。使うときに load する)
const RATE_ITEM := "res://GameScene/Item/power_up_rate.tscn"
const POWER_ITEM := "res://GameScene/Item/power_up_power.tscn"
const CARRIER := "res://GameScene/Enemy/Hazard/hazard_carrier.tscn"
## 2面の雑魚列車の車両が、強化アイテムを落とす確率
const TRAIN_DROP_CHANCE : float = 0.15
## ハザードキャリア(強化アイテムを落とす中ボス級)が来る、ステージの時間(秒)。最初と、そのあとの間隔
const CARRIER_FIRST : float = 24.0
const CARRIER_INTERVAL : float = 38.0

## 時間で +1 する間隔(秒)
const TIME_INTERVAL : float = 20.0
## ショットボタンを1回と数える間隔(秒)と、+1 に必要な回数
const SHOT_TICK : float = 0.1
const SHOT_TICKS_PER_RANK : int = 300
## 撃破数で +1 する体数
const KILLS_PER_RANK : int = 100

## ANOTHER で遊んでいるか(GameManager が、ステージの始めに入れる)
static var active : bool = false
## 二周目(BLACK ANOTHER)か。ANOTHER をクリアしたら入る(最終ステージのクリアから、二周目に入れる)
static var black_loop : bool = false
static var rank : int = 0
static var floor_rank : int = 0
static var _time : float = 0.0
static var _shot_time : float = 0.0
static var _shot_ticks : int = 0
static var _kills : int = 0
## 最後に変わった理由(デバッグ表示)
static var last_reason : String = ""

## 出撃したとき(機体選択から): 全部 0 から
static func reset_run() -> void:
	carriers_off = false
	black_loop = false
	rank = 0
	floor_rank = 0
	_reset_counters()
	last_reason = "START"

## コンティニュー(ゲームオーバーからやり直し): ランクは下限まで戻る。下限はそのまま
static func on_continue() -> void:
	rank = maxi(floor_rank, 0)
	_reset_counters()
	last_reason = "CONTINUE"

## 次のステージへ進んだ: 下限 +10。ランクはそのまま持ち越す
static func on_next_stage() -> void:
	add(0, 10, "STAGE")

static func _reset_counters() -> void:
	_time = 0.0
	_shot_time = 0.0
	_shot_ticks = 0
	_kills = 0

## ランクを amount 上げ(マイナスなら下げ)、下限を floor_up 上げる
static func add(amount : int, floor_up : int = 0, reason : String = "") -> void:
	if not active:
		return
	floor_rank = clampi(floor_rank + floor_up, 0, MAX_RANK)
	var before := rank
	# 下限より下には下がらない(下限は 0 以上なので、マイナスにもならない)
	rank = clampi(rank + amount, maxi(floor_rank, 0), MAX_RANK)
	if reason != "":
		# 表示は、実際に変わった量(下限で止まったら、止まったぶんだけ)
		last_reason = "%s %+d" % [reason, rank - before] + (" (floor %+d)" % floor_up if floor_up != 0 else "")

## 自爆(残機を失った)。lives は、失う前の残機
static func on_death(lives : int) -> void:
	var drop := 50
	if lives >= 5:
		drop = 5
	elif lives == 4:
		drop = 10
	elif lives == 3:
		drop = 15
	elif lives == 2:
		drop = 30
	add(-drop, 0, "MISS(lives %d)" % lives)

## 敵を倒した(HP が尽きた)
static func on_enemy_killed(enemy : Enemy) -> void:
	if not active:
		return
	_kills += 1
	if _kills >= KILLS_PER_RANK:
		_kills -= KILLS_PER_RANK
		add(1, 0, "KILL x100")
	if enemy.is_midboss and not enemy.has_meta(&"hazard_carrier"):
		add(1, 0, "MIDBOSS")
	# 2面の雑魚列車(の車両)は、ときどき強化アイテムを落とす
	if enemy.scene_file_path.contains("/Train/car_") and randf() < TRAIN_DROP_CHANCE:
		drop_boost(enemy.get_tree(), enemy.global_position)

## 強化アイテム(連射速度UP・威力UP)を1つ落とす。段階の低いほうを落とし、両方とも最大なら落とさない
static func drop_boost(tree : SceneTree, at : Vector2) -> void:
	if not active or tree == null or tree.current_scene == null:
		return
	var player = tree.get_first_node_in_group("player")
	var rate : int = player.get("rate_boost") if player and player.get("rate_boost") != null else 0
	var power : int = player.get("power_boost") if player and player.get("power_boost") != null else 0
	var scene : String
	if rate >= BOOST_MAX and power >= BOOST_MAX:
		return
	elif rate >= BOOST_MAX:
		scene = POWER_ITEM
	elif power >= BOOST_MAX:
		scene = RATE_ITEM
	elif rate == power:
		scene = RATE_ITEM if randf() < 0.5 else POWER_ITEM
	else:
		scene = RATE_ITEM if rate < power else POWER_ITEM
	var item := (load(scene) as PackedScene).instantiate() as Node2D
	item.position = at
	tree.current_scene.add_child.call_deferred(item)

## ステージの最後のボスを倒した
static func on_boss_killed() -> void:
	add(5, 5, "BOSS")

## イグナイトを撃った(full = 全部撃ち)
static func on_ignite(full : bool) -> void:
	add(4 if full else 2, 0, "IGNITE ALL" if full else "IGNITE")

## 今のランクの段階(0〜20)
static func step() -> int:
	return clampi(rank / STEP_SIZE, 0, MAX_STEP) if active else 0

## 段階に応じた倍率(1 から max_scale まで)
static func scale_for(max_scale : float) -> float:
	return 1.0 + (max_scale - 1.0) * float(step()) / MAX_STEP

## 敵の種類(硬さの決め方が違う)
enum Kind { ZAKO, MIDBOSS, BOSS, HAZARD }

static func hp_scale(kind : Kind) -> float:
	match kind:
		Kind.BOSS:
			return boss_hp_grow() * (BOSS_HP_BASE if active else 1.0)
		Kind.MIDBOSS:
			return boss_hp_grow() * (MIDBOSS_HP_BASE if active else 1.0)
		Kind.HAZARD:
			return scale_for(HAZARD_HP_MAX)
	return scale_for(HP_MAX)

## ボス・中ボスの、ランクによる硬さの伸び: ランク 20 ごとに 1.1 倍(掛け算で増えていく)
static func boss_hp_grow() -> float:
	if not active:
		return 1.0
	return pow(BOSS_HP_GROW, float(rank / BOSS_HP_GROW_RANK))

## 当たった敵(の部位)が ANOTHER のボス・中ボスなら、反射弾のダメージの倍率を返す(ほかは 1)
static func reflect_damage_scale(target : Node) -> float:
	if not active:
		return 1.0
	var node := target
	while node:
		if node.has_meta(&"hazard_boss"):
			return BOSS_REFLECT_DAMAGE
		node = node.get_parent()
	return 1.0

## 今のステージの、雑魚の撃つ頻度の上がり方の割合(StageRunner が、ステージの設定から入れる)
static var zako_rate_ratio : float = 1.0

static func fire_rate_scale(boss : bool) -> float:
	if boss:
		return scale_for(BOSS_FIRE_RATE_MAX)
	return 1.0 + (scale_for(FIRE_RATE_MAX) - 1.0) * zako_rate_ratio

static func bullet_speed_scale() -> float:
	return scale_for(BULLET_SPEED_MAX)

static func item_fall_scale() -> float:
	return scale_for(ITEM_FALL_MAX)

## スコア倍率に足す量
static func score_bonus() -> float:
	return SCORE_BONUS_PER_50 * float(rank / 50) if active else 0.0

## 今撃つ弾幕の段階(boss = ボス・中ボスの砲口か)
## 今のステージで、ランクに関係なく BLACK ANOTHER 用の弾幕を撃つか(StageRunner が、ステージの設定から入れる)
## ANOTHER でなくても、敵弾の当たり判定を半分にする(HARD の最終面など。GameManager がステージごとに決める)
static var small_bullet_hitbox : bool = false
static var stage_force_black : bool = false

static func barrage_tier(boss : bool) -> Tier:
	if not active:
		return Tier.HARD
	if stage_force_black:
		return Tier.BLACK
	if boss:
		return Tier.BLACK if black_loop or rank >= BLACK_BARRAGE_RANK else Tier.ANOTHER
	return Tier.ANOTHER if black_loop or rank >= ANOTHER_BARRAGE_RANK else Tier.HARD

## ANOTHER をクリアした: 二周目(BLACK ANOTHER)に入る。ランクと下限はそのまま持ち越す
static func start_black_loop() -> void:
	Achievements.unlock("limit_break")
	black_loop = true
	last_reason = "BLACK ANOTHER"

## 編隊に足す機数(5 段階ごとに +1)
static func extra_units() -> int:
	return step() / 5

# ---------------------------------------------------------------- ノード(時間・ショット・デバッグ表示)

## 自機(型を書くと、自機のスクリプトが読み込まれて、アイテムのシーンと読み込みが循環するので、書かない)
var player
var _label : Label
## ステージの進行役(型を書くと、読み込みが循環するので、書かない)
var _runner
var _next_carrier : float = CARRIER_FIRST
## オンなら、ハザードキャリアを出さない(プラクティスのボスのミッション)
static var carriers_off : bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if OS.is_debug_build():
		var layer := CanvasLayer.new()
		layer.layer = 90
		add_child(layer)
		_label = Label.new()
		_label.add_theme_font_size_override("font_size", 8)
		_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
		_label.add_theme_color_override("font_outline_color", Color.BLACK)
		_label.add_theme_constant_override("outline_size", 3)
		_label.position = Vector2(4, 150)
		layer.add_child(_label)

func _physics_process(delta : float) -> void:
	if not active:
		return
	_time += delta
	while _time >= TIME_INTERVAL:
		_time -= TIME_INTERVAL
		add(1, 0, "TIME")
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
	if player and player._is_alive and InputMap.has_action("UI_Shoot") and Input.is_action_pressed("UI_Shoot"):
		_shot_time += delta
		while _shot_time >= SHOT_TICK:
			_shot_time -= SHOT_TICK
			_shot_ticks += 1
			if _shot_ticks >= SHOT_TICKS_PER_RANK:
				_shot_ticks -= SHOT_TICKS_PER_RANK
				add(1, 0, "SHOT x300")
	_update_carrier()
	if _label:
		_label.text = "HAZARD %d / floor %d\nstep %d  score+%.1f\nshot %d/300  kill %d/100\n%s" % [
			rank, floor_rank, step(), score_bonus(), _shot_ticks, _kills, last_reason]

## ハザードキャリアを、ステージの時間で出す(ボス・中ボスがいるあいだと、強化が両方とも最大のときは出さない)
func _update_carrier() -> void:
	if carriers_off:
		return
	if not is_instance_valid(_runner):
		_runner = get_tree().get_first_node_in_group("stage_runner")
		if _runner == null:
			return
	if _runner.stage_time < _next_carrier:
		return
	var tree := get_tree()
	var busy := not tree.get_nodes_in_group("stage_boss").is_empty() or not tree.get_nodes_in_group("stage_midboss").is_empty()
	if busy or not is_instance_valid(player) or not player._is_alive:
		_next_carrier = _runner.stage_time + 3.0 # 少し待って、もう一度
		return
	_next_carrier = _runner.stage_time + CARRIER_INTERVAL
	if player.rate_boost >= BOOST_MAX and player.power_boost >= BOOST_MAX:
		return
	var carrier := (load(CARRIER) as PackedScene).instantiate() as Enemy
	carrier.set_meta(&"hazard_carrier", true)
	carrier.is_midboss = true # 撃つ頻度の上がり方を、ボス並みに控えめにする
	carrier.path_offset = Vector2(randf_range(-90.0, 90.0), 0.0) + StageCamera.view_offset(_runner)
	var hp := carrier.get_node("HPComponent")
	var scaled := roundi(hp.max_hp * hp_scale(Kind.HAZARD))
	hp.max_hp = scaled
	hp.hp = scaled
	tree.current_scene.add_child(carrier)
	last_reason = "CARRIER t=%.0f" % _runner.stage_time
