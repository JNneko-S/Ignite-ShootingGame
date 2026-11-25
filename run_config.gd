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

## ノーコンティニューで、まだ一周目なら true(クリアしたら二周目に入れる)
static func can_enter_second_loop() -> bool:
	return loop == 1 and continues_used == 0

## この回数続けてゲームオーバーになったら、やり直しのときに難易度を1つ下げる
const EASE_AFTER_GAME_OVERS : int = 5
