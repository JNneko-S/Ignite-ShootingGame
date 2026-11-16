extends RefCounted
class_name DebugTools
## デバッグ機能の状態(シーンを切り替えても残る)。
## ポーズ画面で Shift + F1 + Space を同時に押し、2秒以内に「debug」と打つと使えるようになる(Unlocked)。
## 使えるようになったら、ゲーム中に F1 でデバッグパネル(DebugPanel)が開く。

## デバッグ機能が使えるか(隠しコマンドで解放する。ゲームを終了するまで残る)
static var unlocked : bool = false
## 一度でもデバッグ機能を使ったか。使ったプレイでは、ハイスコアを保存しない
static var used : bool = false
## 無敵(当たっても何も起きない)
static var invincible : bool = false
## 0 より大きければ、次にステージを読み込んだとき、この秒数から始める(出撃の演出もしない)。読んだら 0 に戻る
static var pending_start_time : float = 0.0
## 次にステージを読み込んだとき、出撃の演出を飛ばす(読んだら false に戻る)
static var skip_intro_once : bool = false
