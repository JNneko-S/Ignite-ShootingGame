extends RefCounted
class_name RunState
## シーンを切り替えても残る「共有の状態」(static)を、まとめて戻す場所。
## 状態を足したら、ここの戻す処理にも足す(戻し忘れると、前のプレイ・前のステージの状態が次に残る不具合になる)。
##   begin_run()   … 出撃したとき(機体選択から)。一回のプレイの状態を、全部まっさらにする
##   begin_stage() … ステージのシーンが始まるとき(GameManager)。ステージをまたいで残ると困るものを戻す
##   to_title()    … タイトルに戻ったとき。二周目へ入る途中でなければ、引き継ぎなどを捨てる
## クリアタイムの時計(プレイしている時間)も、ここで持つ。

## 一回のプレイの、プレイしている時間(秒。ポーズ中は進まない)と、今のステージの時間(秒)
static var run_clock : float = 0.0
static var stage_clock : float = 0.0

## コンティニューで始め直す場所(StageData の Continue Checkpoint Tag の待機を越えたところ)。
## checkpoint_scene が空なら、記録はない(ステージの最初から)
static var checkpoint_scene : String = ""
static var checkpoint_time : float = 0.0
## コンティニューで、記録したところから始め直しているところか(StageRunner が使ったら false に戻す)
static var checkpoint_restart : bool = false

## 記録したところを捨てる(ステージをクリアしたとき・出撃し直したとき・タイトルに戻ったとき)
static func clear_checkpoint() -> void:
	checkpoint_scene = ""
	checkpoint_time = 0.0
	checkpoint_restart = false

static func begin_run() -> void:
	RunConfig.loop = 1
	RunConfig.continues_used = 0
	RunConfig.ignite_counter_kills = 0
	RunConfig.reset_loop_stats(true)
	RunConfig.consecutive_game_overs = 0
	HazardRank.reset_run()
	ScoreBoard.begin_run()
	_clear_carry()
	clear_checkpoint()
	TitleScreen.another_round_pending = false
	run_clock = 0.0
	stage_clock = 0.0

static func begin_stage() -> void:
	EnemyShooter.release_fire() # 前のステージの「全員撃つな」を残さない
	HitStop.reset()
	Engine.time_scale = 1.0
	DifficultyTuning._cache.clear()
	DifficultyTuning.hard_plus = false
	DifficultyTuning.zako_interval_scale = 1.0
	EnemyBullet.set_chain_allowed(false)
	BossDiveState._diving.clear()
	CrossFireState._firing.clear()
	ItemDrop.enabled = true
	stage_clock = 0.0
	RunConfig.stage_shot_damage_used = false

static func to_title() -> void:
	clear_checkpoint()
	if TitleScreen.another_round_pending:
		return # 二周目へ入る途中: 引き継ぎは、まだ使う
	_clear_carry()
	EnemyShooter.release_fire()
	HitStop.reset()
	Engine.time_scale = 1.0

static func _clear_carry() -> void:
	StageCarry.pending = false
	StageCarry.arriving = false
	StageCarry.through_clouds = false

## プレイしている時間を進める(GameManager が、ポーズしていないあいだ毎フレーム呼ぶ)
static func tick(delta : float) -> void:
	run_clock += delta
	stage_clock += delta

## 秒を「分:秒.百分の一」の文字にする
static func format_time(seconds : float) -> String:
	var total := maxf(seconds, 0.0)
	var m := int(total / 60.0)
	var s := fmod(total, 60.0)
	return "%d:%05.2f" % [m, s]
