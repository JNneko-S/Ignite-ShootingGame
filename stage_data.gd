@tool
extends Resource
class_name StageData
## 1ステージ分のタイムライン。.tres で保存して、StageRunner に割り当てる。

@export var stage_name : String = "Stage 1"
## イベントの並び。順番は自由(time の小さい順に実行される)
@export var events : Array[StageEvent] = []
