extends Resource
class_name MovePattern
## MoveStep を順番に並べた移動パターン。.tres で保存して敵に割り当てる。

## true なら出現位置をこのパターンの start_position にする
@export var override_start_position : bool = true
@export var start_position : Vector2 = Vector2(576, -40)
@export var steps : Array[MoveStep] = []
## 0 以上なら、最後のステップのあと、このステップ(0 から数える)に戻って、倒されるまで動き続ける(消えない)。
## ボスのように、いつまで戦うか分からない敵に使う。-1 なら、最後のステップのあと消える(画面の外へ出た想定)
@export var loop_from_step : int = -1
