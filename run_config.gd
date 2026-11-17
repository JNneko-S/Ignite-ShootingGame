extends RefCounted
class_name RunConfig
## 機体選択の画面で選んだ内容を、ステージへ渡す入れ物。シーンを切り替えても残る(static)。
## GameManager は、Has Selection がオンなら、シーンに書いてある難易度の代わりに、ここの難易度を使う。
## ゲームオーバーからやり直したときも、同じ選択のまま。

## 機体選択の画面を通って出撃したか(通っていなければ、シーンの設定のまま)
static var has_selection : bool = false
## 選んだ難易度(0 = EASY, 1 = NORMAL, 2 = HARD)
static var difficulty : int = 1
## 選んだ機体
static var ship : ShipData = null
## 続けてゲームオーバーになった回数(ステージをクリアするか、機体選択から出撃し直すと 0 に戻る)
static var consecutive_game_overs : int = 0
## この回数続けてゲームオーバーになったら、やり直しのときに難易度を1つ下げる
const EASE_AFTER_GAME_OVERS : int = 5
