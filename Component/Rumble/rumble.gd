extends RefCounted
class_name Rumble
## ゲームパッドの振動。どこからでも static で呼ぶ。つながっている全部のパッドを振動させる(パッドがなければ何もしない)。
##   Rumble.play(Rumble.PLAYER_HIT)
## 強さは [弱いモーター(細かい震え), 強いモーター(重い揺れ), 秒] で決める(0〜1)。

## 被弾して耐えたとき: 短く、はっきり
const PLAYER_HIT : Array[float] = [0.6, 0.45, 0.2]
## 撃墜されたとき: 重く、長め
const PLAYER_DEATH : Array[float] = [0.8, 1.0, 0.45]

## false にすると、振動しない(オプションで切れるようにするとき用)
static var enabled : bool = true

static func play(pattern : Array[float]) -> void:
	if not enabled or pattern.size() < 3:
		return
	for device in Input.get_connected_joypads():
		Input.start_joy_vibration(device, pattern[0], pattern[1], pattern[2])

## 振動を止める(ポーズやゲームオーバーで止めたいとき)
static func stop() -> void:
	for device in Input.get_connected_joypads():
		Input.stop_joy_vibration(device)
