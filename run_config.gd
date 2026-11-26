extends RefCounted
class_name RunConfig
## 機体選択の画面で選んだ内容を、ステージへ渡す入れ物。シーンを切り替えても残る(static)。
## GameManager は、Has Selection がオンなら、シーンに書いてある難易度の代わりに、ここの難易度を使う。
## ゲームオーバーからやり直したときも、同じ選択のまま。

## 機体選択の画面を通って出撃したか(通っていなければ、シーンの設定のまま)
static var has_selection : bool = false
## 選んだ難易度(0 = EASY, 1 = NORMAL, 2 = HARD, 3 = ANOTHER)
static var difficulty : int = 1
## 隠し難易度 ANOTHER の番号(弾幕は HARD を元に、ハザードランクで強くなる)
const ANOTHER : int = 3
## 選んだ機体
static var ship : ShipData = null
## 続けてゲームオーバーになった回数(ステージをクリアするか、機体選択から出撃し直すと 0 に戻る)
static var consecutive_game_overs : int = 0
## 何周目か(1 = 一周目)。ノーコンティニューで最終面をクリアすると 2 になり、二周目(Another Round)に入る
static var loop : int = 1
## この出撃で、コンティニュー(ゲームオーバーからのやり直し)をした回数
static var continues_used : int = 0
## この出撃で、イグナイトのチャンス(おとりの雑魚)を、イグナイトで返して倒した数(エンドBの選択条件)
static var ignite_counter_kills : int = 0

## 隠しボスを倒したか(二周目をこれで終えると、クリアの合図が congratulation! になる)。隠しボスが倒されたときに true にする
static var hidden_boss_defeated : bool = false

## この出撃で、ショット(自機・子機の弾)で敵にダメージを与えたか。与えていなければ「イグナイトだけ」で戦っている(実績)
static var shot_damage_used : bool = false

## ---- エンドB(裏ボス Union)の条件に使う、1周ぶんの記録(二周目に入ると、周の記録は数え直す) ----
## この周で、イグナイトを使って(発動中、または返した弾のとどめで)倒した中ボス・ボスの数
static var loop_ignite_boss_kills : int = 0
## この周で、イグナイトを全消費した(Lv5 を長押しで使い切った)回数
static var loop_full_uses : int = 0
## この周の被弾数
static var loop_hits : int = 0
## この周で、ショットを使わずに(イグナイトだけで)クリアしたステージがあるか
static var loop_ignite_only_stage : bool = false
## 一周目で、ミス(撃墜)したか(二周目に入っても残す)
static var loop1_missed : bool = false
## 今のステージで、ショットで敵にダメージを与えたか(ステージが始まるたびに戻す)
static var stage_shot_damage_used : bool = false

## 周の記録を戻す。whole_run なら、一周目のミスの記録も戻す(出撃し直したとき)
static func reset_loop_stats(whole_run : bool) -> void:
	loop_ignite_boss_kills = 0
	loop_full_uses = 0
	loop_hits = 0
	loop_ignite_only_stage = false
	stage_shot_damage_used = false
	if whole_run:
		loop1_missed = false

## 二周目の作り直し(二周目用のステージ・弾幕・雑魚の隊列)を使うか。二周目で、ANOTHER でないとき
## (ANOTHER の二周目は BLACK ANOTHER なので、ANOTHER の弾幕のまま)
static func second_round() -> bool:
	return loop >= 2 and not (has_selection and difficulty == ANOTHER)

## ノーコンティニューで、まだ一周目なら true(クリアしたら二周目に入れる)
static func can_enter_second_loop() -> bool:
	return loop == 1 and continues_used == 0

## この回数続けてゲームオーバーになったら、やり直しのときに難易度を1つ下げる
const EASE_AFTER_GAME_OVERS : int = 5
