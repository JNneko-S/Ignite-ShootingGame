extends Resource
class_name MovePattern
## MoveStep を順番に並べた移動パターン。.tres で保存して敵に割り当てる。

## true なら出現位置をこのパターンの start_position にする
@export var override_start_position : bool = true
@export var start_position : Vector2 = Vector2(576, -40)
@export var steps : Array[MoveStep] = []
